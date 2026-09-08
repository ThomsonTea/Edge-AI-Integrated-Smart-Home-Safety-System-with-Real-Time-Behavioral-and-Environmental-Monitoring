import 'package:flutter/material.dart';

import '../../domain/models/emergency_contact.dart';
import '../../services/phone_call_service.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/emergency_contact_viewmodel.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final EmergencyContactViewModel? viewModel;
  final PhoneCallService? phoneCallService;

  const EmergencyContactsScreen({
    super.key,
    this.viewModel,
    this.phoneCallService,
  });

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late final EmergencyContactViewModel _viewModel;
  late final PhoneCallService _phoneCallService;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? EmergencyContactViewModel();
    _phoneCallService = widget.phoneCallService ?? PhoneCallService();
    _viewModel.addListener(_onUpdate);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _call(EmergencyContact contact) async {
    try {
      await _phoneCallService.openDialer(contact.phoneNumber);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showContactEditor([EmergencyContact? contact]) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmergencyContactFormSheet(contact: contact),
    );
    if (result == null) return;
    final success = await _viewModel.save(result, isNew: contact == null);
    if (!mounted) return;
    _showMessage(
      success
          ? _viewModel.successMessage ?? 'Contact saved.'
          : _viewModel.errorMessage ?? 'Unable to save contact.',
    );
  }

  Future<void> _confirmDelete(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete emergency contact?'),
        content: Text(
          '${contact.contactName} will no longer be available for emergency calls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await _viewModel.delete(contact);
    if (!mounted) return;
    _showMessage(
      success
          ? _viewModel.successMessage ?? 'Contact deleted.'
          : _viewModel.errorMessage ?? 'Unable to delete contact.',
    );
  }

  Future<void> _toggleEnabled(EmergencyContact contact, bool enabled) async {
    final success = await _viewModel.setEnabled(contact, enabled);
    if (!success && mounted) {
      _showMessage(_viewModel.errorMessage ?? 'Unable to update contact.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: _viewModel.canManage
          ? FloatingActionButton.extended(
              key: const ValueKey('add-emergency-contact'),
              onPressed: _viewModel.isSaving ? null : _showContactEditor,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add Contact'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _viewModel.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            96,
          ),
          children: [
            _EmergencyNotice(canManage: _viewModel.canManage),
            const SizedBox(height: AppSpacing.xl),
            if (!_viewModel.isLoading || _viewModel.contacts.isNotEmpty) ...[
              _ContactsSectionHeader(contactCount: _viewModel.contacts.length),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_viewModel.isLoading && _viewModel.contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_viewModel.errorMessage != null &&
                _viewModel.contacts.isEmpty)
              _LoadError(
                message: _viewModel.errorMessage!,
                onRetry: _viewModel.load,
              )
            else if (_viewModel.contacts.isEmpty)
              _EmptyContacts(canManage: _viewModel.canManage)
            else
              for (final contact in _viewModel.contacts) ...[
                _EmergencyContactCard(
                  contact: contact,
                  canManage: _viewModel.canManage,
                  enabled: !_viewModel.isSaving,
                  onCall: () => _call(contact),
                  onEdit: () => _showContactEditor(contact),
                  onDelete: () => _confirmDelete(contact),
                  onEnabledChanged: (enabled) =>
                      _toggleEnabled(contact, enabled),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmergencyNotice extends StatelessWidget {
  final bool canManage;

  const _EmergencyNotice({required this.canManage});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.home_outlined, color: colors.onPrimaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                canManage
                    ? 'Shared with this home. Priority 1 appears first.'
                    : 'Shared with this home. Tap Call to open your dialer.',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsSectionHeader extends StatelessWidget {
  final int contactCount;

  const _ContactsSectionHeader({required this.contactCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trusted contacts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sorted by calling priority',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          ),
          child: Text(
            '$contactCount ${contactCount == 1 ? 'contact' : 'contacts'}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final bool canManage;
  final bool enabled;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;

  const _EmergencyContactCard({
    required this.contact,
    required this.canManage,
    required this.enabled,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
    required this.onEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: ValueKey('emergency-contact-${contact.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: contact.enabled
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  foregroundColor: contact.enabled
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  child: Text(
                    contact.contactName.isEmpty
                        ? '?'
                        : contact.contactName[0].toUpperCase(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.contactName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.chipRadius,
                              ),
                            ),
                            child: Text(
                              'Priority ${contact.priority}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (contact.relationship != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          contact.relationship!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              contact.phoneNumber,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: ValueKey('call-contact-${contact.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    ),
                    onPressed: contact.enabled ? onCall : null,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    key: ValueKey('edit-contact-${contact.id}'),
                    tooltip: 'Edit contact',
                    onPressed: enabled ? onEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    key: ValueKey('delete-contact-${contact.id}'),
                    tooltip: 'Delete contact',
                    onPressed: enabled ? onDelete : null,
                    color: colors.error,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      contact.enabled
                          ? Icons.bolt_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: contact.enabled
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.enabled ? 'Quick call enabled' : 'Hidden',
                            style: textTheme.labelLarge,
                          ),
                          Text(
                            contact.enabled
                                ? 'Visible in the emergency call list'
                                : 'Not shown in the emergency call list',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: contact.enabled,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: enabled ? onEnabledChanged : null,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmergencyContactFormSheet extends StatefulWidget {
  final EmergencyContact? contact;

  const _EmergencyContactFormSheet({this.contact});

  @override
  State<_EmergencyContactFormSheet> createState() =>
      _EmergencyContactFormSheetState();
}

class _EmergencyContactFormSheetState
    extends State<_EmergencyContactFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _priorityController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _nameController = TextEditingController(text: contact?.contactName ?? '');
    _phoneController = TextEditingController(text: contact?.phoneNumber ?? '');
    _relationshipController = TextEditingController(
      text: contact?.relationship ?? '',
    );
    _priorityController = TextEditingController(
      text: (contact?.priority ?? 1).toString(),
    );
    _enabled = contact?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final relationship = _relationshipController.text.trim();
    Navigator.of(context).pop(
      EmergencyContact(
        id: widget.contact?.id ?? 0,
        contactName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        relationship: relationship.isEmpty ? null : relationship,
        priority: int.parse(_priorityController.text),
        enabled: _enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    final availableHeight =
        (media.size.height - media.viewInsets.bottom - AppSpacing.lg)
            .clamp(240.0, media.size.height * 0.94)
            .toDouble();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: availableHeight,
          ),
          child: Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _ContactFormHeader(isEditing: isEditing),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact details',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const ValueKey('emergency-contact-name'),
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Contact name',
                              hintText: 'Who should be contacted?',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter a contact name'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const ValueKey('emergency-contact-phone'),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: '+60 12-345 6789',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: _validatePhone,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            key: const ValueKey(
                              'emergency-contact-relationship',
                            ),
                            controller: _relationshipController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Relationship (optional)',
                              hintText: 'Family, neighbour, security guard',
                              prefixIcon: Icon(Icons.group_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Availability',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.xs,
                              AppSpacing.xs,
                              AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.controlRadius,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.low_priority),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: TextFormField(
                                    key: const ValueKey(
                                      'emergency-contact-priority',
                                    ),
                                    controller: _priorityController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      labelText: 'Calling priority',
                                      helperText: '1 appears first',
                                      border: InputBorder.none,
                                    ),
                                    validator: _validatePriority,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.controlRadius,
                              ),
                            ),
                            child: SwitchListTile.adaptive(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              secondary: const Icon(Icons.bolt_outlined),
                              title: const Text('Available for quick call'),
                              subtitle: const Text(
                                'Show this person in the emergency call list',
                              ),
                              value: _enabled,
                              onChanged: (value) =>
                                  setState(() => _enabled = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            key: const ValueKey('save-emergency-contact'),
                            onPressed: _submit,
                            icon: Icon(
                              isEditing
                                  ? Icons.save_outlined
                                  : Icons.person_add_alt_1_outlined,
                            ),
                            label: Text(
                              isEditing ? 'Save Changes' : 'Add Contact',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter a phone number';
    if (!RegExp(r'^\+?[0-9()\-\s]+$').hasMatch(phone)) {
      return 'Enter a valid phone number';
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 3 || digits.length > 15) {
      return 'Use between 3 and 15 digits';
    }
    return null;
  }

  String? _validatePriority(String? value) {
    final priority = int.tryParse(value ?? '');
    if (priority == null || priority < 1 || priority > 100) {
      return 'Use a number from 1 to 100';
    }
    return null;
  }
}

class _ContactFormHeader extends StatelessWidget {
  final bool isEditing;

  const _ContactFormHeader({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.errorContainer,
            foregroundColor: colors.onErrorContainer,
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.contact_phone_outlined,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing
                      ? 'Edit Emergency Contact'
                      : 'Add Emergency Contact',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isEditing
                      ? 'Update this contact’s details and availability.'
                      : 'Add someone your household can reach quickly.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _EmptyContacts extends StatelessWidget {
  final bool canManage;

  const _EmptyContacts({required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            const Icon(Icons.contact_phone_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No emergency contacts yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              canManage
                  ? 'Use Add Contact to create the first emergency contact.'
                  : 'Ask the home owner or manager to add emergency contacts.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
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
