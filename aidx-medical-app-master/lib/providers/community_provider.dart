import 'package:flutter/foundation.dart';
import '../models/community_support_model.dart';
import '../services/social_media_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommunityProvider extends ChangeNotifier {
  final SocialMediaService _socialService = SocialMediaService();
  
  List<CommunityPostModel> _posts = [];
  final Map<String, List<CommunityCommentModel>> _comments = {};
  final Map<String, bool> _expandedComments = {};
  final Map<String, bool> _likedPosts = {};
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  String _selectedCategory = '';
  
  // Getters
  List<CommunityPostModel> get posts => _posts;
  Map<String, List<CommunityCommentModel>> get comments => _comments;
  Map<String, bool> get expandedComments => _expandedComments;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;
  String get selectedCategory => _selectedCategory;
  
  bool isPostLiked(String postId) => _likedPosts[postId] ?? false;
  bool areCommentsExpanded(String postId) => _expandedComments[postId] ?? false;

  // Load posts
  Future<void> loadPosts({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    
    if (refresh) {
      _posts.clear();
      _hasMorePosts = true;
      _lastDocument = null;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await _socialService.getPosts(
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        limit: 10,
        lastDocument: refresh ? null : _lastDocument,
      );
      _lastDocument = result.lastDocument;
      final posts = result.posts;

      if (refresh) {
        _posts = posts;
      } else {
        _posts.addAll(posts);
      }
      
      // Update liked status using actual user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;
      
      for (final post in posts) {
        _likedPosts[post.id!] = currentUserId != null && post.likedBy.contains(currentUserId);
      }
      
      _hasMorePosts = posts.length >= 10;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading posts: $e');
      rethrow;
    }
  }

  // Load more posts
  Future<void> loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final result = await _socialService.getPosts(
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        limit: 10,
        lastDocument: _lastDocument,
      );
      _lastDocument = result.lastDocument;
      final posts = result.posts;

      if (posts.isEmpty) {
        _hasMorePosts = false;
        _isLoadingMore = false;
        notifyListeners();
        return;
      }
      
      _posts.addAll(posts);
      
      // Update liked status using actual user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;
      
      for (final post in posts) {
        _likedPosts[post.id!] = currentUserId != null && post.likedBy.contains(currentUserId);
      }
      
      _hasMorePosts = posts.length >= 10;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
      debugPrint('Error loading more posts: $e');
      rethrow;
    }
  }

  // Create post
  Future<void> createPost(CommunityPostModel post) async {
    try {
      await _socialService.createPost(post);
      await loadPosts(refresh: true);
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }

  // Like/unlike post
  Future<void> toggleLikePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      
      await _socialService.likePost(postId, currentUser.uid);
      
      // Update local state immediately for better UX
      _likedPosts[postId] = !(_likedPosts[postId] ?? false);
      notifyListeners();
      
      // Refresh posts to get updated counts
      await loadPosts(refresh: true);
    } catch (e) {
      debugPrint('Error toggling like: $e');
      rethrow;
    }
  }

  // Share post
  Future<void> sharePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      
      await _socialService.sharePost(postId, currentUser.uid);
      await loadPosts(refresh: true);
    } catch (e) {
      debugPrint('Error sharing post: $e');
      rethrow;
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      
      await _socialService.deletePost(postId, currentUser.uid);
      _posts.removeWhere((post) => post.id == postId);
      _comments.remove(postId);
      _expandedComments.remove(postId);
      _likedPosts.remove(postId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting post: $e');
      rethrow;
    }
  }

  // Load comments
  Future<void> loadComments(String postId) async {
    if (_comments.containsKey(postId)) return;
    
    try {
      final comments = await _socialService.getComments(postId);
      _comments[postId] = comments;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
  }

  // Add comment
  Future<void> addComment(String postId, String content) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      
      final comment = CommunityCommentModel(
        postId: postId,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'Anonymous User',
        content: content,
        timestamp: DateTime.now(),
      );
      
      await _socialService.createComment(comment);
      
      // Refresh comments
      await loadComments(postId);
      
      // Refresh posts to update comment count
      await loadPosts(refresh: true);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  // Toggle comments visibility
  void toggleComments(String postId) {
    _expandedComments[postId] = !(_expandedComments[postId] ?? false);
    
    if (_expandedComments[postId] == true) {
      loadComments(postId);
    }
    
    notifyListeners();
  }

  // Change category
  Future<void> changeCategory(String category) async {
    if (_selectedCategory == category) return;
    
    _selectedCategory = category;
    _posts.clear();
    _comments.clear();
    _expandedComments.clear();
    _likedPosts.clear();
    _hasMorePosts = true;
    _lastDocument = null;
    
    notifyListeners();
    await loadPosts(refresh: true);
  }

  // Clear all data
  void clearData() {
    _posts.clear();
    _comments.clear();
    _expandedComments.clear();
    _likedPosts.clear();
    _isLoading = false;
    _isLoadingMore = false;
    _hasMorePosts = true;
    notifyListeners();
  }
} 