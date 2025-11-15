# Role-Based Access Control Setup

## Overview
Your Firestore security rules now restrict access to the `users` collection so that **only users with "HR" or "manager" roles** can access user data.

## Requirements

### 1. Firebase Authentication
You need to implement Firebase Authentication. The security rules check `request.auth.uid` to identify the logged-in user.

### 2. Admins Collection in Firestore
You need to create an `admins` collection in Firestore that stores admin user roles.

## Setup Steps

### Step 1: Add Firebase Authentication Package

Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_auth: ^5.0.0
```

Then run:
```bash
flutter pub get
```

### Step 2: Create Admins Collection in Firestore

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **finalyearproject-20e7f**
3. Go to **Firestore Database**
4. Click **Start collection** (if you don't have one)
5. Collection ID: `admins`
6. Add a document with:
   - **Document ID**: Use the Firebase Auth UID of the admin user
   - **Fields**:
     - `role` (string): Set to `"HR"` or `"manager"`
     - `email` (string): Admin's email
     - `name` (string): Admin's name
     - `isActive` (boolean): `true`
     - `createdAt` (timestamp): Current date

### Step 3: Example Admin Document Structure

```json
{
  "role": "HR",
  "email": "hr@jobseek.com",
  "name": "HR Manager",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

Or for a manager:
```json
{
  "role": "manager",
  "email": "manager@jobseek.com",
  "name": "Manager",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Step 4: Update Your Auth Service

You'll need to update `lib/services/auth_service.dart` to use Firebase Authentication instead of dummy authentication.

### Step 5: Deploy Security Rules

1. Go to Firebase Console → Firestore Database → Rules
2. Copy the contents of `firestore.rules`
3. Paste into the rules editor
4. Click **Publish**

## How It Works

1. User logs in via Firebase Authentication
2. Security rules check if `request.auth.uid` exists in the `admins` collection
3. Rules verify the `role` field is either `"HR"` or `"manager"`
4. If both conditions are met, access is granted to the `users` collection

## Testing

1. Create an admin document in Firestore with role "HR" or "manager"
2. Log in with that user's Firebase Auth account
3. Try to access user data - it should work
4. Try with a user who doesn't have HR/manager role - access should be denied

## Temporary Development Access

If you need to test without Firebase Auth first, you can use the `firestore.rules.dev` file:

1. Copy `firestore.rules.dev` to `firestore.rules`
2. Deploy to Firebase Console
3. This will allow all access temporarily

**⚠️ Remember to switch back to the production rules (with HR/manager restrictions) once you implement Firebase Authentication!**

## Quick Summary

✅ **What's Done:**
- Security rules created to restrict access to HR and manager roles only
- Rules file ready to deploy

⏳ **What You Need to Do:**
1. Implement Firebase Authentication in your app
2. Create `admins` collection in Firestore with HR/manager roles
3. Deploy the security rules to Firebase
4. Test with users who have HR/manager roles

