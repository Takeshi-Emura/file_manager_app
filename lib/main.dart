import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'screens/file_explorer_screen.dart';
import 'screens/favorites_screen.dart';
import 'services/audio_handler.dart';
import 'widgets/mini_player.dart';
import 'providers/audio_player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize audio service with error handling
  try {
    await AudioService.init(
      builder: () => MyAudioHandler.instance,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.file_manager.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    );
  } catch (e) {
    print('Audio Service initialization failed: $e');
    // Continue app startup even if audio service fails
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ファイルマネージャー',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    const FileExplorerScreen(),
    FavoritesScreen(onNavigateToFileExplorer: switchToFileExplorer),
  ];

  void switchToFileExplorer() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioPlayerProvider);
    final showMiniPlayer = audioState.currentFile != null && audioState.playlist.isNotEmpty;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini player
          if (showMiniPlayer) const MiniPlayer(),
          
          // Bottom navigation bar
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.folder),
                label: 'ファイル',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'お気に入り',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
