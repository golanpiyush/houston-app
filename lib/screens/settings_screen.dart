import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/providers/lyrics_provider.dart';
import 'package:houston/utils/update_checker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _validateAndFixFontSetting();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  // Add this method to fix the font issue
  void _validateAndFixFontSetting() {
    final currentFont = ref.read(settingsProvider).lyricsFont;

    // If current font is "Source Sans Pro", replace it with "Barlow"
    if (currentFont == 'Source Sans Pro') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(settingsProvider.notifier).updateLyricsFont('Barlow');
      });
    }
  }

  // Enhanced version with error handling
  TextStyle _getGoogleFont(String fontName) {
    try {
      switch (fontName) {
        case 'Poppins':
          return GoogleFonts.poppins();
        case 'Roboto':
          return GoogleFonts.roboto();
        case 'Open Sans':
          return GoogleFonts.openSans();
        case 'Barlow':
          return GoogleFonts.barlow();
        case 'Montserrat':
          return GoogleFonts.montserrat();
        case 'Lato':
          return GoogleFonts.lato();
        case 'Nunito':
          return GoogleFonts.nunito();
        case 'Inter':
          return GoogleFonts.inter();
        case 'Raleway':
          return GoogleFonts.raleway();
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay();
        case 'Luckiest Guy':
          return GoogleFonts.luckiestGuy();
        case 'Oswald':
          return GoogleFonts.oswald();
        case 'Merriweather':
          return GoogleFonts.merriweather();
        case 'Ubuntu':
          return GoogleFonts.ubuntu();
        case 'Fira Sans':
          return GoogleFonts.firaSans();
        case 'Crimson Text':
          return GoogleFonts.crimsonText();
        case 'Libre Baskerville':
          return GoogleFonts.libreBaskerville();
        case 'PT Sans':
          return GoogleFonts.ptSans();
        case 'Quicksand':
          return GoogleFonts.quicksand();
        case 'Caveat':
          return GoogleFonts.caveat();
        case 'Dancing Script':
          return GoogleFonts.dancingScript();
        case 'Comfortaa':
          return GoogleFonts.comfortaa();
        case 'Pacifico':
          return GoogleFonts.pacifico();
        case 'Satisfy':
          return GoogleFonts.satisfy();
        case 'Great Vibes':
          return GoogleFonts.greatVibes();
        // Handle the problematic font by defaulting to Barlow
        case 'Source Sans Pro':
          print('Source Sans Pro not available, using Barlow instead');
          return GoogleFonts.barlow();
        default:
          print('Font not found: $fontName, falling back to Poppins');
          return GoogleFonts.poppins();
      }
    } catch (e) {
      print('Error loading font $fontName: $e, falling back to Poppins');
      return GoogleFonts.poppins();
    }
  }

  // Future<void> _checkForUpdate(BuildContext context) async {
  //   // Show loading indicator
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => const Center(child: CircularProgressIndicator()),
  //   );

  //   // Simulate checking for updates (replace with actual update logic)
  //   await Future.delayed(const Duration(seconds: 2));

  //   // Close loading dialog
  //   if (mounted) {
  //     Navigator.of(context).pop();
  //   }

  //   // Show update result
  //   if (mounted) {
  //     showDialog(
  //       context: context,
  //       builder: (context) => AlertDialog(
  //         title: const Text('Update Check'),
  //         content: const Text('You are using the latest version!'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('OK'),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
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

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Download when saving'),
                    subtitle: const Text(
                      'Automatically download songs when you save them',
                    ),
                    value: settings.downloadMode,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).toggleDownloadMode();
                      Fluttertoast.showToast(
                        msg: value
                            ? "Downloads will be saved automatically"
                            : "Only metadata will be saved",
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Enhanced UI Card with font selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lyrics Display',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // --- Lyrics Provider Dropdown ---
                  DropdownButtonFormField<LyricsSource>(
                    value: settings.lyricsProvider,
                    decoration: InputDecoration(
                      labelText: 'Lyrics Provider',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: LyricsSource.values.map((source) {
                      return DropdownMenuItem<LyricsSource>(
                        value: source,
                        child: Text(
                          source == LyricsSource.kugou
                              ? 'KuGou'
                              : 'SomeRandomAPI',
                        ),
                      );
                    }).toList(),
                    onChanged: (LyricsSource? newProvider) {
                      if (newProvider != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .updateLyricsProvider(newProvider);
                        Fluttertoast.showToast(
                          msg: "Lyrics provider set to ${newProvider.name}",
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // --- Word-by-word toggle (disabled for SomeRandomAPI) ---
                  Opacity(
                    opacity:
                        settings.lyricsProvider == LyricsSource.someRandomApi
                        ? 0.5
                        : 1.0,
                    child: IgnorePointer(
                      ignoring:
                          settings.lyricsProvider == LyricsSource.someRandomApi,
                      child: SwitchListTile(
                        title: const Text('Word-by-word lyrics'),
                        subtitle: const Text(
                          'Show lyrics word by word with highlighting. Disable for line-by-line display.',
                        ),
                        value: settings.wordByWordLyrics,
                        onChanged: (value) {
                          ref
                              .read(settingsProvider.notifier)
                              .toggleWordByWordLyrics();
                          Fluttertoast.showToast(
                            msg: value
                                ? "Word-by-word lyrics enabled"
                                : "Line-by-line lyrics enabled",
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Lyrics Font',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _getSafeCurrentFont(settings.lyricsFont),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: SettingsNotifier.availableFonts.map((String font) {
                        return DropdownMenuItem<String>(
                          value: font,
                          child: Text(
                            font,
                            style: _getGoogleFont(font).copyWith(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newFont) {
                        if (newFont != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .updateLyricsFont(newFont);
                          Fluttertoast.showToast(
                            msg: "Lyrics font changed to $newFont",
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Font Preview ---
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preview:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your lyrics will look like this',
                            style:
                                _getGoogleFont(
                                  _getSafeCurrentFont(settings.lyricsFont),
                                ).copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
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

          const SizedBox(height: 16),

          // Version Info Card
          Card(
            child: InkWell(
              onTap: () => checkForUpdate(context, ref),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Version Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.system_update,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_packageInfo != null) ...[
                      _buildVersionRow(
                        'Build Number',
                        _packageInfo!.buildNumber,
                      ),
                      _buildVersionRow('Version', _packageInfo!.version),
                    ] else ...[
                      const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Tap to check for updates',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to ensure we always have a valid font
  String _getSafeCurrentFont(String currentFont) {
    if (SettingsNotifier.availableFonts.contains(currentFont)) {
      return currentFont;
    }
    // Default to Barlow if current font is not in the list
    return 'Barlow';
  }

  Widget _buildVersionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
