// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:houston/models/song.dart';
// import 'package:houston/providers/audio_state_provider.dart';
// import 'package:houston/providers/ytmusic_provider.dart';

// class ArtistSongsSection extends ConsumerWidget {
//   final List<Song> songs;
//   final String artistName;
//   final bool isLoading;
//   final bool isStreaming;
//   final bool hasError;
//   final String? errorMessage;
//   final Animation<double> animation;
//   final bool isDark;

//   const ArtistSongsSection({
//     super.key,
//     required this.songs,
//     required this.artistName,
//     required this.isLoading,
//     required this.isStreaming,
//     required this.hasError,
//     this.errorMessage,
//     required this.animation,
//     required this.isDark,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return Container(
//       margin: const EdgeInsets.only(top: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildPlayAllButton(context, ref),
//           const SizedBox(height: 24),
//           _buildSongsSection(context),
//         ],
//       ),
//     );
//   }

//   Widget _buildPlayAllButton(BuildContext context, WidgetRef ref) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 20),
//       child: ElevatedButton.icon(
//         onPressed: songs.isNotEmpty ? () => _playAllSongs(ref) : null,
//         icon: isLoading
//             ? const SizedBox(
//                 width: 16,
//                 height: 16,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   color: Colors.white,
//                 ),
//               )
//             : const Icon(Icons.play_arrow, size: 24),
//         label: Text(
//           isLoading ? 'Loading...' : 'Play All',
//           style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
//         ),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: isDark ? Colors.white : Colors.black,
//           foregroundColor: isDark ? Colors.black : Colors.white,
//           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(25),
//           ),
//           elevation: 8,
//           shadowColor: Colors.black.withOpacity(0.3),
//         ),
//       ),
//     );
//   }

//   Widget _buildSongsSection(BuildContext context) {
//     if (hasError) {
//       return _buildErrorState();
//     }

//     if (isLoading && songs.isEmpty) {
//       return _buildLoadingState();
//     }

//     if (songs.isEmpty) {
//       return _buildEmptyState();
//     }

//     final totalItemsToShow = isStreaming
//         ? math.max(8, songs.length)
//         : songs.length;
//     final shimmerCount = totalItemsToShow - songs.length;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//           child: Row(
//             children: [
//               Text(
//                 'Songs',
//                 style: GoogleFonts.poppins(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: isDark ? Colors.white : Colors.black,
//                 ),
//               ),
//               if (isStreaming) ...[
//                 const SizedBox(width: 8),
//                 SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: isDark ? Colors.white : Colors.black87,
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           itemCount: totalItemsToShow,
//           itemBuilder: (context, index) {
//             if (index < songs.length) {
//               return _buildSongTile(songs[index], index);
//             } else {
//               return _buildShimmerTile(index);
//             }
//           },
//         ),
//         const SizedBox(height: 100),
//       ],
//     );
//   }

//   Widget _buildSongTile(Song song, int index) {
//     return AnimatedBuilder(
//       animation: animation,
//       builder: (context, child) {
//         final animationDelay = index * 0.1;
//         final adjustedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//           CurvedAnimation(
//             parent: animation,
//             curve: Interval(
//               animationDelay.clamp(0.0, 1.0),
//               (animationDelay + 0.3).clamp(0.0, 1.0),
//               curve: Curves.easeOutCubic,
//             ),
//           ),
//         );

//         return Transform.translate(
//           offset: Offset(0, 30 * (1 - adjustedAnimation.value)),
//           child: Opacity(
//             opacity: adjustedAnimation.value,
//             child: Container(
//               margin: const EdgeInsets.only(bottom: 8),
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: () => _playSong(song, index, ref),
//                   borderRadius: BorderRadius.circular(12),
//                   child: Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.transparent,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Row(
//                       children: [
//                         _buildAlbumArt(song),
//                         const SizedBox(width: 16),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 song.title,
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                   color: isDark ? Colors.white : Colors.black87,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                               const SizedBox(height: 4),
//                               Text(
//                                 song.artists,
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 14,
//                                   color: isDark
//                                       ? Colors.grey.shade400
//                                       : Colors.grey.shade600,
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ],
//                           ),
//                         ),
//                         IconButton(
//                           onPressed: () => _showSongOptions(song, context),
//                           icon: Icon(
//                             Icons.more_vert,
//                             color: isDark
//                                 ? Colors.grey.shade400
//                                 : Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildAlbumArt(Song song) {
//     return Container(
//       width: 56,
//       height: 56,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(8),
//         child: song.albumArt != null && song.albumArt!.isNotEmpty
//             ? Image.network(
//                 song.albumArt!,
//                 fit: BoxFit.cover,
//                 errorBuilder: (context, error, stackTrace) =>
//                     _buildDefaultAlbumArt(),
//               )
//             : _buildDefaultAlbumArt(),
//       ),
//     );
//   }

