// All data classes used in the app.
import 'widgets.dart';

double toDouble(Object? v) {
  if (v == null) return 0;
  return (v as num).toDouble();
}

String toText(Object? v) {
  if (v == null) return '';
  return v.toString();
}

double round2(double v) {
  return (v * 100).roundToDouble() / 100;
}

// ---------------------------------------------------------------- Customer
class Customer {
  String? id;
  String name;
  String phone;
  String email;
  String address;
  String notes;
  int invoiceCount; // read only (calculated in SQL)
  double balance; // read only (calculated in SQL)

  Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.invoiceCount = 0,
    this.balance = 0,
  });

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'name_lower': name.toLowerCase(),
    };
  }

  static Customer fromMap(String id, Map<String, dynamic> m) {
    return Customer(
      id: id,
      name: toText(m['name']),
      phone: toText(m['phone']),
      email: toText(m['email']),
      address: toText(m['address']),
      notes: toText(m['notes']),
    );
  }
}

// ---------------------------------------------------------------- Product
class Product {
  String? id;
  String name;
  String description;
  String unit;
  double price;
  double taxRate;
  bool trackStock;
  double stock;
  bool isActive;

  Product({
    this.id,
    required this.name,
    this.description = '',
    this.unit = 'pcs',
    this.price = 0,
    this.taxRate = 0,
    this.trackStock = false,
    this.stock = 0,
    this.isActive = true,
  });

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'description': description,
      'unit': unit,
      'price': price,
      'tax_rate': taxRate,
      'track_stock': trackStock,
      'stock': stock,
      'is_active': isActive,
    };
  }

  static Product fromMap(String id, Map<String, dynamic> m) {
    return Product(
      id: id,
      name: toText(m['name']),
      description: toText(m['description']),
      unit: toText(m['unit']),
      price: toDouble(m['price']),
      taxRate: toDouble(m['tax_rate']),
      trackStock: m['track_stock'] == true,
      stock: toDouble(m['stock']),
      isActive: m['is_active'] != false,
    );
  }
}

// ---------------------------------------------------------------- Document line
class DocItem {
  String? productId;
  String description;
  double qty;
  double unitPrice;
  double discountPercent;
  double taxRate;

  DocItem({
    this.productId,
    required this.description,
    this.qty = 1,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.taxRate = 0,
  });

  double get base => qty * unitPrice;
  double get discountAmount => base * discountPercent / 100;
  double get net => base - discountAmount; // line total before tax
  double get tax => net * taxRate / 100;

  Map<String, Object?> toMap() {
    return {
      'product_id': productId,
      'description': description,
      'qty': qty,
      'unit_price': unitPrice,
      'discount_percent': discountPercent,
      'tax_rate': taxRate,
      'line_total': round2(net),
    };
  }

  static DocItem fromMap(Map<String, dynamic> m) {
    return DocItem(
      productId: m['product_id'] as String?,
      description: toText(m['description']),
      qty: toDouble(m['qty']),
      unitPrice: toDouble(m['unit_price']),
      discountPercent: toDouble(m['discount_percent']),
      taxRate: toDouble(m['tax_rate']),
    );
  }

  DocItem copy() {
    return DocItem(
      productId: productId,
      description: description,
      qty: qty,
      unitPrice: unitPrice,
      discountPercent: discountPercent,
      taxRate: taxRate,
    );
  }
}

// ---------------------------------------------------------------- Quotation / Invoice
// One class for both. type = 'quote' or 'invoice'.
class Doc {
  String? id;
  String type;
  String number;
  String customerId;
  String customerName;
  String customerPhone;
  String customerEmail;
  String customerAddress;
  String date;
  String dueDate; // "valid until" for a quotation
  String status;
  String discountType; // 'amount' or 'percent'
  double discountValue;
  double subtotal;
  double taxTotal;
  double discountTotal;
  double total;
  double paid;
  String notes;
  String terms;
  String? linkId; // quote -> invoice id, invoice -> quote id
  int stockApplied;
  List<DocItem> items;

