import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';

// =================================================================== LIST
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> list = [];
  bool loading = true;
  bool showArchived = false;
  String search = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final l = await AppDb.products(search: search, includeInactive: showArchived);
    if (mounted) {
      setState(() {
        list = l;
        loading = false;
      });
    }
  }

  Future<void> open(Product? p) async {
    await Navigator.push(context, slideRoute(ProductFormScreen(product: p)));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & services'),
        actions: [
          IconButton(
            tooltip: showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(showArchived ? Icons.inventory_rounded : Icons.archive_outlined),
            onPressed: () {
              setState(() => showArchived = !showArchived);
              load();
            },
          ),
        ],
      ),
      floatingActionButton: !AppDb.can('products')
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-product',
              onPressed: () => open(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            ),
      body: Column(
        children: [
          SearchBox(
            hint: 'Search products & services',
            onChanged: (v) {
              search = v;
              load();
            },
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No products', subtitle: 'Save the products and services you sell to add them quickly.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: list.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 8),
                        itemBuilder: (c, i) {
                          final p = list[i];
                          final lowStock = p.trackStock && p.stock <= 5;
                          return FadeSlideIn(
                            index: i,
                            child: Opacity(
                              opacity: p.isActive ? 1.0 : 0.55,
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                onTap: () => open(p),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(color: scheme.primary.withAlpha(28), borderRadius: BorderRadius.circular(12)),
                                      child: Icon(p.trackStock ? Icons.inventory_2_rounded : Icons.design_services_rounded, color: scheme.primary, size: 21),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name + (p.isActive ? '' : '  (archived)'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.trackStock ? 'Stock: ${qtyText(p.stock)} ${p.unit}' : 'Service · per ${p.unit}',
                                            style: TextStyle(fontSize: 12.5, color: lowStock ? Colors.red.shade600 : scheme.onSurfaceVariant, fontWeight: lowStock ? FontWeight.w600 : null),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                                        if (p.taxRate > 0) Text('+${qtyText(p.taxRate)}% tax', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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

// =================================================================== FORM
// Returns the saved Product (with id) when popped.
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final description = TextEditingController();
  final unit = TextEditingController();
  final price = TextEditingController();
  final tax = TextEditingController();
  final stock = TextEditingController();
  bool trackStock = false;
  bool isActive = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      name.text = p.name;
      description.text = p.description;
      unit.text = p.unit;
      price.text = p.price.toStringAsFixed(2);
      tax.text = p.taxRate == 0 ? '' : qtyText(p.taxRate);
      stock.text = qtyText(p.stock);
      trackStock = p.trackStock;
      isActive = p.isActive;
    } else {
      unit.text = 'pcs';
      final t = parseNum(App.settings['default_tax'] ?? '0');
      tax.text = t == 0 ? '' : qtyText(t);
      stock.text = '0';
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    unit.dispose();
    price.dispose();
    tax.dispose();
    stock.dispose();
    super.dispose();
  }

  String? numberRule(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t.replaceAll(',', ''));
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final p = Product(
      id: widget.product?.id,
      name: name.text.trim(),
      description: description.text.trim(),
      unit: unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
      price: parseNum(price.text),
      taxRate: parseNum(tax.text),
      trackStock: trackStock,
      stock: parseNum(stock.text),
      isActive: isActive,
    );
    try {
      p.id = await AppDb.saveProduct(p);
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, errorText(e), error: true);
      }
    }
  }

  Future<void> delete() async {
    final ok = await confirm(context, 'Delete product?', 'If it is used in documents it will be archived instead.', okText: 'Delete', danger: true);
    if (!ok) return;
    try {
      final msg = await AppDb.deleteProduct(widget.product!.id!);
      if (mounted) {
        toast(context, msg);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const numKeys = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'New product' : 'Edit product'),
        actions: [
          if (widget.product != null) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: delete),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              index: 0,
              child: TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(index: 1, child: TextFormField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description'))),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: price,
                      keyboardType: numKeys,
                      decoration: InputDecoration(labelText: 'Price (${App.currency}) *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Price is required' : numberRule(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (pcs, hr, kg)'))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: TextFormField(controller: tax, keyboardType: numKeys, validator: numberRule, decoration: const InputDecoration(labelText: 'Tax %')),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              index: 4,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Track stock'),
                subtitle: const Text('Stock goes down when an invoice is issued, and back up if it is cancelled.'),
                value: trackStock,
                onChanged: (v) => setState(() => trackStock = v),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: trackStock
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(controller: stock, keyboardType: numKeys, validator: numberRule, decoration: const InputDecoration(labelText: 'Quantity in stock')),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (widget.product != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Archived products are hidden when creating documents.'),
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save product')),
        ),
      ),
    );
  }
}
