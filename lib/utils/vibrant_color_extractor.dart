import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class VibrantColorExtractor {
  static Future<Color> extract(String imageUrl) async {
    try {
      ImageProvider imageProvider;

      if (imageUrl.startsWith('http')) {
        imageProvider = NetworkImage(imageUrl);
      } else {
        imageProvider = FileImage(File(imageUrl));
      }

      final generator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 10,
      );

      return generator.vibrantColor?.color ??
          generator.dominantColor?.color ??
          Colors.grey.shade600;
    } catch (e) {
      print('Error extracting color: $e');
      return Colors.grey.shade600;
    }
  }
}
