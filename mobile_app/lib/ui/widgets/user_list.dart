import 'package:flutter/material.dart';

import '../../domain/models/user.dart';
import '../../theme/app_spacing.dart';

class UserList extends StatelessWidget {
  final List<User> users;
  final bool Function({required String userId}) isDeleting;
  final Future<void> Function({required String id}) onDelete;

  const UserList({
    super.key,
    required this.users,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.group_off_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('No users registered yet'),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final user = users[index];
        final deleting = isDeleting(userId: user.id);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _subtitleFor(user),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete user',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: deleting ? null : () => onDelete(id: user.id),
                  icon: deleting
                      ? const SizedBox(
                          width: AppSpacing.xl,
                          height: AppSpacing.xl,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitleFor(User user) {
    final parts = <String>[
      user.role,
      if (user.email.isNotEmpty) user.email,
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
        user.phoneNumber!,
    ];

    return parts.where((part) => part.isNotEmpty).join(' - ');
  }
}
