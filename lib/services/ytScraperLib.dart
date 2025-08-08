import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class YtScraperSearch {
  final String apiKey;

  /// List of real-world User-Agent strings (randomized each request)
  static final List<String> userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:108.0) Gecko/20100101 Firefox/108.0',
  ];

  final Map<String, dynamic> clientContext = {
    "client": {"clientName": "WEB_REMIX", "clientVersion": "1.20231213.01.00"},
  };

  final Random _random = Random();

  YtScraperSearch({this.apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"});

  Map<String, String> getBaseHeaders() {
    final ua = userAgents[_random.nextInt(userAgents.length)];
    return {
      'Content-Type': 'application/json',
      'User-Agent': ua,
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
    };
  }

  Future<List<String>> getSuggestions(String query) async {
    final uri = Uri.https(
      'music.youtube.com',
      '/youtubei/v1/music/get_search_suggestions',
      {'key': apiKey},
    );

    final body = jsonEncode({
      'context': {'client': clientContext['client']},
      'input': query,
    });

    try {
      final response = await http.post(
        uri,
        headers: getBaseHeaders(),
        body: body,
      );

      if (response.statusCode != 200) {
        print('❌ Suggestions API error: ${response.statusCode}');
        return [];
      }

      final json = jsonDecode(response.body);
      final List<String> suggestions = [];

      if (json.containsKey('contents')) {
        for (var content in json['contents']) {
          if (content.containsKey('searchSuggestionsSectionRenderer')) {
            final section = content['searchSuggestionsSectionRenderer'];
            if (section.containsKey('contents')) {
              for (var item in section['contents']) {
                if (item.containsKey('searchSuggestionRenderer')) {
                  final suggestionData = item['searchSuggestionRenderer'];
                  if (suggestionData.containsKey('suggestion')) {
                    final suggestionText = StringBuffer();
                    for (var run in suggestionData['suggestion']['runs']) {
                      if (run.containsKey('text')) {
                        suggestionText.write(run['text']);
                      }
                    }
                    if (suggestionText.isNotEmpty) {
                      suggestions.add(suggestionText.toString());
                    }
                  }
                }
              }
            }
          }
        }
      }

      return suggestions.take(30).toList();
    } catch (e) {
      print('⚠️ Error getting suggestions: $e');
      return [];
    }
  }

  Future<List<QuickPickSong>> getQuickPicks({
    int limit = 30,
    String audioQuality = 'AUDIO_QUALITY_MEDIUM',
    String thumbnailQuality = 'medium',
  }) async {
    print('🔍 Starting Quick Picks request...');

    final uri = Uri.https('music.youtube.com', '/youtubei/v1/browse', {
      'key': apiKey,
    });

    final body = jsonEncode({
      'context': {
        'client': {
          ...clientContext['client'],
          'originalUrl': 'https://music.youtube.com/',
          'mainAppWebInfo': {'graftUrl': '/music'},
        },
        'user': {'lockedSafetyMode': false},
        'request': {
          'useSsl': true,
          'internalExperimentFlags': [],
          'consistencyTokenJars': [],
        },
      },
      'browseId': 'FEmusic_home',
    });

    try {
      print('📡 Making API request to: ${uri.toString()}');
      final response = await http.post(
        uri,
        headers: getBaseHeaders(),
        body: body,
      );

      print('📊 Response status: ${response.statusCode}');
      // print('📊 Response headers: ${response.headers}');

      if (response.statusCode != 200) {
        print('❌ Quick Picks API error: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return [];
      }

      final json = jsonDecode(response.body);
      // print('✅ Successfully parsed JSON response');

      // Debug: Print the top-level structure
      // print('🔍 Top-level keys: ${json.keys.toList()}');

      final List<QuickPickSong> songs = [];

      // Navigate through the response structure to find Quick Picks
      if (json.containsKey('contents')) {
        // print('✅ Found contents key');
        final contents = json['contents'];
        // print('🔍 Contents keys: ${contents.keys.toList()}');

        if (contents.containsKey('singleColumnBrowseResultsRenderer')) {
          // print('✅ Found singleColumnBrowseResultsRenderer');
          final renderer = contents['singleColumnBrowseResultsRenderer'];
          // print(
          //   '🔍 singleColumnBrowseResultsRenderer keys: ${renderer.keys.toList()}',
          // );

          if (renderer.containsKey('tabs')) {
            final tabs = renderer['tabs'];
            // print('✅ Found ${tabs.length} tabs');

            for (int tabIndex = 0; tabIndex < tabs.length; tabIndex++) {
              final tab = tabs[tabIndex];
              // print('🔍 Processing tab $tabIndex: ${tab.keys.toList()}');

              if (tab.containsKey('tabRenderer')) {
                final tabRenderer = tab['tabRenderer'];
                // print('🔍 Tab renderer keys: ${tabRenderer.keys.toList()}');

                if (tabRenderer.containsKey('content')) {
                  final tabContent = tabRenderer['content'];
                  // print('🔍 Tab content keys: ${tabContent.keys.toList()}');

                  if (tabContent.containsKey('sectionListRenderer')) {
                    final sectionList = tabContent['sectionListRenderer'];
                    // print('🔍 Section list keys: ${sectionList.keys.toList()}');

                    if (sectionList.containsKey('contents')) {
                      final sections = sectionList['contents'];
                      // print('✅ Found ${sections.length} sections');

                      for (
                        int sectionIndex = 0;
                        sectionIndex < sections.length;
                        sectionIndex++
                      ) {
                        final section = sections[sectionIndex];
                        // print(
                        //   '🔍 Processing section $sectionIndex: ${section.keys.toList()}',
                        // );

                        // Check for different types of shelf renderers
                        String? shelfType;
                        Map<String, dynamic>? shelf;

                        if (section.containsKey('musicCarouselShelfRenderer')) {
                          shelfType = 'musicCarouselShelfRenderer';
                          shelf = section['musicCarouselShelfRenderer'];
                        } else if (section.containsKey('musicShelfRenderer')) {
                          shelfType = 'musicShelfRenderer';
                          shelf = section['musicShelfRenderer'];
                        } else if (section.containsKey(
                          'musicImmersiveCarouselShelfRenderer',
                        )) {
                          shelfType = 'musicImmersiveCarouselShelfRenderer';
                          shelf =
                              section['musicImmersiveCarouselShelfRenderer'];
                        }

                        if (shelf != null) {
                          // print('✅ Found shelf type: $shelfType');
                          // print('🔍 Shelf keys: ${shelf.keys.toList()}');

                          // Extract header text to identify Quick Picks
                          String headerText = '';
                          if (shelf.containsKey('header')) {
                            // print('✅ Found shelf header');
                            final header = shelf['header'];
                            // print('🔍 Header keys: ${header.keys.toList()}');

                            if (header.containsKey(
                              'musicCarouselShelfBasicHeaderRenderer',
                            )) {
                              final basicHeader =
                                  header['musicCarouselShelfBasicHeaderRenderer'];
                              if (basicHeader.containsKey('title')) {
                                headerText = _extractTextFromRuns(
                                  basicHeader['title'],
                                );
                              }
                            } else if (header.containsKey(
                              'musicShelfHeaderRenderer',
                            )) {
                              final shelfHeader =
                                  header['musicShelfHeaderRenderer'];
                              if (shelfHeader.containsKey('title')) {
                                headerText = _extractTextFromRuns(
                                  shelfHeader['title'],
                                );
                              }
                            }
                          }

                          // print('📝 Section header: "$headerText"');

                          // Check if this is a Quick Picks section
                          final isQuickPicks =
                              headerText.toLowerCase().contains(
                                'quick picks',
                              ) ||
                              headerText.toLowerCase().contains(
                                'mixed for you',
                              ) ||
                              headerText.toLowerCase().contains(
                                'listen again',
                              ) ||
                              headerText.toLowerCase().contains('recommended');

                          // print('🎯 Is Quick Picks section: $isQuickPicks');

                          if (isQuickPicks && shelf.containsKey('contents')) {
                            final contents = shelf['contents'];
                            // print(
                            //   // '✅ Found ${contents.length} items in Quick Picks section',
                            // );

                            for (
                              int itemIndex = 0;
                              itemIndex < contents.length &&
                                  songs.length < limit;
                              itemIndex++
                            ) {
                              final item = contents[itemIndex];
                              // print(
                              //   // '🔍 Processing item $itemIndex: ${item.keys.toList()}',
                              // );

                              try {
                                final song = await _parseQuickPickSong(
                                  item,
                                  audioQuality,
                                  thumbnailQuality,
                                  itemIndex,
                                );

                                if (song != null) {
                                  songs.add(song);
                                  // print(
                                  //   // '✅ Successfully parsed song: ${song.title}',
                                  // );
                                } else {
                                  print('⚠️ Failed to parse item $itemIndex');
                                }
                              } catch (e) {
                                print('❌ Error parsing item $itemIndex: $e');
                              }
                            }

                            // If we found songs in this section, we can break
                            if (songs.isNotEmpty) {
                              print(
                                '🎉 Found ${songs.length} songs, stopping search',
                              );
                              break;
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } else {
        print('❌ No contents key found in response');
        // print('🔍 Available keys: ${json.keys.toList()}');
      }

      print('🎵 Final result: Found ${songs.length} Quick Pick songs');
      return songs.take(limit).toList();
    } catch (e) {
      print('❌ Error getting Quick Picks: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Parse individual song data from Quick Picks (Updated - with HQ album art)
  Future<QuickPickSong?> _parseQuickPickSong(
    Map<String, dynamic> item,
    String audioQuality,
    String thumbnailQuality,
    int itemIndex,
  ) async {
    // print('🔧 Parsing song item $itemIndex...');
    // print('🔍 Item keys: ${item.keys.toList()}');

    try {
      String? videoId;
      String title = '';
      List<String> artists = [];
      String albumArt = '';

      if (item.containsKey('musicResponsiveListItemRenderer')) {
        // print('✅ Found musicResponsiveListItemRenderer');
        final renderer = item['musicResponsiveListItemRenderer'];
        // print('🔍 Renderer keys: ${renderer.keys.toList()}');

        // Try to get video ID from overlay (common in Quick Picks)
        if (renderer.containsKey('overlay')) {
          final overlay = renderer['overlay'];
          if (overlay.containsKey('musicItemThumbnailOverlayRenderer')) {
            final overlayRenderer =
                overlay['musicItemThumbnailOverlayRenderer'];
            if (overlayRenderer.containsKey('content') &&
                overlayRenderer['content'].containsKey(
                  'musicPlayButtonRenderer',
                )) {
              final playButton =
                  overlayRenderer['content']['musicPlayButtonRenderer'];
              if (playButton.containsKey('playNavigationEndpoint') &&
                  playButton['playNavigationEndpoint'].containsKey(
                    'watchEndpoint',
                  )) {
                videoId =
                    playButton['playNavigationEndpoint']['watchEndpoint']['videoId'];
                // print('🎯 Found video ID from overlay: $videoId');
              }
            }
          }
        }

        // Fallback to navigation endpoint
        if (videoId == null && renderer.containsKey('flexColumns')) {
          final flexColumns = renderer['flexColumns'];
          for (final column in flexColumns) {
            if (column.containsKey(
              'musicResponsiveListItemFlexColumnRenderer',
            )) {
              final columnRenderer =
                  column['musicResponsiveListItemFlexColumnRenderer'];
              if (columnRenderer.containsKey('text') &&
                  columnRenderer['text'].containsKey('runs')) {
                for (final run in columnRenderer['text']['runs']) {
                  if (run.containsKey('navigationEndpoint') &&
                      run['navigationEndpoint'].containsKey('watchEndpoint')) {
                    videoId =
                        run['navigationEndpoint']['watchEndpoint']['videoId'];
                    if (videoId != null) {
                      // print('🎯 Found video ID from flex column: $videoId');
                      break;
                    }
                  }
                }
              }
            }
          }
        }

        // Extract title and artists
        if (renderer.containsKey('flexColumns')) {
          final flexColumns = renderer['flexColumns'];
          for (int i = 0; i < flexColumns.length; i++) {
            final column = flexColumns[i];
            if (column.containsKey(
              'musicResponsiveListItemFlexColumnRenderer',
            )) {
              final columnRenderer =
                  column['musicResponsiveListItemFlexColumnRenderer'];
              if (columnRenderer.containsKey('text')) {
                final text = columnRenderer['text'];
                final extractedText = _extractTextFromRuns(text);

                if (i == 0) {
                  // First column is title
                  title = extractedText;
                  // print('🎵 Title: $title');
                } else if (i == 1) {
                  // Second column is artists and plays
                  artists = extractedText
                      .split('•')[0]
                      .trim()
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
                  // print('👥 Artists: $artists');
                }
              }
            }
          }
        }

        // Extract thumbnail with high quality preference
        if (renderer.containsKey('thumbnail')) {
          final thumbnailData = renderer['thumbnail'];
          albumArt = _extractHighQualityThumbnail(
            thumbnailData,
            thumbnailQuality,
          );
          // print('🖼️ Album art URL: $albumArt');
        }
      }

      // If we still don't have a video ID, try to find it in the menu items
      if (videoId == null && item.containsKey('menu')) {
        final menu = item['menu']['menuRenderer'];
        for (final item in menu['items']) {
          if (item.containsKey('menuNavigationItemRenderer')) {
            final navItem = item['menuNavigationItemRenderer'];
            if (navItem.containsKey('navigationEndpoint') &&
                navItem['navigationEndpoint'].containsKey('watchEndpoint')) {
              videoId =
                  navItem['navigationEndpoint']['watchEndpoint']['videoId'];
              print('🎯 Found video ID from menu: $videoId');
              break;
            }
          }
        }
      }

      if (videoId == null) {
        print('⚠️ No video ID found for item $itemIndex');
        return null;
      }

      // print('🎯 Successfully extracted video ID: $videoId for song: $title');

      if (title.isNotEmpty) {
        return QuickPickSong(
          title: title,
          artists: artists,
          albumArt: albumArt,
          audioUrl: null, // Will be fetched when needed via YtMusicNotifier
          videoId: videoId,
          audioQuality: audioQuality,
          thumbnailQuality: thumbnailQuality,
        );
      }
    } catch (e) {
      print('❌ Error parsing song item $itemIndex: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }

    return null;
  }

  /// Extract high-quality thumbnail URL (544x544 preferred)
  String _extractHighQualityThumbnail(
    Map<String, dynamic> thumbnailData,
    String quality,
  ) {
    if (thumbnailData.containsKey('musicThumbnailRenderer')) {
      final thumbnail = thumbnailData['musicThumbnailRenderer']['thumbnail'];
      if (thumbnail.containsKey('thumbnails')) {
        final thumbnails = thumbnail['thumbnails'] as List;

        if (thumbnails.isNotEmpty) {
          // print('🔍 Available thumbnail sizes:');
          // for (var thumb in thumbnails) {
          //   // print('   - ${thumb['width']}x${thumb['height']}: ${thumb['url']}');
          // }

          // Get the largest available thumbnail URL to modify
          var bestThumbnail = thumbnails.first;
          for (var thumb in thumbnails) {
            if ((thumb['width'] as int) > (bestThumbnail['width'] as int)) {
              bestThumbnail = thumb;
            }
          }

          String originalUrl = bestThumbnail['url'];
          // print('🎯 Original URL: $originalUrl');

          // Convert to high-quality URL by modifying parameters
          String highQualityUrl = _convertToHighQualityUrl(originalUrl, 544);
          // print('🎯 High-quality URL (544x544): $highQualityUrl');

          return highQualityUrl;
        }
      }
    }

    return '';
  }

  /// Convert Google thumbnail URL to high-quality version
  String _convertToHighQualityUrl(String originalUrl, int targetSize) {
    try {
      // print('🔧 Converting URL to ${targetSize}x$targetSize');
      // print('   Original: $originalUrl');

      // Check if it's a Googleusercontent URL
      if (originalUrl.contains('googleusercontent.com')) {
        // Find the position of the last '=' which starts the parameters
        int lastEqualIndex = originalUrl.lastIndexOf('=');

        if (lastEqualIndex != -1) {
          // Extract the base URL (everything before the last '=')
          String baseUrl = originalUrl.substring(0, lastEqualIndex);

          // Create new high-quality parameters
          String newParams = 'w$targetSize-h$targetSize-l90-rj';

          // Construct the high-quality URL
          String highQualityUrl = '$baseUrl=$newParams';

          // print('🔧 URL conversion successful:');
          // print('   Base: $baseUrl');
          // print('   New params: $newParams');
          // print('   Final URL: $highQualityUrl');

          return highQualityUrl;
        } else {
          print('⚠️ No parameters found in Google URL');
        }
      }

      // Fallback: try regex replacement for any URL with size parameters
      if (originalUrl.contains('=w') && originalUrl.contains('-h')) {
        print('🔧 Attempting regex replacement...');

        // Replace existing width and height parameters completely
        String modifiedUrl = originalUrl.replaceAllMapped(
          RegExp(r'=w\d+-h\d+-[^=]*$'),
          (match) => '=w$targetSize-h$targetSize-l90-rj',
        );

        if (modifiedUrl != originalUrl) {
          print('🔧 Regex replacement successful: $modifiedUrl');
          return modifiedUrl;
        } else {
          print('⚠️ Regex replacement failed, trying alternative pattern...');

          // Try a more aggressive replacement pattern
          modifiedUrl = originalUrl.replaceAllMapped(
            RegExp(r'=w\d+-h\d+.*$'),
            (match) => '=w$targetSize-h$targetSize-l90-rj',
          );

          if (modifiedUrl != originalUrl) {
            print('🔧 Alternative regex successful: $modifiedUrl');
            return modifiedUrl;
          }
        }
      }

      // Additional fallback: try to construct URL if it contains known Google patterns
      if (originalUrl.contains('googleusercontent.com') &&
          originalUrl.contains('=')) {
        print('🔧 Trying Google URL reconstruction...');

        // Split at the first '=' and rebuild
        List<String> parts = originalUrl.split('=');
        if (parts.length >= 2) {
          String reconstructedUrl =
              '${parts[0]}=w$targetSize-h$targetSize-l90-rj';
          print('🔧 Reconstructed URL: $reconstructedUrl');
          return reconstructedUrl;
        }
      }

      // Final fallback: return original URL
      print('⚠️ Could not modify URL, returning original');
      return originalUrl;
    } catch (e) {
      print('❌ Error converting URL to high quality: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return originalUrl;
    }
  }

  /// Extract text from YouTube's text runs format
  String _extractTextFromRuns(Map<String, dynamic>? textObject) {
    if (textObject == null) return '';

    if (textObject.containsKey('runs')) {
      final buffer = StringBuffer();
      for (var run in textObject['runs']) {
        if (run.containsKey('text')) {
          buffer.write(run['text']);
        }
      }
      return buffer.toString();
    } else if (textObject.containsKey('simpleText')) {
      return textObject['simpleText'];
    }

    return '';
  }

  /// Extract thumbnail URL with specified quality (legacy method - kept for compatibility)
  String _extractThumbnail(Map<String, dynamic> thumbnailData, String quality) {
    if (thumbnailData.containsKey('musicThumbnailRenderer')) {
      final thumbnail = thumbnailData['musicThumbnailRenderer']['thumbnail'];
      if (thumbnail.containsKey('thumbnails')) {
        final thumbnails = thumbnail['thumbnails'] as List;

        // Return highest quality available or specified quality
        if (thumbnails.isNotEmpty) {
          // Try to find the requested quality, otherwise return the last (highest quality)
          for (var thumb in thumbnails.reversed) {
            if (quality == 'high' && thumb['width'] >= 480) {
              return thumb['url'];
            } else if (quality == 'medium' && thumb['width'] >= 320) {
              return thumb['url'];
            } else if (quality == 'low' && thumb['width'] >= 120) {
              return thumb['url'];
            }
          }
          // Fallback to last available
          return thumbnails.last['url'];
        }
      }
    }

    return '';
  }
}

/// Data class for Quick Pick songs
class QuickPickSong {
  final String title;
  final List<String> artists;
  final String albumArt;
  final String? audioUrl;
  final String videoId;
  final String audioQuality;
  final String thumbnailQuality;

  QuickPickSong({
    required this.title,
    required this.artists,
    required this.albumArt,
    required this.audioUrl,
    required this.videoId,
    required this.audioQuality,
    required this.thumbnailQuality,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artists': artists,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'videoId': videoId,
      'audioQuality': audioQuality,
      'thumbnailQuality': thumbnailQuality,
    };
  }

  @override
  String toString() {
    return 'QuickPickSong(title: $title, artists: ${artists.join(", ")}, videoId: $videoId)';
  }
}
