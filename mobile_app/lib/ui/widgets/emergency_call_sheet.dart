import 'package:flutter/material.dart';

import '../../domain/models/emergency_contact.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/phone_call_service.dart';
import '../../theme/app_spacing.dart';

class EmergencyCallSheet extends StatefulWidget {
  final EmergencyContactService? contactService;
  final PhoneCallService? phoneCallService;

  const EmergencyCallSheet({
    super.key,
    this.contactService,
    this.phoneCallService,
  });

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const EmergencyCallSheet(),
    );
  }

  @override
  State<EmergencyCallSheet> createState() => _EmergencyCallSheetState();
}

class _EmergencyCallSheetState extends State<EmergencyCallSheet> {
  late final EmergencyContactService _contactService;
  late final PhoneCallService _phoneCallService;
  late Future<List<EmergencyContact>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _contactService = widget.contactService ?? EmergencyContactService();
    _phoneCallService = widget.phoneCallService ?? PhoneCallService();
    _contactsFuture = _loadEnabledContacts();
  }

  Future<List<EmergencyContact>> _loadEnabledContacts() async {
    final contacts = await _contactService.fetchContacts();
    return contacts.where((contact) => contact.enabled).toList(growable: false);
  }

  void _retry() {
    setState(() => _contactsFuture = _loadEnabledContacts());
  }

  Future<void> _call(EmergencyContact contact) async {
    try {
      await _phoneCallService.openDialer(contact.phoneNumber);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  child: const Icon(Icons.phone_in_talk),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Call',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Choose a contact to open your phone dialer',
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
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: FutureBuilder<List<EmergencyContact>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _SheetMessage(
                      icon: Icons.cloud_off_outlined,
                      message: snapshot.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                      actionLabel: 'Retry',
                      onAction: _retry,
                    );
                  }
                  final contacts = snapshot.data ?? const [];
                  if (contacts.isEmpty) {
                    return const _SheetMessage(
                      icon: Icons.contact_phone_outlined,
                      message:
                          'No active emergency contacts have been configured.',
                    );
                  }
                  return ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              contact.contactName.isEmpty
                                  ? '?'
                                  : contact.contactName[0].toUpperCase(),
                            ),
                          ),
                          title: Text(contact.contactName),
                          subtitle: Text(
                            [
                              if (contact.relationship != null)
                                contact.relationship!,
                              contact.phoneNumber,
                            ].join(' • '),
                          ),
                          trailing: FilledButton.icon(
                            key: ValueKey('quick-call-${contact.id}'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            ),
                            onPressed: () => _call(contact),
                            icon: const Icon(Icons.call, size: 18),
                            label: const Text('Call'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SheetMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
