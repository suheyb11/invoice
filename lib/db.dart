// Firebase Cloud Firestore: data structure, business rules and every query in one place.
//
// All users work on the same company data:
//   company/main/customers/{id}
//   company/main/products/{id}
//   company/main/quotations/{id}     (items are stored inside the document)
//   company/main/invoices/{id}       (items are stored inside the document)
//   company/main/payments/{id}       (invoice_id field)
//   company/main/activity/{id}       (every action: who, what, when)
//   company/main/meta/settings       (company info, prefixes, counters)
//   members/{uid}                    (role, active, privileges)
//
// Privileges are checked here (friendly message) and again in firestore.rules.
// Only simple "where equal" queries are used, so no Firestore indexes are needed.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'widgets.dart';

typedef Json = Map<String, dynamic>;

class AppDb {
  static FirebaseFirestore get fs => FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser!.uid;
  static DocumentReference<Json> get companyRef => fs.collection('company').doc('main');
  static CollectionReference<Json> col(String name) => companyRef.collection(name);
  static DocumentReference<Json> get settingsRef => companyRef.collection('meta').doc('settings');
  static DocumentReference<Json> memberRef(String id) => fs.collection('members').doc(id);

  // This email becomes admin automatically on first sign in (also in firestore.rules).
  static const adminEmail = 'suheyb0102@gmail.com';

  static String docTable(String type) => type == 'quote' ? 'quotations' : 'invoices';

  // Privilege key for a document action, e.g. perm('quote', 'edit') -> 'quotes_edit'.
  static String perm(String type, String action) => '${type == 'quote' ? 'quotes' : 'invoices'}_$action';
  static String _now() => DateTime.now().toIso8601String();

  static final Map<String, String> defaultSettings = {
    'company_name': 'My Company',
    'company_address': 'Mogadishu, Somalia',
    'company_phone': '',
    'company_email': '',
    'currency': '\$',
    'quote_prefix': 'QT-',
    'invoice_prefix': 'INV-',
    'default_tax': '0',
    'quote_valid_days': '14',
    'invoice_due_days': '30',
    'quote_terms': 'This quotation is valid until the date shown above.',
    'invoice_terms': 'Payment is due by the due date. Thank you for your business.',
    'default_notes': '',
    'theme': 'system',
  };

  // ============================================================ SETTINGS
  static Future<Map<String, String>> getSettings() async {
    final m = <String, String>{};
    m.addAll(defaultSettings);
    final snap = await settingsRef.get();
    final data = snap.data();
    if (data != null) {
      data.forEach((k, v) {
        if (v != null && k != 'quote_next' && k != 'invoice_next' && k != 'migrated') m[k] = v.toString();
      });
    }
    return m;
  }

  static Future<void> saveSettings(Map<String, String> values) async {
    _require('settings');
    await settingsRef.set(values, SetOptions(merge: true));
    App.settings = await getSettings();
    await _log('settings', 'settings', 'Company settings changed');
  }

  // Light / dark mode is personal, so it is saved on the member, not the company.
  static Future<void> saveTheme(String theme) async {
    await memberRef(uid).update({'theme': theme});
    me?.theme = theme;
  }

  // ============================================================ MEMBERS & PRIVILEGES
  static Member? me;

  static bool can(String p) => me?.can(p) ?? false;
  static bool get isAdmin => (me?.active ?? false) && me!.isAdmin;

  static void _require(String p) {
    if (!can(p)) throw Exception('You do not have permission to: ${(permLabels[p] ?? p).toLowerCase()}. Ask the admin.');
  }

