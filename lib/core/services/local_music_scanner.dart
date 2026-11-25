import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';

enum AudioPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

class LocalMusicScanner {
  LocalMusicScanner._();
  static final LocalMusicScanner instance = LocalMusicScanner._();

  static const MethodChannel _channel = MethodChannel('com.ryu.music/media_store');

  Future<int> _sdkInt() async {
    try {
      return await _channel.invokeMethod<int>('getSdkInt') ?? 33;
    } catch (_) {
      return 33;
    }
  }

  AudioPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AudioPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return AudioPermissionStatus.permanentlyDenied;
    }
    return AudioPermissionStatus.denied;
  }

  Future<AudioPermissionStatus> checkAndRequestPermission({
    bool requestIfNeeded = true,
  }) async {
    if (!Platform.isAndroid) return AudioPermissionStatus.granted;

    // Android 13+ uses READ_MEDIA_AUDIO; Android 12 and below use
    // READ_EXTERNAL_STORAGE. Checking the wrong one would report
    // "permanently denied" even when the user only denied once.
    final sdk = await _sdkInt();
    final Permission permission =
        sdk >= 33 ? Permission.audio : Permission.storage;

    PermissionStatus status = await permission.status;
    if (!status.isGranted && requestIfNeeded) {
      status = await permission.request();
    }

    final result = _map(status);
    if (result == AudioPermissionStatus.granted && sdk >= 33) {
      await _requestNotificationPermissionIfNeeded();
    }
    return result;
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Ignore on Android < 13 where notification permission isn't runtime
    }
  }

  Future<List<Song>> scanSongs() async {
    final rawList = await _channel.invokeMethod<List<dynamic>>('scanAudio');
    if (rawList == null) return const [];
    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map(Song.fromMap)
        .where((s) => s.uri.isNotEmpty)
        .toList();
  }
}
