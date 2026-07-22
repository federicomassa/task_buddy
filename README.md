# Task Buddy

A cross-platform (Web + Android) task, goal, and habit tracking app built with
Flutter, Riverpod, and Firebase (Firestore + Anonymous Auth).

## Setup

1. Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) and
   an existing Firebase project.
2. From the project root, run:

   ```
   flutterfire configure
   ```

   This overwrites `lib/firebase_options.dart` with your project's real
   configuration (it ships as a placeholder that throws until you do this).
3. In the Firebase console, enable **Anonymous** sign-in under
   Authentication > Sign-in method.
4. Deploy the Firestore security rules and indexes committed in this repo:

   ```
   firebase deploy --only firestore:rules,firestore:indexes
   ```

5. Run the app:

   ```
   flutter run -d chrome   # Web
   flutter run -d <device> # Android
   ```

## Architecture

- **State management:** `flutter_riverpod`, with `StreamProvider`s in
  `lib/providers/app_providers.dart` wrapping real-time Firestore queries.
- **Data models:** `lib/models/` — plain Dart classes with manual
  Firestore (de)serialization.
- **Data access:** `lib/services/` — one repository per Firestore collection,
  plus `HabitCycleService` (lazy per-period habit rollover) and
  `TaskRepository.toggleComplete` (transactional task/goal progress sync).
- **Features:** `lib/features/{dashboard,tasks,goals,categories,insights}` —
  one screen (and forms, where relevant) per feature area.
- **Shared widgets:** `lib/widgets/`.

See the top-level plan for the full data model and business logic spec.
