import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../network/repositories/follow_repository.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final int initialTab;

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FollowRepository _followRepo = FollowRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Followers & Following'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersTab(context, mediaQuery, currentUser?.uid),
          _buildFollowingTab(context, mediaQuery, currentUser?.uid),
        ],
      ),
    );
  }

  Widget _buildFollowersTab(BuildContext context, MediaQueryData mediaQuery, String? currentUserId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _followRepo.watchFollowers(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final followers = snapshot.data ?? [];
        
        return _buildFollowersList(context, mediaQuery, currentUserId, followers);
      },
    );
  }

  Widget _buildFollowersList(BuildContext context, MediaQueryData mediaQuery, String? currentUserId, List<Map<String, dynamic>> followers) {
    if (followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            const Text('No followers yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
      itemCount: followers.length,
      itemBuilder: (context, index) {
        final user = followers[index];
        final userId = user['id'] as String;
        final displayName = user['display_name'] as String? ?? 'User';
        final photoUrl = user['photo_url'] as String?;
        final isCurrentUser = userId == currentUserId;

        return Card(
          margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(displayName),
            subtitle: Text(_getSafeEmail(user, currentUserId)),
            trailing: isCurrentUser
                ? null
                : _buildFollowButton(context, currentUserId ?? '', userId),
          ),
        );
      },
    );
  }

  Widget _buildFollowingTab(BuildContext context, MediaQueryData mediaQuery, String? currentUserId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _followRepo.watchFollowing(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final following = snapshot.data ?? [];
        
        return _buildFollowingList(context, mediaQuery, currentUserId, following);
      },
    );
  }

  Widget _buildFollowingList(BuildContext context, MediaQueryData mediaQuery, String? currentUserId, List<Map<String, dynamic>> following) {
    if (following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: mediaQuery.size.height * 0.02),
            const Text('Not following anyone yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(mediaQuery.size.width * 0.04),
      itemCount: following.length,
      itemBuilder: (context, index) {
        final user = following[index];
        final userId = user['id'] as String;
        final displayName = user['display_name'] as String? ?? 'User';
        final photoUrl = user['photo_url'] as String?;
        final isCurrentUser = userId == currentUserId;

        return Card(
          margin: EdgeInsets.only(bottom: mediaQuery.size.height * 0.01),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(displayName),
            subtitle: Text(_getSafeEmail(user, currentUserId)),
            trailing: isCurrentUser
                ? null
                : _buildFollowButton(context, currentUserId ?? '', userId),
          ),
        );
      },
    );
  }

  Widget _buildFollowButton(BuildContext context, String currentUserId, String targetUserId) {
    if (currentUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _followRepo.isFollowing(currentUserId, targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final isFollowing = snapshot.data ?? false;
        
        return TextButton(
          onPressed: () async {
            try {
              if (isFollowing) {
                await _followRepo.unfollowUser(currentUserId, targetUserId);
              } else {
                await _followRepo.followUser(currentUserId, targetUserId);
              }
              setState(() {}); // Refresh the button state
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          },
          child: Text(isFollowing ? 'Following' : 'Follow'),
        );
      },
    );
  }

  String _getSafeEmail(Map<String, dynamic> user, String? currentUserId) {
    final userId = user['id'] as String?;
    final email = user['email'] as String?;
    final isEmailPublic = (user['is_email_public'] ?? user['isEmailPublic']) as bool? ?? false;
    
    if (email == null || email.isEmpty) return '';
    if (currentUserId == null) return 'Email hidden';
    if (userId == currentUserId) return email;
    if (!isEmailPublic) return 'Email hidden';
    return email;
  }
}
