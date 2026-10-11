import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../db.dart';
import '../widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // One text controller per setting key.
  final Map<String, TextEditingController> c = {};
  String theme = 'system';
  bool saving = false;

  static const textKeys = [
    'company_name',
    'company_address',
    'company_phone',
    'company_email',
    'currency',
    'quote_prefix',
    'invoice_prefix',
    'default_tax',
    'quote_valid_days',
    'invoice_due_days',
    'quote_terms',
    'invoice_terms',
    'default_notes',
  ];

  @override
  void initState() {
    super.initState();
    for (final k in textKeys) {
      c[k] = TextEditingController(text: App.settings[k] ?? '');
    }
    theme = App.settings['theme'] ?? 'system';
  }

  @override
  void dispose() {
    for (final ctrl in c.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (c['company_name']!.text.trim().isEmpty) {
      toast(context, 'Company name is required.', error: true);
      return;
    }
    if (int.tryParse(c['quote_valid_days']!.text.trim()) == null || int.tryParse(c['invoice_due_days']!.text.trim()) == null) {
      toast(context, 'Days must be whole numbers.', error: true);
      return;
    }
    setState(() => saving = true);
    final values = <String, String>{};
    for (final k in textKeys) {
      values[k] = c[k]!.text.trim();
    }
    values['theme'] = theme;
    await AppDb.saveSettings(values);
    App.themeMode.value = themeFromText(theme);
    if (!mounted) return;
    setState(() => saving = false);
    toast(context, 'Settings saved.');
  }

  Future<void> clearAll() async {
    final ok = await confirm(context, 'Delete ALL data?', 'Every customer, product, quotation, invoice and payment will be deleted. Settings are kept.',
        okText: 'Delete everything', danger: true);
    if (!ok) return;
    await AppDb.clearAll();
    if (mounted) toast(context, 'All data deleted.');
  }

  Future<void> signOut() async {
    final ok = await confirm(context, 'Sign out?', 'You can sign in again any time. Your data stays safe in the cloud.', okText: 'Sign out');
    if (!ok || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await FirebaseAuth.instance.signOut();
  }

  Widget field(String key, String label, {int lines = 1, TextInputType? keyboard, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c[key],
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const digits = TextInputType.number;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle('Account'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
              subtitle: const Text('Data is saved in Firebase and synced across devices'),
              trailing: TextButton(onPressed: signOut, child: const Text('Sign out')),
            ),
          ),
          const SectionTitle('Company (shown on PDFs)'),
          FadeSlideIn(
            index: 0,
            child: Column(
              children: [
                field('company_name', 'Company name', icon: Icons.business_rounded),
                field('company_address', 'Address', lines: 2, icon: Icons.location_on_outlined),
                field('company_phone', 'Phone', keyboard: TextInputType.phone, icon: Icons.phone_outlined),
                field('company_email', 'Email', keyboard: TextInputType.emailAddress, icon: Icons.alternate_email_rounded),
              ],
            ),
          ),
          const SectionTitle('Money & numbering'),
          FadeSlideIn(
            index: 1,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: field('currency', 'Currency symbol')),
                    const SizedBox(width: 10),
                    Expanded(child: field('default_tax', 'Default tax %', keyboard: digits)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: field('quote_prefix', 'Quote prefix')),
                    const SizedBox(width: 10),
                    Expanded(child: field('invoice_prefix', 'Invoice prefix')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: field('quote_valid_days', 'Quote valid (days)', keyboard: digits)),
                    const SizedBox(width: 10),
                    Expanded(child: field('invoice_due_days', 'Invoice due (days)', keyboard: digits)),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Default text'),
          FadeSlideIn(
            index: 2,
            child: Column(
              children: [
                field('quote_terms', 'Quotation terms', lines: 3),
                field('invoice_terms', 'Invoice terms', lines: 3),
                field('default_notes', 'Default notes', lines: 2),
              ],
            ),
          ),
          const SectionTitle('Appearance'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
              ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
              ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
            ],
            selected: {theme},
            onSelectionChanged: (s) {
              setState(() => theme = s.first);
              App.themeMode.value = themeFromText(theme); // preview right away
            },
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save settings')),
          const SectionTitle('Data'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: Colors.red.shade600),
                  title: Text('Delete all data', style: TextStyle(color: Colors.red.shade600)),
                  onTap: clearAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('Invoice & Quotation · v1.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
