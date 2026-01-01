import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_constants.dart';

class FollowRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      throw Exception('Cannot follow yourself');
    }

    await _firestore.collection('follows').doc('$followerId-$followingId').set({
      'followerId': followerId,
      'followingId': followingId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await Future.wait([
      _firestore.collection(AppConstants.collectionUsers).doc(followerId).update({
        'followingCount': FieldValue.increment(1),
      }),
      _firestore.collection(AppConstants.collectionUsers).doc(followingId).update({
        'followersCount': FieldValue.increment(1),
      }),
    ]);
  }

  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    await _firestore.collection('follows').doc('$followerId-$followingId').delete();

    await Future.wait([
      _firestore.collection(AppConstants.collectionUsers).doc(followerId).update({
        'followingCount': FieldValue.increment(-1),
      }),
      _firestore.collection(AppConstants.collectionUsers).doc(followingId).update({
        'followersCount': FieldValue.increment(-1),
      }),
    ]);
  }

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    final doc = await _firestore.collection('follows').doc('$followerId-$followingId').get();
    return doc.exists;
  }

  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followingId,
  }) {
    return _firestore
        .collection('follows')
        .doc('$followerId-$followingId')
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<List<String>> getFollowers(String userId) {
    return _firestore
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['followerId'] as String)
            .toList());
  }

  Stream<List<String>> getFollowing(String userId) {
    return _firestore
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['followingId'] as String)
            .toList());
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }
}

