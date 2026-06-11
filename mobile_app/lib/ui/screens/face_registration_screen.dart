import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/user.dart';
import '../../viewmodels/face_registration_viewmodel.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final FaceRegistrationViewModel _viewModel = FaceRegistrationViewModel();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadUsers();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );

    if (image == null) return;

    _viewModel.setImage(File(image.path));
  }

  Future<void> _registerFace() async {
    await _viewModel.registerFace();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Registration')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_viewModel.isLoadingUsers && _viewModel.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MessagePanel(
          errorMessage: _viewModel.errorMessage,
          successMessage: _viewModel.successMessage,
          onDismiss: _viewModel.clearMessages,
        ),
        _UserSelector(
          users: _viewModel.users,
          selectedUser: _viewModel.selectedUser,
          currentUserId: _viewModel.currentUserId,
          isLoading: _viewModel.isLoadingUsers,
          onChanged: (user) {
            if (user == null) return;
            _viewModel.selectUser(user);
          },
          onRefresh: _viewModel.loadUsers,
        ),
        const SizedBox(height: 16),
        _ImageActions(
          onCameraPressed: () => _pickImage(ImageSource.camera),
          onGalleryPressed: () => _pickImage(ImageSource.gallery),
        ),
        const SizedBox(height: 16),
        _ImagePreview(image: _viewModel.selectedImage),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _viewModel.isLoading ? null : _registerFace,
            icon: _viewModel.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.face_retouching_natural),
            label: Text(
              _viewModel.isLoading ? 'Registering...' : 'Register Face',
            ),
          ),
        ),
      ],
    );
  }
}

class _UserSelector extends StatelessWidget {
  final List<User> users;
  final User? selectedUser;
  final String? currentUserId;
  final bool isLoading;
  final ValueChanged<User?> onChanged;
  final VoidCallback onRefresh;

  const _UserSelector({
    required this.users,
    required this.selectedUser,
    required this.currentUserId,
    required this.isLoading,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select User',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: isLoading ? null : onRefresh,
              tooltip: 'Refresh users',
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<User>(
          initialValue: selectedUser,
          decoration: const InputDecoration(
            labelText: 'User profile',
            border: OutlineInputBorder(),
          ),
          items: users
              .map(
                (user) => DropdownMenuItem<User>(
                  value: user,
                  child: Text(
                    _userLabel(user, currentUserId),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: users.isEmpty ? null : onChanged,
        ),
        if (users.isEmpty && !isLoading) ...[
          const SizedBox(height: 8),
          const Text('No users available.'),
        ],
      ],
    );
  }

  String _userLabel(User user, String? currentUserId) {
    final role = user.role.isEmpty ? 'No role' : user.role;
    final youLabel = user.id == currentUserId ? ' (You)' : '';
    return '${user.name}$youLabel ($role)';
  }
}

class _ImageActions extends StatelessWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;

  const _ImageActions({
    required this.onCameraPressed,
    required this.onGalleryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCameraPressed,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Capture'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onGalleryPressed,
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose'),
          ),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File? image;

  const _ImagePreview({required this.image});

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;

    if (selectedImage == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No face image selected'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        selectedImage,
        height: 260,
        width: double.infinity,
        fit: BoxFit.cover,
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

    if (message == null) {
      return const SizedBox.shrink();
    }

    final isError = errorMessage != null;
    final color = isError ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss message',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
