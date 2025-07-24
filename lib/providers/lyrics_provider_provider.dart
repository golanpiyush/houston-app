// providers/lyrics_provider_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/lyrics_provider.dart' as lyrics_provider;
import 'package:houston/providers/settings_provider.dart';

final lyricsProviderProvider = Provider<lyrics_provider.LyricsProvider>((ref) {
  final settings = ref.watch(settingsProvider);
  final provider = lyrics_provider.LyricsProvider();
  provider.selectedSource = settings.lyricsProvider;

  // Dispose the provider when it's no longer needed
  ref.onDispose(() {
    provider.dispose();
  });

  return provider;
});
