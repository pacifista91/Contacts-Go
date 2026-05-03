import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Manages phone calling through platform channels.
class CallService {
  static const MethodChannel _channel = MethodChannel('com.contacts.app/calling');

  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  void initialize() {
    // No-op now, but keeping for compatibility if needed later
  }

  // ─── Call Actions ──────────────────────────────────────────────────────────

  Future<void> makeCall(String number, {String contactName = '', String contactId = ''}) async {
    // We favor directly using the platform channel for ACTION_CALL to "land on the calling page"
    try {
      await _channel.invokeMethod('makeCall', {'number': number});
    } catch (e) {
      debugPrint('Native calling failed, falling back to tel: intent: $e');
      final url = Uri.parse('tel:$number');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  Future<bool> isDefaultDialer() async {
    try {
      final bool? result = await _channel.invokeMethod('isDefaultDialer');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestDefaultDialer() async {
    try {
      await _channel.invokeMethod('requestDefaultDialer');
    } catch (_) {}
  }

  void dispose() {}
}
