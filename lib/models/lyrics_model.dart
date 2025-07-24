class LyricsLine {
  final int timestamp;
  final String text;
  final String timeFormatted;

  LyricsLine({
    required this.timestamp,
    required this.text,
    required this.timeFormatted,
  });

  factory LyricsLine.fromMap(Map<String, dynamic> map) {
    return LyricsLine(
      timestamp: map['timestamp'] ?? 0,
      text: map['text'] ?? '',
      timeFormatted: map['time'] ?? '',
    );
  }

  String toLrcLine() {
    return '[$timeFormatted]$text';
  }
}

class PlainLyricsLine {
  final String text;

  PlainLyricsLine({required this.text});

  factory PlainLyricsLine.fromJson(Map<String, dynamic> json) {
    return PlainLyricsLine(text: json['text']);
  }

  Map<String, dynamic> toJson() {
    return {'text': text};
  }
}
