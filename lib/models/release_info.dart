enum UpdateDialogState { idle, downloading, done, installing }

class ReleaseInfo {
  final String tagName;
  final String body;
  final String publishedAt;
  final List<dynamic> assets; //
  ReleaseInfo({
    required this.tagName,
    required this.body,
    required this.publishedAt,
    required this.assets, //
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      tagName: json['tag_name'] ?? '',
      body: json['body'] ?? '',
      publishedAt: json['published_at'] ?? '',
      assets: json['assets'] ?? [], //
    );
  }
}
