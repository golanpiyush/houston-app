// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:houston/models/song.dart';
// import 'package:houston/providers/queue_provider.dart';

// class QueueScreen extends ConsumerStatefulWidget {
//   const QueueScreen({super.key});

//   @override
//   ConsumerState<QueueScreen> createState() => _QueueScreenState();
// }

// class _QueueScreenState extends ConsumerState<QueueScreen>
//     with TickerProviderStateMixin {
//   late TabController _tabController;
//   bool _isEditMode = false;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 3, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final queueState = ref.watch(queueProvider);
//     final queueNotifier = ref.read(queueProvider.notifier);

//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text(
//           'Queue',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(
//               _isEditMode ? Icons.done : Icons.edit,
//               color: Colors.white,
//             ),
//             onPressed: () {
//               setState(() {
//                 _isEditMode = !_isEditMode;
//               });
//             },
//           ),
//           PopupMenuButton<String>(
//             icon: const Icon(Icons.more_vert, color: Colors.white),
//             color: Colors.grey[900],
//             onSelected: (value) {
//               switch (value) {
//                 case 'clear_queue':
//                   _showClearQueueDialog(context, queueNotifier);
//                   break;
//                 case 'save_queue':
//                   _showSaveQueueDialog(context);
//                   break;
//                 case 'shuffle_queue':
//                   queueNotifier.toggleShuffle();
//                   break;
//               }
//             },
//             itemBuilder: (context) => [
//               PopupMenuItem(
//                 value: 'shuffle_queue',
//                 child: Row(
//                   children: [
//                     Icon(
//                       queueState.isShuffled ? Icons.shuffle_on : Icons.shuffle,
//                       color: queueState.isShuffled
//                           ? Colors.green
//                           : Colors.white,
//                     ),
//                     const SizedBox(width: 12),
//                     Text(
//                       queueState.isShuffled ? 'Unshuffle' : 'Shuffle',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: 'save_queue',
//                 child: Row(
//                   children: [
//                     Icon(Icons.playlist_add, color: Colors.white),
//                     SizedBox(width: 12),
//                     Text(
//                       'Save as Playlist',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: 'clear_queue',
//                 child: Row(
//                   children: [
//                     Icon(Icons.clear_all, color: Colors.red),
//                     SizedBox(width: 12),
//                     Text('Clear Queue', style: TextStyle(color: Colors.red)),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.white,
//           labelColor: Colors.white,
//           unselectedLabelColor: Colors.grey,
//           tabs: const [
//             Tab(text: 'Current Queue'),
//             Tab(text: 'Up Next'),
//             Tab(text: 'Smart Queue'),
//           ],
//         ),
//       ),
//       body: Column(
//         children: [
//           // Queue Controls
//           _buildQueueControls(queueState, queueNotifier),

//           // Current Song Banner
//           if (queueState.currentSong != null)
//             _buildCurrentSongBanner(queueState.currentSong!),

//           // Tab Content
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 _buildCurrentQueueTab(queueState, queueNotifier),
//                 _buildUpNextTab(queueState, queueNotifier),
//                 _buildSmartQueueTab(queueState),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildQueueControls(
//     QueueState queueState,
//     QueueNotifier queueNotifier,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _buildControlButton(
//             icon: queueState.playbackMode == PlaybackMode.normal
//                 ? Icons.repeat
//                 : queueState.playbackMode == PlaybackMode.repeatAll
//                 ? Icons.repeat
//                 : Icons.repeat_one,
//             label: queueState.playbackMode == PlaybackMode.normal
//                 ? 'No Repeat'
//                 : queueState.playbackMode == PlaybackMode.repeatAll
//                 ? 'Repeat All'
//                 : 'Repeat One',
//             isActive: queueState.playbackMode != PlaybackMode.normal,
//             onTap: () => queueNotifier.togglePlaybackMode(),
//           ),
//           _buildControlButton(
//             icon: Icons.shuffle,
//             label: 'Shuffle',
//             isActive: queueState.isShuffled,
//             onTap: () => queueNotifier.toggleShuffle(),
//           ),
//           _buildControlButton(
//             icon: Icons.auto_awesome,
//             label: 'Autoplay',
//             isActive: queueState.autoplayEnabled,
//             onTap: () => queueNotifier.toggleAutoplay(),
//           ),
//           _buildControlButton(
//             icon: Icons.trending_up,
//             label: 'Crossfade',
//             isActive: queueState.crossfadeEnabled,
//             onTap: () => queueNotifier.toggleCrossfade(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSongMenu(Song song) {
//     return PopupMenuButton<String>(
//       icon: const Icon(Icons.more_vert, color: Colors.white),
//       color: Colors.grey[900],
//       onSelected: (value) {
//         final queueNotifier = ref.read(queueProvider.notifier);
//         final queueState = ref.read(queueProvider);

