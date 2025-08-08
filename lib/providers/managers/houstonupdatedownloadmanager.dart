import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:houston/utils/apk_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String fileName;
  final String version;

  const DownloadProgressDialog({
    super.key,
    required this.downloadUrl,
    required this.fileName,
    required this.version,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  String _status = 'Preparing download...';
  bool _isCompleted = false;
  bool _hasError = false;
  String? _downloadedFilePath;

  // Speed tracking variables
  int _downloadedBytes = 0;
  DateTime _downloadStartTime = DateTime.now();
  DateTime _lastUpdateTime = DateTime.now();
  double _currentSpeed = 0.0; // bytes per second
  String _speedText = '';

  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  final int _previousDownloadedLength = 0;
  final List<double> _speedHistory = [];
  static const int _speedHistorySize = 5;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Initialize speed tracking variables
    _downloadStartTime = DateTime.now();
    _lastUpdateTime = DateTime.now();
    _downloadedBytes = 0;
    _currentSpeed = 0.0;
    _speedText = '';
    _startDownload();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    try {
      setState(() {
        _status = 'Starting download...';
      });

      // Initialize speed tracking
      _downloadStartTime = DateTime.now();
      _lastUpdateTime = DateTime.now();
      _downloadedBytes = 0;

      // Use streaming download for better performance
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      final downloadedBytes = <int>[];

      setState(() {
        _status = 'Downloading ${widget.fileName}...';
      });

      // Stream the download with larger chunks and less frequent UI updates
      const chunkSize = 65536; // 64KB chunks for better performance
      int updateCounter = 0;
      const updateFrequency = 8; // Update UI every 8 chunks (512KB)
      int previousDownloadedLength = 0;

      await for (final chunk in response.stream) {
        if (!mounted) return;

        downloadedBytes.addAll(chunk);
        _downloadedBytes = downloadedBytes.length;
        updateCounter++;

        // Update UI less frequently for better performance
        if (updateCounter % updateFrequency == 0 ||
            downloadedBytes.length >= totalBytes) {
          // Calculate download speed
          final currentTime = DateTime.now();
          final timeDiff = currentTime
              .difference(_lastUpdateTime)
              .inMilliseconds;

          if (timeDiff > 100) {
            // Only update speed every 100ms for stability
            final bytesDiff = downloadedBytes.length - previousDownloadedLength;
            final instantSpeed =
                (bytesDiff * 1000.0) / timeDiff; // bytes per second

            // Smooth the speed using exponential moving average
            if (_currentSpeed == 0) {
              _currentSpeed = instantSpeed;
            } else {
              _currentSpeed = (_currentSpeed * 0.7) + (instantSpeed * 0.3);
            }

            _speedText = _formatSpeed(_currentSpeed);
            _lastUpdateTime = currentTime;
            previousDownloadedLength = downloadedBytes.length;
          }

          final progress = totalBytes > 0
              ? downloadedBytes.length / totalBytes
              : 0.0;

          setState(() {
            _progress = progress;
            final etaText = totalBytes > 0
                ? _calculateETA(
                    totalBytes,
                    downloadedBytes.length,
                    _currentSpeed,
                  )
                : '';
            _status = totalBytes > 0
                ? 'Downloaded ${_formatBytes(downloadedBytes.length)} of ${_formatBytes(totalBytes)} • $_speedText$etaText'
                : 'Downloaded ${_formatBytes(downloadedBytes.length)}... • $_speedText';
          });

          // Optional: Very small delay only for UI updates, not every chunk
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.fileName}';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(downloadedBytes));

      setState(() {
        _progress = 1.0;
        _status = 'Download completed!';
        _isCompleted = true;
        _downloadedFilePath = filePath;
      });

      _pulseController.stop();
      _rotationController.stop();

      // Show completion animation
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _showInstallOptions();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _status = 'Download failed: ${e.toString()}';
      });
      _pulseController.stop();
      _rotationController.stop();
    }
  }

  // Alternative faster download method without artificial chunking
  Future<void> _startDownloadFast() async {
    try {
      setState(() {
        _status = 'Starting download...';
      });

      // Initialize speed tracking
      _downloadStartTime = DateTime.now();
      _lastUpdateTime = DateTime.now();
      _downloadedBytes = 0;

      final response = await http.get(Uri.parse(widget.downloadUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      setState(() {
        _status = 'Downloading ${widget.fileName}...';
        _progress = 0.5; // Show some progress while processing
      });

      // Save file directly - much faster
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.fileName}';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _progress = 1.0;
        _status = 'Download completed!';
        _isCompleted = true;
        _downloadedFilePath = filePath;
      });

      _pulseController.stop();
      _rotationController.stop();

      // Show completion animation
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _showInstallOptions();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _status = 'Download failed: ${e.toString()}';
      });
      _pulseController.stop();
      _rotationController.stop();
    }
  }

  void _showInstallOptions() async {
    final canInstall = await HoustonInstaller.canInstallPackages();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ready to Install',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Houston v${widget.version} has been downloaded successfully.',
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (!canInstall) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Install from Unknown Sources permission is required.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close install dialog
              Navigator.of(context).pop(); // Close download dialog
            },
            child: Text(
              'Later',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (!canInstall)
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: Text(
                'Grant Permission',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await HoustonInstaller.openInstallPermissionSettings();
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          if (canInstall)
            ElevatedButton.icon(
              icon: const Icon(Icons.system_update),
              label: Text(
                'Install Now',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                try {
                  await HoustonInstaller.installApk(_downloadedFilePath!);
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  Fluttertoast.showToast(msg: '🚀 Installing update...');
                } catch (e) {
                  Fluttertoast.showToast(msg: '❌ Installation failed: $e');
                }
              },
            ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) {
      return '0 B/s';
    } else if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1048576) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else if (bytesPerSecond < 1073741824) {
      return '${(bytesPerSecond / 1048576).toStringAsFixed(1)} MB/s';
    } else {
      return '${(bytesPerSecond / 1073741824).toStringAsFixed(2)} GB/s';
    }
  }

  String _calculateETA(int totalBytes, int downloadedBytes, double speed) {
    if (speed <= 0 || downloadedBytes >= totalBytes || totalBytes <= 0) {
      return '';
    }

    final remainingBytes = totalBytes - downloadedBytes;
    final etaSeconds = remainingBytes / speed;

    if (etaSeconds < 1) {
      return ' • <1s left';
    } else if (etaSeconds < 60) {
      return ' • ${etaSeconds.round()}s left';
    } else if (etaSeconds < 3600) {
      final minutes = (etaSeconds / 60).round();
      return ' • ${minutes}m left';
    } else {
      final hours = (etaSeconds / 3600);
      if (hours < 10) {
        return ' • ${hours.toStringAsFixed(1)}h left';
      } else {
        return ' • ${hours.round()}h left';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Column(
            children: [
              if (!_isCompleted && !_hasError)
                Lottie.asset(
                  'assets/animations/downloadingHoustonUpdates.json',
                  width: 300,
                  height: 300,
                  repeat: true,
                  fit: BoxFit.contain,
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _hasError
                        ? LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade600],
                          )
                        : LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                  ),
                  child: Icon(
                    _hasError ? Icons.error : Icons.check,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _hasError
                ? 'Download Failed'
                : _isCompleted
                ? 'Download Complete!'
                : 'Downloading Update',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Houston v${widget.version}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 20),
            if (!_hasError) ...[
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: _isCompleted
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(_progress * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
      actions: _hasError
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _progress = 0.0;
                    _hasError = false;
                    _isCompleted = false;
                  });
                  _pulseController.repeat(reverse: true);
                  _rotationController.repeat();
                  _startDownload();
                },
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ]
          : _isCompleted
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
    );
  }
}
