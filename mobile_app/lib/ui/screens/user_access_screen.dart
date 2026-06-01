import 'package:flutter/material.dart';
import '../../viewmodels/user_access_viewmodel.dart';
import '../widgets/user_register_form.dart';

class UserAccessScreen extends StatefulWidget {
  const UserAccessScreen({super.key});

  @override
  State<UserAccessScreen> createState() => _UserAccessScreenState();
}

class _UserAccessScreenState extends State<UserAccessScreen> {
  final vm = UserAccessViewModel();

  final TextEditingController nameController = TextEditingController();
  String selectedRole = 'Viewer';

  @override
  void initState() {
    super.initState();
    vm.loadUsers();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _addUser() async {
    if (nameController.text.isEmpty) return;

    await vm.registerUser(nameController.text, selectedRole);
    nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('User Access Management'),
          ),

          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    UserRegisterForm(
                      onSubmit: (name, role) async {
                      await vm.registerUser(name, role);
                      },
                    ),

                    const Divider(),

                    // USER LIST
                    Expanded(
                      child: ListView.builder(
                        itemCount: vm.users.length,
                        itemBuilder: (context, index) {
                          final user = vm.users[index];

                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(user.name),
                            subtitle: Text(user.role),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => vm.deleteUser(user.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}