import 'package:flutter/material.dart';

class UserRegisterForm extends StatefulWidget {
  final Future<void> Function(String name, String role) onSubmit;

  const UserRegisterForm({
    super.key,
    required this.onSubmit,
  });

  @override
  State<UserRegisterForm> createState() => _UserRegisterFormState();
}

class _UserRegisterFormState extends State<UserRegisterForm> {
  final TextEditingController nameController = TextEditingController();

  String selectedRole = 'Viewer';
  bool isLoading = false;

  final List<String> roles = [
    'Admin',
    'Operator',
    'Viewer',
    'Guest',
  ];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (nameController.text.isEmpty) return;

    setState(() => isLoading = true);

    await widget.onSubmit(
      nameController.text,
      selectedRole,
    );

    setState(() {
      isLoading = false;
      nameController.clear();
      selectedRole = 'Viewer';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Register New User",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedRole,
              items: roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Create User"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}