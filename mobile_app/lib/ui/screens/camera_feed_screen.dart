import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../domain/models/security_camera.dart';
import '../../viewmodels/camera_feed_viewmodel.dart';
import '../widgets/camera_widget.dart';
import '../widgets/screen_header.dart';

class CameraFeedScreen extends StatefulWidget {
  final bool showAppBar;
  final CameraFeedViewModel? viewModel;

  const CameraFeedScreen({super.key, this.showAppBar = false, this.viewModel});

  @override
  State<CameraFeedScreen> createState() => _CameraFeedScreenState();
}

class _CameraFeedScreenState extends State<CameraFeedScreen> {
  late final CameraFeedViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? CameraFeedViewModel();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadCameraSession();
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
    final message = _viewModel.successMessage;
    if (message != null) {
      _viewModel.clearMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = RefreshIndicator(
      onRefresh: _viewModel.loadCameraSession,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: ScreenHeader(
                  title: 'Camera Feed',
                  subtitle: _viewModel.jwtToken == null
                      ? 'Waiting for secure session'
                      : 'Secure live stream ready',
                  icon: Icons.videocam_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Refresh camera session',
                onPressed: _viewModel.isLoading
                    ? null
                    : _viewModel.loadCameraSession,
                color: colorScheme.primary,
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        width: AppSpacing.xl,
                        height: AppSpacing.xl,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              if (_viewModel.canManage)
                IconButton(
                  tooltip: 'Add camera',
                  onPressed: _showAddCameraDialog,
                  icon: const Icon(Icons.add_circle_outline),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_viewModel.errorMessage != null) ...[
            _CameraStatusBanner(message: _viewModel.errorMessage!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_viewModel.cameras.isNotEmpty) ...[
            _CameraSelector(
              cameras: _viewModel.cameras,
              selected: _viewModel.selectedCamera,
              canManage: _viewModel.canManage,
              onSelected: _viewModel.selectCamera,
              onEdit: _showEditCameraDialog,
              onDelete: _confirmDelete,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_viewModel.selectedCamera != null) ...[
            CameraWidget(
              key: ValueKey(_viewModel.selectedCamera!.id),
              jwtToken: _viewModel.jwtToken,
              cameraId: _viewModel.selectedCamera!.id,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_viewModel.cameras.isEmpty)
            _EmptyCameraCard(
              canManage: _viewModel.canManage,
              onAdd: _showAddCameraDialog,
            ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Feed')),
      body: content,
    );
  }

  Future<void> _showAddCameraDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddCameraDialog(viewModel: _viewModel),
    );
  }

  Future<void> _showEditCameraDialog(SecurityCamera camera) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddCameraDialog(viewModel: _viewModel, camera: camera),
    );
  }

  Future<void> _confirmDelete(SecurityCamera camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove camera?'),
        content: Text(
          'Remove ${camera.name} from this system? Existing events will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _viewModel.deleteCamera(camera);
  }
}

class _CameraSelector extends StatelessWidget {
  final List<SecurityCamera> cameras;
  final SecurityCamera? selected;
  final bool canManage;
  final ValueChanged<SecurityCamera> onSelected;
  final ValueChanged<SecurityCamera> onEdit;
  final ValueChanged<SecurityCamera> onDelete;
  const _CameraSelector({
    required this.cameras,
    required this.selected,
    required this.canManage,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.videocam_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SecurityCamera>(
                  value: selected,
                  isExpanded: true,
                  items: cameras
                      .map(
                        (camera) => DropdownMenuItem(
                          value: camera,
                          child: Text(
                            '${camera.name}${camera.location?.isNotEmpty == true ? ' • ${camera.location}' : ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (camera) {
                    if (camera != null) onSelected(camera);
                  },
                ),
              ),
            ),
            if (selected != null)
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected!.isOnline ? Colors.green : Colors.orange,
                ),
              ),
            if (canManage && selected != null)
              IconButton(
                tooltip: 'Edit camera',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onEdit(selected!),
              ),
            if (canManage && selected != null)
              IconButton(
                tooltip: 'Remove camera',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(selected!),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCameraCard extends StatelessWidget {
  final bool canManage;
  final VoidCallback onAdd;
  const _EmptyCameraCard({required this.canManage, required this.onAdd});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text('No cameras configured', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            canManage
                ? 'Add an RTSP, HTTP, or HTTPS camera to start monitoring.'
                : 'Ask an owner or manager to add a camera.',
          ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Camera'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AddCameraDialog extends StatefulWidget {
  final CameraFeedViewModel viewModel;
  final SecurityCamera? camera;
  const _AddCameraDialog({required this.viewModel, this.camera});
  @override
  State<_AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<_AddCameraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _location = TextEditingController(),
      _url = TextEditingController(),
      _username = TextEditingController(),
      _password = TextEditingController(),
      _cameraIp = TextEditingController(),
      _onvifPort = TextEditingController(text: '80');
  bool detection = true, snapshot = true, enabled = true;

  bool get isEditing => widget.camera != null;
  String get originalHost =>
      Uri.tryParse(widget.camera?.streamUrl ?? '')?.host ?? '';

  @override
  void initState() {
    super.initState();
    final camera = widget.camera;
    if (camera == null) return;
    _name.text = camera.name;
    _location.text = camera.location ?? '';
    _url.text = camera.streamUrl;
    _cameraIp.text = originalHost;
    _username.text = camera.username ?? '';
    detection = camera.detectionEnabled;
    snapshot = camera.snapshotEnabled;
    enabled = camera.enabled;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _location,
      _url,
      _username,
      _password,
      _cameraIp,
      _onvifPort,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get payload => {
    'name': _name.text.trim(),
    'location': _location.text.trim(),
    'stream_url': _url.text.trim(),
    'username': _username.text.trim().isEmpty ? null : _username.text.trim(),
    'password': _password.text.isEmpty ? null : _password.text,
    'stream_protocol':
        Uri.tryParse(_url.text.trim())?.scheme.toLowerCase() ?? 'rtsp',
    'detection_enabled': detection,
    'snapshot_enabled': snapshot,
    'confidence_threshold': widget.camera?.confidenceThreshold ?? .7,
  };

  Map<String, dynamic> get submissionPayload {
    final value = Map<String, dynamic>.from(payload);
    if (isEditing && _password.text.isEmpty) value.remove('password');
    if (isEditing) value['enabled'] = enabled;
    return value;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (context, _) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isEditing
                        ? Icons.edit_outlined
                        : Icons.add_a_photo_outlined,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Camera' : 'Add Camera',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: widget.viewModel.isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isEditing
                    ? 'Update the camera details. Leave the password blank to keep the current password.'
                    : 'Enter the camera network details. The system will configure its stream automatically.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCameraIpField(),
                        const SizedBox(height: AppSpacing.md),
                        _responsivePair(
                          TextFormField(
                            controller: _onvifPort,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ONVIF port *',
                              hintText: '80',
                              prefixIcon: Icon(Icons.settings_ethernet),
                            ),
                            validator: _onvifPortValidator,
                          ),
                          TextFormField(
                            controller: _url,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Stream URL (optional)',
                              hintText: 'rtsp://192.168.1.50:554/stream1',
                              prefixIcon: Icon(Icons.link),
                              helperText: 'Use this if ONVIF is unavailable.',
                            ),
                            validator: _streamUrlValidator,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _responsivePair(
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Camera name *',
                              prefixIcon: Icon(Icons.videocam_outlined),
                            ),
                            validator: _required,
                          ),
                          TextFormField(
                            controller: _location,
                            decoration: const InputDecoration(
                              labelText: 'Location',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _responsivePair(
                          TextFormField(
                            controller: _username,
                            decoration: InputDecoration(
                              labelText: isEditing
                                  ? 'Camera username'
                                  : 'Camera username *',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: _credentialValidator,
                          ),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: isEditing
                                  ? 'Camera password'
                                  : 'Camera password *',
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            validator: _credentialValidator,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _responsivePair(
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('AI detection'),
                            subtitle: const Text(
                              'Detects people and creates security events from this camera.',
                            ),
                            value: detection,
                            onChanged: (v) => setState(() => detection = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Event snapshots'),
                            subtitle: const Text(
                              'Saves an image when this camera detects a security event.',
                            ),
                            value: snapshot,
                            onChanged: (v) => setState(() => snapshot = v),
                          ),
                        ),
                        if (isEditing)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Camera enabled'),
                            subtitle: const Text(
                              'Disabled cameras stop streaming and detection.',
                            ),
                            value: enabled,
                            onChanged: (value) =>
                                setState(() => enabled = value),
                          ),
                        if (widget.viewModel.errorMessage != null)
                          _CameraStatusBanner(
                            message: widget.viewModel.errorMessage!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: widget.viewModel.isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _isBusy ? null : _test,
                    icon: widget.viewModel.isTesting
                        ? _progressIndicator()
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Test connection'),
                  ),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : _save,
                    icon: widget.viewModel.isSubmitting
                        ? _progressIndicator()
                        : const Icon(Icons.add),
                    label: Text(isEditing ? 'Save changes' : 'Add camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  bool get _isBusy =>
      widget.viewModel.isTesting ||
      widget.viewModel.isSubmitting ||
      widget.viewModel.isResolving;

  Widget _responsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              first,
              const SizedBox(height: AppSpacing.md),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildCameraIpField() {
    return TextFormField(
      controller: _cameraIp,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Camera IP address *',
        hintText: '192.168.1.50',
        prefixIcon: Icon(Icons.lan_outlined),
      ),
      validator: _cameraIpValidator,
    );
  }

  Widget _progressIndicator() => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _credentialValidator(String? value) {
    if (!isEditing || _cameraIp.text.trim() != originalHost) {
      return _required(value);
    }
    return null;
  }

  String? _cameraIpValidator(String? value) {
    final parts = (value ?? '').trim().split('.');
    if (parts.length != 4 ||
        parts.any((part) {
          final number = int.tryParse(part);
          return number == null || number < 0 || number > 255;
        })) {
      return 'Enter a valid IPv4 address';
    }
    return null;
  }

  String? _onvifPortValidator(String? value) {
    final port = int.tryParse((value ?? '').trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Enter a port from 1 to 65535';
    }
    return null;
  }

  String? _streamUrlValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.host.isEmpty ||
        !const {'rtsp', 'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      return 'Enter a valid RTSP, HTTP, or HTTPS URL';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'Enter credentials in the username and password fields';
    }
    return null;
  }

  Future<void> _test() async {
    if (_formKey.currentState?.validate() != true) return;
    if (isEditing && _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the camera password to test the connection.'),
        ),
      );
      return;
    }
    if (!await _prepareStreamUrl()) return;
    await widget.viewModel.testConnection(payload);
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (!await _prepareStreamUrl()) return;
    final saved = isEditing
        ? await widget.viewModel.updateCamera(widget.camera!, submissionPayload)
        : await widget.viewModel.addCamera(submissionPayload);
    if (saved && mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _prepareStreamUrl() async {
    final directUrl = Uri.tryParse(_url.text.trim());
    if (directUrl != null &&
        directUrl.host == _cameraIp.text.trim() &&
        _streamUrlValidator(_url.text) == null) {
      return true;
    }
    if (isEditing &&
        _cameraIp.text.trim() == originalHost &&
        _password.text.isEmpty) {
      return true;
    }
    final camera = _cameraFromIp();
    if (camera == null) return false;
    final streamUrl = await widget.viewModel.resolveStream(
      camera: camera,
      username: _username.text.trim(),
      password: _password.text,
    );
    if (streamUrl == null) return false;
    _url.text = streamUrl;
    return true;
  }

  DiscoveredCamera? _cameraFromIp() {
    final host = _cameraIp.text.trim();
    if (_cameraIpValidator(host) != null) return null;
    final port = int.tryParse(_onvifPort.text.trim());
    if (port == null || port < 1 || port > 65535) return null;
    return DiscoveredCamera(
      id: 'manual-onvif-$host',
      name: _name.text.trim(),
      host: host,
      serviceUrl: 'http://$host:$port/onvif/device_service',
    );
  }
}

class _CameraStatusBanner extends StatelessWidget {
  final String message;

  const _CameraStatusBanner({required this.message});

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
