import 'package:flutter/material.dart';
import 'controllers/audio_controller.dart';
import 'controllers/library_controller.dart';

class RyuScope extends InheritedWidget {
  const RyuScope({
    super.key,
    required this.library,
    required this.audio,
    required super.child,
  });

  final LibraryController library;
  final AudioController audio;

  static RyuScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RyuScope>();
    assert(scope != null, 'No RyuScope found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(RyuScope oldWidget) =>
      library != oldWidget.library || audio != oldWidget.audio;
}
