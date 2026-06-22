import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../widgets/screen_header.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const ProfileScreen({super.key, this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileViewModel _viewModel = ProfileViewModel();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  int? _loadedProfileId;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadProfile();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    if (!mounted) return;

    final profile = _viewModel.profile;
    if (profile != null && profile.id != _loadedProfileId) {
      _loadedProfileId = profile.id;
      _usernameController.text = profile.username;
      _emailController.text = profile.email;
      _phoneController.text = profile.phoneNumber ?? '';
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    final success = await _viewModel.updateProfile(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    _showResult(success);
  }

  Future<void> _changePassword() async {
    final success = await _viewModel.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (success) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }

    _showResult(success);
  }

  Future<void> _changeProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
    );

    if (image == null) return;

    final success = await _viewModel.uploadProfilePicture(File(image.path));
    _showResult(success);
  }

  Future<void> _registerFace() async {
    final source = await _showFaceImageSourceSheet();
    if (source == null) return;

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );

    if (image == null) return;

    final success = await _viewModel.registerFace(File(image.path));
    _showResult(success);
  }

  Future<ImageSource?> _showFaceImageSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Upload from Album'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showResult(bool success) {
    if (!mounted) return;

    final message = success
        ? _viewModel.successMessage
        : _viewModel.errorMessage ?? 'Profile action failed';

    if (message == null || message.isEmpty) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _viewModel.profile;

    if (_viewModel.isLoading && profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && profile == null) {
      return _ProfileLoadError(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadProfile,
      );
    }

    if (profile == null) {
      return const Center(child: Text('Profile unavailable'));
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const ScreenHeader(
            title: 'Profile',
            subtitle: 'Manage your account, password, and face registration',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileHeader(
            profile: profile,
            isSaving: _viewModel.isSaving,
            onChangePicture: _changeProfilePicture,
          ),
          const SizedBox(height: AppSpacing.lg),
          _MessagePanel(
            errorMessage: _viewModel.errorMessage,
            successMessage: _viewModel.successMessage,
            onDismiss: _viewModel.clearMessages,
          ),
          _UserDetailsCard(
            profile: profile,
            usernameController: _usernameController,
            emailController: _emailController,
            phoneController: _phoneController,
            isSaving: _viewModel.isSaving,
            onSave: _saveProfile,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FaceStatusCard(
            faceRegistered: profile.faceRegistered,
            isSaving: _viewModel.isSaving,
            onRegisterFace: _registerFace,
          ),
          const SizedBox(height: AppSpacing.lg),
          _AccountActions(
            isSaving: _viewModel.isSaving,
            currentPasswordController: _currentPasswordController,
            newPasswordController: _newPasswordController,
            confirmPasswordController: _confirmPasswordController,
            obscureCurrentPassword: _obscureCurrentPassword,
            obscureNewPassword: _obscureNewPassword,
            obscureConfirmPassword: _obscureConfirmPassword,
            onToggleCurrentPassword: () => setState(
              () => _obscureCurrentPassword = !_obscureCurrentPassword,
            ),
            onToggleNewPassword: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
            onToggleConfirmPassword: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            onChangePassword: _changePassword,
            onLogout: widget.onLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final bool isSaving;
  final VoidCallback onChangePicture;

  const _ProfileHeader({
    required this.profile,
    required this.isSaving,
    required this.onChangePicture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _ProfileAvatar(imageUrl: profile.profileImageUrl),
            const SizedBox(height: AppSpacing.md),
            Text(
              profile.username,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(profile.role, style: Theme.of(context).textTheme.bodySmall),
            if (profile.premiseName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Premise: ${profile.premiseName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: isSaving ? null : onChangePicture,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Upload Profile Picture'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;

  const _ProfileAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    if (url == null) {
      return const CircleAvatar(
        radius: AppSpacing.xxl,
        child: Icon(Icons.person, size: AppSpacing.xxl),
      );
    }

    return CircleAvatar(
      radius: AppSpacing.xxl,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }
}

class _UserDetailsCard extends StatelessWidget {
  final UserProfile profile;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final bool isSaving;
  final VoidCallback onSave;

  const _UserDetailsCard({
    required this.profile,
    required this.usernameController,
    required this.emailController,
    required this.phoneController,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'User Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: usernameController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: AppSpacing.md),
            _ReadOnlyProfileRow(label: 'Role', value: profile.role),
            _ReadOnlyProfileRow(
              label: 'Premise',
              value: profile.premiseName ?? 'Not assigned',
            ),
            _ReadOnlyProfileRow(
              label: 'Last Seen',
              value: _formatTimestamp(profile.lastSeen),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'Saving...' : 'Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Not available';
    final value = timestamp.toLocal().toString();
    return value.length > 16 ? value.substring(0, 16) : value;
  }
}

class _ReadOnlyProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceStatusCard extends StatelessWidget {
  final bool faceRegistered;
  final bool isSaving;
  final VoidCallback onRegisterFace;

  const _FaceStatusCard({
    required this.faceRegistered,
    required this.isSaving,
    required this.onRegisterFace,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = faceRegistered
        ? _safeColor(context)
        : _warningColor(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Face Recognition',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  faceRegistered ? Icons.verified : Icons.info_outline,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    faceRegistered
                        ? 'Face registration completed'
                        : 'Face registration not completed',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: isSaving ? null : onRegisterFace,
              icon: const Icon(Icons.face_retouching_natural),
              label: Text(faceRegistered ? 'Update Face' : 'Register Face'),
            ),
          ],
        ),
      ),
    );
  }

  Color _safeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;
  }

  Color _warningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.warningDark
        : AppColors.warning;
  }
}

class _AccountActions extends StatelessWidget {
  final bool isSaving;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final VoidCallback onToggleCurrentPassword;
  final VoidCallback onToggleNewPassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onChangePassword;
  final VoidCallback? onLogout;

  const _AccountActions({
    required this.isSaving,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureCurrentPassword,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.onToggleCurrentPassword,
    required this.onToggleNewPassword,
    required this.onToggleConfirmPassword,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Account Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _PasswordField(
              controller: currentPasswordController,
              label: 'Current Password',
              obscureText: obscureCurrentPassword,
              onToggleVisibility: onToggleCurrentPassword,
            ),
            const SizedBox(height: AppSpacing.md),
            _PasswordField(
              controller: newPasswordController,
              label: 'New Password',
              obscureText: obscureNewPassword,
              onToggleVisibility: onToggleNewPassword,
            ),
            const SizedBox(height: AppSpacing.md),
            _PasswordField(
              controller: confirmPasswordController,
              label: 'Confirm New Password',
              obscureText: obscureConfirmPassword,
              onToggleVisibility: onToggleConfirmPassword,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: isSaving ? null : onChangePassword,
              icon: isSaving
                  ? const SizedBox(
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset),
              label: Text(isSaving ? 'Saving...' : 'Change Password'),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: isSaving ? null : onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Show password' : 'Hide password',
          onPressed: onToggleVisibility,
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String? errorMessage;
  final String? successMessage;
  final VoidCallback onDismiss;

  const _MessagePanel({
    required this.errorMessage,
    required this.successMessage,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final message = errorMessage ?? successMessage;

    if (message == null) return const SizedBox.shrink();

    final isError = errorMessage != null;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.6)
        : _safeColor(context).withValues(alpha: 0.12);
    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : _safeColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: foregroundColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
              IconButton(
                tooltip: 'Dismiss message',
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _safeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;
  }
}

class _ProfileLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Unable to load profile',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
