import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/lyrics_provider.dart' as lyrics_provider;
import 'package:houston/providers/settings_provider.dart';

final lyricsProviderProvider = Provider<lyrics_provider.LyricsProvider>((ref) {
  final settings = ref.watch(
    settingsProvider,
  ); // Use watch to listen for changes

  // Debug print to verify the source
  print(
    'LYRICS_PROVIDER_PROVIDER: Creating NEW provider with source: ${settings.lyricsProvider}',
  );

  final provider = lyrics_provider.LyricsProvider();
  provider.selectedSource = settings.lyricsProvider;

  // Confirm assignment
  print(
    'LYRICS_PROVIDER_PROVIDER: Provider selectedSource set to: ${provider.selectedSource}',
  );

  // Dispose the provider when it's no longer needed or when settings change
  ref.onDispose(() {
    print('LYRICS_PROVIDER_PROVIDER: Disposing old provider');
    provider.dispose();
  });

  return provider;
});

// Alternative: Force invalidation when settings change
final lyricsProviderStateProvider =
    StateNotifierProvider<
      LyricsProviderNotifier,
      lyrics_provider.LyricsProvider
    >((ref) {
      final settings = ref.watch(settingsProvider);

      // This will create a new provider instance whenever settings change
      ref.listen(settingsProvider, (previous, next) {
        if (previous?.lyricsProvider != next.lyricsProvider) {
          print(
            'LYRICS_PROVIDER_NOTIFIER: Settings changed, invalidating provider',
          );
          ref.invalidateSelf(); // Force recreation of this provider
        }
      });

      return LyricsProviderNotifier(settings.lyricsProvider);
    });

class LyricsProviderNotifier
    extends StateNotifier<lyrics_provider.LyricsProvider> {
  LyricsProviderNotifier(lyrics_provider.LyricsSource initialSource)
    : super(lyrics_provider.LyricsProvider()..selectedSource = initialSource) {
    print('LYRICS_PROVIDER_NOTIFIER: Created with source: $initialSource');
  }
}

// For immediate effect, you can also create a method to force refresh:
final lyricsProviderRefreshProvider =
    Provider.family<lyrics_provider.LyricsProvider, int>((ref, refreshId) {
      final settings = ref.watch(settingsProvider);
      print(
        'LYRICS_PROVIDER_REFRESH: Creating provider #$refreshId with source: ${settings.lyricsProvider}',
      );

      final provider = lyrics_provider.LyricsProvider();
      provider.selectedSource = settings.lyricsProvider;

      ref.onDispose(() => provider.dispose());
      return provider;
    });
