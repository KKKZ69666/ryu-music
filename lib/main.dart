import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/controllers/audio_controller.dart';
import 'core/controllers/library_controller.dart';
import 'core/ryu_scope.dart';
import 'core/services/storage_service.dart';
import 'core/theme/ryu_theme.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await StorageService.instance.init();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryu.music.channel.audio',
    androidNotificationChannelName: 'RYU Audio Playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  final libraryController = LibraryController();
  final audioController = AudioController(library: libraryController);

  await audioController.initialize();
  await libraryController.initialize();

  runApp(
    RyuApp(
      libraryController: libraryController,
      audioController: audioController,
    ),
  );
}

class RyuApp extends StatefulWidget {
  const RyuApp({
    super.key,
    required this.libraryController,
    required this.audioController,
  });

  final LibraryController libraryController;
  final AudioController audioController;

  @override
  State<RyuApp> createState() => _RyuAppState();
}

class _RyuAppState extends State<RyuApp> {
  @override
  void dispose() {
    widget.audioController.dispose();
    widget.libraryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RyuScope(
      library: widget.libraryController,
      audio: widget.audioController,
      child: MaterialApp(
        title: 'RYU',
        debugShowCheckedModeBanner: false,
        theme: RyuTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