//         switch (value) {
//           case 'play_next':
//             queueNotifier.playSongNext(song);
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Added "${song.title}" to play next'),
//                 backgroundColor: Colors.green,
//               ),
//             );

//             // If currently at end of queue, play immediately
//             if (queueState.currentIndex == queueState.currentQueue.length - 1) {
//               queueNotifier.jumpToSong(queueState.currentIndex + 1);
//             }
//             break;

//           case 'add_to_queue':
//             queueNotifier.addSongToUpNext(song);
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Added "${song.title}" to Up Next'),
//                 backgroundColor: Colors.green,
//               ),
//             );
//             break;
//         }
//       },
//       itemBuilder: (context) => [
//         const PopupMenuItem(
//           value: 'play_next',
//           child: Row(
//             children: [
//               Icon(Icons.skip_next, color: Colors.white),
//               SizedBox(width: 12),
//               Text('Play Next', style: TextStyle(color: Colors.white)),
//             ],
//           ),
//         ),
//         const PopupMenuItem(
//           value: 'add_to_queue',
//           child: Row(
//             children: [
//               Icon(Icons.queue, color: Colors.white),
//               SizedBox(width: 12),
//               Text('Add to Up Next', style: TextStyle(color: Colors.white)),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildControlButton({
//     required IconData icon,
//     required String label,
//     required bool isActive,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: isActive ? Colors.white : Colors.grey[800],
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Icon(
//               icon,
//               color: isActive ? Colors.black : Colors.white,
//               size: 20,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: TextStyle(
//               color: isActive ? Colors.white : Colors.grey,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCurrentSongBanner(Song song) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Colors.purple.withOpacity(0.3),
//             Colors.blue.withOpacity(0.3),
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(8),
//               image: song.albumArt != null
//                   ? DecorationImage(
//                       image: NetworkImage(song.albumArt!),
//                       fit: BoxFit.cover,
//                     )
//                   : null,
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Now Playing',
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   song.title,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 Text(
//                   song.artists,
//                   style: const TextStyle(color: Colors.white70, fontSize: 14),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//           const Icon(Icons.music_note, color: Colors.white),
//         ],
//       ),
//     );
//   }

//   Widget _buildCurrentQueueTab(
//     QueueState queueState,
//     QueueNotifier queueNotifier,
//   ) {
//     if (queueState.currentQueue.isEmpty) {
//       return _buildEmptyState('No songs in queue', Icons.queue_music);
//     }

//     return ReorderableListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: queueState.currentQueue.length,
//       onReorder: (oldIndex, newIndex) {
//         if (_isEditMode) {
//           if (newIndex > oldIndex) {
//             newIndex -= 1;
//           }
//           queueNotifier.reorderQueue(oldIndex, newIndex);
//         }
//       },
//       itemBuilder: (context, index) {
//         final song = queueState.currentQueue[index];
//         final isCurrentSong = index == queueState.currentIndex;

//         return _buildSongTile(
//           key: ValueKey('${song.videoId}_$index'),
//           song: song,
//           index: index,
//           isCurrentSong: isCurrentSong,
//           showReorderHandle: _isEditMode,
//           onTap: () => queueNotifier.jumpToSong(index),
//           onDelete: _isEditMode
//               ? () => queueNotifier.removeSongFromQueue(index)
//               : null,
//           trailing: _buildSongMenu(song),
//         );
//       },
//     );
//   }

//   Widget _buildUpNextTab(QueueState queueState, QueueNotifier queueNotifier) {
//     if (queueState.upNext.isEmpty) {
//       return _buildEmptyState('No songs in Up Next', Icons.queue_play_next);
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: queueState.upNext.length,
//       itemBuilder: (context, index) {
//         final song = queueState.upNext[index];
//         final actualIndex = queueState.currentQueue.length + index;

//         return _buildSongTile(
//           key: ValueKey('${song.videoId}_upnext_$index'),
//           song: song,
//           index: index + 1,
//           isCurrentSong: false,
//           showReorderHandle: false,
//           onTap: () => queueNotifier.jumpToSong(actualIndex),
//           onDelete: _isEditMode
//               ? () => queueNotifier.removeFromUpNext(index)
//               : null,
//           trailing: _buildSongMenu(song),
//         );
//       },
//     );
//   }

//   Widget _buildSmartQueueTab(QueueState queueState) {
//     if (queueState.smartQueue.isEmpty) {
//       return _buildEmptyState(
//         queueState.isLoadingRelated
//             ? 'Loading smart suggestions...'
//             : 'No smart suggestions yet',
//         Icons.auto_awesome,
//         showLoading: queueState.isLoadingRelated,
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: queueState.smartQueue.length,
//       itemBuilder: (context, index) {
//         final song = queueState.smartQueue[index];

//         return _buildSongTile(
//           key: ValueKey('${song.videoId}_smart_$index'),
//           song: song,
//           index: index + 1,
//           isCurrentSong: false,
//           showReorderHandle: false,
//           onTap: null,
//           trailing: IconButton(
//             icon: const Icon(Icons.playlist_add, color: Colors.white),
//             onPressed: () {
//               ref.read(queueProvider.notifier).addSongToUpNext(song);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text('Added "${song.title}" to Up Next'),
//                   backgroundColor: Colors.green,
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSongTile({
//     required Key key,
//     required Song song,
//     required int index,
//     required bool isCurrentSong,
//     required bool showReorderHandle,
//     VoidCallback? onTap,
//     VoidCallback? onDelete,
//     Widget? trailing,
//   }) {
//     return Container(
//       key: key,
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         color: isCurrentSong ? Colors.white.withOpacity(0.1) : Colors.grey[900],
//         borderRadius: BorderRadius.circular(12),
//         border: isCurrentSong
//             ? Border.all(color: Colors.white.withOpacity(0.3))
//             : null,
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         leading: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (showReorderHandle)
//               ReorderableDragStartListener(
//                 index: index,
//                 child: const Icon(Icons.drag_handle, color: Colors.grey),
//               )
//             else
//               Container(
//                 width: 24,
//                 height: 24,
//                 decoration: BoxDecoration(
//                   color: isCurrentSong ? Colors.white : Colors.grey[700],
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Center(
//                   child: Text(
//                     '$index',
//                     style: TextStyle(
//                       color: isCurrentSong ? Colors.black : Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//             const SizedBox(width: 12),
//             Container(
//               width: 48,
//               height: 48,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(8),
//                 color: Colors.grey[800],
//                 image: song.albumArt != null
//                     ? DecorationImage(
//                         image: NetworkImage(song.albumArt!),
//                         fit: BoxFit.cover,
//                       )
//                     : null,
//               ),
//               child: Stack(
//                 children: [
//                   if (song.albumArt == null)
//                     const Center(
//                       child: Icon(
//                         Icons.music_note,
//                         color: Colors.white,
//                         size: 24,
//                       ),
//                     ),
//                   if (isCurrentSong)
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.5),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: const Center(
//                         child: Icon(
//                           Icons.play_arrow,
//                           color: Colors.white,
//                           size: 24,
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         title: Text(
//           song.title,
//           style: TextStyle(
//             color: isCurrentSong ? Colors.white : Colors.white,
//             fontSize: 16,
//             fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
//           ),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//         subtitle: Text(
//           song.artists,
//           style: TextStyle(
//             color: isCurrentSong ? Colors.white70 : Colors.grey,
//             fontSize: 14,
//           ),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (onDelete != null)
//               IconButton(
//                 icon: const Icon(Icons.delete, color: Colors.red),
//                 onPressed: onDelete,
//               ),
//             if (trailing != null) trailing,
//           ],
//         ),
//         onTap: onTap,
//       ),
//     );
//   }

//   Widget _buildEmptyState(
//     String message,
//     IconData icon, {
//     bool showLoading = false,
//   }) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           if (showLoading)
//             const CircularProgressIndicator(color: Colors.white)
//           else
//             Icon(icon, size: 64, color: Colors.grey),
//           const SizedBox(height: 16),
//           Text(
//             message,
//             style: const TextStyle(color: Colors.grey, fontSize: 16),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   void _showClearQueueDialog(
//     BuildContext context,
//     QueueNotifier queueNotifier,
//   ) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: const Text('Clear Queue', style: TextStyle(color: Colors.white)),
//         content: const Text(
//           'Are you sure you want to clear the entire queue? This action cannot be undone.',
//           style: TextStyle(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () {
//               queueNotifier.clearQueue();
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Queue cleared'),
//                   backgroundColor: Colors.red,
//                 ),
//               );
//             },
//             child: const Text('Clear', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showSaveQueueDialog(BuildContext context) {
//     final TextEditingController playlistNameController =
//         TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: const Text(
//           'Save Queue as Playlist',
//           style: TextStyle(color: Colors.white),
//         ),
//         content: TextField(
//           controller: playlistNameController,
//           style: const TextStyle(color: Colors.white),
//           decoration: const InputDecoration(
//             hintText: 'Enter playlist name',
//             hintStyle: TextStyle(color: Colors.grey),
//             enabledBorder: OutlineInputBorder(
//               borderSide: BorderSide(color: Colors.grey),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderSide: BorderSide(color: Colors.white),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//           ),
//           TextButton(
//             onPressed: () {
//               // Implement save playlist functionality
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text(
//                     'Playlist "${playlistNameController.text}" saved',
//                   ),
//                   backgroundColor: Colors.green,
//                 ),
//               );
//             },
//             child: const Text('Save', style: TextStyle(color: Colors.green)),
//           ),
//         ],
//       ),
//     );
//   }
// }
