import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/user.dart';
import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/user_access_viewmodel.dart';
import '../widgets/screen_header.dart';
import '../widgets/user_list.dart';
import '../widgets/user_register_form.dart';

class UserAccessScreen extends StatefulWidget {
  const UserAccessScreen({super.key});

  @override
  State<UserAccessScreen> createState() => _UserAccessScreenState();
}

class _UserAccessScreenState extends State<UserAccessScreen> {
  final UserAccessViewModel vm = UserAccessViewModel();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isModalOpen = false;

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
    if (_isModalOpen && vm.errorMessage != null) return;

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
                        child: const ScreenHeader(
                          title: 'User Management',
                          subtitle: 'Provision and manage system users',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                      ),
                      if (!vm.canManageUsers && vm.users.isEmpty)
                        const Expanded(child: _AccessDeniedState())
                      else ...[
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
                              isResettingPassword: vm.isResettingPasswordFor,
                              isRegisteringFace: vm.isRegisteringFaceFor,
                              isCurrentUser: vm.isCurrentUser,
                              canEdit: vm.canEditUser,
                              canDelete: vm.canDeleteUser,
                              canResetPassword: vm.canResetPassword,
                              canRegisterFace: vm.canRegisterFace,
                              onEdit: _showEditUserSheet,
                              onDelete: vm.deleteUser,
                              onResetPassword: _showResetPasswordDialog,
                              onRegisterFace: _showFaceSourceSheet,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          floatingActionButton: vm.canManageUsers && vm.roleOptions.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _showAddUserSheet,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add User'),
                )
              : null,
        );
      },
    );
  }

  Future<void> _showAddUserSheet() async {
    _isModalOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: vm,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          0,
                        ),
                        child: _InlineError(message: vm.errorMessage!),
                      ),
                    _RegisterFormHost(
                      viewModel: vm,
                      onRegistered: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _isModalOpen = false;
  }

  Future<void> _showEditUserSheet(User user) async {
    _isModalOpen = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: vm,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _EditUserForm(
                    user: user,
                    viewModel: vm,
                    onUpdated: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _isModalOpen = false;
  }

  Future<void> _showResetPasswordDialog(User user) async {
    _isModalOpen = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return _ResetPasswordDialog(
          user: user,
          viewModel: vm,
          onReset: () => Navigator.of(context).pop(),
        );
      },
    );

    _isModalOpen = false;
  }

  Future<void> _showFaceSourceSheet(User user) async {
    _isModalOpen = true;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.faceRegistered ? 'Update Face' : 'Register Face',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Choose a clear image with exactly one face.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    _isModalOpen = false;

    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) return;

      await vm.registerFaceForUser(id: user.id, imageFile: File(image.path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select image: $error')));
    }
  }
}

class _RegisterFormHost extends StatefulWidget {
  final UserAccessViewModel viewModel;
  final VoidCallback? onRegistered;

  const _RegisterFormHost({required this.viewModel, this.onRegistered});

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
              widget.onRegistered?.call();
            }
          },
    );
  }
}

class _EditUserForm extends StatefulWidget {
  final User user;
  final UserAccessViewModel viewModel;
  final VoidCallback onUpdated;

  const _EditUserForm({
    required this.user,
    required this.viewModel,
    required this.onUpdated,
  });

  @override
  State<_EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends State<_EditUserForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late String _role;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );
    _role = widget.user.normalizedRole;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = await widget.viewModel.updateUser(
      id: widget.user.id,
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      role: _role,
    );

    if (updated) {
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleOptions = widget.viewModel.roleOptionsForTarget(widget.user);
    final isUpdating = widget.viewModel.isUpdating(userId: widget.user.id);
    final isSelfEditing = widget.viewModel.isCurrentUser(widget.user);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit ${widget.user.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.viewModel.errorMessage != null) ...[
            _InlineError(message: widget.viewModel.errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter username';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter email';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          if (!isSelfEditing && roleOptions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: roleOptions.any((option) => option.value == _role)
                  ? _role
                  : roleOptions.first.value,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.security_outlined),
              ),
              items: roleOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: roleOptions.length <= 1
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _role = value);
                    },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating ? null : _submit,
                  child: isUpdating
                      ? const SizedBox(
                          width: AppSpacing.lg,
                          height: AppSpacing.lg,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final User user;
  final UserAccessViewModel viewModel;
  final VoidCallback onReset;

  const _ResetPasswordDialog({
    required this.user,
    required this.viewModel,
    required this.onReset,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final reset = await widget.viewModel.resetPassword(
      id: widget.user.id,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (reset) {
      widget.onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        return AlertDialog(
          title: Text('Reset ${widget.user.name} password'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.viewModel.errorMessage != null) ...[
                    _InlineError(message: widget.viewModel.errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        ),
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: widget.viewModel.isResettingPassword
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: widget.viewModel.isResettingPassword ? null : _submit,
              child: widget.viewModel.isResettingPassword
                  ? const SizedBox(
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset Password'),
            ),
          ],
        );
      },
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.errorContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
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
