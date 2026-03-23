import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrimeYardBootstrapApp());
}

class PrimeYardBootstrapApp extends StatefulWidget {
  const PrimeYardBootstrapApp({super.key});

  @override
  State<PrimeYardBootstrapApp> createState() => _PrimeYardBootstrapAppState();
}

class _PrimeYardBootstrapAppState extends State<PrimeYardBootstrapApp> {
  late final Future<_BootstrapPayload> _future = _init();

  Future<_BootstrapPayload> _init() async {
    String? startupError;
    try {
      await BackendService.initialize().timeout(const Duration(seconds: 12));
      await BackendService.ensureAnonymousSession().timeout(const Duration(seconds: 12));
    } catch (e) {
      startupError = e.toString();
    }
    final session = await AppSession.load();
    return _BootstrapPayload(session: session, startupError: startupError);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Palette.deepGreen,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo-mark.png', width: 120, height: 120),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Starting PrimeYard Workspace...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return PrimeYardApp(
          initialSession: snapshot.data!.session,
          startupError: snapshot.data!.startupError,
        );
      },
    );
  }
}

class _BootstrapPayload {
  final AppSession session;
  final String? startupError;

  const _BootstrapPayload({required this.session, this.startupError});
}

class FirebaseConfig {
  static const options = FirebaseOptions(
    apiKey: 'AIzaSyAf0ziL9na5z7CPodC33T1SjQVBOCXUFCg',
    appId: '1:1063126418476:android:d42f77528438d22ac7bd89',
    messagingSenderId: '1063126418476',
    projectId: 'primeyard-521ea',
    storageBucket: 'primeyard-521ea.firebasestorage.app',
  );
}



class BackendBootstrap {
  final WorkspaceState state;
  final String? error;
  final bool hasRemoteData;

  const BackendBootstrap({
    required this.state,
    this.error,
    required this.hasRemoteData,
  });

  bool get hasUsers => state.users.isNotEmpty;
  bool get hasClients => state.clients.isNotEmpty;
}

class Palette {
  static const green = Color(0xFF1A6B30);
  static const deepGreen = Color(0xFF0D3B1A);
  static const softGreen = Color(0xFF2F8A4B);
  static const gold = Color(0xFFF2B632);
  static const khaki = Color(0xFFD9CFB8);
  static const cream = Color(0xFFF5F1E8);
  static const card = Colors.white;
  static const text = Color(0xFF171717);
  static const muted = Color(0xFF6D665D);
  static const border = Color(0xFFE6DED0);
  static const danger = Color(0xFFC62828);
}

class PrimeYardApp extends StatefulWidget {
  final AppSession initialSession;
  final String? startupError;
  const PrimeYardApp({super.key, required this.initialSession, this.startupError});

  @override
  State<PrimeYardApp> createState() => _PrimeYardAppState();
}

class _PrimeYardAppState extends State<PrimeYardApp> {
  late AppSession session = widget.initialSession;

  void onSignedIn(AppSession value) => setState(() => session = value);

  Future<void> onSignedOut() async {
    await AppSession.clear();
    setState(() => session = const AppSession());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.green,
      primary: Palette.green,
      secondary: Palette.gold,
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PrimeYard Workspace',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.cream,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Palette.text,
              displayColor: Palette.text,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Palette.text,
        ),
        cardTheme: CardThemeData(
          color: Palette.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Palette.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Palette.green, width: 1.5),
          ),
        ),
      ),
      home: session.loggedIn
          ? WorkspaceShell(session: session, onSignOut: onSignedOut)
          : LoginScreen(onSignedIn: onSignedIn, startupError: widget.startupError),
    );
  }
}

class AppSession {
  final bool loggedIn;
  final String id;
  final String username;
  final String displayName;
  final String role;

  const AppSession({
    this.loggedIn = false,
    this.id = '',
    this.username = '',
    this.displayName = '',
    this.role = '',
  });

