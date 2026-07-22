import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/category_repository.dart';
import '../services/goal_repository.dart';
import '../services/habit_cycle_service.dart';
import '../services/habit_repository.dart';
import '../services/task_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in user's uid. Guarded by AuthGate, so this only resolves
/// once a user is present.
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw StateError('currentUserIdProvider read before authentication');
  }
  return user.uid;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(firestoreProvider));
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(firestoreProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(firestoreProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(firestoreProvider));
});

final habitCycleServiceProvider = Provider<HabitCycleService>((ref) {
  return HabitCycleService(
    ref.watch(habitRepositoryProvider),
    ref.watch(goalRepositoryProvider),
  );
});

final categoriesStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(categoryRepositoryProvider).streamCategories(userId);
});

final habitsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(habitRepositoryProvider).streamHabits(userId);
});

final standaloneGoalsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(goalRepositoryProvider).streamStandaloneGoals(userId);
});

final habitInstancesStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(goalRepositoryProvider).streamHabitInstances(userId);
});

final allGoalsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(goalRepositoryProvider).streamAllGoals(userId);
});

final tasksStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(taskRepositoryProvider).streamTasks(userId);
});
