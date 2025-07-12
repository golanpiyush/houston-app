import 'dart:convert';
import 'dart:math';

import 'package:houston/utils/lyrics_parser.dart';
import 'package:http/http.dart' as http;

class LyricsProvider {
  static const int pageSize = 8;
  static const int durationTolerance = 8;

  final http.Client client = http.Client();
  final List<String> _userAgents = [
    // Desktop
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15',
    // Android
    'Mozilla/5.0 (Linux; Android 12; Pixel 6 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; SM-A515F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.6312.120 Mobile Safari/537.36',
    // iOS
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile Safari/604.1',
    'Mozilla/5.0 (iPad; CPU OS 15_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1',
  ];

  Map<String, String> get randomHeaders => {
    'User-Agent': _userAgents[Random().nextInt(_userAgents.length)],
  };

  Future<Map<String, dynamic>> fetchLyrics(
    String title,
    String artist, {
    int duration = -1,
  }) async {
    final keyword = '$title - $artist';
    print("Tile Lyrics Searching: $title");
    print("Artists Lyrics Searching: $artist");
    final searchResponse = await client.get(
      Uri.https('mobileservice.kugou.com', '/api/v3/search/song', {
        'version': '9108',
        'plat': '0',
        'pagesize': '$pageSize',
        'showtype': '0',
        'keyword': keyword,
      }),
      headers: randomHeaders,
    );

    final searchData = json.decode(searchResponse.body);
    final songs = searchData['data']['info'];

    for (final song in songs) {
      if (duration == -1 ||
          (song['duration'] - duration).abs() <= durationTolerance) {
        final hash = song['hash'];

        final lyricsSearchResponse = await client.get(
          Uri.https('lyrics.kugou.com', '/search', {
            'ver': '1',
            'man': 'yes',
            'client': 'pc',
            'hash': hash,
          }),
          headers: randomHeaders,
        );

        final lyricsData = json.decode(lyricsSearchResponse.body);
        if (lyricsData['candidates'] != null &&
            lyricsData['candidates'].isNotEmpty) {
          final candidate = lyricsData['candidates'][0];
          final downloadResponse = await client.get(
            Uri.https('lyrics.kugou.com', '/download', {
              'fmt': 'lrc',
              'charset': 'utf8',
              'client': 'pc',
              'ver': '1',
              'id': candidate['id'].toString(),
              'accesskey': candidate['accesskey'],
            }),
            headers: randomHeaders,
          );

          final downloadData = json.decode(downloadResponse.body);
          if (downloadData['content'] != null) {
            final content = utf8.decode(base64.decode(downloadData['content']));
            final lines = LyricsParser.parseLrc(content);

            return {
              'success': true,
              'lrc': LyricsParser.toLrcString(lines),
              'lines': lines
                  .map(
                    (e) => {
                      'timestamp': e.timestamp,
                      'text': e.text,
                      'time': e.timeFormatted,
                    },
                  )
                  .toList(),
              'source': 'KuGou',
              'total_lines': lines.length,
            };
          }
        }
      }
    }

    return {'success': false, 'error': 'No lyrics found for $title by $artist'};
  }
}