  static Future<AppSession> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSession(
      loggedIn: prefs.getBool('loggedIn') ?? false,
      id: prefs.getString('uid') ?? '',
      username: prefs.getString('username') ?? '',
      displayName: prefs.getString('displayName') ?? '',
      role: prefs.getString('role') ?? '',
    );
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', loggedIn);
    await prefs.setString('uid', id);
    await prefs.setString('username', username);
    await prefs.setString('displayName', displayName);
    await prefs.setString('role', role);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

class WorkspaceState {
  final List<dynamic> clients;
  final List<dynamic> invoices;
  final List<dynamic> jobs;
  final List<dynamic> emps;
  final List<dynamic> quotes;
  final List<dynamic> equipment;
  final List<dynamic> checkLogs;
  final List<dynamic> clockEntries;
  final List<dynamic> users;
  final String schedDate;
  final DateTime? updatedAt;

  const WorkspaceState({
    required this.clients,
    required this.invoices,
    required this.jobs,
    required this.emps,
    required this.quotes,
    required this.equipment,
    required this.checkLogs,
    required this.clockEntries,
    required this.users,
    required this.schedDate,
    this.updatedAt,
  });

  factory WorkspaceState.empty() => WorkspaceState(
        clients: const [],
        invoices: const [],
        jobs: const [],
        emps: const [],
        quotes: const [],
        equipment: const [],
        checkLogs: const [],
        clockEntries: const [],
        users: const [],
        schedDate: _today(),
      );

  factory WorkspaceState.fromMap(Map<String, dynamic>? map) {
    final data = map ?? <String, dynamic>{};
    return WorkspaceState(
      clients: List<dynamic>.from(data['clients'] ?? const []),
      invoices: List<dynamic>.from(data['invoices'] ?? const []),
      jobs: List<dynamic>.from(data['jobs'] ?? const []),
      emps: List<dynamic>.from(data['emps'] ?? const []),
      quotes: List<dynamic>.from(data['quotes'] ?? const []),
      equipment: List<dynamic>.from(data['equipment'] ?? const []),
      checkLogs: List<dynamic>.from(data['checkLogs'] ?? const []),
      clockEntries: List<dynamic>.from(data['clockEntries'] ?? const []),
      users: List<dynamic>.from(data['users'] ?? const []),
      schedDate: (data['schedDate'] ?? _today()).toString(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'clients': clients,
        'invoices': invoices,
        'jobs': jobs,
        'emps': emps,
        'quotes': quotes,
        'equipment': equipment,
        'checkLogs': checkLogs,
        'clockEntries': clockEntries,
        'users': users,
        'schedDate': schedDate,
      };

  WorkspaceState copyWith({
    List<dynamic>? clients,
    List<dynamic>? invoices,
    List<dynamic>? jobs,
    List<dynamic>? emps,
    List<dynamic>? quotes,
    List<dynamic>? equipment,
    List<dynamic>? checkLogs,
    List<dynamic>? clockEntries,
    List<dynamic>? users,
    String? schedDate,
    DateTime? updatedAt,
  }) {
    return WorkspaceState(
      clients: clients ?? this.clients,
      invoices: invoices ?? this.invoices,
      jobs: jobs ?? this.jobs,
      emps: emps ?? this.emps,
      quotes: quotes ?? this.quotes,
      equipment: equipment ?? this.equipment,
      checkLogs: checkLogs ?? this.checkLogs,
      clockEntries: clockEntries ?? this.clockEntries,
      users: users ?? this.users,
      schedDate: schedDate ?? this.schedDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


class BackendService {
  static final _auth = fb.FirebaseAuth.instance;
  static final _doc = FirebaseFirestore.instance.collection('primeyard').doc('sharedState');

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: FirebaseConfig.options);
    }
  }

  static Future<void> ensureAnonymousSession() async {
    await initialize();
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  static Future<void> _cacheStateMap(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedWorkspaceState', jsonEncode(data));
  }

  static Future<void> _cacheUsers(List<dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedUsers', jsonEncode(users));
  }

  static Future<WorkspaceState> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cachedWorkspaceState');
    if (raw == null || raw.isEmpty) return WorkspaceState.empty();
    try {
      return WorkspaceState.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WorkspaceState.empty();
    }
  }

  static Future<List<Map<String, dynamic>>> _loadCachedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cachedUsers');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<BackendBootstrap> bootstrap() async {
    try {
      await ensureAnonymousSession();
      final snap = await _doc.get();
      if (!snap.exists) {
        final cached = await _loadCachedState();
        return BackendBootstrap(
          state: cached,
          hasRemoteData: false,
          error: 'No live sharedState document was found in Firestore.',
        );
      }
      final data = Map<String, dynamic>.from(snap.data() ?? const {});
      await _cacheStateMap(data);
      await _cacheUsers(List<dynamic>.from(data['users'] ?? const []));
      return BackendBootstrap(
        state: WorkspaceState.fromMap(data),
        hasRemoteData: true,
      );
    } catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(
        state: cached,
        hasRemoteData: false,
        error: e.toString(),
      );
    }
  }