  Doc({
    this.id,
    required this.type,
    this.number = '',
    this.customerId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerAddress = '',
    this.date = '',
    this.dueDate = '',
    this.status = 'draft',
    this.discountType = 'amount',
    this.discountValue = 0,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.discountTotal = 0,
    this.total = 0,
    this.paid = 0,
    this.notes = '',
    this.terms = '',
    this.linkId,
    this.stockApplied = 0,
    List<DocItem>? items,
  }) : items = items ?? [];

  bool get isQuote => type == 'quote';
  double get balance => round2(total - paid);
  String get title => isQuote ? 'Quotation' : 'Invoice';

  // A new empty document with defaults from settings.
  static Doc empty(String type) {
    final s = App.settings;
    final days = int.tryParse(type == 'quote' ? (s['quote_valid_days'] ?? '14') : (s['invoice_due_days'] ?? '30')) ?? 14;
    final start = today();
    return Doc(
      type: type,
      date: start,
      dueDate: addDays(start, days),
      terms: type == 'quote' ? (s['quote_terms'] ?? '') : (s['invoice_terms'] ?? ''),
      notes: s['default_notes'] ?? '',
    );
  }

  void recalc() {
    double sub = 0;
    double tax = 0;
    for (final item in items) {
      sub += item.net;
      tax += item.tax;
    }
    double disc = discountType == 'percent' ? sub * discountValue / 100 : discountValue;
    if (disc > sub) disc = sub;
    if (disc < 0) disc = 0;
    subtotal = round2(sub);
    taxTotal = round2(tax);
    discountTotal = round2(disc);
    total = round2(sub - disc + tax);
  }

  Map<String, Object?> toMap() {
    return {
      'number': number,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'date': date,
      'due_date': dueDate,
      'status': status,
      'discount_type': discountType,
      'discount_value': discountValue,
      'subtotal': subtotal,
      'tax_total': taxTotal,
      'discount_total': discountTotal,
      'total': total,
      'paid': paid,
      'notes': notes,
      'terms': terms,
      'link_id': linkId,
      'stock_applied': stockApplied,
      'items': items.map((i) => i.toMap()).toList(),
      'product_ids': items.where((i) => i.productId != null).map((i) => i.productId!).toSet().toList(),
    };
  }

