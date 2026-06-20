import 'package:flutter/material.dart';

import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/user_access_viewmodel.dart';
import '../widgets/user_list.dart';
import '../widgets/user_register_form.dart';

class UserAccessScreen extends StatefulWidget {
  const UserAccessScreen({super.key});

  @override
  State<UserAccessScreen> createState() => _UserAccessScreenState();
}

class _UserAccessScreenState extends State<UserAccessScreen> {
  final UserAccessViewModel vm = UserAccessViewModel();

  @override
  void initState() {
    super.initState();
    vm.addListener(_showViewModelMessage);
    vm.loadUsers();
  }

  @override
  void dispose() {
    vm.removeListener(_showViewModelMessage);
    vm.dispose();
    super.dispose();
  }

  void _showViewModelMessage() {
    final message = vm.errorMessage ?? vm.successMessage;

    if (message == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      vm.clearMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final canPop = ModalRoute.of(context)?.canPop ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('User Access Management'),
            leading: canPop
                ? const BackButton()
                : IconButton(
                    icon: const Icon(Icons.home),
                    tooltip: 'Back to dashboard',
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.home);
                    },
                  ),
          ),
          body: vm.isLoading && vm.users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Provision and manage system users',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!vm.canManageUsers)
                        const Expanded(child: _AccessDeniedState())
                      else ...[
                        if (vm.roleOptions.isNotEmpty)
                          _RegisterFormHost(viewModel: vm),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: UserList(
                              users: vm.users,
                              isDeleting: vm.isDeleting,
                              onDelete: vm.deleteUser,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _RegisterFormHost extends StatefulWidget {
  final UserAccessViewModel viewModel;

  const _RegisterFormHost({required this.viewModel});

  @override
  State<_RegisterFormHost> createState() => _RegisterFormHostState();
}

class _RegisterFormHostState extends State<_RegisterFormHost> {
  final GlobalKey<UserRegisterFormState> _formKey =
      GlobalKey<UserRegisterFormState>();

  @override
  Widget build(BuildContext context) {
    return UserRegisterForm(
      key: _formKey,
      isSubmitting: widget.viewModel.isSubmitting,
      roleOptions: widget.viewModel.roleOptions,
      onSubmit:
          ({
            required String username,
            required String email,
            required String phoneNumber,
            required String password,
            required String role,
          }) async {
            final registered = await widget.viewModel.registerUser(
              username: username,
              email: email,
              phoneNumber: phoneNumber,
              password: password,
              role: role,
            );

            if (registered) {
              _formKey.currentState?.reset();
            }
          },
    );
  }
}

class _AccessDeniedState extends StatelessWidget {
  const _AccessDeniedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'User management access denied',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Only Owner and Manager accounts can manage users.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
