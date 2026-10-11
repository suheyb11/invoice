import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'firebase_options.dart';
import 'screens/customers.dart';
import 'screens/dashboard.dart';
import 'screens/documents.dart';
import 'screens/login.dart';
import 'screens/products.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const InvoiceApp());
}

// `accent` is the main color; each bottom tab passes its own (see Palette.tabs).
ThemeData buildTheme(Brightness brightness, {Color accent = Palette.blue}) {
  final light = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: accent, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
  final primary = light ? accent : Color.lerp(accent, Colors.white, 0.22)!;
  final scheme = base.copyWith(
    primary: primary,
    onPrimary: Colors.white,
    secondary: Palette.cyan,
    tertiary: Palette.orange,
    secondaryContainer: primary.withAlpha(light ? 38 : 60),
    onSecondaryContainer: light ? accent : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? const Color(0xFFF5F6FA) : const Color(0xFF0E1015),
    appBarTheme: AppBarTheme(
      backgroundColor: light ? const Color(0xFFF5F6FA) : const Color(0xFF0E1015),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface, letterSpacing: -0.3),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withAlpha(light ? 110 : 70),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(backgroundColor: light ? const Color(0xFF1E293B) : const Color(0xFF2A3040)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
    }),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: light ? Colors.white : const Color(0xFF161922),
      indicatorColor: scheme.primary.withAlpha(light ? 32 : 55),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
    ),
  );
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: App.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Invoice & Quotation',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}

// Shows the login screen, or the app when a user is signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SplashScreen();
        final user = snap.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: user == null ? const LoginScreen(key: ValueKey('login')) : SessionLoader(key: ValueKey(user.uid)),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (c, v, child) => Transform.scale(scale: v, child: child),
          child: const Floating(child: AppLogo(size: 88)),
        ),
      ),
    );
  }
}

// Loads this user's settings once after login, then opens the app.
class SessionLoader extends StatefulWidget {
  const SessionLoader({super.key});

  @override
  State<SessionLoader> createState() => _SessionLoaderState();
}

class _SessionLoaderState extends State<SessionLoader> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      App.settings = await AppDb.getSettings();
    } catch (e) {
      App.settings = Map<String, String>.from(AppDb.defaultSettings);
    }
    App.themeMode.value = themeFromText(App.settings['theme']);
    try {
      await AppDb.refreshStatuses();
    } catch (e) {
      // offline: statuses are refreshed again on the dashboard
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return ready ? const HomeShell() : const SplashScreen();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  void openTab(int i) {
    setState(() => index = i);
  }

  Widget page() {
    switch (index) {
      case 1:
        return const DocListScreen(type: 'quote');
      case 2:
        return const DocListScreen(type: 'invoice');
      case 3:
        return const CustomersScreen();
      case 4:
        return const ProductsScreen();
      default:
        return DashboardScreen(onOpenTab: openTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every tab has its own color; AnimatedTheme blends between them.
    return AnimatedTheme(
      data: buildTheme(Theme.of(context).brightness, accent: Palette.tabs[index]),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: shell(),
    );
  }

  Widget shell() {
    return Scaffold(
      // Each tab is rebuilt when opened, so it always shows fresh data.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(index), child: page()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: openTab,
        animationDuration: const Duration(milliseconds: 450),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.request_quote_outlined), selectedIcon: Icon(Icons.request_quote_rounded), label: 'Quotes'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Invoices'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Products'),
        ],
      ),
    );
  }
}
