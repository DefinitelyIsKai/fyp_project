# JobSeek – Part-Time Job Platform (Client & Admin)

This repository contains the Flutter implementation of **JobSeek**, a mobile-based part-time job platform
for **job seekers, recruiters, and administrators**. The system includes:

- **Client-side app** – for students/job seekers and employers to register, manage profiles, post jobs,
  search/apply, chat, manage bookings, and handle credits.
- **Admin-side module** – for managers/HR/staff to moderate posts and users, review reports, monitor
  messages, manage categories/tags, configure matching rules, and view analytics.

Both sides share the same Flutter codebase and Firebase backend (Firestore, Authentication, Cloud Functions, Storage, etc.).

## Prerequisites

- Flutter SDK installed (stable channel)
- A configured Firebase project (Web / Android / iOS)
- Firebase CLI (optional but recommended) if you want to deploy rules from the command line

## Firestore Security Rules (Must Implement for the Whole System)

The **entire JobSeek system (client + admin)** relies on a custom Firestore security model to protect:

- Authentication and **active user checks** (`isActive`, role, permissions)
- Role-based access control for admins (`manager`, `hr`, `staff`)
- Fine-grained permissions: `user_management`, `post_moderation`, `analytics`, `monitoring`,
  `system_config`, `message_oversight`, `role_management`
- Access to **users, posts, applications, job_matches, bookings, availability_slots**
- **Wallets & transactions**, pending_payments and credit flows
- **Reports & report_categories**, logs, and admin actions
- **Conversations & messages**, notifications, matching_rules, system_config, etc.

All these rules are defined in the root file: **`firestore.rules`**.

You **must** apply these rules to your Firebase project before running JobSeek against real data:

1. Make sure `firebase.json` is configured to use `firestore.rules` (or set this file in the Firebase Console).
2. Either:
   - Deploy via Firebase CLI: `firebase deploy --only firestore:rules`, **or**
   - Open Firebase Console → Firestore → **Rules**, and paste the full contents of `firestore.rules`.

Without these rules in Firestore, the **client and admin features (posting, applications, wallet, reports,
messaging, matching, analytics, etc.) are not protected and may not work as designed**.

## Getting Started (Flutter)

Typical Flutter commands:

- `flutter pub get` – install dependencies
- `flutter run` – run the app on a connected device or emulator
- `flutter build apk`– build release binaries

For more Flutter help, see the official documentation:

- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter cookbook](https://docs.flutter.dev/cookbook)
- [Full Flutter documentation](https://docs.flutter.dev/)
