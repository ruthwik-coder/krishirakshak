import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final StreamController<String?> onNotificationClick =
      StreamController<String?>.broadcast();
  static String? initialPayload;

  static Future<void> init() async {
    // Use the custom launcher icon for notifications
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);

    final NotificationAppLaunchDetails? launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      initialPayload = launchDetails?.notificationResponse?.payload;
    }

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationClick.add(response.payload);
      },
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'intruder_alerts',
      'Intruder Alerts',
      channelDescription: 'Notifications for detected intruders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Colors.green,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, details, payload: payload);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cnbrwbibvlbzzztenfzr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzY2NDQsImV4cCI6MjA4ODIxMjY0NH0.quKfAnBY8FDxPkvuQbtz3PTVjC77VNvAYMaKUkLJ7Uo',
  );

  await NotificationService.init();

  runApp(const KrishiRakshakApp());
}

final supabase = Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────────────────────

class KrishiRakshakApp extends StatelessWidget {
  const KrishiRakshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'KrishiRakshak',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0, backgroundColor: Color(0xFF0F0F0F)),
          ),
          home: StreamBuilder<AuthState>(
            stream: supabase.auth.onAuthStateChange,
            builder: (context, snapshot) {
              final session = snapshot.data?.session;
              if (session != null) return const FarmDashboard();
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeC = TextEditingController();
  final _passC = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    final code = _codeC.text.trim();
    final pass = _passC.text.trim();
    if (code.isEmpty || pass.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      String email = code.contains('@') ? code : '${code.toLowerCase()}@krishirakshak.com';
      await supabase.auth.signInWithPassword(
        email: email,  
        password: pass,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF1B5E20).withValues(alpha: 0.2), const Color(0xFF0F0F0F)]
              : [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.05),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.green.withValues(alpha: 0.1)),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        isDark ? 'assets/logo/app_logo.png' : 'assets/logo/app_logo_light.png',
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.asset('assets/logo/app_logo.png', height: 100, width: 100),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('KRISHI RAKSHAK',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 8),
                Text('Secure Your Harvest',
                    style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                    border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade100),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeC,
                        decoration: InputDecoration(
                            labelText: 'User ID', 
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passC,
                        obscureText: true,
                        decoration: InputDecoration(
                            labelText: 'Password', 
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FARM DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class FarmDashboard extends StatefulWidget {
  const FarmDashboard({super.key});

  @override
  State<FarmDashboard> createState() => _FarmDashboardState();
}

class _FarmDashboardState extends State<FarmDashboard> {
  String? _selectedDevice;
  bool _isTalking = false;
  bool _sirenActive = false;
  bool _autoDeterActive = false;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription? _notifSub;

  // Real-time Audio Stream Vars
  HttpClient? _liveAudioClient;
  HttpClientRequest? _liveAudioRequest;

  @override
  void initState() {
    super.initState();
    _listenForAlerts();
    _handleNotificationClicks();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _recorder.dispose();
    _liveAudioRequest?.close();
    _liveAudioClient?.close();
    super.dispose();
  }

  void _handleNotificationClicks() {
    _notifSub =
        NotificationService.onNotificationClick.stream.listen((payload) {
      if (payload != null && payload.contains('|')) {
        final parts = payload.split('|');
        setState(() => _selectedDevice = parts[0]);
        if (mounted) _showEvents(context, highlightImage: parts[1]);
      }
    });

    if (NotificationService.initialPayload != null) {
      Timer(const Duration(seconds: 1), () {
        final p = NotificationService.initialPayload!;
        if (p.contains('|')) {
          final parts = p.split('|');
          setState(() => _selectedDevice = parts[0]);
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            _showEvents(ctx, highlightImage: parts[1]);
          }
        }
        NotificationService.initialPayload = null;
      });
    }
  }

  void _listenForAlerts() {
    supabase
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            final intruder = payload.newRecord['intruder_type'] ?? 'Unknown';
            final device = payload.newRecord['device_code'] ?? 'Camera';
            final imageUrl = payload.newRecord['image_url'] ?? '';

            NotificationService.showNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: '⚠️ INTRUDER DETECTED!',
              body: '$intruder detected at $device',
              payload: '$device|$imageUrl',
            );
          },
        )
        .subscribe();
  }

  String _formatSupabaseTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  void _showMsg(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _onTalkStart() async {
    if (_selectedDevice == null || _isTalking) return;

    // Set UI state immediately for responsiveness
    setState(() => _isTalking = true);

    HapticFeedback.lightImpact();

    try {
      final status = await Permission.microphone.request();

      if (!status.isGranted || !_isTalking) {
        if (!_isTalking) _onTalkEnd();
        return;
      }

      final res = await supabase
          .from('device_registrations')
          .select('stream_url')
          .eq('device_code', _selectedDevice!)
          .single();
          
      final baseUrl = res['stream_url']?.toString() ?? "";
      if (baseUrl.isEmpty) {
        _showMsg("System not configured for this device");
        _onTalkEnd();
        return;
      }

      if (!_isTalking) { _onTalkEnd(); return; }

      final audioUrl = baseUrl.replaceAll('/video_feed', '/audio_stream');

      _liveAudioClient = HttpClient();
      _liveAudioClient!.connectionTimeout = const Duration(seconds: 5);
      
      _liveAudioClient!.badCertificateCallback = (cert, host, port) => true;

      _liveAudioRequest = await _liveAudioClient!.postUrl(Uri.parse(audioUrl));
      _liveAudioRequest!.headers.set('Content-Type', 'application/octet-stream');
      _liveAudioRequest!.headers.set('Transfer-Encoding', 'chunked');

      final recordStream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      recordStream.listen((data) {
        if (_isTalking) {
          _liveAudioRequest?.add(data);
        }
      });

      await supabase
          .from('device_registrations')
          .update({'is_talking': true}).eq('device_code', _selectedDevice!).select('device_code');
    } catch (e) {
      debugPrint('Live Talk Error: $e');
      if (e is SocketException) {
        _showMsg("Camera connection failed. Check your tunnel URL.");
      } else {
        _showMsg("Intercom Error: $e");
      }
      _onTalkEnd();
    }
  }

  Future<void> _onTalkEnd() async {
    if (!_isTalking) return;
    setState(() => _isTalking = false);
    try {
      await _recorder.stop();
      await _liveAudioRequest?.close();
      _liveAudioClient?.close();

      await supabase
          .from('device_registrations')
          .update({'is_talking': false}).eq('device_code', _selectedDevice!).select('device_code');
    } catch (e) {
      debugPrint('Stop Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Hero(
            tag: 'app_logo',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.05),
              ),
              child: ClipOval(
                child: Image.asset(
                  isDark ? 'assets/logo/app_logo.png' : 'assets/logo/app_logo_light.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Image.asset('assets/logo/app_logo.png'),
                ),
              ),
            ),
          ),
        ),
        title: Text('KRISHI RAKSHAK',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.primary, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
              setState(() {});
            },
          ),
          IconButton(
              onPressed: () => supabase.auth.signOut(),
              icon: const Icon(Icons.logout))
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCameraSelector(),
            if (_selectedDevice != null) 
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('device_registrations')
                    .stream(primaryKey: ['device_code'])
                    .eq('device_code', _selectedDevice!),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint("Stream error: ${snapshot.error}");
                    // If auto_deterrence column is missing, this stream might fail.
                    // Once user adds column, they should reload schema cache.
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                  final d = snapshot.data!.first;
                  _sirenActive = d['siren_active'] ?? false;
                  // Handle potential missing column gracefully
                  _autoDeterActive = (d.containsKey('auto_deterrence')) ? (d['auto_deterrence'] ?? false) : false;
                  final isLive = d['is_live_requested'] ?? false;

                  return Column(
                    children: [
                      _buildStatusBannerContent(isLive, _sirenActive),
                      _buildQuickAlertPreview(),
                      _buildAutoDeterSectionContent(_autoDeterActive),
                      _buildActionGrid(),
                    ],
                  );
                }
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSelector() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('device_registrations')
          .stream(primaryKey: ['device_code']).eq(
              'owner_id', supabase.auth.currentUser!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final devices = snapshot.data!;
        if (devices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ActionChip(
                label: const Text('Add Camera'), onPressed: _addCamera),
          );
        }
        if (_selectedDevice == null) {
          Future.microtask(() =>
              setState(() => _selectedDevice = devices.first['device_code']));
        }

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: devices.length + 1,
            itemBuilder: (ctx, i) {
              if (i == devices.length) {
                return IconButton(
                    onPressed: _addCamera,
                    icon: const Icon(Icons.add_circle, color: Colors.green));
              }
              final d = devices[i];
              final isSel = _selectedDevice == d['device_code'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(d['area_name'] ?? d['device_code']),
                  selected: isSel,
                  onSelected: (_) =>
                      setState(() => _selectedDevice = d['device_code']),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusBannerContent(bool isLive, bool sirenActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.green.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('DEVICE STATUS', isLive ? 'LIVE' : 'IDLE',
              isLive ? Colors.red : Colors.green),
          const VerticalDivider(width: 1),
          _buildStat('SECURITY', sirenActive ? 'ALARM ON' : 'SAFE',
              sirenActive ? Colors.orange : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildQuickAlertPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('alerts')
          .stream(primaryKey: ['id'])
          .eq('device_code', _selectedDevice!)
          .order('created_at', ascending: false)
          .limit(1),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
        final lastAlert = snapshot.data!.first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () => _showEvents(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(lastAlert['image_url'], width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text(lastAlert['intruder_type'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Detected at ${_formatSupabaseTime(lastAlert['created_at'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoDeterSectionContent(bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.1)),
      ),
      child: SwitchListTile(
        title: const Text('AUTO DETERRENCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: const Text('Play predator sounds automatically', style: TextStyle(fontSize: 12)),
        secondary: Icon(Icons.auto_fix_high, color: active ? Colors.blue : Colors.grey),
        value: active,
        onChanged: (val) => _toggleAutoDeter(val),
      ),
    );
  }

  Widget _buildStat(String label, String val, Color col) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Text(val,
            style: TextStyle(
                color: col, fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _buildActionGrid() {
    if (_selectedDevice == null) return const SizedBox();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionCard(
            'LIVE FEED', Icons.videocam_rounded, Colors.orange, _showLiveFeed),
        _buildActionCard('ACTIVITY', Icons.history_rounded, Colors.blue,
            () => _showEvents(context)),
        _buildActionCard(
            'SIREN', Icons.notifications_active_rounded, Colors.red, _toggleSirenAction,
            isActive: _sirenActive),
        _buildActionCard('SETTINGS', Icons.settings_rounded, Colors.grey, _showSettings),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color col, VoidCallback tap,
      {bool isActive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? col.withValues(alpha: 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isDark && !isActive)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
          ],
          border: Border.all(
              color: isActive
                  ? col
                  : (isDark ? Colors.white10 : Colors.green.shade50)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: col, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Logic Methods ──────────────────────────────────────────────────────

  void _showLiveFeed() async {
    final res = await supabase
        .from('device_registrations')
        .select('stream_url')
        .eq('device_code', _selectedDevice!)
        .single();
    final url = res['stream_url'] as String?;

    if (url == null || url.isEmpty) {
      if (mounted) _showMsg("Configuration missing for this camera");
      return;
    }

    try {
      await supabase
          .from('device_registrations')
          .update({'is_live_requested': true}).eq('device_code', _selectedDevice!).select('device_code');
    } catch (e) {
      debugPrint("Error starting live: $e");
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return PopScope(
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) {
                _stopLive();
              }
            },
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  Expanded(child: Center(child: MjpegViewer(url: url))),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModalControl(
                          icon: _isTalking ? Icons.mic : Icons.mic_none,
                          label: 'TALK',
                          color: _isTalking ? Colors.green : Colors.white24,
                          isLarge: true,
                          onTapDown: (_) async {
                            await _onTalkStart();
                            setModalState(() {});
                          },
                          onTapUp: (_) async {
                            await _onTalkEnd();
                            setModalState(() {});
                          },
                          onTapCancel: () async {
                            await _onTalkEnd();
                            setModalState(() {});
                          },
                        ),
                        _buildModalControl(
                          icon: _sirenActive ? Icons.notifications_active : Icons.notifications_off,
                          label: 'SIREN',
                          color: _sirenActive ? Colors.red : Colors.white24,
                          onTap: () async {
                            final newState = !_sirenActive;
                            try {
                              await supabase.from('device_registrations').update({'siren_active': newState}).eq('device_code', _selectedDevice!).select('device_code');
                              setModalState(() => _sirenActive = newState);
                            } catch (e) {
                              debugPrint("Siren error: $e");
                            }
                          },
                        ),
                        _buildModalControl(
                          icon: Icons.close,
                          label: 'EXIT',
                          color: Colors.white24,
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );

    // Final cleanup after BottomSheet is closed (if PopScope didn't catch it or for extra safety)
    _stopLive();
  }

  void _stopLive() async {
    await _onTalkEnd();
    if (_selectedDevice != null) {
      try {
        await supabase
            .from('device_registrations')
            .update({'is_live_requested': false})
            .eq('device_code', _selectedDevice!)
            .select('device_code');
      } catch (e) {
        debugPrint("Error stopping live: $e");
      }
    }
  }

  Widget _buildModalControl({
    required IconData icon,
     
    required String label, 
    required Color color, 
    bool isLarge = false, 

    VoidCallback? onTap, 
    Function(TapDownDetails)? onTapDown, 
    Function(TapUpDetails)? onTapUp,
    VoidCallback? onTapCancel,
    Function(LongPressStartDetails)? onLongPressStart, 
    Function(LongPressEndDetails)? onLongPressEnd
  }) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(

          onTap: onTap,
          onTapDown: onTapDown,
          onTapUp: onTapUp,
          onTapCancel: onTapCancel,
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.all(isLarge ? 20 : 16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isLarge && _isTalking ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 20)] : [],
            ),
            child: Icon(icon, color: Colors.white, size: isLarge ? 40 : 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showEvents(BuildContext context, {String? highlightImage}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('ACTIVITY LOG', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('alerts')
                    .stream(primaryKey: ['id'])
                    .eq('device_code', _selectedDevice!)
                    .order('created_at', ascending: false),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final alerts = snap.data!;
                  if (alerts.isEmpty) return const Center(child: Text('No activity detected yet'));
                  return ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final a = alerts[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: GestureDetector(
                            onTap: () => _previewLargeImage(context, a['image_url'], a['intruder_type'], a['id'].toString()),
                            child: Hero(
                              tag: a['id'].toString(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(a['image_url'], width: 70, height: 70, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          title: Text(a['intruder_type'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_formatSupabaseTime(a['created_at'])),
                          onTap: () => _previewLargeImage(context, a['image_url'], a['intruder_type'], a['id'].toString()),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previewLargeImage(BuildContext context, String url, String? title, String heroTag) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title ?? "Intruder Preview", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    )));
  }

  void _toggleSirenAction() async {
    final newState = !_sirenActive;
    try {
      await supabase.from('device_registrations').update({'siren_active': newState}).eq('device_code', _selectedDevice!).select('device_code');
    } catch (e) {
      debugPrint("Toggle Siren error: $e");
    }
  }

  void _toggleAutoDeter(bool val) async {
    try {
      // Use select to minimize issues if PostgREST cache is stale
      await supabase.from('device_registrations').update({'auto_deterrence': val}).eq('device_code', _selectedDevice!).select('device_code');
    } catch (e) {
      debugPrint("Toggle Auto Deter error: $e");
      if (e is PostgrestException && e.code == 'PGRST204') {
         _showMsg("Database column not found. Please reload Supabase Schema Cache.");
      }
    }
  }

  void _addCamera() {
    final idC = TextEditingController();
    final nameC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Camera'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idC, decoration: const InputDecoration(labelText: 'Device Serial Number')),
            const SizedBox(height: 12),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Location Name (e.g. Back Gate)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              try {
                final deviceCode = idC.text.trim();
                final areaName = nameC.text.trim();
                
                final existing = await supabase
                    .from('device_registrations')
                    .select('device_code')
                    .eq('device_code', deviceCode)
                    .maybeSingle();
                
                if (existing != null) {
                  await supabase.from('device_registrations').update({
                    'owner_id': supabase.auth.currentUser!.id,
                    'area_name': areaName,
                    'is_activated': true
                  }).eq('device_code', deviceCode);
                } else {
                  await supabase.from('device_registrations').insert({
                    'device_code': deviceCode,
                    'owner_id': supabase.auth.currentUser!.id,
                    'area_name': areaName,
                    'is_activated': true,
                    'stream_url': '',
                    'siren_active': false,
                    'auto_deterrence': false,
                    'is_live_requested': false,
                    'is_talking': false,
                  });
                }
              } catch (e) {
                debugPrint("Add camera error: $e");
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('LINK DEVICE'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    final nameC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Update Location Name')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await supabase.from('device_registrations').update({
                  'owner_id': null,
                  'is_activated': false,
                  'is_live_requested': false,
                  'siren_active': false
                }).eq('device_code', _selectedDevice!).select('device_code');
                setState(() => _selectedDevice = null);
              } catch (e) {
                debugPrint("Unlink error: $e");
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('UNLINK DEVICE', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isNotEmpty) {
                try {
                  await supabase.from('device_registrations').update({'area_name': nameC.text}).eq('device_code', _selectedDevice!).select('device_code');
                } catch (e) {
                  debugPrint("Update name error: $e");
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MJPEG VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class MjpegViewer extends StatefulWidget {
  final String url;
  const MjpegViewer({super.key, required this.url});
  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  Uint8List? _frame;
  HttpClient? _httpClient;
  StreamSubscription? _subscription;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() async {
    if (!mounted) return;
    _cleanup();
    
    try {
      debugPrint("MJPEG: Connecting to ${widget.url}");
      _httpClient = HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 15);
      
      final request = await _httpClient!.getUrl(Uri.parse(widget.url));
      // Essential headers for tunnels
      request.headers.set('ngrok-skip-browser-warning', 'true');
      request.headers.set('cf-terminate-connection', 'false');
      
      final response = await request.close();
      
      if (response.statusCode != 200) {
        debugPrint("MJPEG: Status ${response.statusCode}");
        _handleRetry();
        return;
      }
      
      final List<int> buffer = [];
      
      _subscription = response.listen((chunk) {
        if (!mounted) return;
        buffer.addAll(chunk);
        
        while (buffer.length >= 2) {
          int start = -1;
          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
              start = i;
              break;
            }
          }
          
          if (start == -1) {
            if (buffer.length > 1024 * 1024) buffer.clear();
            break;
          }
          
          if (start > 0) buffer.removeRange(0, start);
          
          int end = -1;
          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
              end = i + 2;
              break;
            }
          }
          
          if (end == -1) break;
          
          final frame = Uint8List.fromList(buffer.sublist(0, end));
          buffer.removeRange(0, end);
          
          if (mounted) {
            setState(() {
              _frame = frame;
              _loading = false;
            });
          }
        }
      }, onError: (e) {
        debugPrint("MJPEG Stream Error: $e");
        _handleRetry();
      }, onDone: () {
        debugPrint("MJPEG Stream Finished");
        _handleRetry();
      });
      
    } catch (e) {
      debugPrint("MJPEG Connect Exception: $e");
      _handleRetry();
    }
  }

  void _handleRetry() async {
    if (!mounted) return;
    _cleanup();
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) _connect();
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _frame == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 24),
          Text('Establishing encrypted link...', style: TextStyle(color: Colors.white38, letterSpacing: 1)),
        ],
      );
    }
    return _frame == null
        ? const CircularProgressIndicator()
        : Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(8)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_frame!, gaplessPlayback: true, fit: BoxFit.contain, width: double.infinity),
            ),
          );
  }
}
