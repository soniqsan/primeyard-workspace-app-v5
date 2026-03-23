import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
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
    } catch (e) {
      startupError = 'Firebase init failed: $e';
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
          : (data['updatedAt'] is String
              ? DateTime.tryParse(data['updatedAt'])
              : null),
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

    if (_auth.currentUser != null) {
      return;
    }

    await _auth.signInAnonymously();

    if (_auth.currentUser != null) {
      return;
    }

    await _auth.authStateChanges().firstWhere((user) => user != null);
  }

  static Future<void> _cacheStateMap(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedWorkspaceState', jsonEncode(_jsonSafeMap(data)));
  }

  static Future<void> _cacheUsers(List<dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedUsers', jsonEncode(_jsonSafe(users)));
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

      final snap = await _doc.get(const GetOptions(source: Source.serverAndCache));

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

      final state = WorkspaceState.fromMap(data);
      final hasRemoteData = state.users.isNotEmpty ||
          state.clients.isNotEmpty ||
          state.jobs.isNotEmpty ||
          state.invoices.isNotEmpty;

      return BackendBootstrap(
        state: state,
        hasRemoteData: hasRemoteData,
        error: hasRemoteData ? null : 'Connected, but the live sharedState is empty.',
      );
    } on fb.FirebaseAuthException catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(
        state: cached,
        hasRemoteData: false,
        error: '[firebase_auth/${e.code}] ${e.message ?? 'Authentication failed.'}',
      );
    } on FirebaseException catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(
        state: cached,
        hasRemoteData: false,
        error: '[firebase/${e.code}] ${e.message ?? 'Firestore failed.'}',
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
    try {
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
    } catch (_) {
      yield await _loadCachedState();
    }
  }

  static Future<WorkspaceState> getState() async {
    try {
      await ensureAnonymousSession();

      final snap = await _doc.get(const GetOptions(source: Source.serverAndCache));

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
    final trimmedPassword = password.trim();
    final hashes = <String>{
      _hash(trimmedPassword),
      _legacyHash(trimmedPassword),
      trimmedPassword,
    };

    bool usernameMatches(Map<String, dynamic> u) {
      final candidates = <String>{
        (u['username'] ?? '').toString().trim().toLowerCase(),
        (u['userName'] ?? '').toString().trim().toLowerCase(),
        (u['name'] ?? '').toString().trim().toLowerCase(),
        (u['displayName'] ?? '').toString().trim().toLowerCase(),
        (u['email'] ?? '').toString().trim().toLowerCase(),
      }..removeWhere((e) => e.isEmpty);

      return candidates.contains(normalizedUser);
    }

    bool passwordMatches(Map<String, dynamic> u) {
      final candidates = <String>{
        (u['passwordHash'] ?? '').toString().trim(),
        (u['password'] ?? '').toString().trim(),
        (u['passcode'] ?? '').toString().trim(),
        (u['pin'] ?? '').toString().trim(),
      }..removeWhere((e) => e.isEmpty);

      return candidates.any((p) => hashes.contains(p));
    }

    Future<Map<String, dynamic>?> fromUsers(List<dynamic> users) async {
      for (final entry in users) {
        if (entry is Map) {
          final u = Map<String, dynamic>.from(entry);
          if (usernameMatches(u) && passwordMatches(u)) {
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

  static Future<void> saveState(
    WorkspaceState state, {
    String updatedBy = 'flutter_v6_relinked',
  }) async {
    await ensureAnonymousSession();

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
        error = 'Incorrect username or password.';
        loading = false;
      });
      return;
    }
    final session = AppSession(
      loggedIn: true,
      id: (user['id'] ?? '').toString(),
      username: (user['username'] ?? '').toString(),
      displayName: (user['displayName'] ?? user['name'] ?? user['username'] ?? 'PrimeYard').toString(),
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
                                      bootstrap!.hasRemoteData
                                          ? Icons.cloud_done_rounded
                                          : Icons.cloud_off_rounded,
                                      color: bootstrap!.hasRemoteData ? Palette.green : Palette.danger,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      bootstrap!.hasRemoteData
                                          ? 'Live workspace connected'
                                          : 'Live workspace not confirmed',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Use your PrimeYard Workspace username and password.',
                                  style: TextStyle(color: Palette.muted),
                                ),
                                if (bootstrap!.error != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    bootstrap!.error!,
                                    style: const TextStyle(
                                      color: Palette.danger,
                                      fontWeight: FontWeight.w700,
                                    ),
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
        _PageDef('Clock', 'Clock', Icons.punch_clock_rounded, (c, s) => ClockPage(state: s, session: widget.session)),
        _PageDef('Checks', 'Checks', Icons.handyman_rounded, (c, s) => EquipmentPage(state: s, session: widget.session)),
      ];
    }
    if (role == 'supervisor') {
      return [
        _PageDef('Dashboard', 'Home', Icons.dashboard_rounded, (c, s) => DashboardPage(state: s, session: widget.session)),
        _PageDef('Clock', 'Clock', Icons.punch_clock_rounded, (c, s) => ClockPage(state: s, session: widget.session)),
        _PageDef('Scheduler', 'Jobs', Icons.calendar_month_rounded, (c, s) => SchedulerPage(state: s, session: widget.session)),
        _PageDef('Checks', 'Checks', Icons.handyman_rounded, (c, s) => EquipmentPage(state: s, session: widget.session)),
        _PageDef('Jobs log', 'Log', Icons.task_alt_rounded, (c, s) => JobsLogPage(state: s, session: widget.session)),
      ];
    }
    return [
      _PageDef('Dashboard', 'Home', Icons.dashboard_rounded, (c, s) => DashboardPage(state: s, session: widget.session)),
      _PageDef('Quotes', 'Quotes', Icons.calculate_rounded, (c, s) => QuotesPage(state: s, session: widget.session)),
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
  final AppSession session;
  const DashboardPage({super.key, required this.state, required this.session});

  @override
  Widget build(BuildContext context) {
    final activeClients = state.clients.whereType<Map>().where((e) => (e['active'] ?? true) == true).length;
    final recurring = state.clients.whereType<Map>().fold<double>(0, (sum, e) => sum + _num(e['rate']));
    final outstanding = state.invoices.whereType<Map>().where((e) => (e['status'] ?? '') == 'unpaid').fold<double>(0, (sum, e) => sum + _num(e['amount']));
    final weekJobs = _jobsThisWeek(state.jobs);
    final done = weekJobs.where((e) => (e['done'] ?? false) == true).length;
    final activeEntries = _activeClockEntries(state.clockEntries);
    final todayChecks = _todayCheckIssues(state.checkLogs);

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
            _StatCard(title: 'Jobs this week', value: '$done/${weekJobs.length}', subtitle: 'Completed', icon: Icons.task_alt_rounded, accent: const Color(0xFF6A1B9A)),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Currently clocked in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (activeEntries.isEmpty)
                  const Text('No staff members are currently clocked in.', style: TextStyle(color: Palette.muted))
                else
                  ...activeEntries.map((entry) {
                    final emp = _findEmployeeById(state.emps, (entry['empId'] ?? '').toString());
                    final label = (emp?['name'] ?? entry['empId'] ?? 'Worker').toString();
                    final started = _fmtDateTime((entry['clockIn'] ?? '').toString());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.punch_clock_rounded, color: Palette.green),
                          const SizedBox(width: 10),
                          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text(started, style: const TextStyle(color: Palette.muted)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (todayChecks.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Equipment issues today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  ...todayChecks.take(6).map((issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(issue['status'] == 'missing' ? Icons.error_outline_rounded : Icons.build_circle_outlined, color: issue['status'] == 'missing' ? Palette.danger : Palette.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${issue['equipmentName'] ?? 'Equipment'} • ${issue['status'] ?? ''}${(issue['note'] ?? '').toString().isNotEmpty ? ' • ${issue['note']}' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
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

class EquipmentPage extends StatefulWidget {
  final WorkspaceState state;
  final AppSession session;
  const EquipmentPage({super.key, required this.state, required this.session});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  String phase = 'morning';
  String? selectedEmpId;
  late Map<String, Map<String, dynamic>> items;

  @override
  void initState() {
    super.initState();
    selectedEmpId = _resolveCurrentEmpId();
    _loadExisting();
  }

  String? _resolveCurrentEmpId() {
    final emp = _findEmployeeForSession(widget.state.emps, widget.session);
    return (emp?['id'] ?? '').toString().isEmpty ? null : (emp?['id']).toString();
  }

  List<Map<String, dynamic>> get equipmentItems {
    final base = widget.state.equipment.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (base.isNotEmpty) return base;
    return const [
      {'id': 'eq1', 'name': 'Brush cutter', 'status': 'ok'},
      {'id': 'eq2', 'name': 'Lawn mower', 'status': 'ok'},
      {'id': 'eq3', 'name': 'Blower', 'status': 'ok'},
      {'id': 'eq4', 'name': 'Hedge trimmer', 'status': 'ok'},
      {'id': 'eq5', 'name': 'Fuel can', 'status': 'ok'},
      {'id': 'eq6', 'name': 'PPE & safety gear', 'status': 'ok'},
    ];
  }

  void _loadExisting() {
    final current = _existingLog();
    items = {
      for (final eq in equipmentItems)
        (eq['id'] ?? '').toString(): {
          'equipmentId': (eq['id'] ?? '').toString(),
          'equipmentName': (eq['name'] ?? 'Equipment').toString(),
          'status': 'ok',
          'note': '',
        }
    };
    if (current != null) {
      final data = List<Map<String, dynamic>>.from(((current[phase] ?? const {})['items'] ?? const []).map((e) => Map<String, dynamic>.from(e)));
      for (final row in data) {
        final id = (row['equipmentId'] ?? '').toString();
        if (items.containsKey(id)) {
          items[id] = {
            'equipmentId': id,
            'equipmentName': row['equipmentName'] ?? items[id]!['equipmentName'],
            'status': row['status'] ?? 'ok',
            'note': row['note'] ?? '',
          };
        }
      }
    }
  }

  Map<String, dynamic>? _existingLog() {
    final empId = selectedEmpId;
    if (empId == null || empId.isEmpty) return null;
    for (final entry in widget.state.checkLogs.whereType<Map>()) {
      final row = Map<String, dynamic>.from(entry);
      if ((row['date'] ?? '') == _today() && (row['empId'] ?? '') == empId) {
        return row;
      }
    }
    return null;
  }

  Future<void> _saveChecklist() async {
    final empId = selectedEmpId;
    if (empId == null || empId.isEmpty) return;
    final employee = _findEmployeeById(widget.state.emps, empId);
    final rows = items.values.map((e) => Map<String, dynamic>.from(e)).toList();
    final summary = {
      'submittedAt': DateTime.now().toIso8601String(),
      'submittedBy': widget.session.username,
      'items': rows,
    };
    final existing = widget.state.checkLogs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final idx = existing.indexWhere((e) => (e['date'] ?? '') == _today() && (e['empId'] ?? '') == empId);
    final payload = {
      'id': idx == -1 ? DateTime.now().millisecondsSinceEpoch.toString() : (existing[idx]['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()),
      'date': _today(),
      'empId': empId,
      'employeeName': (employee?['name'] ?? widget.session.displayName).toString(),
      'morning': idx != -1 ? existing[idx]['morning'] : null,
      'evening': idx != -1 ? existing[idx]['evening'] : null,
    };
    payload[phase] = summary;
    if (idx == -1) {
      existing.insert(0, payload);
    } else {
      existing[idx] = payload;
    }
    await BackendService.saveState(widget.state.copyWith(checkLogs: existing, equipment: equipmentItems), updatedBy: widget.session.username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${phase[0].toUpperCase()}${phase.substring(1)} check saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final emps = widget.state.emps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final recent = widget.state.checkLogs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => (e['date'] ?? '') == _today()).toList();
    return StatefulBuilder(
      builder: (context, refresh) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _SectionHeader(title: 'Equipment checks', subtitle: 'Morning and evening compliance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.session.role != 'worker')
                      DropdownButtonFormField<String>(
                        value: selectedEmpId,
                        items: emps.map((emp) => DropdownMenuItem<String>(value: (emp['id'] ?? '').toString(), child: Text((emp['name'] ?? 'Employee').toString()))).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedEmpId = value;
                            _loadExisting();
                          });
                          refresh(() {});
                        },
                        decoration: const InputDecoration(labelText: 'Employee'),
                      ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'morning', label: Text('Morning')),
                        ButtonSegment(value: 'evening', label: Text('Evening')),
                      ],
                      selected: {phase},
                      onSelectionChanged: (value) {
                        setState(() {
                          phase = value.first;
                          _loadExisting();
                        });
                        refresh(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    ...equipmentItems.map((eq) {
                      final id = (eq['id'] ?? '').toString();
                      final row = items[id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Palette.border),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((row['equipmentName'] ?? 'Equipment').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: ['ok', 'issue', 'missing'].map((status) => ChoiceChip(
                                  label: Text(status.toUpperCase()),
                                  selected: row['status'] == status,
                                  onSelected: (_) {
                                    setState(() => row['status'] = status);
                                    refresh(() {});
                                  },
                                )).toList(),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: (row['note'] ?? '').toString(),
                                maxLines: 2,
                                decoration: const InputDecoration(labelText: 'Notes (issue / missing details)'),
                                onChanged: (value) => row['note'] = value,
                              )
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: selectedEmpId == null || selectedEmpId!.isEmpty ? null : _saveChecklist,
                      icon: const Icon(Icons.save_rounded),
                      label: Text('Save ${phase[0].toUpperCase()}${phase.substring(1)} check'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent today submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (recent.isEmpty)
                      const Text('No equipment check logs captured for today yet.', style: TextStyle(color: Palette.muted))
                    else
                      ...recent.map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text('${log['employeeName'] ?? 'Employee'} • ${(log['morning'] != null) ? 'Morning' : ''}${(log['morning'] != null && log['evening'] != null) ? ' & ' : ''}${(log['evening'] != null) ? 'Evening' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
    final contact = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'New employee',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact')),
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
      'contact': contact.text.trim(),
      'role': 'Ground Worker',
      'dailyRate': double.tryParse(rate.text.trim()) ?? 0,
      'startDate': _today(),
      'annualLeaveDays': 15,
      'sickLeaveDays': 30,
      'log': <dynamic>[],
    });
    await BackendService.saveState(state.copyWith(emps: items), updatedBy: session.username);
  }

  Future<void> _addLogEntry(BuildContext context, Map<String, dynamic> emp) async {
    String type = 'work';
    final date = TextEditingController(text: _today());
    final hours = TextEditingController(text: '8');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _EditDialog(
          title: 'Add log entry',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'work', child: Text('Work day')),
                  DropdownMenuItem(value: 'annual', child: Text('Annual leave')),
                  DropdownMenuItem(value: 'sick', child: Text('Sick leave')),
                  DropdownMenuItem(value: 'family', child: Text('Family responsibility')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent (unpaid)')),
                  DropdownMenuItem(value: 'public', child: Text('Public holiday')),
                ],
                onChanged: (v) => setModalState(() => type = v ?? 'work'),
                decoration: const InputDecoration(labelText: 'Entry type'),
              ),
              const SizedBox(height: 10),
              TextField(controller: date, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
              const SizedBox(height: 10),
              TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hours worked')),
              const SizedBox(height: 10),
              TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final list = state.emps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final idx = list.indexWhere((e) => (e['id'] ?? '') == (emp['id'] ?? ''));
    if (idx == -1) return;
    final updatedEmp = Map<String, dynamic>.from(list[idx]);
    final log = List<dynamic>.from(updatedEmp['log'] ?? const []);
    log.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'date': date.text.trim().isEmpty ? _today() : date.text.trim(),
      'hours': double.tryParse(hours.text.trim()) ?? 8,
      'note': note.text.trim(),
    });
    updatedEmp['log'] = log;
    list[idx] = updatedEmp;
    await BackendService.saveState(state.copyWith(emps: list), updatedBy: session.username);
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(emp['name']))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((emp['name'] ?? 'Employee').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text('${emp['role'] ?? 'Worker'} • ${_money(_num(emp['dailyRate']))}/day', style: const TextStyle(color: Palette.muted)),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(onPressed: () => _addLogEntry(context, emp), icon: const Icon(Icons.post_add_rounded), label: const Text('Log')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(text: 'Annual ${(emp['annualLeaveDays'] ?? 15)}d'),
                        _Chip(text: 'Sick ${(emp['sickLeaveDays'] ?? 30)}d'),
                        if ((emp['contact'] ?? '').toString().isNotEmpty) _Chip(text: (emp['contact'] ?? '').toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Recent log entries', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...List<Map<String, dynamic>>.from((emp['log'] ?? const []).map((e) => Map<String, dynamic>.from(e))).take(5).map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text('${entry['date'] ?? '-'} • ${_entryTypeLabel((entry['type'] ?? '').toString())}', style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text('${_num(entry['hours']).toStringAsFixed(1)}h', style: const TextStyle(color: Palette.muted)),
                            ],
                          ),
                        )),
                    if (List<dynamic>.from(emp['log'] ?? const []).isEmpty)
                      const Text('No work or leave entries yet.', style: TextStyle(color: Palette.muted)),
                  ],
                ),
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
          icon: Icons.punch_clock_rounded,
          title: 'Clock entries',
          subtitle: 'Review active and completed clock records',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Clock entries')), body: ClockEntriesPage(state: state, session: session)))),
        ),
        _ActionTile(
          icon: Icons.handyman_rounded,
          title: 'Equipment',
          subtitle: 'Inspect and submit morning/evening equipment checks',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Equipment')), body: EquipmentPage(state: state, session: session)))),
        ),
        _ActionTile(
          icon: Icons.task_alt_rounded,
          title: 'Jobs log',
          subtitle: 'View completed and pending jobs, notes, and photo placeholders',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Jobs log')), body: JobsLogPage(state: state, session: session)))),
        ),
        _ActionTile(
          icon: Icons.manage_accounts_rounded,
          title: 'Users & access',
          subtitle: 'See staff accounts synced from Firebase',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Users & access')), body: UsersPage(state: state, session: session)))),
        ),
        _ActionTile(
          icon: Icons.calculate_rounded,
          title: 'Quote calculator',
          subtitle: 'Build recurring or once-off quotes and save to live state',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Quote calculator')), body: QuotesPage(state: state, session: session)))),
        ),
      ],
    );
  }
}

class JobsLogPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const JobsLogPage({super.key, required this.state, required this.session});

  Future<void> _editJob(BuildContext context, Map<String, dynamic> job) async {
    final beforeCtrl = TextEditingController(text: (job['beforePhotoUrl'] ?? '').toString());
    final afterCtrl = TextEditingController(text: (job['afterPhotoUrl'] ?? '').toString());
    final notesCtrl = TextEditingController(text: (job['notes'] ?? '').toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _EditDialog(
        title: 'Job notes & photo links',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: beforeCtrl, decoration: const InputDecoration(labelText: 'Before photo URL / reference')),
            const SizedBox(height: 10),
            TextField(controller: afterCtrl, decoration: const InputDecoration(labelText: 'After photo URL / reference')),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Job notes')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final idx = jobs.indexWhere((e) => (e['id'] ?? '') == (job['id'] ?? ''));
    if (idx == -1) return;
    jobs[idx]['beforePhotoUrl'] = beforeCtrl.text.trim();
    jobs[idx]['afterPhotoUrl'] = afterCtrl.text.trim();
    jobs[idx]['notes'] = notesCtrl.text.trim();
    await BackendService.saveState(state.copyWith(jobs: jobs), updatedBy: session.username);
  }

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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(job['done'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: job['done'] == true ? Palette.green : Palette.muted),
                        const SizedBox(width: 10),
                        Expanded(child: Text((job['name'] ?? 'Job').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text((job['date'] ?? '-').toString(), style: const TextStyle(color: Palette.muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${job['address'] ?? ''}
${job['workerName'] ?? 'Unassigned'}', style: const TextStyle(color: Palette.muted)),
                    if ((job['notes'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text((job['notes'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        if ((job['beforePhotoUrl'] ?? '').toString().isNotEmpty) _Chip(text: 'Before linked'),
                        if ((job['afterPhotoUrl'] ?? '').toString().isNotEmpty) _Chip(text: 'After linked'),
                        OutlinedButton.icon(onPressed: () => _editJob(context, job), icon: const Icon(Icons.edit_note_rounded), label: const Text('Notes / photos')),
                      ],
                    )
                  ],
                ),
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
                leading: CircleAvatar(backgroundColor: const Color(0xFFE8F3EA), child: Text(_initials(user['displayName'] ?? user['name']))),
                title: Text((user['displayName'] ?? user['name'] ?? 'User').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${user['username'] ?? ''} · ${user['role'] ?? 'worker'}${(user['empId'] ?? '').toString().isNotEmpty ? ' · Linked emp ${user['empId']}' : ''}'),
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
    final emp = _findEmployeeForSession(state.emps, session);
    final activeClock = emp == null ? null : _activeClockEntryForEmp(state.clockEntries, (emp['id'] ?? '').toString());
    final jobs = state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((job) {
      final worker = (job['workerName'] ?? '').toString().toLowerCase();
      return worker == session.displayName.toLowerCase() || worker == session.username.toLowerCase() || (emp != null && worker == (emp['name'] ?? '').toString().toLowerCase()) || worker.isEmpty;
    }).where((job) => (job['date'] ?? '') == state.schedDate).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'My route', subtitle: state.schedDate),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shift status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(activeClock == null ? 'You are currently clocked out.' : 'Clocked in at ${_fmtTime((activeClock['clockIn'] ?? '').toString())}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Use the Clock tab to clock in or out. Equipment checks are under Checks.', style: TextStyle(color: Palette.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: job['done'] == true,
                title: Text((job['name'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${job['address'] ?? ''}${(job['notes'] ?? '').toString().isNotEmpty ? '
${job['notes']}' : ''}'),
                onChanged: (value) async {
                  final updated = state.jobs.whereType<Map>().map((e) {
                    final item = Map<String, dynamic>.from(e);
                    if (item['id'] == job['id']) item['done'] = value ?? false;
                    return item;
                  }).toList();
                  await BackendService.saveState(state.copyWith(jobs: updated), updatedBy: session.username);
                },
              ),
            ),
          ),
        if (jobs.isEmpty)
          const _EmptyState(icon: Icons.route_rounded, title: 'No route assigned', subtitle: 'No jobs are assigned to you for this date yet.')
      ],
    );
  }
}

class ClockPage extends StatefulWidget {
  final WorkspaceState state;
  final AppSession session;
  const ClockPage({super.key, required this.state, required this.session});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  late String? selectedEmpId;

  @override
  void initState() {
    super.initState();
    final emp = _findEmployeeForSession(widget.state.emps, widget.session);
    selectedEmpId = (emp?['id'] ?? '').toString().isEmpty ? null : (emp?['id']).toString();
  }

  Future<void> _clockIn(String empId) async {
    final entries = widget.state.clockEntries.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (entries.any((e) => (e['empId'] ?? '') == empId && (e['clockOut'] == null || (e['clockOut'] ?? '').toString().isEmpty))) return;
    entries.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'empId': empId,
      'clockIn': DateTime.now().toIso8601String(),
      'clockInDate': _today(),
      'clockOut': null,
      'hoursWorked': null,
    });
    await BackendService.saveState(widget.state.copyWith(clockEntries: entries), updatedBy: widget.session.username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clocked in.')));
  }

  Future<void> _clockOut(String empId) async {
    final now = DateTime.now();
    final entries = widget.state.clockEntries.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final idx = entries.indexWhere((e) => (e['empId'] ?? '') == empId && ((e['clockOut'] ?? '').toString().isEmpty));
    if (idx == -1) return;
    final start = DateTime.tryParse((entries[idx]['clockIn'] ?? '').toString()) ?? now;
    final hrs = double.parse((now.difference(start).inMinutes / 60).toStringAsFixed(2));
    entries[idx]['clockOut'] = now.toIso8601String();
    entries[idx]['hoursWorked'] = hrs;

    final emps = widget.state.emps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final empIdx = emps.indexWhere((e) => (e['id'] ?? '') == empId);
    if (empIdx != -1) {
      final emp = Map<String, dynamic>.from(emps[empIdx]);
      final log = List<dynamic>.from(emp['log'] ?? const []);
      final existing = log.indexWhere((e) => (e['type'] ?? '') == 'work' && (e['date'] ?? '') == _today() && (e['source'] ?? '') == 'clock');
      final row = {
        'id': existing == -1 ? DateTime.now().millisecondsSinceEpoch.toString() : log[existing]['id'],
        'type': 'work',
        'date': _today(),
        'hours': hrs,
        'note': 'Auto-logged via clock in/out',
        'source': 'clock',
      };
      if (existing == -1) {
        log.insert(0, row);
      } else {
        log[existing] = row;
      }
      emp['log'] = log;
      emps[empIdx] = emp;
    }

    await BackendService.saveState(widget.state.copyWith(clockEntries: entries, emps: emps), updatedBy: widget.session.username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clocked out.')));
  }

  @override
  Widget build(BuildContext context) {
    final emps = widget.state.emps.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final emp = _findEmployeeById(widget.state.emps, selectedEmpId ?? '');
    final active = selectedEmpId == null ? null : _activeClockEntryForEmp(widget.state.clockEntries, selectedEmpId!);
    final earnings = selectedEmpId == null ? const {'today': 0.0, 'week': 0.0, 'month': 0.0, 'hoursToday': 0.0, 'hoursWeek': 0.0} : _workerEarnings(widget.state.emps, selectedEmpId!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Clock in / out', subtitle: 'Live shift and work log sync'),
        if (widget.session.role != 'worker')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: selectedEmpId,
                items: emps.map((emp) => DropdownMenuItem<String>(value: (emp['id'] ?? '').toString(), child: Text((emp['name'] ?? 'Employee').toString()))).toList(),
                onChanged: (value) => setState(() => selectedEmpId = value),
                decoration: const InputDecoration(labelText: 'Employee'),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((emp?['name'] ?? widget.session.displayName).toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(active == null ? 'Currently clocked out' : 'Clocked in at ${_fmtTime((active['clockIn'] ?? '').toString())}', style: const TextStyle(color: Palette.muted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: FilledButton(onPressed: selectedEmpId == null || active != null ? null : () => _clockIn(selectedEmpId!), child: const Text('Clock in'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: selectedEmpId == null || active == null ? null : () => _clockOut(selectedEmpId!), child: const Text('Clock out'))),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(text: 'Today ${_money(_num(earnings['today']))}'),
                    _Chip(text: 'Week ${_money(_num(earnings['week']))}'),
                    _Chip(text: 'Month ${_money(_num(earnings['month']))}'),
                    _Chip(text: 'Hours today ${_num(earnings['hoursToday']).toStringAsFixed(1)}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class QuotesPage extends StatefulWidget {
  final WorkspaceState state;
  final AppSession session;
  const QuotesPage({super.key, required this.state, required this.session});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  final nameCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final sqmCtrl = TextEditingController();
  String serviceType = 'recurring';
  String pkg = 'PrimeCare';
  String freq = 'biweekly';
  String tier = 'launch';
  bool og = false;
  bool ac = false;
  bool asClient = false;
  final Set<String> adds = {};
  final Set<String> customTasks = {};

  int get total => _calculateQuoteTotal(
        sqm: int.tryParse(sqmCtrl.text.trim()) ?? 0,
        serviceType: serviceType,
        pkg: pkg,
        freq: freq,
        tier: tier,
        og: og,
        ac: ac,
        adds: adds.toList(),
        customTasks: customTasks.toList(),
      );

  Future<void> _saveQuote() async {
    final quotes = widget.state.quotes.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final quote = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': nameCtrl.text.trim(),
      'notes': notesCtrl.text.trim(),
      'sqm': int.tryParse(sqmCtrl.text.trim()) ?? 0,
      'serviceType': serviceType,
      'pkg': pkg,
      'freq': freq,
      'tier': tier,
      'og': og,
      'ac': ac,
      'adds': adds.toList(),
      'customTasks': customTasks.toList(),
      'amount': total,
      'createdAt': _today(),
    };
    quotes.insert(0, quote);
    var clients = widget.state.clients.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (asClient && nameCtrl.text.trim().isNotEmpty) {
      clients.insert(0, {
        'id': 'CL-${DateTime.now().millisecondsSinceEpoch}',
        'name': nameCtrl.text.trim(),
        'address': '',
        'rate': total.toDouble(),
        'active': true,
        'createdAt': _today(),
      });
    }
    await BackendService.saveState(widget.state.copyWith(quotes: quotes, clients: clients), updatedBy: widget.session.username);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote saved to live workspace.')));
  }

  @override
  Widget build(BuildContext context) {
    final quotes = widget.state.quotes.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Quote calculator', subtitle: '${quotes.length} saved quotes'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Client / lead name')),
                const SizedBox(height: 10),
                TextField(controller: sqmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Property size (m²)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: serviceType, items: const [DropdownMenuItem(value: 'recurring', child: Text('Recurring')), DropdownMenuItem(value: 'onceoff', child: Text('Once-off'))], onChanged: (v) => setState(() => serviceType = v ?? 'recurring'), decoration: const InputDecoration(labelText: 'Service type')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: pkg, items: const [DropdownMenuItem(value: 'PrimeCare', child: Text('PrimeCare')), DropdownMenuItem(value: 'Premium', child: Text('Premium')), DropdownMenuItem(value: 'CustomTasks', child: Text('Custom tasks'))], onChanged: (v) => setState(() => pkg = v ?? 'PrimeCare'), decoration: const InputDecoration(labelText: 'Package')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: freq, items: const [DropdownMenuItem(value: 'weekly', child: Text('Weekly')), DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')), DropdownMenuItem(value: 'monthly', child: Text('Monthly'))], onChanged: (v) => setState(() => freq = v ?? 'biweekly'), decoration: const InputDecoration(labelText: 'Frequency')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: tier, items: const [DropdownMenuItem(value: 'launch', child: Text('Launch')), DropdownMenuItem(value: 'standard', child: Text('Standard')), DropdownMenuItem(value: 'premium', child: Text('Premium'))], onChanged: (v) => setState(() => tier = v ?? 'launch'), decoration: const InputDecoration(labelText: 'Tier')),
                const SizedBox(height: 10),
                SwitchListTile(value: og, onChanged: (v) => setState(() => og = v), title: const Text('Overgrown premium')),
                SwitchListTile(value: ac, onChanged: (v) => setState(() => ac = v), title: const Text('Access complexity premium')),
                SwitchListTile(value: asClient, onChanged: (v) => setState(() => asClient = v), title: const Text('Also create as client')),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text('Add-ons', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quoteAddons.map((addon) => FilterChip(label: Text('${addon['name']} (+${_money(_num(addon['price']))})'), selected: adds.contains(addon['id']), onSelected: (v) => setState(() => v ? adds.add(addon['id'] as String) : adds.remove(addon['id'])))).toList(),
                ),
                const SizedBox(height: 10),
                if (pkg == 'CustomTasks') ...[
                  Align(alignment: Alignment.centerLeft, child: Text('Custom tasks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _taskOptions.map((task) => FilterChip(label: Text(task['name'] as String), selected: customTasks.contains(task['id']), onSelected: (v) => setState(() => v ? customTasks.add(task['id'] as String) : customTasks.remove(task['id'])))).toList(),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE8F3EA), borderRadius: BorderRadius.circular(18)),
                  child: Text('Estimated total: ${_money(total.toDouble())}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _saveQuote, icon: const Icon(Icons.save_rounded), label: const Text('Save quote')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...quotes.take(10).map((quote) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text((quote['name'] ?? 'Quote').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${quote['serviceType'] ?? 'recurring'} • ${quote['pkg'] ?? ''} • ${quote['createdAt'] ?? '-'}'),
                  trailing: Text(_money(_num(quote['amount'])), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            )),
      ],
    );
  }
}

class ClockEntriesPage extends StatelessWidget {
  final WorkspaceState state;
  final AppSession session;
  const ClockEntriesPage({super.key, required this.state, required this.session});

  @override
  Widget build(BuildContext context) {
    final entries = state.clockEntries.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Clock entries', subtitle: '${entries.length} total records'),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text((_findEmployeeById(state.emps, (entry['empId'] ?? '').toString())?['name'] ?? entry['empId'] ?? 'Employee').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('In: ${_fmtDateTime((entry['clockIn'] ?? '').toString())}
Out: ${_fmtDateTime((entry['clockOut'] ?? '').toString())}'),
                trailing: Text((entry['hoursWorked'] == null) ? 'Active' : '${_num(entry['hoursWorked']).toStringAsFixed(2)}h', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          )
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

String _hash(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

String _legacyHash(String input) {
  return _hash(input);
}

dynamic _jsonSafe(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), _jsonSafe(val)));
  }
  if (value is Iterable) {
    return value.map(_jsonSafe).toList();
  }
  return value;
}

Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> data) {
  return Map<String, dynamic>.from(_jsonSafe(data) as Map);
}


const List<Map<String, Object>> _quoteAddons = [
  {'id': 'waste', 'name': 'Waste removal', 'price': 120},
  {'id': 'fertilise', 'name': 'Fertilising', 'price': 180},
  {'id': 'weed', 'name': 'Weed treatment', 'price': 140},
  {'id': 'trim', 'name': 'Extra hedge trimming', 'price': 220},
];

const List<Map<String, Object>> _taskOptions = [
  {'id': 'mowing', 'name': 'Grass cutting / mowing', 'weight': 0.65},
  {'id': 'edging', 'name': 'Edging', 'weight': 0.18},
  {'id': 'blowing', 'name': 'Blowing', 'weight': 0.15},
  {'id': 'weeding', 'name': 'Weeding', 'weight': 0.22},
  {'id': 'light_hedge', 'name': 'Light hedge trimming', 'weight': 0.28},
  {'id': 'deep_hedge', 'name': 'Deep hedge trimming', 'weight': 0.35},
  {'id': 'cleanup', 'name': 'General clean-up', 'weight': 0.12},
  {'id': 'waste', 'name': 'Waste removal', 'weight': 0.20},
];

List<Map<String, dynamic>> _jobsThisWeek(List<dynamic> jobs) {
  final now = DateTime.now();
  final start = now.subtract(Duration(days: now.weekday % 7));
  final end = start.add(const Duration(days: 6));
  final startKey = DateFormat('yyyy-MM-dd').format(start);
  final endKey = DateFormat('yyyy-MM-dd').format(end);
  return jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((job) {
    final date = (job['date'] ?? '').toString();
    return date.compareTo(startKey) >= 0 && date.compareTo(endKey) <= 0;
  }).toList();
}

List<Map<String, dynamic>> _todayCheckIssues(List<dynamic> checkLogs) {
  final todayLogs = checkLogs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => (e['date'] ?? '') == _today());
  final issues = <Map<String, dynamic>>[];
  for (final log in todayLogs) {
    for (final bucket in ['morning', 'evening']) {
      final phase = log[bucket];
      if (phase is Map) {
        final items = List<Map<String, dynamic>>.from(((phase['items'] ?? const []).map((e) => Map<String, dynamic>.from(e))));
        issues.addAll(items.where((e) => (e['status'] ?? '') == 'issue' || (e['status'] ?? '') == 'missing'));
      }
    }
  }
  return issues;
}

List<Map<String, dynamic>> _activeClockEntries(List<dynamic> clockEntries) {
  return clockEntries.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => (e['clockOut'] ?? '').toString().isEmpty).toList();
}

Map<String, dynamic>? _activeClockEntryForEmp(List<dynamic> clockEntries, String empId) {
  for (final entry in clockEntries.whereType<Map>()) {
    final row = Map<String, dynamic>.from(entry);
    if ((row['empId'] ?? '') == empId && (row['clockOut'] ?? '').toString().isEmpty) {
      return row;
    }
  }
  return null;
}

Map<String, dynamic>? _findEmployeeById(List<dynamic> emps, String id) {
  for (final entry in emps.whereType<Map>()) {
    final row = Map<String, dynamic>.from(entry);
    if ((row['id'] ?? '').toString() == id) return row;
  }
  return null;
}

Map<String, dynamic>? _findEmployeeForSession(List<dynamic> emps, AppSession session) {
  for (final entry in emps.whereType<Map>()) {
    final row = Map<String, dynamic>.from(entry);
    final name = (row['name'] ?? '').toString().trim().toLowerCase();
    if (name == session.displayName.trim().toLowerCase() || name == session.username.trim().toLowerCase()) {
      return row;
    }
  }
  return null;
}

Map<String, dynamic> _workerEarnings(List<dynamic> emps, String empId) {
  final emp = _findEmployeeById(emps, empId);
  if (emp == null) return {'today': 0.0, 'week': 0.0, 'month': 0.0, 'hoursToday': 0.0, 'hoursWeek': 0.0};
  final rate = _num(emp['dailyRate']);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday % 7));
  final monthStart = DateTime(now.year, now.month, 1);
  final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
  final monthKey = DateFormat('yyyy-MM-dd').format(monthStart);
  final log = List<Map<String, dynamic>>.from(((emp['log'] ?? const []).map((e) => Map<String, dynamic>.from(e))));
  final workLog = log.where((l) => (l['type'] ?? '') == 'work').toList();
  final todayLogs = workLog.where((l) => (l['date'] ?? '') == _today()).toList();
  final weekLogs = workLog.where((l) => (l['date'] ?? '').toString().compareTo(weekKey) >= 0).toList();
  final monthLogs = workLog.where((l) => (l['date'] ?? '').toString().compareTo(monthKey) >= 0).toList();
  final hoursToday = todayLogs.fold<double>(0, (s, l) => s + _num(l['hours']).clamp(0, 24));
  final hoursWeek = weekLogs.fold<double>(0, (s, l) => s + _num(l['hours']).clamp(0, 24));
  final daysWeek = weekLogs.map((l) => (l['date'] ?? '').toString()).toSet().length;
  final daysMonth = monthLogs.map((l) => (l['date'] ?? '').toString()).toSet().length;
  return {
    'today': (hoursToday / 8) * rate,
    'week': daysWeek * rate,
    'month': daysMonth * rate,
    'hoursToday': hoursToday,
    'hoursWeek': hoursWeek,
  };
}

String _fmtTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '-';
  return DateFormat('HH:mm').format(dt.toLocal());
}

String _fmtDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '-';
  return DateFormat('dd MMM HH:mm').format(dt.toLocal());
}

String _entryTypeLabel(String type) {
  switch (type) {
    case 'annual': return 'Annual leave';
    case 'sick': return 'Sick leave';
    case 'family': return 'Family responsibility';
    case 'absent': return 'Absent';
    case 'public': return 'Public holiday';
    default: return 'Work day';
  }
}

int _calculateQuoteTotal({
  required int sqm,
  required String serviceType,
  required String pkg,
  required String freq,
  required String tier,
  required bool og,
  required bool ac,
  required List<String> adds,
  required List<String> customTasks,
}) {
  final band = sqm <= 300 ? 1.0 : sqm <= 800 ? 1.35 : 1.8;
  final pkgBase = {
    'PrimeCare': 950.0,
    'Premium': 1450.0,
    'CustomTasks': 780.0,
  }[pkg] ?? 950.0;
  final freqFactor = {'weekly': 1.9, 'biweekly': 1.0, 'monthly': 0.62}[freq] ?? 1.0;
  final tierFactor = {'launch': 1.0, 'standard': 1.12, 'premium': 1.28}[tier] ?? 1.0;
  double total = pkgBase * band * freqFactor * tierFactor;
  if (serviceType == 'onceoff') total = total * 1.15;
  if (pkg == 'CustomTasks' && customTasks.isNotEmpty) {
    final weight = customTasks.fold<double>(0.0, (sum, id) => sum + (_taskOptions.firstWhere((e) => e['id'] == id, orElse: () => {'weight': 0.1})['weight'] as num).toDouble());
    total = (pkgBase * band) * (weight < 0.22 ? 0.22 : weight);
  }
  if (og) total *= 1.25;
  if (ac) total *= 1.15;
  total += adds.fold<double>(0.0, (sum, id) => sum + _num(_quoteAddons.firstWhere((e) => e['id'] == id, orElse: () => {'price': 0})['price']));
  return total.round();
}

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(double value) => 'R${value.toStringAsFixed(2)}';
String _initials(dynamic name) {
  final parts = (name ?? '').toString().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'P';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}
