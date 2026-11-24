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

  Future<AudioPermissionStatus> checkAndRequestPermission({
    bool requestIfNeeded = true,
  }) async {
    if (!Platform.isAndroid) return AudioPermissionStatus.granted;

    // Request READ_MEDIA_AUDIO (Android 13+) and/or storage (Android <= 12)
    PermissionStatus audioStatus = await Permission.audio.status;
    PermissionStatus storageStatus = await Permission.storage.status;

    if (audioStatus.isGranted || storageStatus.isGranted) {
      await _requestNotificationPermissionIfNeeded();
      return AudioPermissionStatus.granted;
    }

    if (!requestIfNeeded) {
      if (audioStatus.isPermanentlyDenied && storageStatus.isPermanentlyDenied) {
        return AudioPermissionStatus.permanentlyDenied;
      }
      return AudioPermissionStatus.denied;
    }

    final statuses = await [
      Permission.audio,
      Permission.storage,
    ].request();

    audioStatus = statuses[Permission.audio] ?? PermissionStatus.denied;
    storageStatus = statuses[Permission.storage] ?? PermissionStatus.denied;

    if (audioStatus.isGranted || storageStatus.isGranted) {
      await _requestNotificationPermissionIfNeeded();
      return AudioPermissionStatus.granted;
    }

    if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      return AudioPermissionStatus.permanentlyDenied;
    }

    return AudioPermissionStatus.denied;
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
