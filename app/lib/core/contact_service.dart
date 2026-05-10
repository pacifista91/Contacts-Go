import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'ffi_bridge.dart';
import '../models/contact.dart' as models;

class ContactSyncService {
  static final ContactSyncService _instance = ContactSyncService._internal();
  factory ContactSyncService() => _instance;
  ContactSyncService._internal();

  bool _isSyncing = false;

  /// Syncs contacts between the system and the local Go engine.
  Future<void> syncWithSystem() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      if (!await FlutterContacts.requestPermission()) {
        debugPrint('Contact permission denied');
        _isSyncing = false;
        return;
      }

      // 1. Fetch system contacts
      final systemContacts = await FlutterContacts.getContacts(withProperties: true);
      
      // 2. Fetch local contacts
      final localContactsData = FFIBridge.getContacts();
      final localContacts = localContactsData.map((j) => models.Contact.fromJson(j)).toList();

      // 3. Auto-import from system
      int importedCount = 0;
      for (final sc in systemContacts) {
        final phone = sc.phones.isNotEmpty ? sc.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '') : '';
        if (phone.isEmpty) continue;

        // Check if already exists locally (by phone)
        final exists = localContacts.any((lc) => lc.phone.replaceAll(RegExp(r'[^0-9+]'), '') == phone);
        
        if (!exists) {
          final newContact = models.Contact(
            id: DateTime.now().millisecondsSinceEpoch.toString() + importedCount.toString(),
            firstName: sc.name.first,
            lastName: sc.name.last,
            nickname: sc.name.nickname,
            phone: phone,
            email: sc.emails.isNotEmpty ? sc.emails.first.address : '',
            organization: sc.organizations.isNotEmpty ? sc.organizations.first.company : '',
            note: sc.notes.isNotEmpty ? sc.notes.first.note : '',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          FFIBridge.saveContact(newContact.toJson());
          importedCount++;
        }
      }
      if (importedCount > 0) debugPrint('Imported $importedCount contacts from system');

      // 4. Auto-export to system (only local-only contacts)
      int exportedCount = 0;
      for (final lc in localContacts) {
        final phone = lc.phone.replaceAll(RegExp(r'[^0-9+]'), '');
        if (phone.isEmpty) continue;

        final existsInSystem = systemContacts.any((sc) => 
          sc.phones.any((p) => p.number.replaceAll(RegExp(r'[^0-9+]'), '') == phone));

        if (!existsInSystem) {
          final newContact = Contact()
            ..name.first = lc.firstName
            ..name.last = lc.lastName
            ..phones = [Phone(lc.phone)]
            ..emails = lc.email.isNotEmpty ? [Email(lc.email)] : []
            ..organizations = lc.organization.isNotEmpty ? [Organization(company: lc.organization)] : []
            ..notes = lc.note.isNotEmpty ? [Note(lc.note)] : [];
          
          await newContact.insert();
          exportedCount++;
        }
      }
      if (exportedCount > 0) debugPrint('Exported $exportedCount contacts to system');

    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Pushes a single local contact to the system.
  Future<void> pushToSystem(models.Contact lc) async {
    try {
      if (!await FlutterContacts.requestPermission()) return;
      
      final systemContacts = await FlutterContacts.getContacts(withProperties: true);
      final phone = lc.phone.replaceAll(RegExp(r'[^0-9+]'), '');
      
      final existing = systemContacts.where((sc) => 
        sc.phones.any((p) => p.number.replaceAll(RegExp(r'[^0-9+]'), '') == phone)).firstOrNull;

      if (existing != null) {
        // Update existing
        existing.name.first = lc.firstName;
        existing.name.last = lc.lastName;
        existing.phones = [Phone(lc.phone)];
        existing.emails = lc.email.isNotEmpty ? [Email(lc.email)] : [];
        existing.organizations = lc.organization.isNotEmpty ? [Organization(company: lc.organization)] : [];
        existing.notes = lc.note.isNotEmpty ? [Note(lc.note)] : [];
        await existing.update();
      } else {
        // Insert new
        final newContact = Contact()
          ..name.first = lc.firstName
          ..name.last = lc.lastName
          ..phones = [Phone(lc.phone)]
          ..emails = lc.email.isNotEmpty ? [Email(lc.email)] : []
          ..organizations = lc.organization.isNotEmpty ? [Organization(company: lc.organization)] : []
          ..notes = lc.note.isNotEmpty ? [Note(lc.note)] : [];
        await newContact.insert();
      }
    } catch (e) {
      debugPrint('Failed to push contact to system: $e');
    }
  }
}