  static Stream<WorkspaceState> streamState() async* {
    await ensureAnonymousSession();
    yield* _doc.snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) {
        return await _loadCachedState();
      }
      final data = Map<String, dynamic>.from(snapshot.data() ?? const {});
      await _cacheStateMap(data);
      await _cacheUsers(List<dynamic>.from(data['users'] ?? const []));
      return WorkspaceState.fromMap(data);
    });
  }

  static Future<WorkspaceState> getState() async {
    try {
      await ensureAnonymousSession();
      final snap = await _doc.get();
      if (!snap.exists) return await _loadCachedState();
      final data = Map<String, dynamic>.from(snap.data() ?? const {});
      await _cacheStateMap(data);
      await _cacheUsers(List<dynamic>.from(data['users'] ?? const []));
      return WorkspaceState.fromMap(data);
    } catch (_) {
      return await _loadCachedState();
    }
  }

  static Future<Map<String, dynamic>?> login(String username, String password) async {
    final normalizedUser = username.trim().toLowerCase();
    final hashes = <String>{_hash(password), _legacyHash(password)};

    Future<Map<String, dynamic>?> fromUsers(List<dynamic> users) async {
      for (final entry in users) {
        if (entry is Map) {
          final u = Map<String, dynamic>.from(entry);
          final userName = (u['username'] ?? '').toString().trim().toLowerCase();
          final passwordHash = (u['passwordHash'] ?? '').toString();
          if (userName == normalizedUser && hashes.contains(passwordHash)) {
            return u;
          }
        }
      }
      return null;
    }

    final state = await getState();
    final hit = await fromUsers(state.users);
    if (hit != null) return hit;

    final cached = await _loadCachedUsers();
    return await fromUsers(cached);
  }

  static Future<void> saveState(WorkspaceState state, {String updatedBy = 'flutter_v6_relinked'}) async {
    final data = {
      ...state.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
    await _doc.set(data, SetOptions(merge: true));
    await _cacheStateMap(state.toMap());
    await _cacheUsers(state.users);
  }
}