  static Doc fromMap(String id, Map<String, dynamic> m, String type) {
    final rawItems = (m['items'] as List?) ?? [];
    return Doc(
      id: id,
      type: type,
      number: toText(m['number']),
      customerId: toText(m['customer_id']),
      customerName: toText(m['customer_name']),
      customerPhone: toText(m['customer_phone']),
      customerEmail: toText(m['customer_email']),
      customerAddress: toText(m['customer_address']),
      date: toText(m['date']),
      dueDate: toText(m['due_date']),
      status: toText(m['status']),
      discountType: toText(m['discount_type']),
      discountValue: toDouble(m['discount_value']),
      subtotal: toDouble(m['subtotal']),
      taxTotal: toDouble(m['tax_total']),
      discountTotal: toDouble(m['discount_total']),
      total: toDouble(m['total']),
      paid: toDouble(m['paid']),
      notes: toText(m['notes']),
      terms: toText(m['terms']),
      linkId: m['link_id'] as String?,
      stockApplied: m['stock_applied'] == null ? 0 : (m['stock_applied'] as num).toInt(),
      items: rawItems.map((e) => DocItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

// ---------------------------------------------------------------- Payment
class Payment {
  String? id;
  String invoiceId;
  double amount;
  String date;
  String method;
  String reference;
  String notes;

  Payment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.date,
    this.method = 'Cash',
    this.reference = '',
    this.notes = '',
  });

  Map<String, Object?> toMap() {
    return {
      'invoice_id': invoiceId,
      'amount': amount,
      'date': date,
      'method': method,
      'reference': reference,
      'notes': notes,
    };
  }

  static Payment fromMap(String id, Map<String, dynamic> m) {
    return Payment(
      id: id,
      invoiceId: toText(m['invoice_id']),
      amount: toDouble(m['amount']),
      date: toText(m['date']),
      method: toText(m['method']),
      reference: toText(m['reference']),
      notes: toText(m['notes']),
    );
  }
}

// ---------------------------------------------------------------- Activity log
class Activity {
  String action;
  String createdAt;
  String byEmail;
  Activity(this.action, this.createdAt, {this.byEmail = ''});
}

// One line of the company-wide action log (admin panel).
class LogEntry {
  String type; // quote | invoice | customer | product | settings | member | data
  String docId;
  String action;
  String label; // document number, customer name, ...
  String byUid;
  String byEmail;
  String createdAt;

  LogEntry(this.type, this.docId, this.action, this.label, this.byUid, this.byEmail, this.createdAt);

  static LogEntry fromMap(Map<String, dynamic> m) {
    return LogEntry(toText(m['doc_type']), toText(m['doc_id']), toText(m['action']), toText(m['label']), toText(m['by_uid']), toText(m['by_email']),
        toText(m['created_at']));
  }
}

// ---------------------------------------------------------------- Member (user access)
// Every privilege the admin can give. Admins always have all of them.
const Map<String, String> permLabels = {
  'quotes_create': 'Create quotations',
  'quotes_edit': 'Edit quotations & change status',
  'quotes_delete': 'Delete quotations',
  'invoices_create': 'Create invoices',
  'invoices_edit': 'Edit, issue & cancel invoices',
  'invoices_delete': 'Delete invoices',
  'payments_add': 'Record payments',
  'payments_delete': 'Delete payments',
  'customers': 'Add, edit & delete customers',
  'products': 'Add, edit & delete products',
  'settings': 'Change company settings',
  'delete_all': 'Delete all data',
};

const Map<String, List<String>> permGroups = {
  'Quotations': ['quotes_create', 'quotes_edit', 'quotes_delete'],
  'Invoices': ['invoices_create', 'invoices_edit', 'invoices_delete'],
  'Payments': ['payments_add', 'payments_delete'],
  'Customers & products': ['customers', 'products'],
  'Settings & data': ['settings', 'delete_all'],
};

class Member {
  String uid;
  String email;
  String role; // admin | staff
  bool active; // false = waiting for approval or blocked
  Map<String, bool> perms;
  String theme;
  String createdAt;

  Member({required this.uid, required this.email, this.role = 'staff', this.active = false, Map<String, bool>? perms, this.theme = '', this.createdAt = ''})
      : perms = perms ?? {};

  bool get isAdmin => role == 'admin';
  bool can(String p) => active && (isAdmin || perms[p] == true);
  int get permCount => isAdmin ? permLabels.length : permLabels.keys.where((k) => perms[k] == true).length;

  static Member fromMap(String uid, Map<String, dynamic> m) {
    final raw = m['perms'];
    final perms = <String, bool>{};
    if (raw is Map) {
      raw.forEach((k, v) => perms[k.toString()] = v == true);
    }
    return Member(
      uid: uid,
      email: toText(m['email']),
      role: toText(m['role']).isEmpty ? 'staff' : toText(m['role']),
      active: m['active'] == true,
      perms: perms,
      theme: toText(m['theme']),
      createdAt: toText(m['created_at']),
    );
  }
}

// ---------------------------------------------------------------- Dashboard numbers
class DashboardData {
  double invoicedThisMonth = 0;
  double collectedThisMonth = 0;
  double outstanding = 0;
  double overdueAmount = 0;
  int overdueCount = 0;
  int openQuotes = 0;
  double openQuotesValue = 0;
  double conversionRate = 0;
  List<String> months = [];
  List<double> monthTotals = [];
  List<Doc> recent = [];
  List<String> topNames = [];
  List<double> topTotals = [];
}
