import 'dart:async';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/lyric_line.dart';
import '../models/song.dart';
import '../services/artwork_service.dart';
import '../services/lyrics_service.dart';
import '../services/palette_service.dart';
import '../services/storage_service.dart';
import 'library_controller.dart';

enum RyuRepeatMode {
  off,
  all,
  one,
}

class AudioController extends ChangeNotifier {
  AudioController({required LibraryController library}) : _library = library;

  final LibraryController _library;
  final AudioPlayer _player = AudioPlayer();
  final StorageService _storage = StorageService.instance;
  final Random _random = Random();

  ConcatenatingAudioSource? _playlistSource;
  List<Song> _originalQueue = [];
  List<Song> _queue = [];
  int _currentIndex = -1;
  String _queueContextLabel = 'Library';

  bool _isPlaying = false;
  bool _shuffleEnabled = false;
  RyuRepeatMode _repeatMode = RyuRepeatMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _playbackError;

  bool _isSettingSource = false;
  bool _handlingCompletion = false;
  bool _resumeAfterInterruption = false;
  bool _disposed = false;

  AmbientPalette _ambientPalette = AmbientPalette.fallback;
  LyricsDocument? _currentLyrics;
  bool _isLoadingLyrics = false;
  int? _lastRecordedSongId;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  AudioPlayer get player => _player;
  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;
  String get queueContextLabel => _queueContextLabel;
  bool get isPlaying => _isPlaying;
  bool get shuffleEnabled => _shuffleEnabled;
  RyuRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get playbackError => _playbackError;
  AmbientPalette get ambientPalette => _ambientPalette;
  LyricsDocument? get currentLyrics => _currentLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;