class LoginScreen extends StatefulWidget {
  final ValueChanged<AppSession> onSignedIn;
  final String? startupError;
  const LoginScreen({super.key, required this.onSignedIn, this.startupError});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = true;
  String? error;
  BackendBootstrap? bootstrap;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final info = await BackendService.bootstrap();
    if (!mounted) return;
    setState(() {
      bootstrap = info;
      loading = false;
      if (info.error != null && info.state.users.isEmpty) {
        error = info.error;
      } else if (info.state.users.isEmpty) {
        error = 'Connected, but no shared users were found in primeyard/sharedState.';
      }
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    final user = await BackendService.login(userCtrl.text, passCtrl.text);
    if (user == null) {
      setState(() {
        error = 'Incorrect username or password, or shared users have not synced yet.';
        loading = false;
      });
      return;
    }
    final session = AppSession(
      loggedIn: true,
      id: (user['id'] ?? '').toString(),
      username: (user['username'] ?? '').toString(),
      displayName: (user['displayName'] ?? 'PrimeYard').toString(),
      role: (user['role'] ?? 'worker').toString(),
    );
    await session.persist();
    widget.onSignedIn(session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Palette.deepGreen, Palette.green, Palette.softGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        Center(child: Image.asset('assets/logo-full.png', height: 64)),
                        const SizedBox(height: 8),
                        Text(
                          'Business Manager',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Palette.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your property, our pride.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Image.asset('assets/mascot.png', height: 180, fit: BoxFit.contain),
                        const SizedBox(height: 18),
                        if (bootstrap != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F4EC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Palette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      bootstrap!.hasRemoteData ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                      color: bootstrap!.hasRemoteData ? Palette.green : Palette.danger,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      bootstrap!.hasRemoteData ? 'Live workspace connected' : 'Live workspace not confirmed',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Users: ${bootstrap!.state.users.length} · Clients: ${bootstrap!.state.clients.length} · Jobs: ${bootstrap!.state.jobs.length}',
                                  style: const TextStyle(color: Palette.muted),
                                ),
                                if (bootstrap!.error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    bootstrap!.error!,
                                    style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: userCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Username'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(labelText: 'Password'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(error!, style: const TextStyle(color: Palette.danger, fontWeight: FontWeight.w700)),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: loading ? null : _login,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(loading ? 'Signing in...' : 'Sign in'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Use your PrimeYard Workspace username and password',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Palette.muted, fontSize: 12),
                        )
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

class WorkspaceShell extends StatefulWidget {
  final AppSession session;
  final Future<void> Function() onSignOut;
  const WorkspaceShell({super.key, required this.session, required this.onSignOut});

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkspaceState>(
      stream: BackendService.streamState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final state = snapshot.data ?? WorkspaceState.empty();
        final pages = _pagesForRole(widget.session.role, state);
        if (index >= pages.length) index = 0;
        final current = pages[index];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                Image.asset('assets/logo-mark.png', width: 28, height: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(
                        widget.session.displayName,
                        style: const TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => showAboutDialog(
                  context: context,
                  applicationName: 'PrimeYard Workspace',
                  applicationVersion: 'v4',
                  children: const [Text('Native Flutter rebuild with live Firestore sync status.')],
                ),
                icon: const Icon(Icons.info_outline_rounded),
              ),
              IconButton(
                onPressed: () async => widget.onSignOut(),
                icon: const Icon(Icons.logout_rounded),
              )
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: current.builder(context, state),
          ),
          bottomNavigationBar: NavigationBar(
            height: 72,
            selectedIndex: index,
            destinations: [
              for (final page in pages) NavigationDestination(icon: Icon(page.icon), label: page.shortLabel),
            ],
            onDestinationSelected: (value) => setState(() => index = value),
          ),
        );
      },
    );
  }

  List<_PageDef> _pagesForRole(String role, WorkspaceState state) {
    if (role == 'worker') {
      return [
        _PageDef('Today', 'Today', Icons.today_rounded, (c, s) => WorkerTodayPage(session: widget.session, state: s)),
        _PageDef('Equipment', 'Equipment', Icons.handyman_rounded, (c, s) => EquipmentPage(state: s, session: widget.session)),
      ];
    }
    if (role == 'supervisor') {
      return [
        _PageDef('Dashboard', 'Home', Icons.dashboard_rounded, (c, s) => DashboardPage(state: s)),
        _PageDef('Scheduler', 'Jobs', Icons.calendar_month_rounded, (c, s) => SchedulerPage(state: s, session: widget.session)),
        _PageDef('Equipment', 'Checks', Icons.handyman_rounded, (c, s) => EquipmentPage(state: s, session: widget.session)),
        _PageDef('Jobs log', 'Log', Icons.task_alt_rounded, (c, s) => JobsLogPage(state: s)),
      ];
    }
    return [
      _PageDef('Dashboard', 'Home', Icons.dashboard_rounded, (c, s) => DashboardPage(state: s)),
      _PageDef('Clients', 'Clients', Icons.people_alt_rounded, (c, s) => ClientsPage(state: s, session: widget.session)),
      _PageDef('Invoices', 'Bills', Icons.receipt_long_rounded, (c, s) => InvoicesPage(state: s, session: widget.session)),
      _PageDef('Scheduler', 'Jobs', Icons.calendar_month_rounded, (c, s) => SchedulerPage(state: s, session: widget.session)),
      _PageDef('Staff', 'Staff', Icons.badge_rounded, (c, s) => EmployeesPage(state: s, session: widget.session)),
      _PageDef('More', 'More', Icons.tune_rounded, (c, s) => MorePage(state: s, session: widget.session)),
    ];
  }
}

class _PageDef {
  final String label;
  final String shortLabel;
  final IconData icon;
  final Widget Function(BuildContext, WorkspaceState) builder;
  _PageDef(this.label, this.shortLabel, this.icon, this.builder);
}

class DashboardPage extends StatelessWidget {
  final WorkspaceState state;
  const DashboardPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final activeClients = state.clients.whereType<Map>().where((e) => (e['active'] ?? true) == true).length;
    final recurring = state.clients.whereType<Map>().fold<double>(0, (sum, e) => sum + _num(e['rate']));
    final outstanding = state.invoices.whereType<Map>().where((e) => (e['status'] ?? '') == 'unpaid').fold<double>(0, (sum, e) => sum + _num(e['amount']));
    final todayJobs = state.jobs.whereType<Map>().where((e) => (e['date'] ?? '') == state.schedDate).toList();
    final done = todayJobs.where((e) => (e['done'] ?? false) == true).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _HeroCard(state: state),
        const SizedBox(height: 14),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          shrinkWrap: true,
          children: [
            _StatCard(title: 'Active clients', value: '$activeClients', subtitle: 'Recurring accounts', icon: Icons.people_alt_rounded, accent: Palette.green),
            _StatCard(title: 'Monthly recurring', value: _money(recurring), subtitle: 'Expected monthly', icon: Icons.payments_rounded, accent: const Color(0xFF1565C0)),
            _StatCard(title: 'Outstanding', value: _money(outstanding), subtitle: 'Unpaid invoices', icon: Icons.receipt_long_rounded, accent: Palette.danger),
            _StatCard(title: 'Jobs today', value: '$done/${todayJobs.length}', subtitle: 'Completed route jobs', icon: Icons.task_alt_rounded, accent: const Color(0xFF6A1B9A)),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Mission',
          child: const Text(
            'Deliver dependable lawn and property care with professional standards, honest communication, and visible pride in every finished result.',
            style: TextStyle(height: 1.6),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Core values',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _Chip(text: 'Reliability'),
              _Chip(text: 'Professional presentation'),
              _Chip(text: 'Respect for property'),
              _Chip(text: 'Clear communication'),
              _Chip(text: 'Consistent quality'),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final WorkspaceState state;
  const _HeroCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Palette.deepGreen, Palette.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x25000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PrimeYard Workspace', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text(
                  'Run quotes, jobs, staff, invoices, and equipment from one polished mobile app.',
                  style: TextStyle(color: Color(0xE6FFFFFF), height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    state.updatedAt == null ? 'Waiting for live sync timestamp' : 'Last sync ${DateFormat('HH:mm').format(state.updatedAt!)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Image.asset('assets/mascot.png', height: 128),
        ],
      ),
    );
  }
}

class ClientsPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const ClientsPage({super.key, required this.state, required this.session});

  Future<void> _addClient(BuildContext context) async {
    final name = TextEditingController();
    final address = TextEditingController();
    final rate = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'New client',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Client name')),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address / area')),
            const SizedBox(height: 10),
            TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly rate (R)')),
          ],
        ),
      ),
    );
    if (result != true) return;
    final items = List<dynamic>.from(state.clients);
    items.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name.text.trim(),
      'address': address.text.trim(),
      'rate': double.tryParse(rate.text.trim()) ?? 0,
      'active': true,
      'createdAt': _today(),
    });
    await BackendService.saveState(state.copyWith(clients: items), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final clients = state.clients.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(
          title: 'Clients',
          subtitle: '${clients.length} total',
          action: FilledButton.icon(
            onPressed: () => _addClient(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add client'),
          ),
        ),
        for (final client in clients)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(client['name']))),
                title: Text((client['name'] ?? 'Unnamed').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${client['address'] ?? 'No address'}\n${_money(_num(client['rate']))} / month'),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (client['active'] ?? true) ? const Color(0xFFE8F5E9) : const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text((client['active'] ?? true) ? 'Active' : 'Paused'),
                ),
              ),
            ),
          )
      ],
    );
  }
}

class InvoicesPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const InvoicesPage({super.key, required this.state, required this.session});

  Future<void> _addInvoice(BuildContext context) async {
    final client = TextEditingController();
    final amount = TextEditingController();
    final status = ValueNotifier<String>('unpaid');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: status,
        builder: (context, value, _) => _EditDialog(
          title: 'New invoice',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: client, decoration: const InputDecoration(labelText: 'Client name')),
              const SizedBox(height: 10),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (R)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: value,
                items: const [
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                ],
                onChanged: (v) => status.value = v ?? 'unpaid',
                decoration: const InputDecoration(labelText: 'Status'),
              )
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final items = List<dynamic>.from(state.invoices);
    items.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'client': client.text.trim(),
      'amount': double.tryParse(amount.text.trim()) ?? 0,
      'status': status.value,
      'createdAt': _today(),
    });
    await BackendService.saveState(state.copyWith(invoices: items), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final invoices = state.invoices.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(
          title: 'Invoices',
          subtitle: '${invoices.length} records',
          action: FilledButton.icon(onPressed: () => _addInvoice(context), icon: const Icon(Icons.add_rounded), label: const Text('Add invoice')),
        ),
        for (final invoice in invoices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text((invoice['client'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Created ${invoice['createdAt'] ?? '-'}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_money(_num(invoice['amount'])), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    _StatusPill(text: (invoice['status'] ?? 'unpaid').toString()),
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }
}

class SchedulerPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const SchedulerPage({super.key, required this.state, required this.session});

  Future<void> _addJob(BuildContext context) async {
    final client = TextEditingController();
    final address = TextEditingController();
    final worker = TextEditingController();
    final date = TextEditingController(text: state.schedDate);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'Schedule job',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: client, decoration: const InputDecoration(labelText: 'Client name')),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 10),
            TextField(controller: worker, decoration: const InputDecoration(labelText: 'Worker name')),
            const SizedBox(height: 10),
            TextField(controller: date, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final jobs = List<dynamic>.from(state.jobs);
    jobs.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': client.text.trim(),
      'address': address.text.trim(),
      'workerName': worker.text.trim(),
      'date': date.text.trim().isEmpty ? _today() : date.text.trim(),
      'done': false,
    });
    await BackendService.saveState(state.copyWith(jobs: jobs), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => (e['date'] ?? '') == state.schedDate).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(
          title: 'Route scheduler',
          subtitle: 'Showing ${state.schedDate}',
          action: FilledButton.icon(onPressed: () => _addJob(context), icon: const Icon(Icons.add_rounded), label: const Text('Add job')),
        ),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                value: job['done'] == true,
                title: Text((job['name'] ?? 'Job').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${job['address'] ?? ''}\n${job['workerName'] ?? 'Unassigned'}'),
                onChanged: (v) async {
                  final updated = state.jobs.whereType<Map>().map((e) {
                    final item = Map<String, dynamic>.from(e);
                    if (item['id'] == job['id']) item['done'] = v ?? false;
                    return item;
                  }).toList();
                  await BackendService.saveState(state.copyWith(jobs: updated), updatedBy: session.username);
                },
              ),
            ),
          ),
        if (jobs.isEmpty)
          const _EmptyState(icon: Icons.calendar_month_rounded, title: 'No jobs scheduled', subtitle: 'Add jobs for the selected date to start building your route.')
      ],
    );
  }
}

class EquipmentPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const EquipmentPage({super.key, required this.state, required this.session});

  Future<void> _seedEquipment() async {
    if (state.equipment.isNotEmpty) return;
    const seed = [
      {'id': 'eq1', 'name': 'Brush cutter', 'status': 'ok'},
      {'id': 'eq2', 'name': 'Lawn mower', 'status': 'ok'},
      {'id': 'eq3', 'name': 'Blower', 'status': 'ok'},
      {'id': 'eq4', 'name': 'Hedge trimmer', 'status': 'ok'},
    ];
    await BackendService.saveState(state.copyWith(equipment: seed), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final items = state.equipment.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (items.isEmpty) {
      _seedEquipment();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Equipment checks', subtitle: '${items.length} tracked items'),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.handyman_rounded, color: Palette.green),
                        const SizedBox(width: 10),
                        Expanded(child: Text((item['name'] ?? 'Equipment').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        _StatusPill(text: (item['status'] ?? 'ok').toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final status in const ['ok', 'issue', 'missing'])
                          ChoiceChip(
                            label: Text(status.toUpperCase()),
                            selected: (item['status'] ?? 'ok') == status,
                            onSelected: (_) async {
                              final updated = state.equipment.whereType<Map>().map((e) {
                                final row = Map<String, dynamic>.from(e);
                                if (row['id'] == item['id']) row['status'] = status;
                                return row;
                              }).toList();
                              await BackendService.saveState(state.copyWith(equipment: updated), updatedBy: session.username);
                            },
                          )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        if (items.isEmpty)
          const _EmptyState(icon: Icons.handyman_rounded, title: 'Preparing equipment list', subtitle: 'The default PrimeYard gear list is being created.')
      ],
    );
  }
}

class EmployeesPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const EmployeesPage({super.key, required this.state, required this.session});

  Future<void> _addEmployee(BuildContext context) async {
    final name = TextEditingController();
    final rate = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'New employee',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily rate (R)')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final items = List<dynamic>.from(state.emps);
    items.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name.text.trim(),
      'dailyRate': double.tryParse(rate.text.trim()) ?? 0,
      'startDate': _today(),
    });
    await BackendService.saveState(state.copyWith(emps: items), updatedBy: session.username);
  }

  @override
  Widget build(BuildContext context) {
    final emps = state.emps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(
          title: 'Employees',
          subtitle: '${emps.length} on record',
          action: FilledButton.icon(onPressed: () => _addEmployee(context), icon: const Icon(Icons.add_rounded), label: const Text('Add employee')),
        ),
        for (final emp in emps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(emp['name']))),
                title: Text((emp['name'] ?? 'Employee').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Daily rate ${_money(_num(emp['dailyRate']))}\nStarted ${emp['startDate'] ?? '-'}'),
              ),
            ),
          )
      ],
    );
  }
}

