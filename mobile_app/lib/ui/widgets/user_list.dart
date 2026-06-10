import 'package:flutter/material.dart';

import '../../domain/models/user.dart';

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
      return const Center(child: Text('No users registered yet'));
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = users[index];
        final deleting = isDeleting(userId: user.id);

        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(user.name),
          subtitle: Text(_subtitleFor(user)),
          trailing: IconButton(
            tooltip: 'Delete user',
            onPressed: deleting ? null : () => onDelete(id: user.id),
            icon: deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
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
