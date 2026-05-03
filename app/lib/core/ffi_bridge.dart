import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef _InitDBNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _InitDB = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _ListContactsNative = ffi.Pointer<Utf8> Function();
typedef _ListContacts = ffi.Pointer<Utf8> Function();

typedef _SaveContactNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _SaveContact = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _SearchContactsNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _SearchContacts = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _DeleteContactNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _DeleteContact = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _ImportFromFileNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef _ImportFromFile = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);

typedef _ExportToFileNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _ExportToFile = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _FreeString = void Function(ffi.Pointer<Utf8>);

// Backup bindings
typedef _SetBackupDirNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _SetBackupDir = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _GetBackupDirNative = ffi.Pointer<Utf8> Function();
typedef _GetBackupDir = ffi.Pointer<Utf8> Function();

typedef _TriggerBackupNative = ffi.Pointer<Utf8> Function();
typedef _TriggerBackup = ffi.Pointer<Utf8> Function();

typedef _RestoreFromBackupNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _RestoreFromBackup = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _GetBackupStatusNative = ffi.Pointer<Utf8> Function();
typedef _GetBackupStatus = ffi.Pointer<Utf8> Function();

class FFIBridge {
  static late ffi.DynamicLibrary _lib;
  static late _InitDB _initDB;
  static late _ListContacts _listContacts;
  static late _SaveContact _saveContact;
  static late _SearchContacts _searchContacts;
  static late _DeleteContact _deleteContact;
  static late _ImportFromFile _importFromFile;
  static late _ExportToFile _exportToFile;
  static late _FreeString _freeString;

  // Backup
  static late _SetBackupDir _setBackupDir;
  static late _GetBackupDir _getBackupDir;
  static late _TriggerBackup _triggerBackup;
  static late _RestoreFromBackup _restoreFromBackup;
  static late _GetBackupStatus _getBackupStatus;

  static bool _initialized = false;

  static Future<void> load() async {
    if (_initialized) return;

    final String libName = Platform.isAndroid ? 'libengine.so' : 'libengine.dylib';
    String libPath = libName;
    if (Platform.isMacOS) {
      libPath = path.join(Directory.current.parent.path, 'engine', libName);
    }

    _lib = ffi.DynamicLibrary.open(libPath);

    _initDB = _lib.lookupFunction<_InitDBNative, _InitDB>('InitDB');
    _listContacts = _lib.lookupFunction<_ListContactsNative, _ListContacts>('ListContacts');
    _saveContact = _lib.lookupFunction<_SaveContactNative, _SaveContact>('SaveContact');
    _searchContacts = _lib.lookupFunction<_SearchContactsNative, _SearchContacts>('SearchContacts');
    _deleteContact = _lib.lookupFunction<_DeleteContactNative, _DeleteContact>('DeleteContact');
    _importFromFile = _lib.lookupFunction<_ImportFromFileNative, _ImportFromFile>('ImportFromFile');
    _exportToFile = _lib.lookupFunction<_ExportToFileNative, _ExportToFile>('ExportToFile');
    _freeString = _lib.lookupFunction<_FreeStringNative, _FreeString>('FreeString');

    // Backup
    _setBackupDir = _lib.lookupFunction<_SetBackupDirNative, _SetBackupDir>('SetBackupDir');
    _getBackupDir = _lib.lookupFunction<_GetBackupDirNative, _GetBackupDir>('GetBackupDir');
    _triggerBackup = _lib.lookupFunction<_TriggerBackupNative, _TriggerBackup>('TriggerBackup');
    _restoreFromBackup = _lib.lookupFunction<_RestoreFromBackupNative, _RestoreFromBackup>('RestoreFromBackup');
    _getBackupStatus = _lib.lookupFunction<_GetBackupStatusNative, _GetBackupStatus>('GetBackupStatus');

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(docsDir.path, 'contacts.db');

    final dbPathPtr = dbPath.toNativeUtf8();
    final resultPtr = _initDB(dbPathPtr);
    print('DB Initialization: ${resultPtr.toDartString()}');
    _freeString(resultPtr);
    malloc.free(dbPathPtr);

    _initialized = true;
  }

  // ─── Safe Call Wrapper ──────────────────────────────────────────────────────

  static String _safeCallString(ffi.Pointer<Utf8> Function() fn) {
    try {
      final ptr = fn();
      final str = ptr.toDartString();
      _freeString(ptr);
      return str;
    } catch (e) {
      return 'error: FFI call failed: $e';
    }
  }

  static String _safeCallStringArg(ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>) fn, String arg) {
    try {
      final argPtr = arg.toNativeUtf8();
      final ptr = fn(argPtr);
      final str = ptr.toDartString();
      _freeString(ptr);
      malloc.free(argPtr);
      return str;
    } catch (e) {
      return 'error: FFI call failed: $e';
    }
  }

  // ─── Contacts ──────────────────────────────────────────────────────────────

  static List<dynamic> getContacts() {
    try {
      final ptr = _listContacts();
      final str = ptr.toDartString();
      _freeString(ptr);
      return jsonDecode(str);
    } catch (e) {
      return [];
    }
  }

  static String saveContact(Map<String, dynamic> contact) {
    return _safeCallStringArg(_saveContact, jsonEncode(contact));
  }

  static String deleteContact(String id) {
    return _safeCallStringArg(_deleteContact, id);
  }

  static List<dynamic> searchContacts(String query) {
    try {
      final queryPtr = query.toNativeUtf8();
      final ptr = _searchContacts(queryPtr);
      final str = ptr.toDartString();
      _freeString(ptr);
      malloc.free(queryPtr);
      return jsonDecode(str);
    } catch (e) {
      return [];
    }
  }

  static String importFromFile(String data, String format) {
    try {
      final dataPtr = data.toNativeUtf8();
      final formatPtr = format.toNativeUtf8();
      final ptr = _importFromFile(dataPtr, formatPtr);
      final result = ptr.toDartString();
      _freeString(ptr);
      malloc.free(dataPtr);
      malloc.free(formatPtr);
      return result;
    } catch (e) {
      return 'error: $e';
    }
  }

  static String exportToFile(String format) {
    return _safeCallStringArg(_exportToFile, format);
  }

  // ─── Backup ────────────────────────────────────────────────────────────────

  static String setBackupDir(String dir) {
    return _safeCallStringArg(_setBackupDir, dir);
  }

  static String getBackupDir() => _safeCallString(_getBackupDir);

  static String triggerBackup() => _safeCallString(_triggerBackup);

  static String restoreFromBackup(String path) {
    return _safeCallStringArg(_restoreFromBackup, path);
  }

  static Map<String, dynamic> getBackupStatus() {
    try {
      final str = _safeCallString(_getBackupStatus);
      return jsonDecode(str);
    } catch (e) {
      return {};
    }
  }
}
