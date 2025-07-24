import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wikipedia/wikipedia.dart';

class WikipediaInfo {
  final String? artistBio;
  final String? activeYears;
  final String? wikipediaImageUrl;
  final bool loading;

  WikipediaInfo({
    this.artistBio,
    this.activeYears,
    this.wikipediaImageUrl,
    this.loading = false,
  });

  WikipediaInfo copyWith({
    String? artistBio,
    String? activeYears,
    String? wikipediaImageUrl,
    bool? loading,
  }) {
    return WikipediaInfo(
      artistBio: artistBio ?? this.artistBio,
      activeYears: activeYears ?? this.activeYears,
      wikipediaImageUrl: wikipediaImageUrl ?? this.wikipediaImageUrl,
      loading: loading ?? this.loading,
    );
  }
}

class WikipediaService {
  static Future<WikipediaInfo> fetchArtistInfo(String artistName) async {
    try {
      final wikipedia = Wikipedia();
      final searchResults = await wikipedia.searchQuery(
        searchQuery: artistName,
        limit: 5,
      );

      if (searchResults != null &&
          searchResults.query != null &&
          searchResults.query!.search != null &&
          searchResults.query!.search!.isNotEmpty) {
        final firstResult = searchResults.query!.search!.first;

        if (firstResult.pageid != null) {
          final pageData = await wikipedia.searchSummaryWithPageId(
            pageId: firstResult.pageid!,
          );

          if (pageData != null) {
            // Extract bio
            String bio = pageData.extract ?? pageData.description ?? '';
            if (bio.length > 300) {
              bio = bio.substring(0, 300) + '...';
            }

            // Extract active years
            String? activeYears;
            final yearRegex = RegExp(r'(\d{4})[-–](\d{4}|\w+)');
            final match = yearRegex.firstMatch(pageData.extract ?? '');
            if (match != null) {
              activeYears = 'Active: ${match.group(0)}';
            } else {
              final birthRegex = RegExp(r'born.*?(\d{4})');
              final birthMatch = birthRegex.firstMatch(pageData.extract ?? '');
              if (birthMatch != null) {
                activeYears = 'Active since ${birthMatch.group(1)}';
              }
            }

            // Get Wikipedia image
            String? imageUrl;
            try {
              final imageResponse = await http.get(
                Uri.parse(
                  'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(pageData.title ?? artistName)}',
                ),
              );
              if (imageResponse.statusCode == 200) {
                final imageData = json.decode(imageResponse.body);
                if (imageData['thumbnail'] != null) {
                  imageUrl = imageData['thumbnail']['source'];
                }
              }
            } catch (e) {
              debugPrint('Error fetching Wikipedia image: $e');
            }

            return WikipediaInfo(
              artistBio: bio,
              activeYears: activeYears ?? 'Active years unknown',
              wikipediaImageUrl: imageUrl,
            );
          }
        }
      }
      return WikipediaInfo(
        artistBio: 'No detailed information available',
        activeYears: 'Information unavailable',
      );
    } catch (e) {
      debugPrint('Error fetching Wikipedia info: $e');
      return WikipediaInfo(
        artistBio: 'Unable to load artist information',
        activeYears: 'Information unavailable',
      );
    }
  }
}
