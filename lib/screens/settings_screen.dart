import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  void _showToast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildThemeOption(
                    context,
                    ref,
                    'Light',
                    'light',
                    settings.themeMode,
                    Icons.light_mode,
                  ),
                  _buildThemeOption(
                    context,
                    ref,
                    'Dark',
                    'dark',
                    settings.themeMode,
                    Icons.dark_mode,
                  ),
                  _buildThemeOption(
                    context,
                    ref,
                    'Material You',
                    'material',
                    settings.themeMode,
                    Icons.palette,
                  ),
                  _buildThemeOption(
                    context,
                    ref,
                    'AMOLED',
                    'amoled',
                    settings.themeMode,
                    Icons.contrast,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Audio Quality
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audio Quality',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildAudioOption(
                    context,
                    ref,
                    'Low',
                    'LOW',
                    settings.audioQuality,
                  ),
                  _buildAudioOption(
                    context,
                    ref,
                    'Medium',
                    'MED',
                    settings.audioQuality,
                  ),
                  _buildAudioOption(
                    context,
                    ref,
                    'High',
                    'HIGH',
                    settings.audioQuality,
                  ),
                  _buildAudioOption(
                    context,
                    ref,
                    'Very High',
                    'VERY_HIGH',
                    settings.audioQuality,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Thumbnail Quality
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thumbnail Quality',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildThumbnailOption(
                    context,
                    ref,
                    'Low',
                    'LOW',
                    settings.thumbnailQuality,
                  ),
                  _buildThumbnailOption(
                    context,
                    ref,
                    'Medium',
                    'MED',
                    settings.thumbnailQuality,
                  ),
                  _buildThumbnailOption(
                    context,
                    ref,
                    'High',
                    'HIGH',
                    settings.thumbnailQuality,
                  ),
                  _buildThumbnailOption(
                    context,
                    ref,
                    'Very High',
                    'VERY_HIGH',
                    settings.thumbnailQuality,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Search Limit
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Limit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: settings.limit.toDouble(),
                          min: 2,
                          max: 12,
                          divisions: 10,
                          label: settings.limit.toString(),
                          onChanged: (value) {
                            ref
                                .read(settingsProvider.notifier)
                                .updateLimit(value.toInt());
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        settings.limit.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Number of songs to fetch in search results',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    String value,
    String currentValue,
    IconData icon,
  ) {
    final isSelected = currentValue == value;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.radio_button_unchecked),
      onTap: () {
        ref.read(settingsProvider.notifier).updateTheme(value);
      },
    );
  }

  Widget _buildAudioOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    String value,
    String currentValue,
  ) {
    final isSelected = currentValue == value;
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.radio_button_unchecked),
      onTap: () {
        ref.read(settingsProvider.notifier).updateAudioQuality(value);
        Fluttertoast.showToast(msg: "Audio Quality set to $title");
      },
    );
  }

  Widget _buildThumbnailOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    String value,
    String currentValue,
  ) {
    final isSelected = currentValue == value;
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.radio_button_unchecked),
      onTap: () {
        ref.read(settingsProvider.notifier).updateThumbnailQuality(value);
        Fluttertoast.showToast(msg: "Thumbnail Quality set to $title");
      },
    );
  }
}
