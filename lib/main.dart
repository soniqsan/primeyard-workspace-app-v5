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
    if (_auth.currentUser != null) return;
    await _auth.signInAnonymously();
    if (_auth.currentUser != null) return;
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
      final hasRemoteData = state.users.isNotEmpty || state.clients.isNotEmpty || state.jobs.isNotEmpty || state.invoices.isNotEmpty || state.emps.isNotEmpty;
      return BackendBootstrap(
        state: state,
        hasRemoteData: hasRemoteData,
        error: hasRemoteData ? null : 'Connected, but the live sharedState is empty.',
      );
    } on fb.FirebaseAuthException catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(state: cached, hasRemoteData: false, error: '[firebase_auth/${e.code}] ${e.message ?? 'Authentication failed.'}');
    } on FirebaseException catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(state: cached, hasRemoteData: false, error: '[firebase/${e.code}] ${e.message ?? 'Firestore failed.'}');
    } catch (e) {
      final cached = await _loadCachedState();
      return BackendBootstrap(state: cached, hasRemoteData: false, error: e.toString());
    }
  }

  static Stream<WorkspaceState> streamState() async* {
    try {
      await ensureAnonymousSession();
      yield* _doc.snapshots().asyncMap((snapshot) async {
        if (!snapshot.exists) return await _loadCachedState();
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
    final hashes = <String>{_hash(trimmedPassword), _legacyHash(trimmedPassword), trimmedPassword};

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
          if (usernameMatches(u) && passwordMatches(u)) return u;
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

  static Future<void> saveState(WorkspaceState state, {String updatedBy = 'flutter_full_package'}) async {
    await ensureAnonymousSession();
    final data = {...state.toMap(), 'updatedAt': FieldValue.serverTimestamp(), 'updatedBy': updatedBy};
    await _doc.set(data, SetOptions(merge: true));
    await _cacheStateMap(state.toMap());
    await _cacheUsers(state.users);
  }

  static List<Map<String, dynamic>> mapList(List<dynamic> raw) => raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  static Map<String, dynamic>? currentUserRecord(AppSession session, WorkspaceState state) {
    for (final raw in mapList(state.users)) {
      final username = (raw['username'] ?? raw['userName'] ?? '').toString().trim().toLowerCase();
      if (username == session.username.trim().toLowerCase()) return raw;
    }
    return null;
  }

  static Map<String, dynamic>? employeeById(String? empId, WorkspaceState state) {
    if (empId == null || empId.isEmpty) return null;
    for (final emp in mapList(state.emps)) {
      if ((emp['id'] ?? '').toString() == empId) return emp;
    }
    return null;
  }

  static Map<String, dynamic>? employeeForSession(AppSession session, WorkspaceState state) {
    final user = currentUserRecord(session, state);
    final linkedId = (user?['linkedEmpId'] ?? user?['empId'] ?? '').toString();
    if (linkedId.isNotEmpty) {
      final linked = employeeById(linkedId, state);
      if (linked != null) return linked;
    }
    for (final emp in mapList(state.emps)) {
      final name = (emp['name'] ?? '').toString().trim().toLowerCase();
      if (name.isEmpty) continue;
      if (name == session.displayName.trim().toLowerCase() || name == session.username.trim().toLowerCase()) {
        return emp;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> clockEntriesForEmp(String empId, WorkspaceState state) {
    final items = mapList(state.clockEntries).where((e) => (e['empId'] ?? '').toString() == empId).toList();
    items.sort((a, b) => (b['clockIn'] ?? '').toString().compareTo((a['clockIn'] ?? '').toString()));
    return items;
  }

  static Map<String, dynamic>? activeClockForEmp(String empId, WorkspaceState state) {
    for (final entry in clockEntriesForEmp(empId, state)) {
      if ((entry['clockOut'] ?? '').toString().isEmpty) return entry;
    }
    return null;
  }

  static List<Map<String, dynamic>> activeClockEntries(WorkspaceState state) => mapList(state.clockEntries).where((e) => (e['clockOut'] ?? '').toString().isEmpty).toList();

  static Duration? activeShiftDuration(String empId, WorkspaceState state) {
    final active = activeClockForEmp(empId, state);
    if (active == null) return null;
    final clockIn = DateTime.tryParse((active['clockIn'] ?? '').toString());
    if (clockIn == null) return null;
    return DateTime.now().difference(clockIn);
  }

  static Future<void> clockIn(AppSession session, WorkspaceState state) async {
    final emp = employeeForSession(session, state);
    if (emp == null) throw Exception('No employee record linked to this user.');
    final empId = (emp['id'] ?? '').toString();
    if (activeClockForEmp(empId, state) != null) return;
    final entry = {
      'id': _newId(),
      'empId': empId,
      'employeeName': (emp['name'] ?? session.displayName).toString(),
      'clockIn': DateTime.now().toIso8601String(),
      'clockInDate': _today(),
      'clockOut': '',
      'hoursWorked': null,
    };
    final next = List<dynamic>.from(state.clockEntries)..insert(0, entry);
    await saveState(state.copyWith(clockEntries: next), updatedBy: session.username);
  }

  static Future<void> clockOut(AppSession session, WorkspaceState state) async {
    final emp = employeeForSession(session, state);
    if (emp == null) throw Exception('No employee record linked to this user.');
    final empId = (emp['id'] ?? '').toString();
    final active = activeClockForEmp(empId, state);
    if (active == null) return;
    final now = DateTime.now();
    final inTime = DateTime.tryParse((active['clockIn'] ?? '').toString()) ?? now;
    final rounded = double.parse(((now.difference(inTime).inMinutes) / 60.0).toStringAsFixed(2));
    final updatedEntries = mapList(state.clockEntries).map((row) {
      if ((row['id'] ?? '').toString() == (active['id'] ?? '').toString()) {
        return {...row, 'clockOut': now.toIso8601String(), 'hoursWorked': rounded};
      }
      return row;
    }).toList();
    final updatedEmployees = mapList(state.emps).map((row) {
      if ((row['id'] ?? '').toString() != empId) return row;
      final log = mapList(List<dynamic>.from(row['log'] ?? const []));
      final idx = log.indexWhere((e) => (e['date'] ?? '').toString() == _today() && (e['type'] ?? '').toString() == 'work');
      final entry = {'id': _newId(), 'date': _today(), 'type': 'work', 'hours': rounded, 'note': 'Clocked via mobile app'};
      if (idx >= 0) {
        log[idx] = {...log[idx], ...entry};
      } else {
        log.insert(0, entry);
      }
      return {...row, 'log': log};
    }).toList();
    await saveState(state.copyWith(clockEntries: updatedEntries, emps: updatedEmployees), updatedBy: session.username);
  }

  static Map<String, dynamic>? checkLogFor({required String empId, required String date, required WorkspaceState state}) {
    for (final log in mapList(state.checkLogs)) {
      if ((log['empId'] ?? '').toString() == empId && (log['date'] ?? '').toString() == date) return log;
    }
    return null;
  }

  static bool shiftSubmitted({required String empId, required String date, required String shift, required WorkspaceState state}) {
    final log = checkLogFor(empId: empId, date: date, state: state);
    final part = (log?[shift] is Map) ? Map<String, dynamic>.from(log![shift]) : null;
    return part != null && (part['submitted'] == true);
  }

  static Future<void> submitEquipmentCheck({
    required AppSession session,
    required WorkspaceState state,
    required String empId,
    required String shift,
    required List<Map<String, dynamic>> items,
    required String generalNote,
  }) async {
    final current = checkLogFor(empId: empId, date: state.schedDate, state: state);
    final employeeName = (employeeById(empId, state)?['name'] ?? '').toString();
    final payload = {
      'submitted': true,
      'submittedAt': DateTime.now().toIso8601String(),
      'submittedBy': session.username,
      'items': items,
      'note': generalNote.trim(),
    };
    final nextLogs = mapList(state.checkLogs);
    if (current == null) {
      nextLogs.insert(0, {'id': _newId(), 'empId': empId, 'employeeName': employeeName, 'date': state.schedDate, shift: payload});
    } else {
      for (var i = 0; i < nextLogs.length; i++) {
        if ((nextLogs[i]['id'] ?? '').toString() == (current['id'] ?? '').toString()) {
          nextLogs[i] = {...nextLogs[i], 'employeeName': employeeName, shift: payload};
          break;
        }
      }
    }
    await saveState(state.copyWith(checkLogs: nextLogs), updatedBy: session.username);
  }

  static Future<void> saveQuote({required AppSession session, required WorkspaceState state, required Map<String, dynamic> quote}) async {
    final next = List<dynamic>.from(state.quotes)..insert(0, quote);
    await saveState(state.copyWith(quotes: next), updatedBy: session.username);
  }

  static Future<void> saveEmployeeLog({required AppSession session, required WorkspaceState state, required String empId, required Map<String, dynamic> logEntry}) async {
    final updatedEmployees = mapList(state.emps).map((row) {
      if ((row['id'] ?? '').toString() != empId) return row;
      final log = mapList(List<dynamic>.from(row['log'] ?? const []));
      log.insert(0, logEntry);
      return {...row, 'log': log};
    }).toList();
    await saveState(state.copyWith(emps: updatedEmployees), updatedBy: session.username);
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
    final activeClockedIn = BackendService.activeClockEntries(state);
    final employees = BackendService.mapList(state.emps);
    final todayChecks = BackendService.mapList(state.checkLogs).where((e) => (e['date'] ?? '') == state.schedDate).toList();
    final completedChecks = todayChecks.fold<int>(0, (sum, row) {
      final morningDone = row['morning'] is Map && row['morning']['submitted'] == true;
      final eveningDone = row['evening'] is Map && row['evening']['submitted'] == true;
      return sum + (morningDone ? 1 : 0) + (eveningDone ? 1 : 0);
    });
    final expectedChecks = employees.isEmpty ? 0 : employees.length * 2;
    final recentQuotes = BackendService.mapList(state.quotes).take(3).toList();

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
            _StatCard(title: 'Clocked in now', value: '${activeClockedIn.length}', subtitle: 'Live staff on shift', icon: Icons.timer_rounded, accent: Palette.gold),
            _StatCard(title: 'Checks today', value: '$completedChecks/${expectedChecks == 0 ? 0 : expectedChecks}', subtitle: 'Morning + evening submitted', icon: Icons.handyman_rounded, accent: const Color(0xFF00897B)),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Currently clocked in',
          child: activeClockedIn.isEmpty
              ? const Text('Nobody is currently clocked in.', style: TextStyle(color: Palette.muted))
              : Column(
                  children: activeClockedIn.map((entry) {
                    final empName = (entry['employeeName'] ?? BackendService.employeeById((entry['empId'] ?? '').toString(), state)?['name'] ?? 'Worker').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Palette.green),
                          const SizedBox(width: 10),
                          Expanded(child: Text(empName, style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text('Since ${_fmtTime(entry['clockIn'])}', style: const TextStyle(color: Palette.muted)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Recent quotes',
          child: recentQuotes.isEmpty
              ? const Text('No quotes saved yet.', style: TextStyle(color: Palette.muted))
              : Column(
                  children: recentQuotes.map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text((q['clientName'] ?? q['name'] ?? 'Quote').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(_money(_num(q['monthlyPrice'] ?? q['price'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )).toList(),
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
  final String? initialEmpId;
  final String? initialShift;
  final bool forceWorkerMode;
  const EquipmentPage({
    super.key,
    required this.state,
    required this.session,
    this.initialEmpId,
    this.initialShift,
    this.forceWorkerMode = false,
  });

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  late String _shift = widget.initialShift ?? 'morning';
  String? _selectedEmpId;
  final Map<String, String> _status = {};
  final Map<String, String> _notes = {};
  final TextEditingController _generalNote = TextEditingController();

  bool get _workerMode => widget.forceWorkerMode || widget.session.role == 'worker';

  @override
  void initState() {
    super.initState();
    _selectedEmpId = widget.initialEmpId ?? BackendService.employeeForSession(widget.session, widget.state)?['id']?.toString();
    _loadFromExisting();
  }

  @override
  void didUpdateWidget(covariant EquipmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.updatedAt != widget.state.updatedAt || oldWidget.initialEmpId != widget.initialEmpId || oldWidget.initialShift != widget.initialShift) {
      _selectedEmpId = widget.initialEmpId ?? _selectedEmpId ?? BackendService.employeeForSession(widget.session, widget.state)?['id']?.toString();
      _loadFromExisting();
    }
  }

  void _loadFromExisting() {
    _status.clear();
    _notes.clear();
    final items = BackendService.mapList(widget.state.equipment);
    for (final item in items) {
      _status[(item['id'] ?? '').toString()] = 'ok';
      _notes[(item['id'] ?? '').toString()] = '';
    }
    final empId = _selectedEmpId;
    if (empId == null || empId.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final log = BackendService.checkLogFor(empId: empId, date: widget.state.schedDate, state: widget.state);
    final part = log != null && log[_shift] is Map ? Map<String, dynamic>.from(log[_shift]) : <String, dynamic>{};
    final submittedItems = part['items'] is List ? BackendService.mapList(List<dynamic>.from(part['items'])) : const <Map<String, dynamic>>[];
    for (final row in submittedItems) {
      final id = (row['equipmentId'] ?? row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      _status[id] = (row['status'] ?? 'ok').toString();
      _notes[id] = (row['note'] ?? '').toString();
    }
    _generalNote.text = (part['note'] ?? '').toString();
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final empId = _selectedEmpId;
    if (empId == null || empId.isEmpty) return;
    final items = BackendService.mapList(widget.state.equipment).map((item) {
      final id = (item['id'] ?? '').toString();
      return {
        'equipmentId': id,
        'name': (item['name'] ?? 'Equipment').toString(),
        'status': _status[id] ?? 'ok',
        'note': (_notes[id] ?? '').trim(),
      };
    }).toList();
    await BackendService.submitEquipmentCheck(session: widget.session, state: widget.state, empId: empId, shift: _shift, items: items, generalNote: _generalNote.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_shift == 'morning' ? 'Morning' : 'Evening'} check saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final employees = BackendService.mapList(widget.state.emps);
    final equipment = BackendService.mapList(widget.state.equipment);
    final effectiveEmpId = _selectedEmpId ?? (employees.isNotEmpty ? (employees.first['id'] ?? '').toString() : null);
    final selectedEmp = BackendService.employeeById(effectiveEmpId, widget.state);
    final history = BackendService.mapList(widget.state.checkLogs).where((e) => effectiveEmpId == null || effectiveEmpId.isEmpty ? false : (e['empId'] ?? '').toString() == effectiveEmpId).take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Equipment checks', subtitle: _workerMode ? 'Submit your start/end shift checks' : 'Manage worker checks and equipment returns'),
        if (!_workerMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: effectiveEmpId,
              items: employees.map((emp) => DropdownMenuItem<String>(value: (emp['id'] ?? '').toString(), child: Text((emp['name'] ?? 'Employee').toString()))).toList(),
              onChanged: (value) {
                setState(() => _selectedEmpId = value);
                _loadFromExisting();
              },
              decoration: const InputDecoration(labelText: 'Employee'),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Morning check'), selected: _shift == 'morning', onSelected: (_) { setState(() => _shift = 'morning'); _loadFromExisting(); }),
                ChoiceChip(label: const Text('Evening return'), selected: _shift == 'evening', onSelected: (_) { setState(() => _shift = 'evening'); _loadFromExisting(); }),
              ]),
              const SizedBox(height: 12),
              if (selectedEmp != null) Text('Employee: ${(selectedEmp['name'] ?? 'Employee').toString()}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Date: ${widget.state.schedDate}', style: const TextStyle(color: Palette.muted)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (equipment.isEmpty)
          const _EmptyState(icon: Icons.handyman_rounded, title: 'No equipment items found', subtitle: 'Add equipment records first so workers can complete checks.')
        else
          ...equipment.map((item) {
            final id = (item['id'] ?? '').toString();
            final currentStatus = _status[id] ?? 'ok';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((item['name'] ?? 'Equipment').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final choice in const ['ok', 'issue', 'missing'])
                          ChoiceChip(label: Text(choice.toUpperCase()), selected: currentStatus == choice, onSelected: (_) => setState(() => _status[id] = choice)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _notes[id] ?? '',
                      minLines: 1,
                      maxLines: 2,
                      onChanged: (value) => _notes[id] = value,
                      decoration: const InputDecoration(labelText: 'Notes', hintText: 'Issue details, missing parts, fuel, blade, etc.'),
                    ),
                  ]),
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        TextField(controller: _generalNote, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'General check note', hintText: 'Anything the admin should know about this shift check')),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: equipment.isEmpty || effectiveEmpId == null || effectiveEmpId.isEmpty ? null : _submit, icon: const Icon(Icons.cloud_upload_rounded), label: Text(_shift == 'morning' ? 'Submit morning check' : 'Submit evening return')),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Recent history',
          child: history.isEmpty
              ? const Text('No recent check logs for this employee.', style: TextStyle(color: Palette.muted))
              : Column(children: history.map((row) {
                  final morningDone = row['morning'] is Map && row['morning']['submitted'] == true;
                  final eveningDone = row['evening'] is Map && row['evening']['submitted'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(child: Text((row['date'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                      if (morningDone) const _StatusPill(text: 'Morning'),
                      if (morningDone && eveningDone) const SizedBox(width: 6),
                      if (eveningDone) const _StatusPill(text: 'Evening'),
                    ]),
                  );
                }).toList()),
        ),
      ],
    );
  }
}

class EmployeesPage extends StatefulWidget {
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
        _ActionTile(icon: Icons.calculate_rounded, title: 'Quote calculator', subtitle: 'Create, price, and save service quotes', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Quote calculator')), body: QuoteCalculatorPage(state: state, session: session))))),
        _ActionTile(icon: Icons.handyman_rounded, title: 'Equipment checks', subtitle: 'Inspect and update shift equipment status', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Equipment checks')), body: EquipmentPage(state: state, session: session))))),
        _ActionTile(icon: Icons.task_alt_rounded, title: 'Jobs log', subtitle: 'View completed and pending jobs', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Jobs log')), body: JobsLogPage(state: state))))),
        _ActionTile(icon: Icons.manage_accounts_rounded, title: 'Users & access', subtitle: 'See staff accounts synced from Firebase', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Users & access')), body: UsersPage(state: state, session: session))))),
        _ActionTile(icon: Icons.analytics_rounded, title: 'Reports', subtitle: 'Clocking, checks, and quote summaries', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Reports')), body: ReportsPage(state: state))))),
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

class WorkerTodayPage extends StatefulWidget {
  final AppSession session;
  final WorkspaceState state;
  const WorkerTodayPage({super.key, required this.session, required this.state});

  @override
  State<WorkerTodayPage> createState() => _WorkerTodayPageState();
}

class _WorkerTodayPageState extends State<WorkerTodayPage> {
  @override
  Widget build(BuildContext context) {
    final emp = BackendService.employeeForSession(widget.session, widget.state);
    final empId = (emp?['id'] ?? '').toString();
    final active = empId.isEmpty ? null : BackendService.activeClockForEmp(empId, widget.state);
    final duration = empId.isEmpty ? null : BackendService.activeShiftDuration(empId, widget.state);
    final jobs = widget.state.jobs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((job) {
      final assignedEmpId = (job['empId'] ?? '').toString();
      final worker = (job['workerName'] ?? '').toString().toLowerCase();
      final sameWorker = assignedEmpId.isNotEmpty ? assignedEmpId == empId : (worker == widget.session.displayName.toLowerCase() || worker == widget.session.username.toLowerCase() || worker.isEmpty);
      return sameWorker && (job['date'] ?? '') == widget.state.schedDate;
    }).toList();
    final morningDone = empId.isNotEmpty && BackendService.shiftSubmitted(empId: empId, date: widget.state.schedDate, shift: 'morning', state: widget.state);
    final eveningDone = empId.isNotEmpty && BackendService.shiftSubmitted(empId: empId, date: widget.state.schedDate, shift: 'evening', state: widget.state);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'My route', subtitle: widget.state.schedDate),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active == null ? 'Not clocked in' : 'Currently clocked in', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 6),
              Text(active == null ? 'Clock in before you start the shift.' : 'On shift for ${_formatDuration(duration ?? Duration.zero)}', style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: emp == null ? null : () async {
                    if (active == null) {
                      await BackendService.clockIn(widget.session, widget.state);
                    } else {
                      await BackendService.clockOut(widget.session, widget.state);
                    }
                  },
                  icon: Icon(active == null ? Icons.play_arrow_rounded : Icons.stop_circle_outlined),
                  label: Text(active == null ? 'Clock in' : 'Clock out'),
                ),
                OutlinedButton.icon(
                  onPressed: emp == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Morning equipment check')), body: EquipmentPage(state: widget.state, session: widget.session, initialEmpId: empId, initialShift: 'morning', forceWorkerMode: true)))),
                  icon: const Icon(Icons.sunny_rounded),
                  label: Text(morningDone ? 'Morning check ✓' : 'Morning check'),
                ),
                OutlinedButton.icon(
                  onPressed: emp == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Evening equipment return')), body: EquipmentPage(state: widget.state, session: widget.session, initialEmpId: empId, initialShift: 'evening', forceWorkerMode: true)))),
                  icon: const Icon(Icons.nightlight_round),
                  label: Text(eveningDone ? 'Evening return ✓' : 'Evening return'),
                ),
              ]),
              if (emp == null) ...[
                const SizedBox(height: 10),
                const Text('No employee record linked — ask admin to link your account.', style: TextStyle(color: Palette.danger)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: CheckboxListTile(
                value: job['done'] == true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.all(16),
                title: Text((job['name'] ?? 'Client').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${job['address'] ?? ''}
${(job['taskChecklist'] is List && (job['taskChecklist'] as List).isNotEmpty) ? 'Checklist attached' : 'Standard visit'}'),
                onChanged: (v) async {
                  final updated = widget.state.jobs.whereType<Map>().map((e) {
                    final item = Map<String, dynamic>.from(e);
                    if (item['id'] == job['id']) item['done'] = v ?? false;
                    return item;
                  }).toList();
                  await BackendService.saveState(widget.state.copyWith(jobs: updated), updatedBy: widget.session.username);
                },
              ),
            ),
          ),
        if (jobs.isEmpty)
          const _EmptyState(icon: Icons.route_rounded, title: 'No route assigned', subtitle: 'No jobs are assigned to you for this date yet.'),
      ],
    );
  }
}

class QuoteCalculatorPage extends StatefulWidget {
  final WorkspaceState state;
  final AppSession session;
  const QuoteCalculatorPage({super.key, required this.state, required this.session});

  @override
  State<QuoteCalculatorPage> createState() => _QuoteCalculatorPageState();
}

class _QuoteCalculatorPageState extends State<QuoteCalculatorPage> {
  String packageName = 'Garden maintenance';
  String frequency = 'Weekly';
  final areaCtrl = TextEditingController(text: '400');
  final clientCtrl = TextEditingController();
  bool wasteRemoval = false;
  bool hedges = false;
  bool poolArea = false;

  double get monthlyPrice {
    final area = double.tryParse(areaCtrl.text.trim()) ?? 0;
    double base;
    switch (packageName) {
      case 'Lawn only':
        base = 450;
        break;
      case 'Full property care':
        base = 950;
        break;
      default:
        base = 700;
    }
    final areaBand = area <= 300 ? 0 : area <= 800 ? 180 : 320;
    final extras = (wasteRemoval ? 180 : 0) + (hedges ? 150 : 0) + (poolArea ? 120 : 0);
    final multiplier = frequency == 'Weekly' ? 4.0 : frequency == 'Bi-weekly' ? 2.2 : 1.0;
    return ((base + areaBand + extras) * multiplier);
  }

  double get perVisit => frequency == 'Weekly' ? monthlyPrice / 4 : frequency == 'Bi-weekly' ? monthlyPrice / 2 : monthlyPrice;

  Future<void> _saveQuote() async {
    await BackendService.saveQuote(
      session: widget.session,
      state: widget.state,
      quote: {
        'id': _newId(),
        'clientName': clientCtrl.text.trim().isEmpty ? 'Walk-in quote' : clientCtrl.text.trim(),
        'package': packageName,
        'frequency': frequency,
        'areaM2': double.tryParse(areaCtrl.text.trim()) ?? 0,
        'wasteRemoval': wasteRemoval,
        'hedges': hedges,
        'poolArea': poolArea,
        'price': double.parse(perVisit.toStringAsFixed(2)),
        'monthlyPrice': double.parse(monthlyPrice.toStringAsFixed(2)),
        'createdAt': _today(),
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Quote calculator', subtitle: 'Build and save service quotes'),
        TextField(controller: clientCtrl, decoration: const InputDecoration(labelText: 'Client / site name')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: packageName,
          items: const [
            DropdownMenuItem(value: 'Lawn only', child: Text('Lawn only')),
            DropdownMenuItem(value: 'Garden maintenance', child: Text('Garden maintenance')),
            DropdownMenuItem(value: 'Full property care', child: Text('Full property care')),
          ],
          onChanged: (v) => setState(() => packageName = v ?? packageName),
          decoration: const InputDecoration(labelText: 'Package'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: frequency,
          items: const [
            DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'Bi-weekly', child: Text('Bi-weekly')),
            DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
          ],
          onChanged: (v) => setState(() => frequency = v ?? frequency),
          decoration: const InputDecoration(labelText: 'Frequency'),
        ),
        const SizedBox(height: 12),
        TextField(controller: areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated site size (m²)')),
        const SizedBox(height: 12),
        CheckboxListTile(value: wasteRemoval, onChanged: (v) => setState(() => wasteRemoval = v ?? false), title: const Text('Include waste removal')),
        CheckboxListTile(value: hedges, onChanged: (v) => setState(() => hedges = v ?? false), title: const Text('Include hedge trimming')),
        CheckboxListTile(value: poolArea, onChanged: (v) => setState(() => poolArea = v ?? false), title: const Text('Include pool / hardscape sweep')),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('Calculated estimate', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text(_money(monthlyPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: Palette.green)),
          const SizedBox(height: 4),
          Text('Approx. ${_money(perVisit)} per visit', style: const TextStyle(color: Palette.muted)),
        ]))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _saveQuote, icon: const Icon(Icons.save_rounded), label: const Text('Save quote')),
      ],
    );
  }
}

class ReportsPage extends StatelessWidget {
  final WorkspaceState state;
  const ReportsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final active = BackendService.activeClockEntries(state);
    final recentChecks = BackendService.mapList(state.checkLogs).take(8).toList();
    final quotes = BackendService.mapList(state.quotes);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _SectionHeader(title: 'Reports', subtitle: 'Live operations snapshot'),
        _SectionCard(
          title: 'Live workforce',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clocked in now: ${active.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (active.isEmpty)
              const Text('No active shifts right now.', style: TextStyle(color: Palette.muted))
            else
              ...active.map((row) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${row['employeeName'] ?? row['empId']} · in at ${_fmtTime(row['clockIn'])}'))),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Recent equipment checks',
          child: recentChecks.isEmpty
              ? const Text('No equipment checks saved yet.', style: TextStyle(color: Palette.muted))
              : Column(children: recentChecks.map((row) {
                  final morning = row['morning'] is Map && row['morning']['submitted'] == true;
                  final evening = row['evening'] is Map && row['evening']['submitted'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(child: Text('${row['date'] ?? '-'} · ${row['employeeName'] ?? row['empId']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (morning) const _StatusPill(text: 'Morning'),
                      if (morning && evening) const SizedBox(width: 6),
                      if (evening) const _StatusPill(text: 'Evening'),
                    ]),
                  );
                }).toList()),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Saved quotes',
          child: quotes.isEmpty
              ? const Text('No quotes saved yet.', style: TextStyle(color: Palette.muted))
              : Column(children: quotes.take(8).map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(child: Text((q['clientName'] ?? q['name'] ?? 'Quote').toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(_money(_num(q['monthlyPrice'] ?? q['price']))),
                    ]),
                  )).toList()),
        ),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: Palette.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]);
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

String _formatDuration(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _fmtTime(dynamic value) {
  final dt = DateTime.tryParse((value ?? '').toString());
  if (dt == null) return '-';
  return DateFormat('HH:mm').format(dt.toLocal());
}

String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());
double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(double value) => 'R${value.toStringAsFixed(2)}';
String _initials(dynamic name) {
  final parts = (name ?? '').toString().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'P';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}
