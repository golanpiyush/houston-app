import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/screens/playlistscreenview.dart';
import 'package:houston/widgets/animated_nav_item.dart';
import 'home_screen.dart';
import 'saved_screen.dart';
import 'playlist_screen.dart'; // This is now the main playlists list screen
import 'player_screen.dart';
import 'settings_screen.dart';
import '../providers/audio/audio_state_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<IconData> _filledIcons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.bookmark_fill,
    CupertinoIcons.list_dash,
    CupertinoIcons.settings,
  ];

  final List<IconData> _outlinedIcons = [
    CupertinoIcons.house,
    CupertinoIcons.bookmark,
    CupertinoIcons.list_bullet,
    CupertinoIcons.gear,
  ];

  final List<String> _labels = ['Home', 'Saved', 'Playlists', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          SavedScreen(),
          PlaylistScreen(), // Now using the correct PlaylistScreen (list of playlists)
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
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_labels.length, (index) {
                return AnimatedNavItem(
                  isSelected: _currentIndex == index,
                  icon: Icon(
                    _currentIndex == index
                        ? _filledIcons[index]
                        : _outlinedIcons[index],
                  ),
                  label: _labels[index],
                  onTap: () => setState(() => _currentIndex = index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