//   Widget _buildDefaultAlbumArt() {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.grey.shade300, Colors.grey.shade400],
//         ),
//       ),
//       child: const Icon(Icons.music_note, size: 28, color: Colors.white),
//     );
//   }

//   Widget _buildShimmerTile(int index) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 56,
//             height: 56,
//             decoration: BoxDecoration(
//               color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   width: 200,
//                   height: 16,
//                   decoration: BoxDecoration(
//                     color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Container(
//                   width: 120,
//                   height: 14,
//                   decoration: BoxDecoration(
//                     color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingState() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//           child: Row(
//             children: [
//               Container(
//                 width: 60,
//                 height: 20,
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade300,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         ListView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           itemCount: 8,
//           itemBuilder: (context, index) {
//             return Container(
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.transparent,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 56,
//                     height: 56,
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade300,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Container(
//                           width: 200,
//                           height: 16,
//                           decoration: BoxDecoration(
//                             color: Colors.grey.shade300,
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Container(
//                           width: 120,
//                           height: 14,
//                           decoration: BoxDecoration(
//                             color: Colors.grey.shade300,
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Container(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           children: [
//             Icon(Icons.music_off, size: 64, color: Colors.grey.shade400),
//             const SizedBox(height: 16),
//             Text(
//               'No songs found',
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'This artist doesn\'t have any songs available.',
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 color: Colors.grey.shade500,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return Center(
//       child: Container(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           children: [
//             Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
//             const SizedBox(height: 16),
//             Text(
//               'Something went wrong',
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.red.shade600,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               errorMessage ?? 'Unknown error occurred',
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 color: Colors.grey.shade500,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               onPressed: () {
//                 // You might want to add a way to retry
//               },
//               icon: const Icon(Icons.refresh),
//               label: Text('Try Again', style: GoogleFonts.poppins()),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red.shade400,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _playSong(Song song, int index, WidgetRef ref) {
//     try {
//       final audioNotifier = ref.read(audioProvider.notifier);
//       audioNotifier.playArtistSongs(songs, startIndex: index);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Playing: ${song.title} by ${song.artists}',
//             style: GoogleFonts.poppins(),
//           ),
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Error playing song: ${e.toString()}',
//             style: GoogleFonts.poppins(),
//           ),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     }
//   }

//   void _playAllSongs(WidgetRef ref) {
//     try {
//       final audioNotifier = ref.read(audioProvider.notifier);
//       audioNotifier.playArtistSongs(songs, startIndex: 0);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Playing all songs by $artistName',
//             style: GoogleFonts.poppins(),
//           ),
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Error playing songs: ${e.toString()}',
//             style: GoogleFonts.poppins(),
//           ),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     }
//   }

//   void _showSongOptions(Song song, BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => _buildSongOptionsSheet(song, context),
//     );
//   }

//   Widget _buildSongOptionsSheet(Song song, BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return Container(
//       decoration: BoxDecoration(
//         color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: SafeArea(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 40,
//               height: 4,
//               margin: const EdgeInsets.symmetric(vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade400,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Row(
//                 children: [
//                   _buildAlbumArt(song),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           song.title,
//                           style: GoogleFonts.poppins(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                             color: isDark ? Colors.white : Colors.black87,
//                           ),
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           song.artists,
//                           style: GoogleFonts.poppins(
//                             fontSize: 14,
//                             color: isDark
//                                 ? Colors.grey.shade400
//                                 : Colors.grey.shade600,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),
//             _buildOptionTile(
//               icon: Icons.play_arrow,
//               title: 'Play',
//               onTap: () {
//                 Navigator.pop(context);
//                 final index = songs.indexOf(song);
//                 _playSong(song, index, ref);
//               },
//               isDark: isDark,
//             ),
//             _buildOptionTile(
//               icon: Icons.playlist_add,
//               title: 'Add to Playlist',
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement add to playlist functionality
//               },
//               isDark: isDark,
//             ),
//             _buildOptionTile(
//               icon: Icons.favorite_border,
//               title: 'Add to Favorites',
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement add to favorites functionality
//               },
//               isDark: isDark,
//             ),
//             _buildOptionTile(
//               icon: Icons.download,
//               title: 'Download',
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement download functionality
//               },
//               isDark: isDark,
//             ),
//             _buildOptionTile(
//               icon: Icons.share,
//               title: 'Share',
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement share functionality
//               },
//               isDark: isDark,
//             ),
//             const SizedBox(height: 16),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOptionTile({
//     required IconData icon,
//     required String title,
//     required VoidCallback onTap,
//     required bool isDark,
//   }) {
//     return ListTile(
//       leading: Icon(icon, color: isDark ? Colors.white : Colors.black87),
//       title: Text(
//         title,
//         style: GoogleFonts.poppins(
//           color: isDark ? Colors.white : Colors.black87,
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//       onTap: onTap,
//     );
//   }
// }
