import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/release_info.dart';

Future<void> checkForUpdate(BuildContext context) async {
  try {
    final res = await http.get(
      Uri.parse(
        'https://api.github.com/repos/golanpiyush/houston-app/releases/latest',
      ),
    );

    if (res.statusCode != 200) {
      Fluttertoast.showToast(msg: '⚠️ Could not check for updates.');
      return;
    }

    final latest = ReleaseInfo.fromJson(jsonDecode(res.body));
    final info = await PackageInfo.fromPlatform();
    final current = 'v${info.version}';

    if (latest.tagName != current) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('🚀 Update Available: ${latest.tagName}'),
          content: SizedBox(
            height: 300,
            child: Markdown(
              data: latest.body,
              physics: const BouncingScrollPhysics(),
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Remind Me Later'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Update Now'),
              onPressed: () async {
                final url = Uri.parse(latest.htmlUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );
    } else {
      Fluttertoast.showToast(msg: '✅ You have the latest version.');
    }
  } catch (e) {
    Fluttertoast.showToast(msg: '❌ No internet connection.');
  }
}
