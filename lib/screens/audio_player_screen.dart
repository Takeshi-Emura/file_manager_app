import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../providers/audio_player_provider.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String audioPath;

  const AudioPlayerScreen({
    super.key,
    required this.audioPath,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = ref.read(audioPlayerProvider);
      // Only load audio if it's not already loaded or if it's a different file
      if (currentState.currentFile != widget.audioPath) {
        ref.read(audioPlayerProvider.notifier).loadAudio(widget.audioPath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final currentFilePath = state.currentFile ?? widget.audioPath;
    final fileName = currentFilePath.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAudioInfo(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Audio file icon
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.music_note,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // File name
            Text(
              fileName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 32),
            
            // Progress bar
            if (state.duration != Duration.zero)
              ProgressBar(
                progress: state.position,
                total: state.duration,
                onSeek: (duration) {
                  ref.read(audioPlayerProvider.notifier).seek(duration);
                },
                progressBarColor: Theme.of(context).colorScheme.primary,
                thumbColor: Theme.of(context).colorScheme.primary,
                barHeight: 4,
                thumbRadius: 8,
              ),
            
            const SizedBox(height: 32),
            
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous track button
                IconButton(
                  onPressed: state.hasPrevious
                      ? () => ref.read(audioPlayerProvider.notifier).playPrevious()
                      : null,
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                  style: IconButton.styleFrom(
                    foregroundColor: state.hasPrevious 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Play/Pause button
                if (state.isLoading)
                  const CircularProgressIndicator()
                else
                  IconButton(
                    onPressed: state.isPlaying
                        ? () => ref.read(audioPlayerProvider.notifier).pause()
                        : () => ref.read(audioPlayerProvider.notifier).play(),
                    icon: Icon(
                      state.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    iconSize: 64,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                
                const SizedBox(width: 16),
                
                // Next track button
                IconButton(
                  onPressed: state.hasNext
                      ? () => ref.read(audioPlayerProvider.notifier).playNext()
                      : null,
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  style: IconButton.styleFrom(
                    foregroundColor: state.hasNext 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Playlist info
            if (state.playlist.isNotEmpty)
              Text(
                '${state.currentIndex + 1} / ${state.playlist.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Duration display
            if (state.duration != Duration.zero)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(state.position)),
                  Text(_formatDuration(state.duration)),
                ],
              ),
            
            // Error message
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  state.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAudioInfo(BuildContext context) {
    final state = ref.read(audioPlayerProvider);
    final currentFilePath = state.currentFile ?? widget.audioPath;
    final file = File(currentFilePath);
    final stat = file.statSync();
    final fileName = currentFilePath.split(Platform.pathSeparator).last;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('オーディオ情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('ファイル名', fileName),
            _buildInfoRow('パス', currentFilePath),
            _buildInfoRow('サイズ', _formatFileSize(stat.size)),
            _buildInfoRow('更新日時', _formatDate(stat.modified)),
            if (state.playlist.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow('プレイリスト', '${state.currentIndex + 1} / ${state.playlist.length}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}