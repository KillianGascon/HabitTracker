import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/habit_form_sheet.dart';
import 'screens/loading_screen.dart';
import 'screens/suivi_screen.dart';
import 'screens/today_screen.dart';
import 'storage/local_storage.dart';
import 'storage/secret_store.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/icons.dart';
import 'widgets/liquid_glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

/// Affiche le loader pendant le chargement (données, police), puis l'appli en fondu.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  HabitStore? _store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Durée minimale : le loader ne fait pas qu'un flash.
    final minimum = Future<void>.delayed(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    final store = await HabitStore.open(LocalStorage(prefs), const SecureSecretStore());
    // Police Inter (téléchargée au premier lancement) : on l'attend, sans
    // bloquer plus de 3 s hors connexion (repli sur la police du système).
    GoogleFonts.inter();
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 3)).then((_) {}, onError: (_) {});
    await minimum;
    if (!mounted) return;
    setState(() => _store = store);
    store.sync();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: store == null ? const LoadingScreen() : MesFichesApp(store: store),
      ),
    );
  }
}

class MesFichesApp extends StatelessWidget {
  const MesFichesApp({super.key, required this.store});
  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Mes fiches',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: buildTheme(Palette.light, Brightness.light),
        darkTheme: buildTheme(Palette.dark, Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) StoreScope.read(context).onResume();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
      ),
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _tab, children: const [TodayScreen(), SuiviScreen()]),
        ),
        // Barre d'onglets flottante en verre dépoli : le contenu défile dessous.
        extendBody: true,
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (dark ? Colors.black : p.accent).withValues(alpha: dark ? .35 : .14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LiquidGlass(
                dark: dark,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: dark ? .22 : .7), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      _tabButton(
                        p,
                        AppIconKind.calendarCheck,
                        'Aujourd’hui',
                        _tab == 0,
                        () => setState(() => _tab = 0),
                      ),
                      _tabButton(
                        p,
                        AppIconKind.squaresFour,
                        'Suivi',
                        _tab == 1,
                        () => setState(() => _tab = 1),
                      ),
                      _tabButton(p, AppIconKind.plusCircle, 'Nouvelle', false, () => openHabitForm(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(Palette p, AppIconKind icon, String label, bool active, VoidCallback onTap) {
    final color = active ? p.accent : p.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: SizedBox(
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: 24, color: color),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
