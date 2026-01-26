import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import '../models/community_support_model.dart';
import '../providers/community_provider.dart';
import '../utils/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inbox_screen.dart';
import 'chat_thread_screen.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommunityFacebookScreen extends StatefulWidget {
  const CommunityFacebookScreen({super.key});

  @override
  State<CommunityFacebookScreen> createState() => _CommunityFacebookScreenState();
}

class _CommunityFacebookScreenState extends State<CommunityFacebookScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isPosting = false;
  bool _showPostForm = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String _selectedCategory = 'general';
  final Map<String, bool> _expandedComments = {};
  final Map<String, TextEditingController> _commentControllers = {};
  bool _showOnlyMyPosts = false;
  
  final List<String> _categories = ['general', 'health_tip', 'medication_experience', 'exercise', 'diet', 'mental_health', 'elderly_care', 'family_support'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CommunityProvider>().loadPosts());
  }

  @override
  void dispose() {
    _postController.dispose();
    _scrollController.dispose();
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<CommunityProvider>();
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !provider.isLoadingMore && provider.hasMorePosts) {
      provider.loadMorePosts();
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty && _selectedImage == null) return;
    setState(() => _isPosting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? imageBase64;
      if (_selectedImage != null) {
        final bytes = _selectedImageBytes ?? await _selectedImage!.readAsBytes();
        String contentType = 'image/jpeg';
        final nameLower = _selectedImage!.name.toLowerCase();
        if (nameLower.endsWith('.png')) contentType = 'image/png';
        if (nameLower.endsWith('.webp')) contentType = 'image/webp';
        final encoded = base64Encode(bytes);
        imageBase64 = 'data:$contentType;base64,$encoded';
      }

      final post = CommunityPostModel(
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous User',
        userAvatar: user.photoURL ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=80&h=80&fit=crop&crop=face',
        userLocation: 'Health Community',
        content: _postController.text.trim(),
        imageUrl: null,
        imageBase64: imageBase64,
        category: _selectedCategory,
        timestamp: DateTime.now(),
        tags: _extractTags(_postController.text),
      );
      
      await context.read<CommunityProvider>().createPost(post);
      _postController.clear();
      setState(() { _selectedImage = null; _selectedImageBytes = null; _showPostForm = false; });
      _showSnackBar('Post created successfully!');
    } catch (e) {
      _showSnackBar('Error creating post: $e');
    } finally {
      setState(() => _isPosting = false);
    }
  }

  List<String> _extractTags(String text) {
    final tags = <String>[];
    final words = text.split(' ');
    for (final word in words) {
      if (word.startsWith('#') && word.length > 1) tags.add(word.substring(1));
    }
    return tags;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.bgGlassMedium,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(FeatherIcons.image, color: Colors.white), title: const Text('Gallery', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ListTile(leading: const Icon(FeatherIcons.camera, color: Colors.white), title: const Text('Camera', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final pickedFile = await picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 85);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() { _selectedImage = pickedFile; _selectedImageBytes = bytes; });
    }
  }

  void _toggleComments(String postId) {
    setState(() => _expandedComments[postId] = !(_expandedComments[postId] ?? false));
    if (_expandedComments[postId] == true) context.read<CommunityProvider>().loadComments(postId);
  }

  void _addComment(String postId) {
    final controller = _commentControllers[postId];
    if (controller != null && controller.text.trim().isNotEmpty) {
      context.read<CommunityProvider>().addComment(postId, controller.text.trim());
      controller.clear();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.primaryColor));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: Builder(builder: (context) => IconButton(icon: const Icon(FeatherIcons.menu, color: Colors.white), onPressed: () => Scaffold.of(context).openDrawer())),
            actions: [
              IconButton(icon: const Icon(FeatherIcons.inbox, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()))),
              IconButton(icon: Icon(_showPostForm ? FeatherIcons.x : FeatherIcons.plus, color: Colors.white), onPressed: () => setState(() => _showPostForm = !_showPostForm)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Community', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor.withOpacity(0.2), AppTheme.bgDark],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFilterChips(),
                  const SizedBox(height: 16),
                  if (_showPostForm) _buildCreatePostCard(),
                  Consumer<CommunityProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                      if (provider.posts.isEmpty) return _buildEmptyState();
                      final me = FirebaseAuth.instance.currentUser;
                      final visiblePosts = _showOnlyMyPosts && me != null ? provider.posts.where((p) => p.userId == me.uid).toList() : provider.posts;
                      return Column(children: visiblePosts.map((post) => _buildPostCard(post, provider)).toList());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showOnlyMyPosts = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_showOnlyMyPosts ? AppTheme.primaryColor : AppTheme.bgGlassMedium,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Center(child: Text("All Posts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showOnlyMyPosts = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _showOnlyMyPosts ? AppTheme.primaryColor : AppTheme.bgGlassMedium,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Center(child: Text("My Posts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatePostCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGlassMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _postController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: InputBorder.none,
            ),
            maxLines: 3,
          ),
          if (_selectedImageBytes != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_selectedImageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover)),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() { _selectedImage = null; _selectedImageBytes = null; }),
                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      dropdownColor: AppTheme.bgDarkSecondary,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ').toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(onPressed: _pickImage, icon: const Icon(FeatherIcons.image, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPosting ? null : _createPost,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: _isPosting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Post"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.bgGlassMedium, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(FeatherIcons.fileText, size: 48, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("No posts yet", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Be the first to share!", style: TextStyle(color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPostModel post, CommunityProvider provider) {
    final isLiked = provider.isPostLiked(post.id!);
    final showComments = _expandedComments[post.id!] ?? false;
    final comments = provider.comments[post.id!] ?? [];
    if (!_commentControllers.containsKey(post.id!)) _commentControllers[post.id!] = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppTheme.bgGlassMedium, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundImage: post.userAvatar.isNotEmpty ? NetworkImage(post.userAvatar) : null, child: post.userAvatar.isEmpty ? Text(post.userName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(DateFormat('MMM dd, HH:mm').format(post.timestamp), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text(post.category.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (post.content.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(post.content, style: const TextStyle(color: Colors.white))),
          if (post.imageBase64 != null && post.imageBase64!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_decodeBase64Image(post.imageBase64!), height: 200, width: double.infinity, fit: BoxFit.cover)),
            )
          else if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: post.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildActionButton(icon: FeatherIcons.heart, label: '${post.likes}', color: isLiked ? Colors.red : Colors.white54, onTap: () => provider.toggleLikePost(post.id!)),
                const SizedBox(width: 24),
                _buildActionButton(icon: FeatherIcons.messageCircle, label: '${comments.length}', color: Colors.white54, onTap: () => _toggleComments(post.id!)),
                const SizedBox(width: 24),
                _buildActionButton(icon: FeatherIcons.share2, label: 'Share', color: Colors.white54, onTap: () => provider.sharePost(post.id!)),
              ],
            ),
          ),
          if (showComments) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...comments.map((comment) => _buildComment(comment)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentControllers[post.id!],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _addComment(post.id!),
                        ),
                      ),
                      IconButton(onPressed: () => _addComment(post.id!), icon: Icon(FeatherIcons.send, color: AppTheme.primaryColor, size: 18)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Uint8List _decodeBase64Image(String dataUri) {
    try {
      final commaIndex = dataUri.indexOf(',');
      final base64Part = commaIndex != -1 ? dataUri.substring(commaIndex + 1) : dataUri;
      return base64Decode(base64Part);
    } catch (e) {
      return Uint8List(0);
    }
  }

  Widget _buildComment(CommunityCommentModel comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, backgroundColor: AppTheme.primaryColor.withOpacity(0.2), child: Text(comment.userName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(comment.content, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }
}