  Stream<Duration> get positionStream => _player.positionStream;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    _shuffleEnabled = _storage.loadShuffle();
    final repeatIdx = _storage.loadRepeatModeIndex().clamp(0, 2);
    _repeatMode = RyuRepeatMode.values[repeatIdx];
    await _applyLoopMode();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(0.35);
        } else {
          _resumeAfterInterruption = _player.playing;
          _player.pause();
        }
      } else {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(1.0);
        } else if (event.type == AudioInterruptionType.unknown &&
            _resumeAfterInterruption) {
          _resumeAfterInterruption = false;
          _player.play();
        } else {
          _resumeAfterInterruption = false;
        }
      }
    });

    _noisySub = session.becomingNoisyEventStream.listen((_) {
      _resumeAfterInterruption = false;
      _player.pause();
    });

    _playerStateSub = _player.playerStateStream.listen((state) {
      final playing = state.playing &&
          state.processingState != ProcessingState.completed;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        _notify();
      }
      if (state.processingState == ProcessingState.completed &&
          _repeatMode == RyuRepeatMode.off &&
          !_handlingCompletion) {
        _handleQueueCompleted();
      }
    });

    _indexSub = _player.currentIndexStream.listen((index) {
      if (_isSettingSource) return;
      if (index != null && index >= 0 && index < _queue.length) {
        final changed = _currentIndex != index;
        _currentIndex = index;
        final song = _queue[index];
        if (changed) {
          _duration = song.duration;
          _position = Duration.zero;
        }
        _notify();

        if (changed) {
          unawaited(_onSongChanged(song));
        }
      }
    });

    // Position is deliberately tracked without notifyListeners(): it ticks
    // ~5x/second and would rebuild every song tile. Widgets that need live
    // progress (mini player, now playing, lyrics) subscribe to positionStream.
    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
        _notify();
      }
    });
  }

  Future<void> _handleQueueCompleted() async {
    _handlingCompletion = true;
    try {
      await _player.pause();
      if (_queue.length > 1) {
        _currentIndex = 0;
        _duration = _queue.first.duration;
        _position = Duration.zero;
        _notify();
        await _player.seek(Duration.zero, index: 0);
        unawaited(_onSongChanged(_queue.first));
      } else {
        _position = Duration.zero;
        _notify();
        await _player.seek(Duration.zero);
      }
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> _onSongChanged(Song song) async {
    if (_disposed) return;

    if (_lastRecordedSongId != song.id) {
      _lastRecordedSongId = song.id;
      unawaited(_library.recordSongPlay(song));
    }

    unawaited(ArtworkService.instance.getArtworkFileUri(song.id, song.albumId));
    if (_currentIndex + 1 < _queue.length) {
      final nextSong = _queue[_currentIndex + 1];
      unawaited(
        ArtworkService.instance.getArtworkFileUri(
          nextSong.id,
          nextSong.albumId,
        ),
      );
    }

    unawaited(
      PaletteService.instance
          .getPaletteForSong(song.id, song.albumId)
          .then((palette) {
        if (!_disposed && currentSong?.id == song.id) {
          _ambientPalette = palette;
          _notify();
        }
      }),
    );

    await refreshLyricsForCurrentSong();
  }

  Future<void> refreshLyricsForCurrentSong() async {
    if (_disposed) return;
    final song = currentSong;
    if (song == null) {
      _currentLyrics = null;
      _isLoadingLyrics = false;
      _notify();
      return;
    }

    _isLoadingLyrics = true;
    _notify();

    try {
      final doc = await LyricsService.instance.loadLyricsForSong(song);
      if (!_disposed && currentSong?.id == song.id) {
        _currentLyrics = doc;
      }
    } finally {
      if (!_disposed && currentSong?.id == song.id) {
        _isLoadingLyrics = false;
        _notify();
      }
    }
  }

  void setLoadedLyrics(LyricsDocument? doc) {
    _currentLyrics = doc;
    _notify();
  }

  Future<void> playSongs(
    List<Song> songs, {
    int initialIndex = 0,
    String contextLabel = 'Library',
    bool forceShuffle = false,
  }) async {
    if (songs.isEmpty) return;
    _playbackError = null;
    _queueContextLabel = contextLabel;
    _lastRecordedSongId = null;

    final safeIndex = initialIndex.clamp(0, songs.length - 1);
    _originalQueue = List<Song>.from(songs);

    if (forceShuffle && !_shuffleEnabled) {
      _shuffleEnabled = true;
      unawaited(_storage.saveShuffle(true));
    }

    int startIndex = safeIndex;
    if (_shuffleEnabled && songs.length > 1) {
      final selected = songs[safeIndex];
      final rest = List<Song>.from(songs)..removeAt(safeIndex);
      rest.shuffle(_random);
      _queue = [selected, ...rest];
      startIndex = 0;
    } else {
      _queue = List<Song>.from(songs);
    }

    final startingSong = _queue[startIndex];
    Uri? startingArtUri;
    try {
      startingArtUri = await ArtworkService.instance.getArtworkFileUri(
        startingSong.id,
        startingSong.albumId,
      );
    } catch (_) {}

    final children = <AudioSource>[];
    for (int i = 0; i < _queue.length; i++) {
      final s = _queue[i];
      final artUri = i == startIndex
          ? startingArtUri
          : ArtworkService.instance.getExistingArtworkFileUriSync(
              s.id,
              s.albumId,
            );
      children.add(_buildAudioSource(s, artUri: artUri));
    }

    _playlistSource = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: children,
    );

    _currentIndex = startIndex;
    _duration = startingSong.duration;
    _position = Duration.zero;
    _notify();

    _isSettingSource = true;
    try {
      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
      _currentIndex = startIndex;
      await _applyLoopMode();
      await _player.play();
      unawaited(_onSongChanged(startingSong));
    } catch (e) {
      _isPlaying = false;
      _playbackError = 'Could not play "${startingSong.title}": $e';
      _notify();
    } finally {
      _isSettingSource = false;
    }
  }

  AudioSource _buildAudioSource(Song song, {Uri? artUri}) {
    return AudioSource.uri(
      Uri.parse(song.uri),
      tag: MediaItem(
        id: song.id.toString(),
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: artUri,
      ),
    );
  }

  Future<void> togglePlayPause() async {
    if (_queue.isEmpty) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : max(0, position.inMilliseconds);
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(0, maxMs),
    );
    _position = clamped;
    _notify();
    await _player.seek(clamped);
  }

  Future<void> seekToNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex + 1 < _queue.length) {
      final nextIndex = _currentIndex + 1;
      await _player.seek(Duration.zero, index: nextIndex);
      if (!_player.playing) await _player.play();
    } else if (_repeatMode == RyuRepeatMode.all) {
      await _player.seek(Duration.zero, index: 0);
      if (!_player.playing) await _player.play();
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> seekToPrevious() async {
    if (_queue.isEmpty) return;
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      final prevIndex = _currentIndex - 1;
      await _player.seek(Duration.zero, index: prevIndex);
      if (!_player.playing) await _player.play();
    } else if (_repeatMode == RyuRepeatMode.all && _queue.length > 1) {
      await _player.seek(Duration.zero, index: _queue.length - 1);
      if (!_player.playing) await _player.play();
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> skipToQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    unawaited(_storage.saveShuffle(_shuffleEnabled));

    final current = currentSong;
    final playlist = _playlistSource;
    if (current == null || playlist == null || _queue.length <= 1) {
      _notify();
      return;
    }

    if (_shuffleEnabled) {
      final rest = _originalQueue.where((s) => s.id != current.id).toList()
        ..shuffle(_random);

      if (_currentIndex + 1 < _queue.length) {
        await playlist.removeRange(_currentIndex + 1, _queue.length);
        _queue.removeRange(_currentIndex + 1, _queue.length);
      }
      if (_currentIndex > 0) {
        await playlist.removeRange(0, _currentIndex);
        _queue.removeRange(0, _currentIndex);
        _currentIndex = 0;
      }

      final newSources = rest
          .map(
            (s) => _buildAudioSource(
              s,
              artUri: ArtworkService.instance.getExistingArtworkFileUriSync(
                s.id,
                s.albumId,
              ),
            ),
          )
          .toList();
      _queue.addAll(rest);
      await playlist.addAll(newSources);
    } else {
      final origIdx = _originalQueue.indexWhere((s) => s.id == current.id);
      if (origIdx >= 0) {
        if (_currentIndex + 1 < _queue.length) {
          await playlist.removeRange(_currentIndex + 1, _queue.length);
          _queue.removeRange(_currentIndex + 1, _queue.length);
        }
        if (_currentIndex > 0) {
          await playlist.removeRange(0, _currentIndex);
          _queue.removeRange(0, _currentIndex);
          _currentIndex = 0;
        }

        final before = _originalQueue.sublist(0, origIdx);
        final after = _originalQueue.sublist(origIdx + 1);

        if (before.isNotEmpty) {
          final beforeSources = before
              .map(
                (s) => _buildAudioSource(
                  s,
                  artUri: ArtworkService.instance.getExistingArtworkFileUriSync(
                    s.id,
                    s.albumId,
                  ),
                ),
              )
              .toList();
          _queue.insertAll(0, before);
          await playlist.insertAll(0, beforeSources);
          _currentIndex = before.length;
        }

        if (after.isNotEmpty) {
          final afterSources = after
              .map(
                (s) => _buildAudioSource(
                  s,
                  artUri: ArtworkService.instance.getExistingArtworkFileUriSync(
                    s.id,
                    s.albumId,
                  ),
                ),
              )
              .toList();
          _queue.addAll(after);
          await playlist.addAll(afterSources);
        }
      }
    }

    _notify();
  }

  Future<void> cycleRepeatMode() async {
    final nextIdx = (_repeatMode.index + 1) % RyuRepeatMode.values.length;
    _repeatMode = RyuRepeatMode.values[nextIdx];
    unawaited(_storage.saveRepeatModeIndex(nextIdx));
    await _applyLoopMode();
    _notify();
  }

  Future<void> _applyLoopMode() async {
    switch (_repeatMode) {
      case RyuRepeatMode.off:
        await _player.setLoopMode(LoopMode.off);
      case RyuRepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
      case RyuRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
    }
  }

  Future<void> playNextInQueue(Song song) async {
    if (_queue.isEmpty || _playlistSource == null) {
      await playSongs([song], contextLabel: 'Queue');
      return;
    }
    final current = currentSong;
    final insertIdx = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(insertIdx, song);

    if (!_originalQueue.any((s) => s.id == song.id)) {
      final origCurrentIdx = current != null
          ? _originalQueue.indexWhere((s) => s.id == current.id)
          : -1;
      if (origCurrentIdx >= 0) {
        _originalQueue.insert(origCurrentIdx + 1, song);
      } else {
        _originalQueue.add(song);
      }
    }

    Uri? artUri;
    try {
      artUri = await ArtworkService.instance.getArtworkFileUri(
        song.id,
        song.albumId,
      );
    } catch (_) {}
    await _playlistSource!.insert(
      insertIdx,
      _buildAudioSource(song, artUri: artUri),
    );
    _notify();
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty || _playlistSource == null) {
      await playSongs([song], contextLabel: 'Queue');
      return;
    }
    _queue.add(song);
    if (!_originalQueue.any((s) => s.id == song.id)) {
      _originalQueue.add(song);
    }
    Uri? artUri;
    try {
      artUri = await ArtworkService.instance.getArtworkFileUri(
        song.id,
        song.albumId,
      );
    } catch (_) {}
    await _playlistSource!.add(_buildAudioSource(song, artUri: artUri));
    _notify();
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (_playlistSource == null) return;
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= _queue.length || oldIndex == newIndex) {
      return;
    }

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    if (!_shuffleEnabled && _originalQueue.length == _queue.length) {
      _originalQueue = List<Song>.from(_queue);
    }

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    await _playlistSource!.move(oldIndex, newIndex);
    _notify();
  }

  Future<void> removeFromQueue(int index) async {
    if (_playlistSource == null || index < 0 || index >= _queue.length) return;
    if (_queue.length == 1) {
      await clearQueue();
      return;
    }

    final wasCurrent = index == _currentIndex;
    final removed = _queue.removeAt(index);
    _originalQueue.remove(removed);

    if (index < _currentIndex) {
      _currentIndex -= 1;
    } else if (wasCurrent) {
      _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
    }

    await _playlistSource!.removeAt(index);

    if (wasCurrent && _currentIndex >= 0 && _currentIndex < _queue.length) {
      final nextCurrent = _queue[_currentIndex];
      _duration = nextCurrent.duration;
      _position = Duration.zero;
      _notify();
      unawaited(_onSongChanged(nextCurrent));
    } else {
      _notify();
    }
  }

  Future<void> clearQueue() async {
    await _player.stop();
    _queue.clear();
    _originalQueue.clear();
    _playlistSource = null;
    _currentIndex = -1;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _currentLyrics = null;
    _ambientPalette = AmbientPalette.fallback;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _playerStateSub?.cancel();
    _indexSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _interruptionSub?.cancel();
    _noisySub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
