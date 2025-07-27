import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import '../services/audio_handler.dart';

final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  return AudioPlayerNotifier();
});

class AudioPlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isLoading;
  final String? currentFile;
  final String? error;
  final List<String> playlist;
  final int currentIndex;

  AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isLoading = false,
    this.currentFile,
    this.error,
    this.playlist = const [],
    this.currentIndex = 0,
  });

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isLoading,
    String? currentFile,
    String? error,
    List<String>? playlist,
    int? currentIndex,
  }) {
    return AudioPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isLoading: isLoading ?? this.isLoading,
      currentFile: currentFile ?? this.currentFile,
      error: error,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  bool get hasNext => currentIndex < playlist.length - 1;
  bool get hasPrevious => currentIndex > 0;
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  late final MyAudioHandler _audioHandler;
  bool _isAudioServiceAvailable = false;

  AudioPlayerNotifier() : super(AudioPlayerState()) {
    _initializeAudioHandler();
  }

  void _initializeAudioHandler() {
    try {
      _audioHandler = MyAudioHandler.instance;
      _isAudioServiceAvailable = true;
      
      _audioHandler.playerStateStream.listen((playerState) {
        state = state.copyWith(
          isPlaying: playerState.playing,
          isLoading: playerState.processingState == ProcessingState.loading ||
                     playerState.processingState == ProcessingState.buffering,
        );

        // Auto-play next track when current track completes
        if (playerState.processingState == ProcessingState.completed) {
          _playNextTrackIfAvailable();
        }
      });

      _audioHandler.positionStream.listen((position) {
        state = state.copyWith(position: position);
      });

      _audioHandler.durationStream.listen((duration) {
        if (duration != null) {
          state = state.copyWith(duration: duration);
        }
      });

      _audioHandler.currentIndexStream.listen((index) {
        if (index != null && state.playlist.isNotEmpty && index < state.playlist.length) {
          state = state.copyWith(
            currentIndex: index,
            currentFile: state.playlist[index],
          );
        }
      });
    } catch (e) {
      print('Audio Handler initialization failed: $e');
      _isAudioServiceAvailable = false;
      // Continue without audio service functionality
    }
  }

  Future<void> _playNextTrackIfAvailable() async {
    if (state.hasNext) {
      await playNext();
    }
  }

  Future<void> loadAudio(String filePath) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('ファイルが見つかりません');
      }

      // Generate playlist from the same folder
      await _generatePlaylist(filePath);

      // Initialize Audio Service with playlist if available
      if (_isAudioServiceAvailable) {
        try {
          await _audioHandler.initializeAudioSource(state.playlist, state.currentIndex);
        } catch (e) {
          print('Audio Service initialization failed: $e');
          // Continue without audio service
        }
      }
      
      state = state.copyWith(
        currentFile: filePath,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'オーディオファイルを読み込めませんでした: $e',
      );
    }
  }

  Future<void> _generatePlaylist(String currentFilePath) async {
    try {
      final currentFile = File(currentFilePath);
      final directory = currentFile.parent;
      
      const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg', 'wma'];
      
      final entities = await directory.list().toList();
      final audioFiles = entities
          .whereType<File>()
          .where((file) {
            final extension = file.path.split('.').last.toLowerCase();
            return audioExtensions.contains(extension);
          })
          .map((file) => file.path)
          .toList();
      
      // Sort files alphabetically
      audioFiles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      
      // Find current file index
      final currentIndex = audioFiles.indexOf(currentFilePath);
      
      state = state.copyWith(
        playlist: audioFiles,
        currentIndex: currentIndex >= 0 ? currentIndex : 0,
      );
    } catch (e) {
      // If playlist generation fails, create single-item playlist
      state = state.copyWith(
        playlist: [currentFilePath],
        currentIndex: 0,
      );
    }
  }

  Future<void> playNext() async {
    if (!_isAudioServiceAvailable) {
      state = state.copyWith(error: 'Audio Serviceが利用できません');
      return;
    }
    try {
      await _audioHandler.skipToNext();
    } catch (e) {
      state = state.copyWith(error: '次のトラックエラー: $e');
    }
  }

  Future<void> playPrevious() async {
    if (!_isAudioServiceAvailable) {
      state = state.copyWith(error: 'Audio Serviceが利用できません');
      return;
    }
    try {
      await _audioHandler.skipToPrevious();
    } catch (e) {
      state = state.copyWith(error: '前のトラックエラー: $e');
    }
  }

  Future<void> play() async {
    if (!_isAudioServiceAvailable) {
      state = state.copyWith(error: 'Audio Serviceが利用できません');
      return;
    }
    try {
      await _audioHandler.play();
    } catch (e) {
      state = state.copyWith(error: '再生エラー: $e');
    }
  }

  Future<void> pause() async {
    if (!_isAudioServiceAvailable) {
      state = state.copyWith(error: 'Audio Serviceが利用できません');
      return;
    }
    try {
      await _audioHandler.pause();
    } catch (e) {
      state = state.copyWith(error: '一時停止エラー: $e');
    }
  }

  Future<void> stop() async {
    try {
      if (_isAudioServiceAvailable) {
        await _audioHandler.stop();
      }
      // Reset state to close mini player regardless of audio service availability
      state = AudioPlayerState();
    } catch (e) {
      // Even if stop fails, reset the state to close mini player
      state = AudioPlayerState();
      print('停止エラー: $e');
    }
  }

  Future<void> seek(Duration position) async {
    if (!_isAudioServiceAvailable) {
      state = state.copyWith(error: 'Audio Serviceが利用できません');
      return;
    }
    try {
      await _audioHandler.seek(position);
    } catch (e) {
      state = state.copyWith(error: 'シークエラー: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}