class SystemStatus {
  final bool success;
  final String? message;
  final bool ytmusicReady;
  final String ytmusicVersion;
  final bool ytdlpReady;
  final String ytdlpVersion;
  final bool pythonInitialized;
  final bool moduleLoaded;
  final bool searcherReady;
  final bool relatedFetcherReady;
  final int cacheSize;

  SystemStatus({
    required this.success,
    this.message,
    required this.ytmusicReady,
    required this.ytmusicVersion,
    required this.ytdlpReady,
    required this.ytdlpVersion,
    required this.pythonInitialized,
    required this.moduleLoaded,
    required this.searcherReady,
    required this.relatedFetcherReady,
    required this.cacheSize,
  });
}
