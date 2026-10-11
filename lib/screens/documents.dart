// Quotations and Invoices: list, create/edit, details, payments.
// Both use the same screens; "type" is 'quote' or 'invoice'.
import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../pdf_service.dart';
import '../widgets.dart';
import 'customers.dart';
import 'products.dart';

const List<String> quoteStatuses = ['all', 'draft', 'sent', 'accepted', 'rejected', 'expired', 'converted'];
const List<String> invoiceStatuses = ['all', 'draft', 'sent', 'partial', 'overdue', 'paid', 'cancelled'];
const List<String> paymentMethods = ['Cash', 'EVC Plus', 'eDahab', 'Bank transfer', 'Card', 'Cheque', 'Other'];

// =================================================================== LIST TILE
class DocTile extends StatelessWidget {
  final Doc doc;
  final VoidCallback onChanged;

  const DocTile({super.key, required this.doc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showBalance = !doc.isQuote && doc.balance > 0 && doc.status != 'draft' && doc.status != 'cancelled';
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await Navigator.push(context, slideRoute(DocDetailScreen(type: doc.type, id: doc.id!)));
        onChanged();
      },
      child: Row(
        children: [
          InitialsAvatar(doc.customerName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'doc-${doc.type}-${doc.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(doc.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ),
                    Text(money(doc.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(doc.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                    StatusChip(doc.status),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${niceDate(doc.date)}  ·  ${doc.isQuote ? 'Valid until' : 'Due'} ${niceDate(doc.dueDate)}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    if (showBalance)
                      Text('Bal ${money(doc.balance)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== LIST SCREEN
class DocListScreen extends StatefulWidget {
  final String type;
  const DocListScreen({super.key, required this.type});

  @override
  State<DocListScreen> createState() => _DocListScreenState();
}

class _DocListScreenState extends State<DocListScreen> {
  List<Doc> docs = [];
  bool loading = true;
  String status = 'all';
  String search = '';

  bool get isQuote => widget.type == 'quote';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final list = await AppDb.docs(widget.type, status: status, search: search);
    if (mounted) {
      setState(() {
        docs = list;
        loading = false;
      });
    }
  }

  Future<void> create() async {
    await Navigator.push(context, slideRoute(DocEditorScreen(type: widget.type)));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = isQuote ? quoteStatuses : invoiceStatuses;
    double sum = 0;
    for (final d in docs) {
      sum += d.total;
    }
    return Scaffold(
      appBar: AppBar(title: Text(isQuote ? 'Quotations' : 'Invoices')),
      floatingActionButton: !AppDb.can(AppDb.perm(widget.type, 'create'))
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-${widget.type}',
              onPressed: create,
              icon: const Icon(Icons.add_rounded),
              label: Text(isQuote ? 'New quote' : 'New invoice'),
            ),
      body: Column(
        children: [
          SearchBox(
            hint: 'Search number or customer',
            onChanged: (v) {
              search = v;
              load();
            },
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in statuses)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1)),
                      selected: status == s,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => status = s);
                        load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Row(
              children: [
                Text('${docs.length} ${isQuote ? 'quotation' : 'invoice'}${docs.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
                const Spacer(),
                AnimatedNumber(value: sum, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : docs.isEmpty
                    ? EmptyState(
                        icon: isQuote ? Icons.request_quote_outlined : Icons.receipt_long_outlined,
                        title: 'Nothing here yet',
                        subtitle: search.isEmpty && status == 'all'
                            ? 'Tap the button below to create your first ${isQuote ? 'quotation' : 'invoice'}.'
                            : 'No results for this filter.',
                      )
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView.separated(
                          key: ValueKey(status),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                          itemCount: docs.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 8),
                          itemBuilder: (c, i) => FadeSlideIn(index: i, child: DocTile(doc: docs[i], onChanged: load)),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== EDITOR (create / edit)
class DocEditorScreen extends StatefulWidget {
  final String type;
  final String? id;
  final String? customerId;

  const DocEditorScreen({super.key, required this.type, this.id, this.customerId});

  @override
  State<DocEditorScreen> createState() => _DocEditorScreenState();
}

class _DocEditorScreenState extends State<DocEditorScreen> {
  Doc? doc;
  bool saving = false;
  final discountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final termsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    discountCtrl.dispose();
    notesCtrl.dispose();
    termsCtrl.dispose();
    super.dispose();
  }

  Future<void> init() async {
    Doc d;
    if (widget.id != null) {
      final loaded = await AppDb.doc(widget.type, widget.id!);
      if (loaded == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      d = loaded;
    } else {
      d = Doc.empty(widget.type);
      if (widget.customerId != null) {
        final c = await AppDb.customer(widget.customerId!);
        if (c != null) {
          d.customerId = c.id!;
          d.customerName = c.name;
        }
      }
    }
    discountCtrl.text = d.discountValue == 0 ? '' : qtyText(d.discountValue);
    notesCtrl.text = d.notes;
    termsCtrl.text = d.terms;
    if (mounted) setState(() => doc = d);
  }

  Future<void> selectCustomer() async {
    final c = await pickCustomer(context);
    if (c != null) {
      setState(() {
        doc!.customerId = c.id!;
        doc!.customerName = c.name;
      });
    }
  }

  Future<void> pickDate(bool isDue) async {
    final current = isDue ? doc!.dueDate : doc!.date;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isDue) {
        doc!.dueDate = dateToText(picked);
      } else {
        // keep the same number of days between date and due date
        final oldDue = DateTime.tryParse(doc!.dueDate) ?? picked;
        final oldDate = DateTime.tryParse(doc!.date) ?? picked;
        final gap = oldDue.difference(oldDate).inDays;
        doc!.date = dateToText(picked);
        doc!.dueDate = addDays(doc!.date, gap < 0 ? 0 : gap);
      }
    });
  }

  Future<void> addFromProduct() async {
    final p = await pickProduct(context);
    if (p == null) return;
    setState(() {
      DocItem? existing;
      for (final it in doc!.items) {
        if (it.productId == p.id) existing = it;
      }
      if (existing != null) {
        existing.qty += 1;
      } else {
        doc!.items.add(DocItem(productId: p.id, description: p.name, unitPrice: p.price, taxRate: p.taxRate));
      }
    });
    if (!mounted) return;
    if (!doc!.isQuote && p.trackStock) {
      double qty = 0;
      for (final it in doc!.items) {
        if (it.productId == p.id) qty += it.qty;
      }
      if (qty > p.stock) toast(context, 'Warning: only ${qtyText(p.stock)} ${p.unit} of ${p.name} in stock.', error: true);
    }
  }

  Future<void> addCustom() async {
    final it = await showItemSheet(context, null);
    if (it != null) setState(() => doc!.items.add(it));
  }

  Future<void> editItem(int index) async {
    final it = await showItemSheet(context, doc!.items[index]);
    if (it != null) setState(() => doc!.items[index] = it);
  }

  Future<void> save() async {
    final d = doc!;
    d.notes = notesCtrl.text.trim();
    d.terms = termsCtrl.text.trim();
    d.discountValue = parseNum(discountCtrl.text);
    setState(() => saving = true);
    try {
      final id = await AppDb.saveDoc(d);
      if (!mounted) return;
      if (widget.id == null) {
        Navigator.pushReplacement(context, slideRoute(DocDetailScreen(type: widget.type, id: id)));
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (doc == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final d = doc!;
    d.recalc();
    final scheme = Theme.of(context).colorScheme;
    final title = widget.id == null ? 'New ${d.title.toLowerCase()}' : 'Edit ${d.number}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle('Customer'),
          FadeSlideIn(
            index: 0,
            child: AppCard(
              onTap: selectCustomer,
              child: Row(
                children: [
                  d.customerId.isEmpty
                      ? CircleAvatar(backgroundColor: scheme.primary.withAlpha(30), child: Icon(Icons.person_add_alt_1_rounded, color: scheme.primary))
                      : InitialsAvatar(d.customerName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.customerId.isEmpty ? 'Select a customer' : d.customerName,
                      style: TextStyle(fontWeight: FontWeight.w600, color: d.customerId.isEmpty ? scheme.primary : null),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SectionTitle('Dates'),
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                Expanded(child: dateBox('Date', d.date, () => pickDate(false))),
                const SizedBox(width: 12),
                Expanded(child: dateBox(d.isQuote ? 'Valid until' : 'Due date', d.dueDate, () => pickDate(true))),
              ],
            ),
          ),
          SectionTitle('Items (${d.items.length})'),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < d.items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ObjectKey(d.items[i]),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => setState(() => d.items.removeAt(i)),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      child: FadeSlideIn(child: itemCard(d.items[i], () => editItem(i))),
                    ),
                  ),
              ],
            ),
          ),
          if (d.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text('Tip: tap an item to edit, swipe left to remove.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(onPressed: addFromProduct, icon: const Icon(Icons.inventory_2_outlined), label: const Text('From products')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(onPressed: addCustom, icon: const Icon(Icons.edit_note_rounded), label: const Text('Custom item')),
              ),
            ],
          ),
          const SectionTitle('Discount on total'),
          Row(
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'amount', label: Text(App.currency)),
                  const ButtonSegment(value: 'percent', label: Text('%')),
                ],
                selected: {d.discountType},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => d.discountType = s.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0', isDense: true),
                  onChanged: (v) => setState(() => d.discountValue = parseNum(v)),
                ),
              ),
            ],
          ),
          const SectionTitle('Notes & terms'),
          TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (shown on PDF)')),
          const SizedBox(height: 10),
          TextField(controller: termsCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Terms & conditions')),
          const SectionTitle('Summary'),
          AppCard(
            child: Column(
              children: [
                InfoRow('Subtotal', money(d.subtotal)),
                if (d.discountTotal > 0) InfoRow('Discount', '- ${money(d.discountTotal)}', color: Colors.green.shade600),
                InfoRow('Tax', money(d.taxTotal)),
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    AnimatedNumber(value: d.total, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: scheme.primary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: saving ? null : save,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: saving
                  ? const SizedBox(key: ValueKey('busy'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Text(widget.id == null ? 'Save ${d.title.toLowerCase()}' : 'Save changes', key: const ValueKey('text')),
            ),
          ),
        ),
      ),
    );
  }

  Widget dateBox(String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18)),
        child: Text(niceDate(value)),
      ),
    );
  }

  Widget itemCard(DocItem it, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    final extras = <String>[];
    if (it.discountPercent > 0) extras.add('-${qtyText(it.discountPercent)}%');
    if (it.taxRate > 0) extras.add('tax ${qtyText(it.taxRate)}%');
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${qtyText(it.qty)} × ${money(it.unitPrice)}${extras.isEmpty ? '' : '  ·  ${extras.join('  ·  ')}'}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(money(it.net), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// =================================================================== ITEM SHEET
Future<DocItem?> showItemSheet(BuildContext context, DocItem? item) {
  return showModalBottomSheet<DocItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => ItemSheet(item: item),
  );
}

class ItemSheet extends StatefulWidget {
  final DocItem? item;
  const ItemSheet({super.key, this.item});

  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  final desc = TextEditingController();
  final qty = TextEditingController();
  final price = TextEditingController();
  final disc = TextEditingController();
  final tax = TextEditingController();
  String error = '';

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    desc.text = it?.description ?? '';
    qty.text = qtyText(it?.qty ?? 1);
    price.text = it == null ? '' : it.unitPrice.toStringAsFixed(2);
    disc.text = it == null || it.discountPercent == 0 ? '' : qtyText(it.discountPercent);
    final defaultTax = parseNum(App.settings['default_tax'] ?? '0');
    final t = it?.taxRate ?? defaultTax;
    tax.text = t == 0 ? '' : qtyText(t);
  }

  @override
  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
    disc.dispose();
    tax.dispose();
    super.dispose();
  }

  DocItem build0() {
    return DocItem(
      productId: widget.item?.productId,
      description: desc.text.trim(),
      qty: parseNum(qty.text),
      unitPrice: parseNum(price.text),
      discountPercent: parseNum(disc.text),
      taxRate: parseNum(tax.text),
    );
  }

  void save() {
    final it = build0();
    if (it.description.isEmpty) return setState(() => error = 'Description is required.');
    if (it.qty <= 0) return setState(() => error = 'Quantity must be more than zero.');
    if (it.unitPrice < 0) return setState(() => error = 'Price cannot be negative.');
    if (it.discountPercent < 0 || it.discountPercent > 100) return setState(() => error = 'Discount must be between 0 and 100%.');
    if (it.taxRate < 0 || it.taxRate > 100) return setState(() => error = 'Tax must be between 0 and 100%.');
    Navigator.pop(context, it);
  }

  @override
  Widget build(BuildContext context) {
    final it = build0();
    const numKeys = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.item == null ? 'Add item' : 'Edit item', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: desc, autofocus: widget.item == null, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: qty, keyboardType: numKeys, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Quantity'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: price, keyboardType: numKeys, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Unit price (${App.currency})'))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: disc, keyboardType: numKeys, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Discount %'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: tax, keyboardType: numKeys, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Tax %'))),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  InfoRow('Line total (before tax)', money(it.net)),
                  InfoRow('Tax', money(it.tax)),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: error.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error, style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                    ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: save, child: Text(widget.item == null ? 'Add item' : 'Update item')),
          ],
        ),
      ),
    );
  }
}

