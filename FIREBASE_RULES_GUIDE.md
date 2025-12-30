# Firebase Security Rules Guide

This document contains the complete Firestore and Storage security rules for the Ameen+ app.

## 📋 Files Included

1. **firestore.rules** - Firestore database security rules
2. **storage.rules** - Firebase Storage security rules

---

## 🚀 How to Deploy Rules

### Option 1: Using Firebase Console (Easiest)

#### Firestore Rules:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Copy contents from `firestore.rules`
5. Paste into the rules editor
6. Click **"Publish"**

#### Storage Rules:
1. Go to **Storage** → **Rules** tab
2. Copy contents from `storage.rules`
3. Paste into the rules editor
4. Click **"Publish"**

### Option 2: Using Firebase CLI

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init firestore
firebase init storage

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules
```

### Option 3: Using FlutterFire CLI

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (if not done)
flutterfire configure

# Rules are managed through Firebase Console or CLI
```

---

## 📖 Rules Explanation

### Firestore Rules

#### Users Collection
- **Read**: Users can read their own profile + public profiles
- **Write**: Users can only modify their own profile

#### Deeds Collection
- **Read**: All authenticated users can read deeds
- **Create**: Authenticated users can create deeds (must set userId to their own)
- **Update/Delete**: Only deed owner can modify/delete
- **Comments**: Similar rules apply to comments subcollection

#### Habits & Moods
- **Read/Write**: Users can only access their own habits/moods

#### Communities
- **Read**: All authenticated users can read communities
- **Create**: Authenticated users can create communities
- **Update**: Creator, admins, or members (for join/leave) can update
- **Delete**: Only creator can delete

#### Chats & Messages
- **Read**: Only participants can read chats
- **Create**: Users can create chats (must include themselves)
- **Messages**: Participants can send messages, sender can update/delete

#### Friend Requests
- **Read**: Users can read requests they sent/received
- **Create**: Users can send friend requests
- **Update**: Only receiver can accept/reject
- **Delete**: Sender or receiver can delete

#### Notifications
- **Read/Write**: Users can only access their own notifications

#### Leaderboard
- **Read**: Public (anyone can read)
- **Write**: Users can only update their own entry

---

### Storage Rules

#### Profile Pictures (`/profiles/{userId}/`)
- **Read**: Public
- **Write**: Only owner, max 2MB, images only

#### Deed Images (`/deeds/{deedId}/`)
- **Read**: Public
- **Write**: Authenticated users, max 5MB, images only

#### Community Images (`/communities/{communityId}/`)
- **Read**: Public
- **Write**: Authenticated users, max 5MB, images only

#### Chat Media (`/chats/{chatId}/`)
- **Read**: Authenticated users (participants)
- **Write**: Authenticated users, max 50MB, images/videos/audio

---

## ⚠️ Important Notes

### Security Considerations

1. **Test Mode**: The rules provided are for production use. If you're in test mode, Firebase allows all reads/writes temporarily.

2. **Notification Creation**: The current rules allow any authenticated user to create notifications. In production, you might want to restrict this to Cloud Functions only.

3. **Badge Creation**: Badge creation is currently open to authenticated users. Consider restricting to admins only.

4. **File Size Limits**: Storage rules include size limits. Adjust based on your needs:
   - Profile pictures: 2MB
   - Deed/Community images: 5MB
   - Chat media: 50MB

5. **Content Type Validation**: Storage rules validate content types. Adjust regex patterns if needed.

### Testing Rules

You can test rules using Firebase Console:

1. Go to **Firestore Database** → **Rules** tab
2. Click **"Rules Playground"**
3. Select collection/document
4. Choose operation (read/write)
5. Set authentication context
6. Test the rule

---

## 🔧 Customization

### Making Communities Private

To make communities private (only members can read):

```javascript
match /communities/{communityId} {
  allow read: if isAuthenticated() && (
    resource.data.isPublic == true ||
    request.auth.uid in resource.data.members
  );
  // ... rest of rules
}
```

### Restricting Notification Creation

To restrict notification creation to Cloud Functions only:

```javascript
match /notifications/{notificationId} {
  allow create: if false; // Only Cloud Functions can create
  // ... rest of rules
}
```

### Adding Admin Role

To add admin capabilities:

```javascript
function isAdmin() {
  return isAuthenticated() && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
}

// Then use in rules:
allow delete: if isAdmin() || isOwner(userId);
```

---

## 📝 Rules Checklist

Before deploying to production:

- [ ] Review all rules for your use case
- [ ] Test rules in Rules Playground
- [ ] Verify file size limits are appropriate
- [ ] Check content type validations
- [ ] Ensure admin-only operations are restricted
- [ ] Test with real user scenarios
- [ ] Monitor Firebase Console for rule violations
- [ ] Set up alerts for security issues

---

## 🐛 Troubleshooting

### Error: "Missing or insufficient permissions"

**Causes:**
1. User not authenticated
2. Rule doesn't allow the operation
3. Field validation failed

**Solutions:**
1. Check if user is logged in
2. Review the rule for that collection
3. Verify request data matches rule conditions

### Error: "Resource data is undefined"

**Cause:** Trying to access `resource.data` on a document that doesn't exist

**Solution:** Use `exists()` check or handle creation separately:
```javascript
allow read: if !exists(/databases/$(database)/documents/path/to/doc) || 
  (exists(/databases/$(database)/documents/path/to/doc) && 
   resource.data.field == value);
```

### Rules Not Updating

**Solution:**
1. Clear browser cache
2. Wait a few minutes (rules can take time to propagate)
3. Redeploy rules via CLI

---

## 📚 Additional Resources

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Storage Security Rules Documentation](https://firebase.google.com/docs/storage/security)
- [Rules Testing Guide](https://firebase.google.com/docs/firestore/security/test-rules)
- [Common Rules Patterns](https://firebase.google.com/docs/firestore/security/rules-conditions)

---

## ✅ Summary

The provided rules:
- ✅ Protect user data (users can only access their own data)
- ✅ Allow public read for deeds and communities
- ✅ Secure chat and messaging
- ✅ Protect file uploads with size/type limits
- ✅ Enable friend requests and notifications
- ✅ Support leaderboard functionality

**Next Steps:**
1. Copy rules to Firebase Console
2. Test in Rules Playground
3. Deploy rules
4. Test app functionality
5. Monitor for any permission errors

Good luck! 🚀

