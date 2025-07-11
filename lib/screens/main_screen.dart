// screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'playlist_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import '../providers/audio_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<IconData> _icons = [
    Icons.home,
    Icons.favorite,
    Icons.playlist_play,
    Icons.settings,
  ];

  final List<String> _labels = ['Home', 'Saved', 'Playlist', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          SavedScreen(),
          PlaylistScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: audioState.currentSong != null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlayerScreen()),
                );
              },
              child: const Icon(Icons.music_note),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: _icons,
        activeIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        gapLocation: audioState.currentSong != null
            ? GapLocation.center
            : GapLocation.none,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 16,
        rightCornerRadius: 16,
        backgroundColor: Theme.of(context).colorScheme.surface,
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}
