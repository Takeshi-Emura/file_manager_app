import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler {
  static MyAudioHandler? _instance;
  static MyAudioHandler get instance => _instance ??= MyAudioHandler._();
  
  MyAudioHandler._();

  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  
  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  Future<void> initializeAudioSource(List<String> filePaths, int initialIndex) async {
    try {
      final mediaSources = <AudioSource>[];
      final mediaItems = <MediaItem>[];

      for (int i = 0; i < filePaths.length; i++) {
        final filePath = filePaths[i];
        final fileName = filePath.split(Platform.pathSeparator).last;
        final fileNameWithoutExtension = fileName.contains('.') 
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;

        final mediaItem = MediaItem(
          id: filePath,
          title: fileNameWithoutExtension,
          artist: 'Unknown Artist',
          album: 'Unknown Album',
          duration: null, // Will be set when audio loads
        );

        mediaItems.add(mediaItem);
        mediaSources.add(AudioSource.file(filePath));
      }

      _playlist.clear();
      await _playlist.addAll(mediaSources);
      
      // Set up the playlist
      await _player.setAudioSource(_playlist, initialIndex: initialIndex);
      
      // Update queue
      queue.add(mediaItems);
      
      // Set initial media item
      if (mediaItems.isNotEmpty) {
        mediaItem.add(mediaItems[initialIndex]);
      }

      // Listen to player state changes
      _listenToChangesInPlayerState();
      _listenToChangesInDuration();
      _listenToChangesInBufferedPosition();
      _listenToChangesInTotalDuration();
      _listenToCurrentSongIndexChanges();
      
    } catch (e) {
      print('Error initializing audio source: $e');
    }
  }

  void _listenToChangesInPlayerState() {
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[playerState.processingState]!;

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ));
    });
  }

  void _listenToChangesInDuration() {
    _player.durationStream.listen((duration) {
      final oldMediaItem = mediaItem.value;
      if (oldMediaItem != null && duration != null) {
        final newMediaItem = oldMediaItem.copyWith(duration: duration);
        mediaItem.add(newMediaItem);
      }
    });
  }

  void _listenToChangesInBufferedPosition() {
    _player.bufferedPositionStream.listen((bufferedPosition) {
      playbackState.add(playbackState.value.copyWith(
        bufferedPosition: bufferedPosition,
      ));
    });
  }

  void _listenToChangesInTotalDuration() {
    _player.durationStream.listen((totalDuration) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: _player.position,
      ));
    });
  }

  void _listenToCurrentSongIndexChanges() {
    _player.currentIndexStream.listen((index) {
      final currentQueue = queue.value;
      if (index != null && currentQueue.isNotEmpty && index < currentQueue.length) {
        mediaItem.add(currentQueue[index]);
        playbackState.add(playbackState.value.copyWith(queueIndex: index));
      }
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  // Getters to access player properties
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _player.playing;
  int? get currentIndex => _player.currentIndex;
}