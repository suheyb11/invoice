import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';
import 'documents.dart';

// =================================================================== LIST
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> list = [];
  bool loading = true;
  String search = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final l = await AppDb.customers(search: search);
    if (mounted) {
      setState(() {
        list = l;
        loading = false;
      });
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, slideRoute(page));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: !AppDb.can('customers')
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-customer',
              onPressed: () => open(const CustomerFormScreen()),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add customer'),
            ),
      body: Column(
        children: [
          SearchBox(
            hint: 'Search name, phone or email',
            onChanged: (v) {
              search = v;
              load();
            },
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const EmptyState(icon: Icons.people_outline_rounded, title: 'No customers', subtitle: 'Add the people and companies you work with.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: list.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 8),
                        itemBuilder: (c, i) {
                          final cu = list[i];
                          return FadeSlideIn(
                            index: i,
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              onTap: () => open(CustomerDetailScreen(customerId: cu.id!)),
                              child: Row(
                                children: [
                                  InitialsAvatar(cu.name),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cu.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                          cu.phone.isNotEmpty ? cu.phone : (cu.email.isNotEmpty ? cu.email : 'No contact info'),
                                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(cu.balance > 0 ? money(cu.balance) : 'No balance',
                                          style: TextStyle(fontWeight: FontWeight.w700, color: cu.balance > 0 ? Colors.orange.shade700 : scheme.onSurfaceVariant)),
                                      Text('${cu.invoiceCount} invoice${cu.invoiceCount == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ],
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

// =================================================================== FORM (add / edit)
// Returns the saved Customer (with id) when popped.
class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;
  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    if (c != null) {
      name.text = c.name;
      phone.text = c.phone;
      email.text = c.email;
      address.text = c.address;
      notes.text = c.notes;
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final c = Customer(
      id: widget.customer?.id,
      name: name.text.trim(),
      phone: phone.text.trim(),
      email: email.text.trim(),
      address: address.text.trim(),
      notes: notes.text.trim(),
    );
    try {
      c.id = await AppDb.saveCustomer(c);
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer == null ? 'New customer' : 'Edit customer')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadeSlideIn(
              index: 0,
              child: TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 1,
              child: TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email';
                },
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 3,
              child: TextFormField(
                controller: address,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 4,
              child: TextFormField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.sticky_note_2_outlined)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save customer')),
        ),
      ),
    );
  }
}

// =================================================================== DETAIL (statement)
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? customer;
  List<Doc> invoices = [];
  List<Doc> quotes = [];
  int tab = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final c = await AppDb.customer(widget.customerId);
    if (!mounted) return;
    if (c == null) {
      Navigator.pop(context);
      return;
    }
    final inv = await AppDb.docs('invoice', customerId: c.id);
    final q = await AppDb.docs('quote', customerId: c.id);
    if (mounted) {
      setState(() {
        customer = c;
        invoices = inv;
        quotes = q;
      });
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, slideRoute(page));
    load();
  }

  Future<void> delete() async {
    final ok = await confirm(context, 'Delete customer?', 'This cannot be undone.', okText: 'Delete', danger: true);
    if (!ok) return;
    try {
      await AppDb.deleteCustomer(customer!.id!);
      if (mounted) {
        toast(context, 'Customer deleted.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (customer == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final c = customer!;
    final scheme = Theme.of(context).colorScheme;
    double billed = 0;
    double paid = 0;
    for (final i in invoices) {
      if (i.status != 'draft' && i.status != 'cancelled') {
        billed += i.total;
        paid += i.paid;
      }
    }
    final list = tab == 0 ? invoices : quotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => open(CustomerFormScreen(customer: c))),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FadeSlideIn(
            child: AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.scale(scale: 1.2, child: InitialsAvatar(c.name)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (c.phone.isNotEmpty) contact(Icons.phone_outlined, c.phone),
                  if (c.email.isNotEmpty) contact(Icons.alternate_email_rounded, c.email),
                  if (c.address.isNotEmpty) contact(Icons.location_on_outlined, c.address),
                  if (c.notes.isNotEmpty) contact(Icons.sticky_note_2_outlined, c.notes),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                Expanded(child: stat('Billed', billed, scheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: stat('Paid', paid, Colors.green.shade600)),
                const SizedBox(width: 8),
                Expanded(child: stat('Balance', c.balance, Colors.orange.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => open(DocEditorScreen(type: 'quote', customerId: c.id)),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('New quote'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => open(DocEditorScreen(type: 'invoice', customerId: c.id)),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('New invoice'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text('Invoices (${invoices.length})')),
              ButtonSegment(value: 1, label: Text('Quotes (${quotes.length})')),
            ],
            selected: {tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(tab),
              children: list.isEmpty
                  ? [const Padding(padding: EdgeInsets.all(24), child: Text('Nothing yet.'))]
                  : [
                      for (var i = 0; i < list.length; i++)
                        FadeSlideIn(
                          index: i,
                          child: Padding(padding: const EdgeInsets.only(bottom: 8), child: DocTile(doc: list[i], onChanged: load)),
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contact(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget stat(String label, double value, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedNumber(value: value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          ),
        ],
      ),
    );
  }
}