// =================================================================== CUSTOMER PICKER
Future<Customer?> pickCustomer(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => const _CustomerPicker(),
  );
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker();

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  List<Customer> list = [];

  @override
  void initState() {
    super.initState();
    load('');
  }

  Future<void> load(String s) async {
    final l = await AppDb.customers(search: s);
    if (mounted) setState(() => list = l);
  }

  Future<void> addNew() async {
    final c = await Navigator.push<Customer>(context, slideRoute(const CustomerFormScreen()));
    if (c != null && mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          SearchBox(hint: 'Search customers', onChanged: load),
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary)),
            title: const Text('Add new customer', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: addNew,
          ),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.people_outline, title: 'No customers found')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) => FadeSlideIn(
                      index: i,
                      child: ListTile(
                        leading: InitialsAvatar(list[i].name),
                        title: Text(list[i].name),
                        subtitle: Text(list[i].phone.isEmpty ? list[i].email : list[i].phone),
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== PRODUCT PICKER
Future<Product?> pickProduct(BuildContext context) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => const _ProductPicker(),
  );
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker();

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  List<Product> list = [];

  @override
  void initState() {
    super.initState();
    load('');
  }

  Future<void> load(String s) async {
    final l = await AppDb.products(search: s);
    if (mounted) setState(() => list = l);
  }

  Future<void> addNew() async {
    final p = await Navigator.push<Product>(context, slideRoute(const ProductFormScreen()));
    if (p != null && mounted) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          SearchBox(hint: 'Search products & services', onChanged: load),
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary)),
            title: const Text('Add new product', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: addNew,
          ),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No products found')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final p = list[i];
                      return FadeSlideIn(
                        index: i,
                        child: ListTile(
                          title: Text(p.name),
                          subtitle: Text(p.trackStock ? 'In stock: ${qtyText(p.stock)} ${p.unit}' : 'Per ${p.unit}'),
                          trailing: Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () => Navigator.pop(context, p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== DETAIL SCREEN
class _Action {
  final String key;
  final String label;
  final IconData icon;
  final bool danger;
  _Action(this.key, this.label, this.icon, {this.danger = false});
}

class DocDetailScreen extends StatefulWidget {
  final String type;
  final String id;
  const DocDetailScreen({super.key, required this.type, required this.id});

  @override
  State<DocDetailScreen> createState() => _DocDetailScreenState();
}

class _DocDetailScreenState extends State<DocDetailScreen> {
  Doc? doc;
  List<Payment> payments = [];
  List<Activity> log = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = await AppDb.doc(widget.type, widget.id);
    if (!mounted) return;
    if (d == null) {
      Navigator.pop(context);
      return;
    }
    final p = d.isQuote ? <Payment>[] : await AppDb.payments(d.id!);
    final a = await AppDb.activity(d.type, d.id!);
    if (mounted) {
      setState(() {
        doc = d;
        payments = p;
        log = a;
      });
    }
  }

  List<_Action> actions() {
    final d = doc!;
    final s = d.status;
    final list = <_Action>[];
    if (d.isQuote) {
      if (s == 'draft') list.add(_Action('sent', 'Mark as sent', Icons.send_rounded));
      if (s == 'draft' || s == 'sent' || s == 'accepted' || s == 'expired') {
        list.add(_Action('convert', 'Convert to invoice', Icons.receipt_long_rounded));
      }
      if (s == 'converted' && d.linkId != null) list.add(_Action('open_link', 'Open invoice', Icons.open_in_new_rounded));
      if (s == 'sent' || s == 'expired') {
        list.add(_Action('accepted', 'Mark as accepted', Icons.thumb_up_alt_outlined));
        list.add(_Action('rejected', 'Mark as rejected', Icons.thumb_down_alt_outlined));
      }
      if (s == 'accepted' || s == 'rejected' || s == 'expired' || s == 'sent') list.add(_Action('draft', 'Back to draft', Icons.undo_rounded));
    } else {
      if (s == 'draft') list.add(_Action('sent', 'Issue invoice', Icons.send_rounded));
      if (s == 'sent' || s == 'partial' || s == 'overdue') list.add(_Action('pay', 'Record payment', Icons.payments_rounded));
      if ((s == 'sent' || s == 'overdue') && d.paid == 0) {
        list.add(_Action('draft', 'Back to draft', Icons.undo_rounded));
        list.add(_Action('cancelled', 'Cancel invoice', Icons.block_rounded, danger: true));
      }
      if (s == 'cancelled') list.add(_Action('draft', 'Restore as draft', Icons.restore_rounded));
      if (d.linkId != null) list.add(_Action('open_link', 'Open quotation', Icons.open_in_new_rounded));
    }
    if (AppDb.canEdit(d)) list.add(_Action('edit', 'Edit', Icons.edit_outlined));
    list.add(_Action('duplicate', 'Duplicate', Icons.copy_rounded));
    final canDelete = d.isQuote ? s != 'converted' : (s == 'draft' || s == 'cancelled');
    if (canDelete) list.add(_Action('delete', 'Delete', Icons.delete_outline_rounded, danger: true));
    // Only show what this user's privileges allow.
    return list.where((a) => allowed(a.key, d)).toList();
  }

  bool allowed(String key, Doc d) {
    switch (key) {
      case 'open_link':
        return true;
      case 'pay':
        return AppDb.can('payments_add');
      case 'convert':
        return AppDb.can('quotes_edit') && AppDb.can('invoices_create');
      case 'duplicate':
        return AppDb.can(AppDb.perm(d.type, 'create'));
      case 'delete':
        return AppDb.can(AppDb.perm(d.type, 'delete'));
      default: // edit and every status change
        return AppDb.can(AppDb.perm(d.type, 'edit'));
    }
  }

  Future<void> run(String key) async {
    final d = doc!;
    try {
      switch (key) {
        case 'edit':
          await Navigator.push(context, slideRoute(DocEditorScreen(type: d.type, id: d.id)));
          break;
        case 'sent':
        case 'accepted':
        case 'draft':
          await AppDb.setStatus(d.type, d.id!, key);
          if (mounted) toast(context, key == 'sent' && !d.isQuote ? 'Invoice issued.' : 'Status updated.');
          break;
        case 'rejected':
        case 'cancelled':
          final sure = await confirm(context, key == 'rejected' ? 'Reject quotation?' : 'Cancel invoice?',
              key == 'rejected' ? 'The quotation will be marked as rejected.' : 'Stock will be returned and the invoice will no longer count as revenue.',
              okText: key == 'rejected' ? 'Reject' : 'Cancel invoice', danger: true);
          if (!sure) return;
          await AppDb.setStatus(d.type, d.id!, key);
          break;
        case 'convert':
          final sureConvert = await confirm(context, 'Convert to invoice?', 'A new draft invoice will be created with the same items.', okText: 'Convert');
          if (!sureConvert) return;
          final invoiceId = await AppDb.convertQuote(d.id!);
          if (!mounted) return;
          toast(context, 'Invoice created.');
          await Navigator.push(context, slideRoute(DocDetailScreen(type: 'invoice', id: invoiceId)));
          break;
        case 'open_link':
          await Navigator.push(context, slideRoute(DocDetailScreen(type: d.isQuote ? 'invoice' : 'quote', id: d.linkId!)));
          break;
        case 'pay':
          final paidOk = await showPaymentSheet(context, d);
          if (paidOk && mounted) toast(context, 'Payment recorded.');
          break;
        case 'duplicate':
          final newId = await AppDb.duplicateDoc(d.type, d.id!);
          if (!mounted) return;
          toast(context, 'Copy created as draft.');
          await Navigator.push(context, slideRoute(DocDetailScreen(type: d.type, id: newId)));
          break;
        case 'delete':
          final sureDelete = await confirm(context, 'Delete ${d.number}?', 'This cannot be undone.', okText: 'Delete', danger: true);
          if (!sureDelete) return;
          await AppDb.deleteDoc(d.type, d.id!);
          if (mounted) {
            toast(context, '${d.title} deleted.');
            Navigator.pop(context);
          }
          return;
        case 'print':
          await PdfService.printDoc(d);
          return;
        case 'share':
          await PdfService.shareDoc(d);
          return;
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
    await load();
  }

  _Action? primary(List<_Action> list) {
    const order = ['pay', 'sent', 'convert', 'open_link'];
    for (final k in order) {
      for (final a in list) {
        if (a.key == k) return a;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (doc == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final d = doc!;
    final scheme = Theme.of(context).colorScheme;
    final list = actions();
    final mainAction = primary(list);
    final menu = list.where((a) => a != mainAction).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(d.title),
        actions: [
          IconButton(tooltip: 'Print', icon: const Icon(Icons.print_outlined), onPressed: () => run('print')),
          IconButton(tooltip: 'Share PDF', icon: const Icon(Icons.ios_share_rounded), onPressed: () => run('share')),
          PopupMenuButton<String>(
            onSelected: run,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (c) => [
              for (final a in menu)
                PopupMenuItem(
                  value: a.key,
                  child: Row(
                    children: [
                      Icon(a.icon, size: 20, color: a.danger ? Colors.red.shade600 : null),
                      const SizedBox(width: 12),
                      Text(a.label, style: TextStyle(color: a.danger ? Colors.red.shade600 : null)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            FadeSlideIn(index: 0, child: headerCard(d)),
            if (!d.isQuote && d.status != 'draft' && d.status != 'cancelled') ...[
              const SizedBox(height: 12),
              FadeSlideIn(index: 1, child: paymentProgress(d)),
            ],
            SectionTitle('Items (${d.items.length})'),
            FadeSlideIn(
              index: 2,
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < d.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.items[i].description, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${qtyText(d.items[i].qty)} × ${money(d.items[i].unitPrice)}'
                                    '${d.items[i].discountPercent > 0 ? '  ·  -${qtyText(d.items[i].discountPercent)}%' : ''}'
                                    '${d.items[i].taxRate > 0 ? '  ·  tax ${qtyText(d.items[i].taxRate)}%' : ''}',
                                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Text(money(d.items[i].net), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: AppCard(
                child: Column(
                  children: [
                    InfoRow('Subtotal', money(d.subtotal)),
                    if (d.discountTotal > 0)
                      InfoRow('Discount${d.discountType == 'percent' ? ' (${qtyText(d.discountValue)}%)' : ''}', '- ${money(d.discountTotal)}', color: Colors.green.shade600),
                    InfoRow('Tax', money(d.taxTotal)),
                    const Divider(height: 20),
                    InfoRow('Total', money(d.total), bold: true),
                    if (!d.isQuote && d.paid > 0) ...[
                      InfoRow('Paid', money(d.paid), color: Colors.green.shade600),
                      InfoRow('Balance due', money(d.balance), bold: true, color: d.balance > 0 ? Colors.orange.shade700 : Colors.green.shade600),
                    ],
                  ],
                ),
              ),
            ),
            if (d.notes.isNotEmpty || d.terms.isNotEmpty) ...[
              const SectionTitle('Notes & terms'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.notes.isNotEmpty) Text(d.notes),
                    if (d.notes.isNotEmpty && d.terms.isNotEmpty) const SizedBox(height: 10),
                    if (d.terms.isNotEmpty) Text(d.terms, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ],
            if (!d.isQuote) ...[
              SectionTitle('Payments (${payments.length})'),
              if (payments.isEmpty)
                AppCard(child: Text(d.status == 'draft' ? 'Issue the invoice to start recording payments.' : 'No payments yet.', style: TextStyle(color: scheme.onSurfaceVariant)))
              else
                for (var i = 0; i < payments.length; i++)
                  FadeSlideIn(
                    index: i,
                    child: Padding(padding: const EdgeInsets.only(bottom: 8), child: paymentCard(payments[i])),
                  ),
            ],
            const SectionTitle('History'),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < log.length; i++) timelineRow(log[i], i == log.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: mainAction == null ? null : bottomButton(mainAction),
    );
  }

  Widget bottomButton(_Action action) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  await run(action.key);
                  if (mounted) setState(() => busy = false);
                },
          icon: Icon(action.icon),
          label: Text(action.label),
        ),
      ),
    );
  }

  Widget headerCard(Doc d) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Hero(
                  tag: 'doc-${d.type}-${d.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(d.number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: StatusChip(d.status, key: ValueKey(d.status)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InitialsAvatar(d.customerName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (d.customerPhone.isNotEmpty || d.customerEmail.isNotEmpty)
                      Text(
                        [d.customerPhone, d.customerEmail].where((x) => x.isNotEmpty).join('  ·  '),
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: miniInfo('Date', niceDate(d.date))),
              Expanded(child: miniInfo(d.isQuote ? 'Valid until' : 'Due date', niceDate(d.dueDate))),
              Expanded(child: miniInfo('Total', money(d.total))),
            ],
          ),
        ],
      ),
    );
  }

  Widget miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      ],
    );
  }

  Widget paymentProgress(Doc d) {
    final ratio = d.total == 0 ? 1.0 : (d.paid / d.total).clamp(0.0, 1.0);
    final color = d.status == 'paid' ? Colors.green.shade600 : (d.status == 'overdue' ? Colors.red.shade600 : Theme.of(context).colorScheme.primary);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(d.status == 'paid' ? 'Fully paid' : 'Payment progress', style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${(ratio * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: ratio),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (c, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: color.withAlpha(30)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Paid ${money(d.paid)}', style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.w600, fontSize: 13))),
              Text('Balance ${money(d.balance)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: d.balance > 0 ? Colors.orange.shade700 : null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget paymentCard(Payment p) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.green.withAlpha(30), child: Icon(Icons.south_west_rounded, color: Colors.green.shade600, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${p.method}  ·  ${niceDate(p.date)}${p.reference.isEmpty ? '' : '  ·  ${p.reference}'}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (doc!.status != 'cancelled' && AppDb.can('payments_delete'))
            IconButton(
              tooltip: 'Delete payment',
              icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
              onPressed: () async {
                final ok = await confirm(context, 'Delete payment?', '${money(p.amount)} will be removed and the balance updated.', okText: 'Delete', danger: true);
                if (!ok) return;
                try {
                  await AppDb.deletePayment(p);
                } catch (e) {
                  if (mounted) toast(context, errorText(e), error: true);
                }
                await load();
              },
            ),
        ],
      ),
    );
  }

  Widget timelineRow(Activity a, bool last) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(width: 9, height: 9, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                if (!last) Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.action, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(a.byEmail.isEmpty ? niceDateTime(a.createdAt) : '${niceDateTime(a.createdAt)} · ${a.byEmail}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== PAYMENT SHEET
Future<bool> showPaymentSheet(BuildContext context, Doc doc) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => PaymentSheet(doc: doc),
  );
  return r == true;
}

class PaymentSheet extends StatefulWidget {
  final Doc doc;
  const PaymentSheet({super.key, required this.doc});

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final amount = TextEditingController();
  final reference = TextEditingController();
  final notes = TextEditingController();
  String date = today();
  String method = 'Cash';
  String error = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    amount.text = widget.doc.balance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = '';
    });
    try {
      await AppDb.addPayment(Payment(
        invoiceId: widget.doc.id!,
        amount: parseNum(amount.text),
        date: date,
        method: method,
        reference: reference.text.trim(),
        notes: notes.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record payment', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${d.number}  ·  Balance ${money(d.balance)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: 'Amount', prefixText: '${App.currency} '),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(label: const Text('Full balance'), onPressed: () => amount.text = d.balance.toStringAsFixed(2)),
                ActionChip(label: const Text('50%'), onPressed: () => amount.text = round2(d.balance / 2).toStringAsFixed(2)),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: DateTime.parse(date), firstDate: DateTime(2015), lastDate: DateTime(2100));
                if (picked != null) setState(() => date = dateToText(picked));
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Payment date', suffixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
                child: Text(niceDate(date)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Method', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in paymentMethods)
                  ChoiceChip(label: Text(m), selected: method == m, showCheckmark: false, onSelected: (_) => setState(() => method = m)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference / transaction ID (optional)')),
            const SizedBox(height: 10),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: error.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error, style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                    ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save payment')),
          ],
        ),
      ),
    );
  }
}
