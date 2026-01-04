import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../objectbox.g.dart'; // IMPORTANT: Import généré
import '../objectbox_entities_complete.dart';

// class NetworkService extends ChangeNotifier {
//   bool _isConnected = true;
//   final Connectivity _connectivity = Connectivity();
//   StreamSubscription<List<ConnectivityResult>>? _subscription;
//   Timer? _pollTimer;
//
//   bool get isConnected => _isConnected;
//
//   NetworkService() {
//     _initConnectivity();
//   }
//
//   Future<void> _initConnectivity() async {
//     try {
//       final results = await _connectivity.checkConnectivity();
//       _updateConnectionStatus(results);
//
//       // Sur Windows/Linux Desktop : Polling au lieu de stream
//       if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
//         debugPrint('NetworkService: Using polling for Windows/Linux');
//         _startPolling();
//       } else {
//         // Android/iOS/Web/macOS : Stream classique
//         _subscription = _connectivity.onConnectivityChanged.listen(
//           _updateConnectionStatus,
//           onError: (e) => debugPrint('Connectivity stream error: $e'),
//         );
//       }
//     } catch (e) {
//       debugPrint('NetworkService init error: $e');
//       _isConnected = true; // Assume connected on error
//     }
//   }
//
//   /// Polling pour Windows Desktop (évite le bug du stream)
//   void _startPolling() {
//     _pollTimer?.cancel();
//     _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
//       try {
//         final results = await _connectivity.checkConnectivity();
//         _updateConnectionStatus(results);
//       } catch (e) {
//         debugPrint('Connectivity poll error: $e');
//       }
//     });
//   }
//
//   void _updateConnectionStatus(List<ConnectivityResult> results) {
//     final wasConnected = _isConnected;
//     _isConnected =
//         results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
//
//     if (wasConnected != _isConnected) {
//       debugPrint('NetworkService: $_isConnected');
//       notifyListeners();
//     }
//   }
//
//   Future<bool> checkConnectivity() async {
//     try {
//       final results = await _connectivity.checkConnectivity();
//       _updateConnectionStatus(results);
//       return _isConnected;
//     } catch (e) {
//       return _isConnected;
//     }
//   }
//
//   @override
//   void dispose() {
//     _subscription?.cancel();
//     _pollTimer?.cancel();
//     super.dispose();
//   }
// }

// ========================================
// OBJECTBOX SERVICE
// ========================================
class ObjectBoxService {
  late final Store _store;
  late final Box<UserEntity> _userBox;
  late final Box<PhotoEntity> _photoBox;
  late final Box<GroupEntity> _groupBox;
  late final Box<NotificationEntity> _notificationBox;

  static ObjectBoxService? _instance;

  ObjectBoxService._();

  static Future<ObjectBoxService> create() async {
    if (_instance != null) return _instance!;

    final instance = ObjectBoxService._();
    await instance._init();
    _instance = instance;
    return instance;
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final storePath = path.join(dir.path, 'objectboxDBProfilum');

    // CORRECTION: Utilisation de openStore depuis objectbox.g.dart
    _store = await openStore(directory: storePath);

    _userBox = Box<UserEntity>(_store);
    _photoBox = Box<PhotoEntity>(_store);
    _groupBox = Box<GroupEntity>(_store);
    _notificationBox = Box<NotificationEntity>(_store);
  }

  // User operations
  Future<void> saveUser(UserEntity user) async {
    _userBox.put(user);
  }

  Future<UserEntity?> getUser(String userId) async {
    final query = _userBox.query(UserEntity_.userId.equals(userId)).build();
    final user = query.findFirst();
    query.close();
    return user;
  }

  Future<UserEntity?> getUserByEmail(String email) async {
    final query = _userBox.query(UserEntity_.email.equals(email)).build();
    final user = query.findFirst();
    query.close();
    return user;
  }

  Future<void> deleteUser(String userId) async {
    final user = await getUser(userId);
    if (user != null) {
      _userBox.remove(user.id);
    }
  }

  // Photo operations
  Future<void> savePhoto(PhotoEntity photo) async {
    _photoBox.put(photo);
  }

  Future<List<PhotoEntity>> getPendingPhotos() async {
    final query = _photoBox
        .query(PhotoEntity_.status.equals('pending'))
        .build();
    final photos = query.find();
    query.close();
    return photos;
  }

  Future<List<PhotoEntity>> getUserPhotos(String userId) async {
    final query = _photoBox.query(PhotoEntity_.userId.equals(userId)).build();
    final photos = query.find();
    query.close();
    return photos;
  }

  // Group operations
  Future<void> saveGroup(GroupEntity group) async {
    _groupBox.put(group);
  }

  Future<List<GroupEntity>> getAllGroups() async {
    return _groupBox.getAll();
  }

  // Notification operations
  Future<void> saveNotification(NotificationEntity notification) async {
    _notificationBox.put(notification);
  }

  Future<List<NotificationEntity>> getUnreadNotifications(String userId) async {
    final query = _notificationBox
        .query(
          NotificationEntity_.userId.equals(userId) &
              NotificationEntity_.isRead.equals(false),
        )
        .build();
    final notifications = query.find();
    query.close();
    return notifications;
  }

  Future<void> markNotificationAsRead(int id) async {
    final notification = _notificationBox.get(id);
    if (notification != null) {
      notification.isRead = true;
      _notificationBox.put(notification);
    }
  }

  void close() {
    _store.close();
  }
}

// ========================================
// SUPABASE SERVICE
// ========================================
class SupabaseService {
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