  // Reads (or creates on first sign in) the member record of the signed-in user.
  // New users wait for the admin to approve them; the admin email is approved at once.
  static Future<Member> loadMember() async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = memberRef(user.uid);
    var snap = await ref.get();
    if (!snap.exists) {
      final admin = (user.email ?? '').toLowerCase() == adminEmail;
      await ref.set({
        'email': user.email ?? '',
        'role': admin ? 'admin' : 'staff',
        'active': admin,
        'perms': <String, bool>{},
        'created_at': _now(),
      });
      snap = await ref.get();
    }
    me = Member.fromMap(snap.id, snap.data()!);
    return me!;
  }

  static Stream<Member?> watchMe() {
    return memberRef(uid).snapshots().map((s) => s.exists ? Member.fromMap(s.id, s.data()!) : null);
  }

  static Future<List<Member>> members() async {
    final snap = await fs.collection('members').get();
    final list = snap.docs.map((d) => Member.fromMap(d.id, d.data())).toList();
    // Waiting for approval first, then admins, then by email.
    int rank(Member m) => !m.active ? 0 : (m.isAdmin ? 1 : 2);
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.email.toLowerCase().compareTo(b.email.toLowerCase());
    });
    return list;
  }

  static Future<void> saveMember(Member m, Member before) async {
    if (!isAdmin) throw Exception('Only the admin can change user access.');
    if (m.uid == uid) throw Exception('You cannot change your own access.');
    final perms = <String, bool>{};
    for (final k in permLabels.keys) {
      if (m.perms[k] == true) perms[k] = true;
    }
    await memberRef(m.uid).update({'role': m.role, 'active': m.active, 'perms': perms});

    final changes = <String>[];
    if (m.active != before.active) changes.add(m.active ? 'approved' : 'blocked');
    if (m.role != before.role) changes.add('role ${m.role}');
    final added = perms.keys.where((k) => before.perms[k] != true).length;
    final removed = before.perms.keys.where((k) => before.perms[k] == true && perms[k] != true).length;
    if (added > 0) changes.add('+$added privilege(s)');
    if (removed > 0) changes.add('-$removed privilege(s)');
    await _log('member', m.uid, changes.isEmpty ? 'Access saved' : 'Access changed: ${changes.join(', ')}', label: m.email);
  }

  // Company-wide action log, newest first (admin panel).
  static Future<List<LogEntry>> allActivity({String? byUid, int limit = 300}) async {
    final QuerySnapshot<Json> snap;
    if (byUid != null) {
      snap = await col('activity').where('by_uid', isEqualTo: byUid).get();
    } else {
      snap = await col('activity').orderBy('created_at', descending: true).limit(limit).get();
    }
    final list = snap.docs.map((d) => LogEntry.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // One time, for the admin: copy data from the old per-user storage
  // (users/{uid}/...) into the shared company storage.
  static Future<void> migratePersonalData() async {
    if (!isAdmin) return;
    final company = await settingsRef.get();
    if (company.data()?['migrated'] == true) return;
    final old = fs.collection('users').doc(uid);
    for (final t in ['customers', 'products', 'quotations', 'invoices', 'payments', 'activity']) {
      final snap = await old.collection(t).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = fs.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          final data = d.data();
          if (t == 'activity') {
            data['by_uid'] = uid;
            data['by_email'] = me!.email;
            data['label'] = data['label'] ?? '';
          }
          batch.set(col(t).doc(d.id), data);
        }
        await batch.commit();
      }
    }
    final oldSettings = await old.collection('meta').doc('settings').get();
    final values = <String, dynamic>{};
    if (!company.exists && oldSettings.exists) values.addAll(oldSettings.data()!);
    values['migrated'] = true;
    await settingsRef.set(values, SetOptions(merge: true));
  }

  // Reads the counter from settings (inside a transaction) and returns the
  // next number, e.g. INV-2026-0001. The caller must write `counterField: n + 1`.
  static String _formatNumber(Json? settings, String type, int n) {
    final prefixKey = type == 'quote' ? 'quote_prefix' : 'invoice_prefix';
    final prefix = (settings?[prefixKey] ?? defaultSettings[prefixKey]).toString();
    return '$prefix${DateTime.now().year}-${n.toString().padLeft(4, '0')}';
  }

  static int _counter(Json? settings, String type) {
    final v = settings?[type == 'quote' ? 'quote_next' : 'invoice_next'];
    if (v is num) return v.toInt();
    return int.tryParse(toText(v)) ?? 1;
  }

  // ============================================================ ACTIVITY LOG
  // Every log line remembers who did it, so the admin can see all actions.
  static Json _logData(String type, String id, String action, {String label = ''}) {
    return {
      'doc_type': type,
      'doc_id': id,
      'action': action,
      'label': label,
      'by_uid': uid,
      'by_email': me?.email ?? FirebaseAuth.instance.currentUser?.email ?? '',
      'created_at': _now(),
    };
  }

  static Future<void> _log(String type, String id, String action, {String label = ''}) async {
    await col('activity').add(_logData(type, id, action, label: label));
  }

  static Future<List<Activity>> activity(String type, String id) async {
    final snap = await col('activity').where('doc_id', isEqualTo: id).where('doc_type', isEqualTo: type).get();
    final list = snap.docs.map((d) => Activity(toText(d.data()['action']), toText(d.data()['created_at']), byEmail: toText(d.data()['by_email']))).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ============================================================ CUSTOMERS
  static Future<List<Customer>> customers({String search = ''}) async {
    final snap = await col('customers').get();
    final invoices = await col('invoices').get();
    final s = search.toLowerCase().trim();

    final list = <Customer>[];
    for (final d in snap.docs) {
      final c = Customer.fromMap(d.id, d.data());
      if (s.isNotEmpty && !c.name.toLowerCase().contains(s) && !c.phone.contains(s) && !c.email.toLowerCase().contains(s)) {
        continue;
      }
      for (final i in invoices.docs) {
        final m = i.data();
        if (m['customer_id'] != c.id) continue;
        final status = toText(m['status']);
        if (status != 'cancelled') c.invoiceCount++;
        if (status == 'sent' || status == 'partial' || status == 'overdue') {
          c.balance += toDouble(m['total']) - toDouble(m['paid']);
        }
      }
      c.balance = round2(c.balance);
      list.add(c);
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  static Future<Customer?> customer(String id) async {
    final list = await customers();
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  static Future<String> saveCustomer(Customer c) async {
    _require('customers');
    if (c.name.trim().isEmpty) throw Exception('Customer name is required.');
    if (c.id == null) {
      final m = c.toMap();
      m['created_at'] = _now();
      final ref = await col('customers').add(m);
      await _log('customer', ref.id, 'Customer added', label: c.name);
      return ref.id;
    }
    final batch = fs.batch();
    batch.update(col('customers').doc(c.id), c.toMap());
    // Keep the customer details on their documents up to date.
    for (final t in ['quotations', 'invoices']) {
      final docs = await col(t).where('customer_id', isEqualTo: c.id).get();
      for (final d in docs.docs) {
        batch.update(d.reference, {
          'customer_name': c.name,
          'customer_phone': c.phone,
          'customer_email': c.email,
          'customer_address': c.address,
        });
      }
    }
    await batch.commit();
    await _log('customer', c.id!, 'Customer edited', label: c.name);
    return c.id!;
  }

  static Future<void> deleteCustomer(String id) async {
    _require('customers');
    final q = await col('quotations').where('customer_id', isEqualTo: id).get();
    final i = await col('invoices').where('customer_id', isEqualTo: id).get();
    final count = q.docs.length + i.docs.length;
    if (count > 0) throw Exception('This customer has $count document(s). Delete those documents first.');
    final snap = await col('customers').doc(id).get();
    await col('customers').doc(id).delete();
    await _log('customer', id, 'Customer deleted', label: toText(snap.data()?['name']));
  }

  // ============================================================ PRODUCTS
  static Future<List<Product>> products({String search = '', bool includeInactive = false}) async {
    final snap = await col('products').get();
    final s = search.toLowerCase().trim();
    final list = <Product>[];
    for (final d in snap.docs) {
      final p = Product.fromMap(d.id, d.data());
      if (!includeInactive && !p.isActive) continue;
      if (s.isNotEmpty && !p.name.toLowerCase().contains(s) && !p.description.toLowerCase().contains(s)) continue;
      list.add(p);
    }
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  static Future<String> saveProduct(Product p) async {
    _require('products');
    if (p.name.trim().isEmpty) throw Exception('Product name is required.');
    if (p.price < 0) throw Exception('Price cannot be negative.');
    if (p.id == null) {
      final m = p.toMap();
      m['created_at'] = _now();
      final ref = await col('products').add(m);
      await _log('product', ref.id, 'Product added', label: p.name);
      return ref.id;
    }
    await col('products').doc(p.id).update(p.toMap());
    await _log('product', p.id!, 'Product edited', label: p.name);
    return p.id!;
  }

  // Returns a message for the user. Used products are archived, not deleted.
  static Future<String> deleteProduct(String id) async {
    _require('products');
    final name = toText((await col('products').doc(id).get()).data()?['name']);
    final a = await col('quotations').where('product_ids', arrayContains: id).limit(1).get();
    final b = await col('invoices').where('product_ids', arrayContains: id).limit(1).get();
    if (a.docs.isNotEmpty || b.docs.isNotEmpty) {
      await col('products').doc(id).update({'is_active': false});
      await _log('product', id, 'Product archived', label: name);
      return 'Product is used in documents, so it was archived instead of deleted.';
    }
    await col('products').doc(id).delete();
    await _log('product', id, 'Product deleted', label: name);
    return 'Product deleted.';
  }

  // ============================================================ DOCUMENTS
  static Future<List<Doc>> docs(String type, {String status = 'all', String search = '', String? customerId}) async {
    Query<Json> q = col(docTable(type));
    if (status != 'all') q = q.where('status', isEqualTo: status);
    if (customerId != null) q = q.where('customer_id', isEqualTo: customerId);
    final snap = await q.get();
    final s = search.toLowerCase().trim();
    final list = <Doc>[];
    for (final d in snap.docs) {
      final doc = Doc.fromMap(d.id, d.data(), type);
      if (s.isNotEmpty && !doc.number.toLowerCase().contains(s) && !doc.customerName.toLowerCase().contains(s)) continue;
      list.add(doc);
    }
    // newest first
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.number.compareTo(a.number);
    });
    return list;
  }

  static Future<Doc?> doc(String type, String id) async {
    final snap = await col(docTable(type)).doc(id).get();
    if (!snap.exists) return null;
    return Doc.fromMap(snap.id, snap.data()!, type);
  }

  static bool canEdit(Doc doc) {
    if (doc.isQuote) return doc.status != 'converted';
    return (doc.status == 'draft' || doc.status == 'sent' || doc.status == 'overdue') && doc.paid == 0;
  }

  // Invoice status from its numbers (draft and cancelled never change by themselves).
  static String invoiceStatus(String status, double total, double paid, String due) {
    if (status == 'draft' || status == 'cancelled') return status;
    if (paid >= total - 0.004) return 'paid';
    if (due.isNotEmpty && due.compareTo(today()) < 0) return 'overdue';
    if (paid > 0) return 'partial';
    return 'sent';
  }

  static Map<String, double> _qtyByProduct(List<DocItem> items) {
    final m = <String, double>{};
    for (final it in items) {
      if (it.productId == null) continue;
      m[it.productId!] = (m[it.productId!] ?? 0) + it.qty;
    }
    return m;
  }

  // Changes stock inside a transaction. change: productId -> amount (+ give back, - take).
  // Firestore rule: all reads must happen before writes, so call this after your
  // own reads and before your own writes.
  static Future<void> _changeStock(Transaction tx, Map<String, double> change) async {
    final refs = <String, DocumentReference<Json>>{};
    final snaps = <String, DocumentSnapshot<Json>>{};
    for (final pid in change.keys) {
      if (change[pid] == 0) continue;
      refs[pid] = col('products').doc(pid);
      snaps[pid] = await tx.get(refs[pid]!);
    }
    for (final pid in snaps.keys) {
      final data = snaps[pid]!.data();
      if (data == null || data['track_stock'] != true) continue;
      final stock = toDouble(data['stock']);
      final newStock = stock + change[pid]!;
      if (newStock < 0) {
        throw Exception('Not enough stock for ${toText(data['name'])}: available ${qtyText(stock)}, needed ${qtyText(-change[pid]!)}.');
      }
    }
    for (final pid in snaps.keys) {
      final data = snaps[pid]!.data();
      if (data == null || data['track_stock'] != true) continue;
      tx.update(refs[pid]!, {'stock': toDouble(data['stock']) + change[pid]!});
    }
  }

  static Map<String, double> _negative(Map<String, double> m) {
    return m.map((k, v) => MapEntry(k, -v));
  }

  static Future<String> saveDoc(Doc doc) async {
    _require(perm(doc.type, doc.id == null ? 'create' : 'edit'));
    if (doc.customerId.isEmpty) throw Exception('Please select a customer.');
    if (doc.items.isEmpty) throw Exception('Add at least one item.');
    for (final it in doc.items) {
      if (it.description.trim().isEmpty) throw Exception('Every item needs a description.');
      if (it.qty <= 0) throw Exception('Quantity must be more than zero (${it.description}).');
      if (it.unitPrice < 0) throw Exception('Price cannot be negative (${it.description}).');
    }
    if (doc.dueDate.isNotEmpty && doc.dueDate.compareTo(doc.date) < 0) {
      throw Exception(doc.isQuote ? 'Valid-until date cannot be before the quotation date.' : 'Due date cannot be before the invoice date.');
    }
    doc.recalc();

    // Save a copy of the customer details on the document (used by lists and PDF).
    final c = await col('customers').doc(doc.customerId).get();
    if (!c.exists) throw Exception('Customer not found.');
    final cu = Customer.fromMap(c.id, c.data()!);
    doc.customerName = cu.name;
    doc.customerPhone = cu.phone;
    doc.customerEmail = cu.email;
    doc.customerAddress = cu.address;

    final t = docTable(doc.type);

    // ---------- new document
    if (doc.id == null) {
      final ref = col(t).doc();
      await fs.runTransaction((tx) async {
        final settings = (await tx.get(settingsRef)).data();
        final n = _counter(settings, doc.type);
        doc.number = _formatNumber(settings, doc.type, n);
        final m = doc.toMap();
        m['created_at'] = _now();
        m['updated_at'] = _now();
        tx.set(ref, m);
        tx.set(settingsRef, {doc.type == 'quote' ? 'quote_next' : 'invoice_next': n + 1}, SetOptions(merge: true));
      });
      await _log(doc.type, ref.id, 'Created', label: doc.number);
      return ref.id;
    }

    // ---------- edit existing document
    final ref = col(t).doc(doc.id);
    var number = doc.number;
    await fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Document not found.');
      final old = Doc.fromMap(snap.id, snap.data()!, doc.type);
      number = old.number;
      if (!canEdit(old)) throw Exception('This ${doc.title.toLowerCase()} can no longer be edited.');

      // Invoice already took stock: give old quantities back, take new ones.
      if (!doc.isQuote && old.stockApplied == 1) {
        final change = _qtyByProduct(old.items);
        _qtyByProduct(doc.items).forEach((pid, q) {
          change[pid] = (change[pid] ?? 0) - q;
        });
        await _changeStock(tx, change);
      }

      final m = doc.toMap();
      m.remove('number');
      m.remove('paid');
      m.remove('stock_applied');
      m.remove('link_id');
      m['status'] = doc.isQuote ? old.status : invoiceStatus(old.status, doc.total, old.paid, doc.dueDate);
      m['updated_at'] = _now();
      tx.update(ref, m);
    });
    await _log(doc.type, doc.id!, 'Edited', label: number);
    return doc.id!;
  }

  // Run on start-up and on the dashboard: expire old quotes, mark overdue invoices.
  // Only users who may edit those documents update them.
  static Future<void> refreshStatuses() async {
    final now = today();
    final batch = fs.batch();
    var changes = 0;

    if (can('quotes_edit')) {
      final quotes = await col('quotations').where('status', isEqualTo: 'sent').get();
      for (final d in quotes.docs) {
        final due = toText(d.data()['due_date']);
        if (due.isNotEmpty && due.compareTo(now) < 0) {
          batch.update(d.reference, {'status': 'expired'});
          batch.set(col('activity').doc(), _logData('quote', d.id, 'Expired', label: toText(d.data()['number'])));
          changes++;
        }
      }
    }

    if (can('invoices_edit')) {
      final invoices = await col('invoices').where('status', whereIn: ['sent', 'partial', 'overdue']).get();
      for (final d in invoices.docs) {
        final m = d.data();
        final old = toText(m['status']);
        final s = invoiceStatus(old, toDouble(m['total']), toDouble(m['paid']), toText(m['due_date']));
        if (s != old) {
          batch.update(d.reference, {'status': s});
          if (s == 'overdue') batch.set(col('activity').doc(), _logData('invoice', d.id, 'Became overdue', label: toText(m['number'])));
          changes++;
        }
      }
    }
    if (changes > 0) await batch.commit();
  }

  static Future<void> setStatus(String type, String id, String status) async {
    _require(perm(type, 'edit'));
    final ref = col(docTable(type)).doc(id);
    String logText = 'Status changed to ${status.toUpperCase()}';
    String number = '';

    await fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Document not found.');
      final d = Doc.fromMap(snap.id, snap.data()!, type);
      number = d.number;
      final update = <String, dynamic>{'updated_at': _now()};

      if (type == 'invoice') {
        if (status == 'sent') {
          if (d.status != 'draft') throw Exception('Only a draft invoice can be issued.');
          if (d.stockApplied == 0) await _changeStock(tx, _negative(_qtyByProduct(d.items)));
          update['stock_applied'] = 1;
          update['status'] = invoiceStatus('sent', d.total, d.paid, d.dueDate);
          logText = 'Issued to customer';
        } else if (status == 'cancelled' || status == 'draft') {
          if (d.paid > 0) throw Exception('This invoice has payments. Delete the payments first.');
          if (d.stockApplied == 1) await _changeStock(tx, _qtyByProduct(d.items));
          update['stock_applied'] = 0;
          update['status'] = status;
        } else {
          update['status'] = status;
        }
      } else {
        if (d.status == 'converted') throw Exception('A converted quotation cannot change status.');
        update['status'] = status;
      }
      tx.update(ref, update);
    });
    await _log(type, id, logText, label: number);
  }

  static Future<String> convertQuote(String quoteId) async {
    _require('quotes_edit');
    _require('invoices_create');
    final dueDays = int.tryParse(App.settings['invoice_due_days'] ?? '30') ?? 30;
    final invoiceTerms = App.settings['invoice_terms'] ?? '';
    final quoteRef = col('quotations').doc(quoteId);
    final invoiceRef = col('invoices').doc();
    String quoteNumber = '';
    String invoiceNumber = '';

    await fs.runTransaction((tx) async {
      final qSnap = await tx.get(quoteRef);
      final settings = (await tx.get(settingsRef)).data();
      if (!qSnap.exists) throw Exception('Quotation not found.');
      final q = Doc.fromMap(qSnap.id, qSnap.data()!, 'quote');
      if (q.status == 'converted') throw Exception('Already converted to an invoice.');
      if (q.status == 'rejected') throw Exception('A rejected quotation cannot be converted.');

      final n = _counter(settings, 'invoice');
      quoteNumber = q.number;
      invoiceNumber = _formatNumber(settings, 'invoice', n);

      final start = today();
      final inv = Doc(
        type: 'invoice',
        number: invoiceNumber,
        customerId: q.customerId,
        customerName: q.customerName,
        customerPhone: q.customerPhone,
        customerEmail: q.customerEmail,
        customerAddress: q.customerAddress,
        date: start,
        dueDate: addDays(start, dueDays),
        status: 'draft',
        discountType: q.discountType,
        discountValue: q.discountValue,
        notes: q.notes,
        terms: invoiceTerms,
        linkId: quoteId,
        items: q.items.map((i) => i.copy()).toList(),
      );
      inv.recalc();
      final m = inv.toMap();
      m['created_at'] = _now();
      m['updated_at'] = _now();

      tx.set(invoiceRef, m);
      tx.update(quoteRef, {'status': 'converted', 'link_id': invoiceRef.id, 'updated_at': _now()});
      tx.set(settingsRef, {'invoice_next': n + 1}, SetOptions(merge: true));
    });

    final batch = fs.batch();
    batch.set(col('activity').doc(), _logData('quote', quoteId, 'Converted to invoice $invoiceNumber', label: quoteNumber));
    batch.set(col('activity').doc(), _logData('invoice', invoiceRef.id, 'Created from quotation $quoteNumber', label: invoiceNumber));
    await batch.commit();
    return invoiceRef.id;
  }

  static Future<String> duplicateDoc(String type, String id) async {
    final old = await doc(type, id);
    if (old == null) throw Exception('Document not found.');
    final fresh = Doc.empty(type);
    fresh.customerId = old.customerId;
    fresh.discountType = old.discountType;
    fresh.discountValue = old.discountValue;
    fresh.notes = old.notes;
    fresh.terms = old.terms;
    fresh.items = old.items.map((i) => i.copy()).toList();
    return saveDoc(fresh);
  }

  static Future<void> deleteDoc(String type, String id) async {
    _require(perm(type, 'delete'));
    final d = await doc(type, id);
    if (d == null) return;

    if (type == 'invoice') {
      if (d.status != 'draft' && d.status != 'cancelled') {
        throw Exception('Only draft or cancelled invoices can be deleted. Cancel it first.');
      }
      final p = await col('payments').where('invoice_id', isEqualTo: id).limit(1).get();
      if (p.docs.isNotEmpty) throw Exception('Delete the payments of this invoice first.');
    } else {
      if (d.status == 'converted') throw Exception('This quotation was converted to an invoice and cannot be deleted.');
    }

    final batch = fs.batch();
    // Give the quotation back its "accepted" status.
    if (type == 'invoice' && d.linkId != null) {
      final q = await doc('quote', d.linkId!);
      if (q != null && q.status == 'converted') {
        batch.update(col('quotations').doc(q.id), {'status': 'accepted', 'link_id': null});
        batch.set(col('activity').doc(), _logData('quote', q.id!, 'Linked invoice ${d.number} was deleted', label: q.number));
      }
    }
    // The history is kept so the admin can still see who deleted what.
    batch.set(col('activity').doc(), _logData(type, id, 'Deleted', label: d.number));
    batch.delete(col(docTable(type)).doc(id));
    await batch.commit();
  }

  // ============================================================ PAYMENTS
  static Future<List<Payment>> payments(String invoiceId) async {
    final snap = await col('payments').where('invoice_id', isEqualTo: invoiceId).get();
    final list = snap.docs.map((d) => Payment.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> addPayment(Payment p) async {
    _require('payments_add');
    final invRef = col('invoices').doc(p.invoiceId);
    final payRef = col('payments').doc();
    var number = '';
    await fs.runTransaction((tx) async {
      final snap = await tx.get(invRef);
      if (!snap.exists) throw Exception('Invoice not found.');
      final inv = Doc.fromMap(snap.id, snap.data()!, 'invoice');
      number = inv.number;
      if (inv.status == 'draft') throw Exception('Issue the invoice before recording payments.');
      if (inv.status == 'cancelled') throw Exception('You cannot pay a cancelled invoice.');
      if (inv.status == 'paid') throw Exception('This invoice is already fully paid.');
      if (p.amount <= 0) throw Exception('Amount must be more than zero.');
      if (p.amount > inv.balance + 0.004) throw Exception('Amount is more than the balance (${money(inv.balance)}).');

      final newPaid = round2(inv.paid + p.amount);
      final m = p.toMap();
      m['created_at'] = _now();
      tx.set(payRef, m);
      tx.update(invRef, {'paid': newPaid, 'status': invoiceStatus(inv.status, inv.total, newPaid, inv.dueDate)});
    });
    await _log('invoice', p.invoiceId, 'Payment ${money(p.amount)} received (${p.method})', label: number);
  }

  static Future<void> deletePayment(Payment p) async {
    _require('payments_delete');
    final invRef = col('invoices').doc(p.invoiceId);
    final payRef = col('payments').doc(p.id);
    var number = '';
    await fs.runTransaction((tx) async {
      final inv = await tx.get(invRef);
      final pay = await tx.get(payRef);
      if (!pay.exists) return;
      final amount = toDouble(pay.data()!['amount']);
      tx.delete(payRef);
      if (inv.exists) {
        final d = Doc.fromMap(inv.id, inv.data()!, 'invoice');
        number = d.number;
        var newPaid = round2(d.paid - amount);
        if (newPaid < 0) newPaid = 0;
        // A paid invoice becomes "sent" again so the status is worked out fresh.
        final base = d.status == 'paid' ? 'sent' : d.status;
        tx.update(invRef, {'paid': newPaid, 'status': invoiceStatus(base, d.total, newPaid, d.dueDate)});
      }
    });
    await _log('invoice', p.invoiceId, 'Payment ${money(p.amount)} removed', label: number);
  }

  // ============================================================ DASHBOARD
  static Future<DashboardData> dashboard() async {
    try {
      await refreshStatuses();
    } catch (e) {
      // offline: keep going with cached data
    }
    final data = DashboardData();
    final month = today().substring(0, 7);
    final invoices = await docs('invoice');
    final quotes = await docs('quote');
    final pays = await col('payments').get();

    double decided = 0;
    double won = 0;
    for (final q in quotes) {
      if (q.status == 'draft' || q.status == 'sent') {
        data.openQuotes++;
        data.openQuotesValue += q.total;
      }
      if (q.status == 'accepted' || q.status == 'converted') won++;
      if (q.status == 'accepted' || q.status == 'converted' || q.status == 'rejected' || q.status == 'expired') decided++;
    }
    data.conversionRate = decided == 0 ? 0 : won / decided * 100;

    final byCustomer = <String, double>{};
    for (final i in invoices) {
      final counts = i.status != 'draft' && i.status != 'cancelled';
      if (counts && i.date.startsWith(month)) data.invoicedThisMonth += i.total;
      if (i.status == 'sent' || i.status == 'partial' || i.status == 'overdue') data.outstanding += i.balance;
      if (i.status == 'overdue') {
        data.overdueCount++;
        data.overdueAmount += i.balance;
      }
      if (counts) byCustomer[i.customerName] = (byCustomer[i.customerName] ?? 0) + i.total;
    }

    // Payments collected in the last 6 months
    final now = DateTime.now();
    for (var k = 5; k >= 0; k--) {
      data.months.add(DateFormat('yyyy-MM').format(DateTime(now.year, now.month - k, 1)));
    }
    final byMonth = <String, double>{};
    for (final p in pays.docs) {
      final date = toText(p.data()['date']);
      if (date.length < 7) continue;
      final m = date.substring(0, 7);
      byMonth[m] = (byMonth[m] ?? 0) + toDouble(p.data()['amount']);
    }
    data.collectedThisMonth = byMonth[month] ?? 0;
    for (final m in data.months) {
      data.monthTotals.add(byMonth[m] ?? 0);
    }

    data.recent = invoices.take(5).toList();

    final top = byCustomer.entries.toList();
    top.sort((a, b) => b.value.compareTo(a.value));
    for (final e in top.take(5)) {
      data.topNames.add(e.key);
      data.topTotals.add(e.value);
    }
    return data;
  }

  // Deletes ALL business data of the company (keeps settings and the action log).
  static Future<void> clearAll() async {
    _require('delete_all');
    for (final t in ['payments', 'invoices', 'quotations', 'products', 'customers']) {
      final snap = await col(t).get();
      // Firestore batches hold max 500 writes.
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = fs.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await settingsRef.set({'quote_next': 1, 'invoice_next': 1}, SetOptions(merge: true));
    await _log('data', 'all', 'Deleted all data');
  }
}
