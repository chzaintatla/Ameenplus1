# Security Documentation

## Overview
This document outlines the security measures implemented in the Ameen+ application to protect user data and ensure secure operations.

## Authentication & Authorization

### Firebase Authentication
- All authentication is handled through Firebase Auth
- Supports multiple authentication methods:
  - Email/Password (with strong password requirements)
  - Google Sign-In
  - Facebook Sign-In
  - Phone Number (OTP)

### Password Requirements
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- Passwords are never stored locally or in logs

## Firestore Security Rules

### Users Collection
- Users can only read their own complete profile
- Other users can only read public profiles
- Email and phone numbers are protected by privacy flags
- Users can only create/update/delete their own profile

### Deeds (Posts) Collection
- Authenticated users can read all deeds
- Only deed owners can create, update, or delete their deeds
- Comments are restricted to authenticated users
- Comment owners can delete their own comments

### Habits Collection
- Users can only access their own habits
- Strict ownership validation on all operations

### Chats Collection
- Only chat participants can access chat data
- Community chats are accessible to all community members
- Messages can only be sent by authenticated participants
- Message deletion restricted to sender

### Follows Collection
- Users can only read follows where they are involved
- Users can only create follows for themselves
- Users can only delete their own follows
- Prevents self-following

### Communities Collection
- Public communities are readable by all authenticated users
- Only creators and admins can modify communities
- Members can join/leave communities

## Storage Security Rules

### Profile Pictures
- Public read access
- Only owners can upload/delete
- 2MB size limit
- Image files only

### Deed Images
- Public read access
- Authenticated users can upload
- 5MB size limit
- Image files only

### Chat Media
- **SECURED**: Only chat participants can access
- Participants verified through Firestore chat document
- 50MB size limit
- Supports images, videos, audio, and documents

## Data Privacy

### Email Privacy
- Email addresses are hidden by default
- Users can make email public through privacy settings
- Email visibility controlled by `isEmailPublic` flag
- Filtered at application level for non-owners

### Phone Number Privacy
- Phone numbers are hidden by default
- Users can make phone public through privacy settings
- Phone visibility controlled by `isPhonePublic` flag
- Filtered at application level for non-owners

### Profile Privacy
- Users can set profile to public or private
- Private profiles only show basic information (name, photo)
- Public profiles show additional details based on privacy flags

## Input Validation & Sanitization

### Security Utilities (`lib/utils/security_utils.dart`)
- **Input Sanitization**: Removes HTML tags, JavaScript, and event handlers
- **Email Validation**: Regex-based email format validation
- **Phone Validation**: International phone number format validation
- **Password Strength**: Validates password complexity
- **Display Name Validation**: Prevents special characters and length limits
- **URL Validation**: Validates and sanitizes URLs

### Data Filtering
- Sensitive data filtered based on:
  - User ownership
  - Privacy settings (isEmailPublic, isPhonePublic, isProfilePublic)
  - Authentication status

## API Keys & Secrets

### Current Status
- Firebase API keys are in `firebase_options.dart` (generated file)
- These keys are safe for client-side use (Firebase handles this)
- No server-side secrets are stored in the app

### Best Practices
- Never commit production API keys to version control
- Use environment variables for sensitive configuration
- Rotate keys regularly
- Monitor API key usage in Firebase Console

## Data Encryption

### In Transit
- All Firebase communications use HTTPS/TLS
- All API calls are encrypted

### At Rest
- Firebase handles encryption at rest
- Local SQLite database stores non-sensitive cached data only
- No passwords or tokens stored locally

## Security Best Practices Implemented

1. **Authentication Required**: Most operations require authentication
2. **Ownership Validation**: Users can only modify their own data
3. **Privacy Controls**: Granular privacy settings for sensitive data
4. **Input Validation**: All user inputs are validated and sanitized
5. **Size Limits**: File uploads have size restrictions
6. **Content Type Validation**: Only allowed file types can be uploaded
7. **Error Handling**: Generic error messages prevent information leakage
8. **Rate Limiting**: Consider implementing rate limiting for production

## Security Checklist

- [x] Firestore security rules implemented
- [x] Storage security rules implemented
- [x] Input validation and sanitization
- [x] Privacy controls for sensitive data
- [x] Password strength requirements
- [x] Authentication required for sensitive operations
- [x] Ownership validation on all write operations
- [x] Data filtering based on privacy settings
- [ ] Rate limiting (recommended for production)
- [ ] Security audit logging (recommended)
- [ ] Penetration testing (recommended)

## Recommendations for Production

1. **Enable App Check**: Use Firebase App Check to prevent abuse
2. **Implement Rate Limiting**: Add rate limiting for API calls
3. **Security Monitoring**: Set up Firebase Security Rules monitoring
4. **Regular Audits**: Conduct regular security audits
5. **Update Dependencies**: Keep all dependencies up to date
6. **Error Logging**: Implement secure error logging (avoid logging sensitive data)
7. **Backup Strategy**: Implement secure backup and recovery procedures

## Reporting Security Issues

If you discover a security vulnerability, please report it responsibly:
1. Do not open a public issue
2. Contact the development team directly
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be addressed before disclosure

## Compliance

- **GDPR**: User data privacy controls implemented
- **Data Minimization**: Only necessary data is collected
- **User Rights**: Users can control their data visibility
- **Data Deletion**: Users can delete their accounts and data

---

**Last Updated**: 2026-01-01
**Version**: 1.0.0

