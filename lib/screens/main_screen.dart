// screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/widgets/animated_nav_item.dart';
import 'package:icons_plus/icons_plus.dart';
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

  final List<Widget> _outlinedIcons = [
    const Icon(Bootstrap.house),
    const Icon(Bootstrap.save),
    const Icon(Bootstrap.bookmark),
    const Icon(Bootstrap.gear),
  ];

  final List<Widget> _filledIcons = [
    const Icon(Bootstrap.house_fill),
    const Icon(Bootstrap.save_fill),
    const Icon(Bootstrap.bookmark_fill),
    const Icon(Bootstrap.gear_fill),
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
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface, // Theme-based background
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_outlinedIcons.length, (index) {
                return AnimatedNavItem(
                  isSelected: _currentIndex == index,
                  icon: _currentIndex == index
                      ? _filledIcons[index]
                      : _outlinedIcons[index],
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
