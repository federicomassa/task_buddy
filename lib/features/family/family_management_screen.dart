import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'join_family_screen.dart';

class FamilyManagementScreen extends ConsumerWidget {
  const FamilyManagementScreen({super.key});

  Future<void> _createFamily(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    final email = ref.read(authServiceProvider).currentUser?.email ?? '';
    try {
      await ref.read(familyRepositoryProvider).createFamily(userId, email);
    } catch (e) {
      if (context.mounted) ref.read(errorReporterProvider).report(e);
    }
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref, String familyId) async {
    final userId = ref.read(currentUserIdProvider);
    try {
      final code = await ref.read(familyRepositoryProvider).createInvite(familyId, userId);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Invite code'),
          content: SelectableText(code),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Copy & close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) ref.read(errorReporterProvider).report(e);
    }
  }

  Future<void> _leaveFamily(BuildContext context, WidgetRef ref, String familyId) async {
    final userId = ref.read(currentUserIdProvider);
    try {
      await ref.read(familyRepositoryProvider).leaveFamily(userId: userId, familyId: familyId);
    } catch (e) {
      if (context.mounted) ref.read(errorReporterProvider).report(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyIdAsync = ref.watch(myFamilyIdStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: familyIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (familyId) {
          if (familyId == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('You are not part of a family yet.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _createFamily(context, ref),
                    child: const Text('Create a family'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinFamilyScreen()),
                    ),
                    child: const Text('Join with an invite code'),
                  ),
                ],
              ),
            );
          }

          final familyAsync = ref.watch(myFamilyStreamProvider);
          return familyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Error: $err')),
            data: (family) {
              if (family == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final members = family.members.entries.toList();
              return ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  for (final entry in members)
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(entry.value.email),
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: const Text('Invite a member'),
                    subtitle: const Text('Generate a shareable code'),
                    onTap: () => _createInvite(context, ref, family.id),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Leave family'),
                    onTap: () => _leaveFamily(context, ref, family.id),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
