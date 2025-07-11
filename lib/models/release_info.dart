class ReleaseInfo {
  final String tagName;
  final String body;
  final String htmlUrl;

  ReleaseInfo({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      tagName: json['tag_name'],
      body: json['body'] ?? '',
      htmlUrl: json['html_url'],
    );
  }
}
