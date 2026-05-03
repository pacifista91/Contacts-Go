import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/contact.dart';
import '../../core/ffi_bridge.dart';
import '../../core/call_service.dart';
import '../contacts/contact_detail_page.dart';

class DialerPage extends StatefulWidget {
  const DialerPage({super.key});

  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> with SingleTickerProviderStateMixin {
  String input = "";
  List<Contact> suggestions = [];
  bool _isDialerOpen = true;

  String _countryCode = '+1';

  late AnimationController _dialerSlideController;
  late Animation<Offset> _dialerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _detectCountryCode();
    _dialerSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dialerSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1.2),
    ).animate(CurvedAnimation(
      parent: _dialerSlideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _dialerSlideController.dispose();
    super.dispose();
  }

  void _detectCountryCode() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final cc = _countryCodeFromLocale(locale.countryCode ?? locale.languageCode.toUpperCase());
    if (cc != null) setState(() => _countryCode = cc);
  }

  String? _countryCodeFromLocale(String cc) {
    const map = {
      'US': '+1', 'CA': '+1', 'GB': '+44', 'AU': '+61', 'IN': '+91',
      'DE': '+49', 'FR': '+33', 'IT': '+39', 'ES': '+34', 'JP': '+81',
      'KR': '+82', 'CN': '+86', 'BR': '+55', 'MX': '+52', 'RU': '+7',
      'ZA': '+27', 'NG': '+234', 'PK': '+92', 'BD': '+880', 'PH': '+63',
      'ID': '+62', 'TR': '+90', 'SA': '+966', 'AE': '+971', 'EG': '+20',
      'NL': '+31', 'SE': '+46', 'NO': '+47', 'DK': '+45', 'FI': '+358',
      'CH': '+41', 'AT': '+43', 'BE': '+32', 'PL': '+48', 'AR': '+54',
    };
    return map[cc.toUpperCase()];
  }

  void _onDigitPressed(String digit) {
    setState(() {
      input += digit;
      _updateSuggestions();
    });
  }

  void _onBackspace() {
    if (input.isNotEmpty) {
      setState(() {
        input = input.substring(0, input.length - 1);
        _updateSuggestions();
      });
    }
  }

  void _onBackspaceLongPress() {
    setState(() {
      input = '';
      suggestions = [];
    });
  }

  void _updateSuggestions() {
    if (input.isEmpty) {
      suggestions = [];
      return;
    }
    final all = FFIBridge.getContacts().map((j) => Contact.fromJson(j)).toList();
    setState(() {
      suggestions = all
          .where((c) => c.phone.contains(input) || _matchesT9(c.fullName, input))
          .toList();
    });
  }

  bool _matchesT9(String name, String digits) {
    if (digits.isEmpty) return true;
    final cleanName = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanName.length < digits.length) return false;
    const t9 = {
      '2': 'abc', '3': 'def', '4': 'ghi', '5': 'jkl',
      '6': 'mno', '7': 'pqrs', '8': 'tuv', '9': 'wxyz',
    };
    for (int i = 0; i < digits.length; i++) {
      final d = digits[i];
      if (!t9.containsKey(d)) continue;
      if (!t9[d]!.contains(cleanName[i])) return false;
    }
    return true;
  }

  void _makeCall(String number, {String name = '', String id = ''}) {
    String dialNumber = number;
    if (!dialNumber.startsWith('+') && !dialNumber.startsWith('00') && dialNumber.isNotEmpty) {
      dialNumber = '$_countryCode$number';
    }
    CallService().makeCall(dialNumber, contactName: name, contactId: id);
  }

  void _toggleDialer() {
    setState(() {
      _isDialerOpen = !_isDialerOpen;
      if (_isDialerOpen) {
        _dialerSlideController.reverse();
      } else {
        _dialerSlideController.forward();
      }
    });
  }

  void _createNewContact() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailPage(
          contact: Contact(
            id: '',
            firstName: '',
            lastName: '',
            nickname: '',
            phone: input,
            email: '',
            organization: '',
            note: '',
            updatedAt: 0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit from main scaffold
      body: SafeArea(
        child: Column(
          children: [
            // Suggestions list
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (details.delta.dy > 10 && _isDialerOpen) {
                    _toggleDialer();
                  }
                },
                child: suggestions.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final c = suggestions[index];
                          final int charCode = c.firstName.isNotEmpty ? c.firstName.codeUnitAt(0) : 63;
                          final hue = (charCode * 37.0) % 360;
                          final avatarColor = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: avatarColor.withValues(alpha: 0.1),
                              child: Text(
                                c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: avatarColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Text(c.phone, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.call_rounded, size: 20, color: colors.primary),
                            ),
                            onTap: () => _makeCall(c.phone, name: c.fullName, id: c.id),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dialpad_rounded, size: 64, color: colors.onSurface.withValues(alpha: 0.05)),
                            const SizedBox(height: 16),
                            Text('Dial a number',
                                style: TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 14)),
                          ],
                        ),
                      ),
              ),
            ),

            // Input Display
            if (input.isNotEmpty)
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 200),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        input,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                          color: colors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _createNewContact,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Add to contact', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),

            // Keypad
            SlideTransition(
              position: _dialerSlideAnimation,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.6),
                      border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 1.4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 16,
                      children: [
                        ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'].map((d) {
                          return _DialerKey(digit: d, onTap: () => _onDigitPressed(d));
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 56),
                        _CallButton(
                          size: 72,
                          onTap: () {
                            if (input.isNotEmpty) _makeCall(input);
                          },
                        ),
                        SizedBox(
                          width: 56,
                          child: input.isNotEmpty
                              ? GestureDetector(
                                  onLongPress: _onBackspaceLongPress,
                                  child: IconButton(
                                    icon: const Icon(Icons.backspace_outlined),
                                    iconSize: 28,
                                    color: colors.onSurface.withValues(alpha: 0.5),
                                    onPressed: _onBackspace,
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
      floatingActionButton: !_isDialerOpen
          ? FloatingActionButton.extended(
              onPressed: _toggleDialer,
              icon: const Icon(Icons.dialpad_rounded),
              label: const Text('Dialer'),
            )
          : null,
    );
  }
}

class _CallButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _CallButton({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00C853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          splashColor: Colors.white.withValues(alpha: 0.3),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.call_rounded, color: Colors.white, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}

class _DialerKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DialerKey({required this.digit, required this.onTap});

  static const _subLabels = {
    '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL',
    '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ',
    '*': '', '0': '+', '#': '',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sub = _subLabels[digit] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: colors.primary.withValues(alpha: 0.1),
          highlightColor: colors.primary.withValues(alpha: 0.05),
          child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(digit, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w400, color: colors.onSurface)),
              if (sub.isNotEmpty)
                Text(sub, style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
              if (digit == '0' && sub.isEmpty) const SizedBox(height: 10), // Placeholder for alignment
            ],
          ),
          ),
        ),
      ),
    );
  }
}
