import 'package:houston/models/lyrics_model.dart';

class LyricsParser {
  static final RegExp acceptedRegex = RegExp(r"\[(\d\d):(\d\d)\.(\d{2,3})\].*");

  static List<LyricsLine> parseLrc(String content) {
    List<LyricsLine> lines = [];

    for (var line in content.split('\n')) {
      var match = acceptedRegex.firstMatch(line);
      if (match != null) {
        int minutes = int.parse(match.group(1)!);
        int seconds = int.parse(match.group(2)!);
        int millis = int.parse(
          match.group(3)!.padRight(3, '0').substring(0, 3),
        );

        int timestampMs = minutes * 60000 + seconds * 1000 + millis;
        String text = line.split(']').length > 1
            ? line.split(']')[1].trim()
            : '';

        if (text.isNotEmpty) {
          lines.add(
            LyricsLine(
              timestamp: timestampMs,
              text: text,
              timeFormatted:
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}',
            ),
          );
        }
      }
    }

    return lines..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static String toLrcString(List<LyricsLine> lines) {
    return lines.map((line) => line.toLrcLine()).join('\n');
  }
}
