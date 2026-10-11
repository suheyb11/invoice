// Shared helpers, formatting and animated widgets.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------- Global app state
class App {
  static Map<String, String> settings = {};
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  static String get currency => settings['currency'] ?? '\$';
}

// ---------------------------------------------------------------- Colors
// Solid colors only (no gradients). One color per bottom tab.
class Palette {
  static const blue = Color(0xFF2563EB);
  static const orange = Color(0xFFEA580C);
  static const green = Color(0xFF059669);
  static const cyan = Color(0xFF0891B2);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFF59E0B);

  // Home, Quotes, Invoices, Customers, Products
  static const tabs = [blue, orange, green, cyan, red];
}

ThemeMode themeFromText(String? v) {
  if (v == 'light') return ThemeMode.light;
  if (v == 'dark') return ThemeMode.dark;
  return ThemeMode.system;
}

// ---------------------------------------------------------------- Formatting
final NumberFormat _moneyFormat = NumberFormat('#,##0.00');

String money(double v) => '${App.currency}${_moneyFormat.format(v)}';

String qtyText(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String dateToText(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String addDays(String date, int days) {
  final d = DateTime.parse(date).add(Duration(days: days));
  return dateToText(d);
}

String niceDate(String date) {
  if (date.isEmpty) return '-';
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
  } catch (e) {
    return date;
  }
}

String niceDateTime(String iso) {
  try {
    return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso));
  } catch (e) {
    return iso;
  }
}

double parseNum(String text) {
  return double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
}

String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

// ---------------------------------------------------------------- Page transition
Route<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, a, b) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------- Messages
void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? Colors.red.shade700 : null,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String okText = 'Yes', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return result == true;
}

// ---------------------------------------------------------------- Animated entrance (staggered)
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final delay = index.clamp(0, 10) * 60;
    final total = 500 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1.0, curve: Curves.easeOutCubic),
      builder: (context, v, ch) {
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - v)),
            child: Transform.scale(scale: 0.96 + 0.04 * v, child: ch),
          ),
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------- Press feedback
// Shrinks its child slightly while a finger is down. Does not consume taps.
class PressScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const PressScale({super.key, required this.child, this.scale = 0.97});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool down = false;

  void set(bool v) {
    if (down != v) setState(() => down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => set(true),
      onPointerUp: (_) => set(false),
      onPointerCancel: (_) => set(false),
      child: AnimatedScale(
        scale: down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------- Gentle up/down float
class Floating extends StatefulWidget {
  final Widget child;
  final double distance;
  const Floating({super.key, required this.child, this.distance = 6});

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(c.value);
        return Transform.translate(offset: Offset(0, widget.distance * (v * 2 - 1)), child: child);
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------- App logo
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Palette.blue,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [BoxShadow(color: Palette.blue.withAlpha(80), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}

// ---------------------------------------------------------------- Solid color button
class ColorButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool busy;

  // soft: light tinted background with colored text instead of a full color fill.
  final bool soft;

  const ColorButton({super.key, required this.text, required this.onPressed, this.icon, this.color = Palette.blue, this.busy = false, this.soft = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = soft ? (dark ? Color.lerp(color, Colors.white, 0.3)! : color) : Colors.white;
    return PressScale(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || busy ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: soft ? color.withAlpha(dark ? 50 : 30) : color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: soft ? null : [BoxShadow(color: color.withAlpha(80), blurRadius: 16, offset: const Offset(0, 7))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: busy
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                        : Row(
                            key: ValueKey(text),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                              Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Soft color tile (KPI)
// Light tinted background; the icon and number carry the color.
class ColorTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Widget value;

  const ColorTile({super.key, required this.color, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? Color.lerp(color, Colors.white, 0.3)! : color;
    return PressScale(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(dark ? 40 : 22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(dark ? 60 : 40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withAlpha(dark ? 60 : 35), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w800),
              child: value,
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Count-up numbers
class AnimatedNumber extends StatelessWidget {
  final double value;
  final bool isMoney;
  final String suffix;
  final TextStyle? style;

  const AnimatedNumber({super.key, required this.value, this.isMoney = true, this.suffix = '', this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = isMoney ? money(v) : '${v.round()}$suffix';
        return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

// ---------------------------------------------------------------- Card
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: dark ? null : [BoxShadow(color: scheme.primary.withAlpha(18), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: dark ? const Color(0xFF181B24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant.withAlpha(dark ? 60 : 70)),
            ),
            child: child,
          ),
        ),
      ),
    );
    return onTap == null ? card : PressScale(scale: 0.98, child: card);
  }
}

// ---------------------------------------------------------------- Status chip
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  static Color colorFor(String s) {
    switch (s) {
      case 'paid':
      case 'accepted':
        return Colors.green.shade600;
      case 'partial':
        return Colors.orange.shade700;
      case 'overdue':
      case 'rejected':
        return Colors.red.shade600;
      case 'sent':
        return Colors.blue.shade600;
      case 'converted':
        return Colors.purple.shade500;
      case 'expired':
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return Colors.blueGrey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }
}

// ---------------------------------------------------------------- Empty state
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: FadeSlideIn(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: scheme.primary.withAlpha(25), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Search box
class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const SearchBox({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Label + value row
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Avatar with initials
class InitialsAvatar extends StatelessWidget {
  final String name;
  const InitialsAvatar(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    String initials = '?';
    if (parts.isNotEmpty) {
      initials = parts.first[0];
      if (parts.length > 1) initials += parts[1][0];
    }
    final colors = [Colors.blue, Colors.teal, Colors.orange, Colors.green, Colors.cyan, Colors.red, Colors.amber];
    final c = colors[name.length % colors.length];
    return CircleAvatar(
      backgroundColor: c.withAlpha(35),
      child: Text(initials.toUpperCase(), style: TextStyle(color: c.shade700, fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------- Section title
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
