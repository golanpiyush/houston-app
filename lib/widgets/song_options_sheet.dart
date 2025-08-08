import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houston/providers/audio/audio_state_provider.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../models/song.dart';

void showSongOptionsSheet(BuildContext context, WidgetRef ref, Song song) {
  showMaterialModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.download,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'Download',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(audioProvider.notifier).download(song);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.playlist_add,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            title: Text(
              'Add to playlist',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            onTap: () {
              Navigator.pop(context);
              print('Tapped add to playlist for: ${song.title}');
              // You can add your playlist logic here
            },
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            title: Text(
              'Close',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
