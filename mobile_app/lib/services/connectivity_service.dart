import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum SyncMode {
  online,
  offline,
  syncing,
  syncError,
}

extension SyncModeExtension on SyncMode {
  String get label {
    switch (this) {
      case SyncMode.online:
        return 'Online';
      case SyncMode.offline:
        return 'Offline — Local Mode';
      case SyncMode.syncing:
        return 'Syncing...';
      case SyncMode.syncError:
        return 'Sync Failed';
    }
  }

  String get iconEmoji {
    switch (this) {
      case SyncMode.online:
        return '🟢';
      case SyncMode.offline:
        return '🔴';
      case SyncMode.syncing:
        return '🔄';
      case SyncMode.syncError:
        return '⚠';
    }
  }
}

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static final ValueNotifier<SyncMode> modeNotifier = ValueNotifier<SyncMode>(SyncMode.online);
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static Timer? _heartbeatTimer;

  static VoidCallback? onReconnected;
  static bool _lastKnownOnlineState = true;

  static SyncMode get currentMode => modeNotifier.value;
  static bool get isOnline => modeNotifier.value == SyncMode.online || modeNotifier.value == SyncMode.syncing;
  static bool get isOffline => modeNotifier.value == SyncMode.offline;

  /// Initialize connectivity listeners and active heartbeat check
  static Future<void> initialize() async {
    // Initial check
    await checkConnectivity();

    // Listen for OS network status changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      await checkConnectivity();
    });

    // Periodic heartbeat check every 30 seconds
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkConnectivity();
    });
  }

  /// Perform active check to distinguish true internet access from isolated networks
  static Future<bool> checkConnectivity() async {
    bool hasConnection = false;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        hasConnection = false;
      } else {
        // Active DNS lookup to confirm actual internet access
        final lookup = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        hasConnection = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
      }
    } catch (_) {
      hasConnection = false;
    }

    final wasOffline = !_lastKnownOnlineState;
    _lastKnownOnlineState = hasConnection;

    if (modeNotifier.value != SyncMode.syncing) {
      if (hasConnection) {
        modeNotifier.value = SyncMode.online;
      } else {
        modeNotifier.value = SyncMode.offline;
      }
    }

    // If transitioned from offline to online, fire callback
    if (wasOffline && hasConnection) {
      debugPrint('Connectivity restored! Triggering automatic sync.');
      onReconnected?.call();
    }

    return hasConnection;
  }

  /// Set the mode to syncing or syncError explicitly
  static void setSyncing(bool isSyncing) {
    if (isSyncing) {
      modeNotifier.value = SyncMode.syncing;
    } else {
      modeNotifier.value = _lastKnownOnlineState ? SyncMode.online : SyncMode.offline;
    }
  }

  static void setSyncError() {
    modeNotifier.value = SyncMode.syncError;
  }

  static void dispose() {
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
  }
}
