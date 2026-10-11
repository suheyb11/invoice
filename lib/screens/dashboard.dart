import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';
import 'documents.dart';
import 'settings.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> onOpenTab;
  const DashboardScreen({super.key, required this.onOpenTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? data;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final d = await AppDb.dashboard();
    if (mounted) setState(() => data = d);
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, slideRoute(page));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(App.settings['company_name'] ?? 'Dashboard'),
            Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => open(const SettingsScreen()),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  FadeSlideIn(index: 0, child: heroCard(context)),
                  const SizedBox(height: 12),
                  FadeSlideIn(index: 1, child: kpiGrid(context)),
                  const SizedBox(height: 12),
                  FadeSlideIn(index: 2, child: quickActions(context)),
                  const FadeSlideIn(index: 3, child: SectionTitle('Collected — last 6 months')),
                  FadeSlideIn(index: 3, child: chartCard(context)),
                  FadeSlideIn(
                    index: 4,
                    child: SectionTitle('Recent invoices', trailing: TextButton(onPressed: () => widget.onOpenTab(2), child: const Text('See all'))),
                  ),
                  if (data!.recent.isEmpty)
                    const AppCard(child: Text('No invoices yet. Create your first one.'))
                  else
                    for (var i = 0; i < data!.recent.length; i++)
                      FadeSlideIn(
                        index: 5 + i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DocTile(doc: data!.recent[i], onChanged: load),
                        ),
                      ),
                  if (data!.topNames.isNotEmpty) ...[
                    const SectionTitle('Top customers'),
                    FadeSlideIn(index: 8, child: topCustomers(context)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget heroCard(BuildContext context) {
    return PressScale(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Palette.blue,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Palette.blue.withAlpha(45), blurRadius: 20, offset: const Offset(0, 12))],
        ),
        child: Stack(
          children: [
            Positioned(right: -40, top: -50, child: bubble(150, 35)),
            Positioned(right: 50, bottom: -60, child: bubble(120, 22)),
            const Positioned(
              right: 20,
              top: 20,
              child: Floating(distance: 4, child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 34)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Outstanding balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  AnimatedNumber(
                    value: data!.outstanding,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      heroPill(Icons.warning_amber_rounded, '${data!.overdueCount} overdue · ${money(data!.overdueAmount)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bubble(double size, int alpha) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(alpha)));
  }

  Widget heroPill(IconData icon, String text) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
                child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Widget kpiGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: kpi('Invoiced this month', data!.invoicedThisMonth, Icons.receipt_long_rounded, Palette.blue)),
            const SizedBox(width: 12),
            Expanded(child: kpi('Collected this month', data!.collectedThisMonth, Icons.payments_rounded, Palette.blue)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: kpi('Open quotes (${data!.openQuotes})', data!.openQuotesValue, Icons.request_quote_rounded, Palette.orange)),
            const SizedBox(width: 12),
            Expanded(child: kpi('Quote win rate', data!.conversionRate, Icons.trending_up_rounded, Palette.orange, isMoney: false, suffix: '%')),
          ],
        ),
      ],
    );
  }

  Widget kpi(String label, double value, IconData icon, Color color, {bool isMoney = true, String suffix = ''}) {
    return ColorTile(
      color: color,
      icon: icon,
      label: label,
      value: AnimatedNumber(value: value, isMoney: isMoney, suffix: suffix),
    );
  }

  Widget quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ColorButton(
            onPressed: () => open(const DocEditorScreen(type: 'quote')),
            icon: Icons.add_rounded,
            text: 'New quote',
            color: Palette.orange,
            soft: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ColorButton(
            onPressed: () => open(const DocEditorScreen(type: 'invoice')),
            icon: Icons.add_rounded,
            text: 'New invoice',
            color: Palette.blue,
            soft: true,
          ),
        ),
      ],
    );
  }

  // Simple animated bar chart (no chart package needed).
  Widget chartCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double max = 0;
    for (final v in data!.monthTotals) {
      if (v > max) max = v;
    }
    return AppCard(
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < data!.months.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        data!.monthTotals[i] == 0 ? '' : NumberFormat.compact().format(data!.monthTotals[i]),
                        style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: max == 0 ? 0.02 : (data!.monthTotals[i] / max).clamp(0.02, 1.0)),
                        duration: Duration(milliseconds: 700 + i * 90),
                        curve: Curves.easeOutBack,
                        builder: (context, v, _) {
                          final last = i == data!.months.length - 1;
                          return Container(
                            height: 110 * v.clamp(0.0, 1.1),
                            decoration: BoxDecoration(
                              color: last ? scheme.primary : scheme.primary.withAlpha(90),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM').format(DateTime.parse('${data!.months[i]}-01')),
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget topCustomers(BuildContext context) {
    final max = data!.topTotals.isEmpty ? 1.0 : data!.topTotals.first;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < data!.topNames.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(data!.topNames[i], style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(money(data!.topTotals[i]), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: max == 0 ? 0.0 : data!.topTotals[i] / max),
                    duration: Duration(milliseconds: 800 + i * 120),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(25)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
