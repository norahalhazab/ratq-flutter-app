import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';
import 'chat_thread_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your inbox.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Blood'),
                  Tab(text: 'Community'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConversationsList(currentUser.uid, category: 'blood'),
                    _buildConversationsList(currentUser.uid, category: 'community'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList(String currentUserId, {required String category}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_conversations')
          .where('participants', arrayContains: currentUserId)
          // Removed orderBy to avoid index requirement errors
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load conversations. Please check your connection and permissions.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No conversations yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        // Client-side filter by category (optional metadata.category)
        final allDocs = snapshot.data!.docs;
        final filtered = allDocs.where((d) => (d['metadata'] != null ? (d['metadata']['category'] ?? 'blood') : 'blood') == category).toList();
        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No conversations yet',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        // Sort by lastMessageTime descending client-side
        filtered.sort((a, b) {
          final aTs = a['lastMessageTime'];
          final bTs = b['lastMessageTime'];
          final aDate = aTs is Timestamp ? aTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = bTs is Timestamp ? bTs.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
          });
        final chats = List<QueryDocumentSnapshot>.from(filtered);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = chats[index].data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final peerId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            final lastMessage = (data['lastMessage'] ?? '') as String;
            final lastTs = data['lastMessageTime'];
            final lastTime = lastTs is Timestamp ? lastTs.toDate() : null;

            if (peerId.isEmpty) {
              return const SizedBox.shrink();
            }

            final participantNames = Map<String, dynamic>.from(data['participantNames'] ?? {});
            String displayName = (participantNames[peerId] as String?) ?? '';
            final isUnread = (data['unreadCount'] ?? 0) > 0;

            return _InboxItem(
              peerId: peerId,
              peerDisplayName: displayName,
              lastMessage: lastMessage,
              lastTime: lastTime,
              isUnread: isUnread,
              onTap: (peerName) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      currentUserId: currentUserId,
                      peerId: peerId,
                      peerName: peerName,
                      category: category,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: AppTheme.glassContainer,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
              decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              ),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.inbox,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
                  Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'Inbox',
                  style: AppTheme.headlineMedium.copyWith(
                    fontSize: 20,
                        fontWeight: FontWeight.bold,
                  ),
                      ),
                const Text(
                  'Your conversations',
                  style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxItem extends StatelessWidget {
  final String peerId;
  final String peerDisplayName;
  final String lastMessage;
  final DateTime? lastTime;
  final bool isUnread;
  final void Function(String peerName) onTap;

  const _InboxItem({
    required this.peerId,
    required this.peerDisplayName,
    required this.lastMessage,
    required this.lastTime,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(peerDisplayName.isNotEmpty ? peerDisplayName : 'User'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgGlassMedium,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.accentColor,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  (peerDisplayName.isNotEmpty ? peerDisplayName[0] : 'U').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerDisplayName.isNotEmpty ? peerDisplayName : 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (lastTime != null)
                  Text(
                    '${lastTime!.hour.toString().padLeft(2, '0')}:${lastTime!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

