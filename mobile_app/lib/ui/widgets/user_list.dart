import 'package:flutter/material.dart';

import '../../domain/models/user.dart';
import '../../theme/app_spacing.dart';

class UserList extends StatelessWidget {
  final List<User> users;
  final bool Function({required String userId}) isDeleting;
  final bool Function({required String userId}) isResettingPassword;
  final bool Function({required String userId}) isRegisteringFace;
  final bool Function(User user) isCurrentUser;
  final bool Function(User user) canEdit;
  final bool Function(User user) canDelete;
  final bool Function(User user) canResetPassword;
  final bool Function(User user) canRegisterFace;
  final Future<void> Function(User user) onEdit;
  final Future<void> Function({required String id}) onDelete;
  final Future<void> Function(User user) onResetPassword;
  final Future<void> Function(User user) onRegisterFace;

  const UserList({
    super.key,
    required this.users,
    required this.isDeleting,
    required this.isResettingPassword,
    required this.isRegisteringFace,
    required this.isCurrentUser,
    required this.canEdit,
    required this.canDelete,
    required this.canResetPassword,
    required this.canRegisterFace,
    required this.onEdit,
    required this.onDelete,
    required this.onResetPassword,
    required this.onRegisterFace,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 4),
      itemCount: users.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final user = users[index];
        final deleting = isDeleting(userId: user.id);
        final resettingPassword = isResettingPassword(userId: user.id);
        final registeringFace = isRegisteringFace(userId: user.id);
        final currentUser = isCurrentUser(user);
        final isProtectedOwner = user.isOwner;
        final canEditUser = canEdit(user);
        final canDeleteUser = canDelete(user);
        final canResetUserPassword = canResetPassword(user);
        final canRegisterUserFace = canRegisterFace(user);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          if (currentUser) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _CurrentUserBadge(),
                          ],
                          if (isProtectedOwner) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _PrimaryOwnerBadge(),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _subtitleFor(user),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _FaceStatusBadge(registered: user.faceRegistered),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      IconButton(
                        tooltip: isProtectedOwner && !currentUser
                            ? 'Primary Owner is protected'
                            : 'Edit user',
                        onPressed: canEditUser ? () => onEdit(user) : null,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: currentUser
                            ? 'Change your password from Profile'
                            : isProtectedOwner
                            ? 'Primary Owner password is protected'
                            : 'Reset password',
                        onPressed: resettingPassword || !canResetUserPassword
                            ? null
                            : () => onResetPassword(user),
                        icon: resettingPassword
                            ? const SizedBox(
                                width: AppSpacing.xl,
                                height: AppSpacing.xl,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_reset),
                      ),
                      IconButton(
                        tooltip: isProtectedOwner && !currentUser
                            ? 'Primary Owner face is managed from Profile'
                            : user.faceRegistered
                            ? 'Update face'
                            : 'Register face',
                        onPressed: registeringFace || !canRegisterUserFace
                            ? null
                            : () => onRegisterFace(user),
                        icon: registeringFace
                            ? const SizedBox(
                                width: AppSpacing.xl,
                                height: AppSpacing.xl,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                user.faceRegistered
                                    ? Icons.face_retouching_natural
                                    : Icons.add_a_photo_outlined,
                              ),
                      ),
                      IconButton(
                        tooltip: currentUser
                            ? 'You cannot delete your own account'
                            : isProtectedOwner
                            ? 'Primary Owner is protected'
                            : 'Delete user',
                        color: Theme.of(context).colorScheme.error,
                        onPressed: deleting || !canDeleteUser
                            ? null
                            : () => onDelete(id: user.id),
                        icon: deleting
                            ? const SizedBox(
                                width: AppSpacing.xl,
                                height: AppSpacing.xl,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
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
      user.roleLabel,
      if (user.email.isNotEmpty) user.email,
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
        user.phoneNumber!,
    ];

    return parts.where((part) => part.isNotEmpty).join(' - ');
  }
}

class _CurrentUserBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Current User',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FaceStatusBadge extends StatelessWidget {
  final bool registered;

  const _FaceStatusBadge({required this.registered});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = registered ? colorScheme.tertiary : colorScheme.outline;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          registered ? Icons.verified_outlined : Icons.face_outlined,
          size: AppSpacing.lg,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          registered ? 'Face registered' : 'Face not registered',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PrimaryOwnerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: AppSpacing.lg,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Primary Owner',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
