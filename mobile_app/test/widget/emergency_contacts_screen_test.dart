import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/emergency_contact.dart';
import 'package:smart_home_security_system/services/emergency_contact_service.dart';
import 'package:smart_home_security_system/services/phone_call_service.dart';
import 'package:smart_home_security_system/services/token_service.dart';
import 'package:smart_home_security_system/theme/app_theme.dart';
import 'package:smart_home_security_system/ui/screens/emergency_contacts_screen.dart';
import 'package:smart_home_security_system/viewmodels/emergency_contact_viewmodel.dart';

class _EmergencyContactServiceStub extends EmergencyContactService {
  final List<EmergencyContact> stored;

  _EmergencyContactServiceStub({List<EmergencyContact>? contacts})
    : stored = [...?contacts];

  @override
  Future<List<EmergencyContact>> fetchContacts() async => [...stored];

  @override
  Future<EmergencyContact> createContact(EmergencyContact contact) async {
    final created = contact.copyWith(id: stored.length + 1);
    stored.add(created);
    return created;
  }

  @override
  Future<EmergencyContact> updateContact(EmergencyContact contact) async {
    final index = stored.indexWhere((item) => item.id == contact.id);
    stored[index] = contact;
    return contact;
  }

  @override
  Future<void> deleteContact(int id) async {
    stored.removeWhere((contact) => contact.id == id);
  }
}

class _TokenServiceStub extends TokenService {
  final String role;

  _TokenServiceStub(this.role);

  @override
  Future<String?> getCurrentUserRole() async => role;
}

class _PhoneCallServiceStub extends PhoneCallService {
  String? openedNumber;

  @override
  Future<void> openDialer(String phoneNumber) async {
    openedNumber = phoneNumber;
  }
}

EmergencyContactViewModel _viewModel(
  String role,
  _EmergencyContactServiceStub service,
) {
  return EmergencyContactViewModel(
    service: service,
    tokenService: _TokenServiceStub(role),
  );
}

void main() {
  const contact = EmergencyContact(
    id: 7,
    contactName: 'Aunt May',
    phoneNumber: '+60123456789',
    relationship: 'Family',
    priority: 1,
    enabled: true,
  );

  testWidgets('owner can see CRUD controls and add a contact', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _EmergencyContactServiceStub(contacts: const [contact]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: EmergencyContactsScreen(
          viewModel: _viewModel('owner', service),
          phoneCallService: _PhoneCallServiceStub(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-emergency-contact')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-contact-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-contact-7')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-emergency-contact')));
    await tester.pumpAndSettle();
    expect(find.text('Add Emergency Contact'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('emergency-contact-name')),
      'Security Guard',
    );
    await tester.enterText(
      find.byKey(const ValueKey('emergency-contact-phone')),
      '0198765432',
    );
    await tester.tap(find.byKey(const ValueKey('save-emergency-contact')));
    await tester.pumpAndSettle();

    expect(service.stored.length, 2);
    expect(find.text('Security Guard'), findsOneWidget);
  });

  testWidgets('normal user can call but cannot manage contacts', (
    tester,
  ) async {
    final service = _EmergencyContactServiceStub(contacts: const [contact]);
    final phoneService = _PhoneCallServiceStub();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: EmergencyContactsScreen(
          viewModel: _viewModel('normal_user', service),
          phoneCallService: phoneService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-emergency-contact')), findsNothing);
    expect(find.byKey(const ValueKey('edit-contact-7')), findsNothing);
    expect(find.byKey(const ValueKey('delete-contact-7')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('call-contact-7')));
    await tester.pump();
    expect(phoneService.openedNumber, '+60123456789');
  });
}