class MorePage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const MorePage({super.key, required this.state, required this.session});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'More workspace tools', subtitle: 'Extra controls and live data'),
        _ActionTile(
          icon: Icons.handyman_rounded,
          title: 'Equipment',
          subtitle: 'Inspect and update daily equipment status',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Equipment')), body: EquipmentPage(state: state, session: session)))),
        ),
        _ActionTile(
          icon: Icons.task_alt_rounded,
          title: 'Jobs log',
          subtitle: 'View completed and pending jobs',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Jobs log')), body: JobsLogPage(state: state)))),
        ),
        _ActionTile(
          icon: Icons.manage_accounts_rounded,
          title: 'Users & access',
          subtitle: 'See staff accounts synced from Firebase',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Users & access')), body: UsersPage(state: state, session: session)))),
        ),
      ],
    );
  }
}

class JobsLogPage extends StatelessWidget {
  final WorkspaceState state;
  const JobsLogPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Jobs log', subtitle: '${jobs.length} total jobs'),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(job['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: job['done'] == true ? Palette.green : Palette.muted),
                title: Text((job['name'] ?? 'Job').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${job['date'] ?? '-'} · ${job['address'] ?? ''}\n${job['workerName'] ?? 'Unassigned'}'),
              ),
            ),
          )
      ],
    );
  }
}

class UsersPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const UsersPage({super.key, required this.state, required this.session});

  @override
  Widget build(BuildContext context) {
    final users = state.users.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Users & access', subtitle: '${users.length} staff accounts'),
        for (final user in users)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(user['displayName']))),
                title: Text((user['displayName'] ?? 'User').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${user['username'] ?? ''} · ${user['role'] ?? 'worker'}'),
                trailing: (user['username'] ?? '') == session.username ? const _StatusPill(text: 'You') : null,
              ),
            ),
          )
      ],
    );
  }
}

class WorkerTodayPage extends StatelessWidget {
  final AppSession session;
  final WorkspaceState state;
  const WorkerTodayPage({super.key, required this.session, required this.state});

