import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_player_provider.dart';
import '../screens/audio_player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    
    // Don't show mini player if no file is loaded or audio service is not available
    if (state.currentFile == null || state.playlist.isEmpty) {
      return const SizedBox.shrink();
    }

    final fileName = state.currentFile!.split(Platform.pathSeparator).last;
    final fileNameWithoutExtension = fileName.contains('.') 
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AudioPlayerScreen(audioPath: state.currentFile!),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Album art placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.music_note,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        fileNameWithoutExtension,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.currentIndex + 1} / ${state.playlist.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Progress indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Circular progress indicator
                      if (state.duration != Duration.zero)
                        CircularProgressIndicator(
                          value: state.position.inMilliseconds / state.duration.inMilliseconds,
                          strokeWidth: 2,
                          backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      
                      // Play/Pause button
                      IconButton(
                        onPressed: state.isLoading
                            ? null
                            : () {
                                if (state.isPlaying) {
                                  ref.read(audioPlayerProvider.notifier).pause();
                                } else {
                                  ref.read(audioPlayerProvider.notifier).play();
                                }
                              },
                        icon: state.isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                state.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 24,
                              ),
                        iconSize: 24,
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Next button
                IconButton(
                  onPressed: state.hasNext
                      ? () => ref.read(audioPlayerProvider.notifier).playNext()
                      : null,
                  icon: const Icon(Icons.skip_next),
                  iconSize: 24,
                  style: IconButton.styleFrom(
                    foregroundColor: state.hasNext 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                ),
                
                // Close button
                IconButton(
                  onPressed: () {
                    ref.read(audioPlayerProvider.notifier).stop();
                  },
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}