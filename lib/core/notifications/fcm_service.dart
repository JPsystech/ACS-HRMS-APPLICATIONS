import 'package:acs_hrms/app.dart';
import 'package:acs_hrms/core/api/endpoints.dart';
import 'package:acs_hrms/core/auth/auth_constants.dart';
import 'package:acs_hrms/core/storage/secure_store.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Required for background isolate work.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  // Release-safe background logging (must not rely on debugPrint).
  final type = message.data['type']?.toString();
  final id = message.data['id']?.toString();
  final title = message.notification?.title?.toString();
  final body = message.notification?.body?.toString();
  print('📬 FCM background handler executed type=$type id=$id title=$title body=$body');
}

class FcmService {
  FcmService({required Dio dio, required SecureStore secureStore})
      : _dio = dio,
        _store = secureStore,
        _notifications = FlutterLocalNotificationsPlugin();

  final Dio _dio;
  final SecureStore _store;
  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  bool _askedPermission = false;

  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'push_notifications',
    'Push Notifications',
    description: 'FCM push notifications',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _approvalsChannel = AndroidNotificationChannel(
    'approvals',
    'Approvals',
    description: 'Approval and action notifications',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _remindersChannel = AndroidNotificationChannel(
    'reminders',
    'Reminders',
    description: 'Attendance and reminder notifications',
    importance: Importance.high,
  );

  void _log(String msg) {
    final prefix = 'FCM: ';
    if (kDebugMode) {
      debugPrint('$prefix$msg');
    } else {
      print('$prefix$msg');
    }
  }

  void _logError(String msg, Object e) {
    final prefix = 'FCM: ';
    if (kDebugMode) {
      debugPrint('$prefix❌ $msg: $e');
    } else {
      print('$prefix❌ $msg: $e');
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      // main.dart also initializes Firebase; keep this idempotent for safety.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );
      await _createAndroidNotificationChannels();
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      _log('Firebase initialized and notification permission requested (Android)');
      
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await ensurePermissions();

      // 1. Handle foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 2. Handle background taps (app was in background but not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _log('Notification tapped while in background');
        _handleRemoteMessageTap(message);
      });

      // 3. Handle terminated state taps (app was closed)
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          _log('Notification tapped while app was terminated');
          _handleRemoteMessageTap(message);
        }
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _log('FCM token refreshed');
        _registerToken(token);
      });

      final authToken = await _store.read(AuthConstants.tokenKey);
      if (authToken != null && authToken.isNotEmpty) {
        await _tryStartupTokenSync();
      }
      _initialized = true;
    } catch (e) {
      _logError('FCM init failed', e);
    }
  }

  Future<void> _createAndroidNotificationChannels() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      await android.createNotificationChannel(_defaultChannel);
      await android.createNotificationChannel(_approvalsChannel);
      await android.createNotificationChannel(_remindersChannel);
      _log('Android notification channels created/verified');
    } catch (e) {
      _logError('Failed to create Android notification channels', e);
    }
  }

  Future<void> _tryStartupTokenSync() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        _log('Startup token sync skipped (no token)');
        return;
      }
      _log('Startup token sync with token prefix=${token.substring(0, 12)}...');
      await _registerToken(token);
    } catch (e) {
      _logError('Startup token sync failed', e);
    }
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    // Extract data from FCM message and handle navigation
    final data = message.data;
    _log('Handling notification tap dataKeys=${data.keys.toList()}');
    if (data.isNotEmpty) _handleNotificationData(data);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final Map<String, dynamic> data = Uri.splitQueryString(payload);
      _handleNotificationData(data);
    } catch (e) {
      _logError('Failed to parse notification payload', e);
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id'] as String?;

    _log('Routing notification: type=$type, id=$id');

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    // Routing logic based on notification type
    switch (type) {
      case 'LEAVE_REQUEST':
      case 'LEAVE_APPROVED':
      case 'LEAVE_REJECTED':
      case 'LEAVE_CANCELLED':
        context.go('/leave');
        break;
      case 'PAYSLIP_GENERATED':
        context.go('/payslips');
        break;
      case 'WFH_REQUEST':
      case 'WFH_APPROVED':
      case 'WFH_REJECTED':
        context.go('/dashboard/wfh');
        break;
      case 'COMPOFF_REQUEST':
      case 'COMPOFF_APPROVED':
      case 'COMPOFF_REJECTED':
        context.go('/leave/compoff-request');
        break;
      case 'ATTN_CORRECTION_REQUEST':
      case 'ATTN_CORRECTION_APPROVED':
      case 'ATTN_CORRECTION_REJECTED':
        context.go('/attendance/correction');
        break;
      case 'ATTN_PUNCH_IN':
      case 'ATTN_PUNCH_OUT':
        // Requirement: reminders should open attendance screen.
        context.go('/attendance');
        break;
      default:
        context.go('/dashboard');
        break;
    }
  }

  Future<void> ensurePermissions() async {
    if (_askedPermission) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      _log('Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      _logError('Permission request failed', e);
    } finally {
      _askedPermission = true;
    }
  }

  Future<void> registerCurrentToken() async {
    await init();
    await ensurePermissions();
    try {
      final token = await FirebaseMessaging.instance.getToken();
      _log('Obtained FCM token: ${token != null ? token.substring(0, 12) : "null"}...');
      if (token != null) {
        await _registerToken(token);
      } else {
        _log('FCM token is null; skipping registration');
      }
    } catch (e) {
      _logError('Failed to get FCM token', e);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final authToken = await _store.read(AuthConstants.tokenKey);
      if (authToken == null || authToken.isEmpty) {
        _log('Skipping device registration (not authenticated)');
        return;
      }
      final platform = _platformString();
      final res = await _dio.post(
        Endpoints.notificationsRegisterDevice,
        data: {
          'fcm_token': token,
          'platform': platform,
          'is_active': true,
        },
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      final code = res.statusCode ?? 0;
      if (code == 200 || code == 201) {
        _log('Registered FCM token for platform=$platform');
      } else {
        _log('Device registration failed status=$code');
      }
    } catch (e) {
      _logError('Failed to register FCM token', e);
    }
  }

  void _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final type = data['type']?.toString();
    final payload = Uri(queryParameters: {
      for (final entry in data.entries) entry.key: '${entry.value}',
    }).query;

    final title = notification?.title?.toString() ??
        data['title']?.toString() ??
        'Notification';
    final body = notification?.body?.toString() ?? data['body']?.toString() ?? '';

    var resolvedTitle = title;
    var resolvedBody = body;
    if (type == 'PAYSLIP_GENERATED') {
      final m = data['month']?.toString() ??
          data['salary_month']?.toString() ??
          data['salaryMonth']?.toString();
      final y = data['year']?.toString() ??
          data['salary_year']?.toString() ??
          data['salaryYear']?.toString();
      final hasMonthYear = (m != null && m.isNotEmpty) && (y != null && y.isNotEmpty);
      final monthNum = m == null ? null : int.tryParse(m);
      final monthText = monthNum == null
          ? m
          : DateFormat('MMM').format(DateTime(2000, monthNum, 1));
      if (resolvedTitle.trim().isEmpty || resolvedTitle == 'Notification') {
        resolvedTitle = 'Payslip Generated';
      }
      if (resolvedBody.trim().isEmpty && hasMonthYear) {
        resolvedBody = 'Your payslip for $monthText $y is now available.';
      }
    }

    if (resolvedTitle.isEmpty && resolvedBody.isEmpty && data.isEmpty) {
      _log('Foreground message ignored (empty notification + empty data)');
      return;
    }

    _log('Foreground message received type=$type payloadKeys=${data.keys.toList()}');

    final channel = _resolveChannel(type);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      final localNotificationId =
          notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
      await _notifications.show(
        localNotificationId,
        resolvedTitle,
        resolvedBody,
        details,
        payload: payload,
      );
    } catch (e) {
      _logError('Failed to show local notification', e);
    }
  }

  AndroidNotificationChannel _resolveChannel(String? type) {
    if (type == null) return _defaultChannel;
    if (type.startsWith('ATTN_PUNCH_')) return _remindersChannel;
    if (type.startsWith('LEAVE_') ||
        type.startsWith('WFH_') ||
        type.startsWith('COMPOFF_') ||
        type.startsWith('ATTN_CORRECTION_')) {
      return _approvalsChannel;
    }
    return _defaultChannel;
  }

  String _platformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