  @override
  Widget build(BuildContext context) {
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((job) {
      final worker = (job['workerName'] ?? '').toString().toLowerCase();
      return worker == session.displayName.toLowerCase() || worker == session.username.toLowerCase() || worker.isEmpty;
    }).where((job) => (job['date'] ?? '') == state.schedDate).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'My route', subtitle: state.schedDate),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(job['done'] == true ? Icons.check_circle_rounded : Icons.location_on_rounded, color: Palette.green),
                title: Text((job['name'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(job['address']?.toString() ?? ''),
              ),
            ),
          ),
        if (jobs.isEmpty)
          const _EmptyState(icon: Icons.route_rounded, title: 'No route assigned', subtitle: 'No jobs are assigned to you for this date yet.')
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const _SectionHeader({required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Palette.muted)),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent),
            const Spacer(),
            Text(title, style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Palette.muted)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFE8F3EA), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    Color bg;
    Color fg;
    switch (lower) {
      case 'paid':
      case 'ok':
      case 'active':
      case 'you':
        bg = const Color(0xFFE8F5E9);
        fg = Palette.green;
        break;
      case 'issue':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFE65100);
        break;
      case 'missing':
      case 'unpaid':
        bg = const Color(0xFFFFEBEE);
        fg = Palette.danger;
        break;
      default:
        bg = const Color(0xFFF1F1F1);
        fg = Palette.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Icon(icon, color: Palette.green)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Palette.green),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted)),
          ],
        ),
      ),
    );
  }
}

class _EditDialog extends StatelessWidget {
  final String title;
  final Widget child;
  const _EditDialog({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(child: child),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    );
  }
}


String _hash(String input) => _legacyHash(input);

String _legacyHash(String msg) {
  int n(int x) => x & 0xffffffff;
  const k = [
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
  ];

  var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
  var h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

  final bytes = utf8.encode(msg).toList();
  final bitLength = bytes.length * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  bytes.addAll([0, 0, 0, 0, (bitLength >> 24) & 0xff, (bitLength >> 16) & 0xff, (bitLength >> 8) & 0xff, bitLength & 0xff]);

  for (var i = 0; i < bytes.length; i += 64) {
    final w = List<int>.filled(64, 0);
    for (var j = 0; j < 16; j++) {
      w[j] = (bytes[i + j * 4] << 24) |
          (bytes[i + j * 4 + 1] << 16) |
          (bytes[i + j * 4 + 2] << 8) |
          bytes[i + j * 4 + 3];
    }
    for (var j = 16; j < 64; j++) {
      final s0 = n(((w[j - 15] >> 7) | (w[j - 15] << 25)) ^ ((w[j - 15] >> 18) | (w[j - 15] << 14)) ^ (w[j - 15] >> 3));
      final s1 = n(((w[j - 2] >> 17) | (w[j - 2] << 15)) ^ ((w[j - 2] >> 19) | (w[j - 2] << 13)) ^ (w[j - 2] >> 10));
      w[j] = n(w[j - 16] + s0 + w[j - 7] + s1);
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, hh = h7;
    for (var j = 0; j < 64; j++) {
      final s1 = n(((e >> 6) | (e << 26)) ^ ((e >> 11) | (e << 21)) ^ ((e >> 25) | (e << 7)));
      final ch = (e & f) ^ ((~e) & g);
      final t1 = n(hh + s1 + ch + k[j] + w[j]);
      final s0 = n(((a >> 2) | (a << 30)) ^ ((a >> 13) | (a << 19)) ^ ((a >> 22) | (a << 10)));
      final maj = (a & b) ^ (a & c) ^ (b & d);
      final t2 = n(s0 + maj);
      hh = g;
      g = f;
      f = e;
      e = n(d + t1);
      d = c;
      c = b;
      b = a;
      a = n(t1 + t2);
    }

    h0 = n(h0 + a); h1 = n(h1 + b); h2 = n(h2 + c); h3 = n(h3 + d);
    h4 = n(h4 + e); h5 = n(h5 + f); h6 = n(h6 + g); h7 = n(h7 + hh);
  }

  return [h0, h1, h2, h3, h4, h5, h6, h7].map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(double value) => 'R${value.toStringAsFixed(2)}';
String _initials(dynamic name) {
  final parts = (name ?? '').toString().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'P';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}
