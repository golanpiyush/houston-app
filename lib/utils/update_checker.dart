import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:houston/providers/managers/houstonupdatedownloadmanager.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/release_info.dart';
import '../providers/settings_provider.dart';

String formatDateTime(String rawDate) {
  final date = DateTime.parse(rawDate).toLocal();
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inHours < 24) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    return '${diff.inHours} hours ago';
  }

  return DateFormat(
    'dd-MM-yyyy '
    'at'
    ' HH:mm',
  ).format(date);
}

Future<void> checkForUpdate(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;

  try {
    final res = await http.get(
      Uri.parse(
        'https://api.github.com/repos/golanpiyush/houston-app/releases',
      ),
    );

    if (res.statusCode != 200) {
      Fluttertoast.showToast(msg: '⚠️ Could not check for updates.');
      return;
    }

    final List<dynamic> jsonList = jsonDecode(res.body);
    if (jsonList.isEmpty) return;

    final latest = ReleaseInfo.fromJson(jsonList.first);
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final latestVersion = latest.tagName.replaceFirst(RegExp(r'^v'), '');

    final currentFont = ref.read(settingsProvider).lyricsFont;

    final uploadedTime = formatDateTime(latest.publishedAt);

    final prefs = await SharedPreferences.getInstance();
    final lastUpdatedKey = 'houston_last_update_download';
    String? lastDownloadedTime = prefs.getString(lastUpdatedKey);
    if (lastDownloadedTime == null) {
      lastDownloadedTime = DateTime.now().toIso8601String();
      await prefs.setString(lastUpdatedKey, lastDownloadedTime);
    }
    final formattedDownloadTime = formatDateTime(lastDownloadedTime);

    if (latestVersion != currentVersion) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return UpdateDialog(
            latest: latest,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            uploadedTime: uploadedTime,
            formattedDownloadTime: formattedDownloadTime,
            currentFont: currentFont,
          );
        },
      );
    } else {
      Fluttertoast.showToast(msg: '✅ You have the latest version.');
    }
  } catch (e) {
    Fluttertoast.showToast(msg: '❌ No internet connection.');
  }
}

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo latest;
  final String currentVersion;
  final String latestVersion;
  final String uploadedTime;
  final String formattedDownloadTime;
  final String currentFont;

  const UpdateDialog({
    super.key,
    required this.latest,
    required this.currentVersion,
    required this.latestVersion,
    required this.uploadedTime,
    required this.formattedDownloadTime,
    required this.currentFont,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _headerShimmerController;
  late AnimationController _buttonShimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _headerShimmerAnimation;
  late Animation<double> _buttonShimmerAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerShimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _buttonShimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _headerShimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _headerShimmerController,
        curve: Curves.easeInOut,
      ),
    );

    _buttonShimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _buttonShimmerController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();

    // Start shimmer animations with delays
    Future.delayed(const Duration(milliseconds: 800), () {
      _headerShimmerController.repeat();
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      _buttonShimmerController.repeat();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _headerShimmerController.dispose();
    _buttonShimmerController.dispose();
    super.dispose();
  }

  void _startDownload() async {
    // Get the correct download URL from the release assets
    final apkAsset = widget.latest.assets.firstWhere(
      (asset) => asset['name'].toString().endsWith('.apk'),
      orElse: () => null,
    );

    if (apkAsset == null) {
      Fluttertoast.showToast(msg: 'No APK file found in release');
      return;
    }

    final downloadUrl = apkAsset['browser_download_url'] as String;
    final fileName = apkAsset['name'] as String;

    // Close current dialog and show download dialog
    Navigator.of(context).pop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        downloadUrl: downloadUrl,
        fileName: fileName,
        version: widget.latestVersion,
      ),
    );
  }

  Widget _buildShimmerHeader() {
    return AnimatedBuilder(
      animation: _headerShimmerAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'v${widget.latestVersion}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Shimmer overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Transform.translate(
                    offset: Offset(_headerShimmerAnimation.value * 200, 0),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerButton() {
    return AnimatedBuilder(
      animation: _buttonShimmerAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            ElevatedButton.icon(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.download,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              label: Text(
                'Download Update',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: _startDownload,
            ),
            // Shimmer overlay
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Transform.translate(
                  offset: Offset(_buttonShimmerAnimation.value * 150, 0),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShimmerHeader(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.currentVersion} → ${widget.latestVersion}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Column(
                            children: [
                              Icon(
                                Icons.upload,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                Icons.download,
                                color: theme.colorScheme.secondary,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Released: ${widget.uploadedTime}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Installed: ${widget.formattedDownloadTime}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Release Notes',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.copy_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          tooltip: 'Copy release notes',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.latest.body),
                            );
                            Fluttertoast.showToast(
                              msg: "📋 Copied to clipboard!",
                            );
                          },
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: MarkdownBody(
                                  data: widget.latest.body,
                                  selectable: true,
                                  onTapLink: (text, href, title) async {
                                    if (href != null) {
                                      final uri = Uri.parse(href);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    }
                                  },
                                  styleSheet:
                                      MarkdownStyleSheet.fromTheme(
                                        theme,
                                      ).copyWith(
                                        p: GoogleFonts.poppins(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                        h1: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        h2: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        code: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          backgroundColor: theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withOpacity(0.5),
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            // Subtle gradient overlay for visual appeal
                            if (widget.latest.body.length > 500)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        theme.colorScheme.surface.withOpacity(
                                          0.8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: Icon(
                    Icons.schedule,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  label: Text(
                    'Remind Me Later',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                _buildShimmerButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}
