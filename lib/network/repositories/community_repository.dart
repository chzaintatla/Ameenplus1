import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/app_constants.dart';
import '../../models/community_model.dart';

class CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all communities
  Stream<List<CommunityModel>> getCommunities() {
    return _firestore
        .collection(AppConstants.collectionCommunities)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get user's joined communities
  Stream<List<CommunityModel>> getUserCommunities(String userId) {
    return _firestore
        .collection(AppConstants.collectionCommunities)
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommunityModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Join a community
  Future<void> joinCommunity(String communityId, String userId) async {
    await _firestore
        .collection(AppConstants.collectionCommunities)
        .doc(communityId)
        .update({
      'members': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Leave a community
  Future<void> leaveCommunity(String communityId, String userId) async {
    await _firestore
        .collection(AppConstants.collectionCommunities)
        .doc(communityId)
        .update({
      'members': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get community by ID
  Future<CommunityModel?> getCommunity(String communityId) async {
    final doc = await _firestore
        .collection(AppConstants.collectionCommunities)
        .doc(communityId)
        .get();
    
    if (!doc.exists) return null;
    return CommunityModel.fromFirestore(doc);
  }

  /// Check if user is member
  Future<bool> isMember(String communityId, String userId) async {
    final community = await getCommunity(communityId);
    return community?.members.contains(userId) ?? false;
  }

  /// Create a new community
  Future<void> createCommunity(CommunityModel community) async {
    await _firestore
        .collection(AppConstants.collectionCommunities)
        .doc(community.id)
        .set(community.toFirestore());
  }
}

