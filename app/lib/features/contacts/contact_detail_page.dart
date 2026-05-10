import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import '../../models/contact.dart';
import '../../core/ffi_bridge.dart';
import '../../core/call_service.dart';
import '../../core/contact_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

class ContactDetailPage extends StatefulWidget {
  final Contact? contact;

  const ContactDetailPage({super.key, this.contact});

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _noteController;
  late TextEditingController _orgController;
  late TextEditingController _nicknameController;
  late bool _isFavorite;
  bool _isEditing = false;

  bool get _isNew => widget.contact == null || widget.contact!.id.isEmpty;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.contact?.firstName ?? "");
    _lastNameController = TextEditingController(text: widget.contact?.lastName ?? "");
    _phoneController = TextEditingController(text: widget.contact?.phone ?? "");
    _emailController = TextEditingController(text: widget.contact?.email ?? "");
    _noteController = TextEditingController(text: widget.contact?.note ?? "");
    _orgController = TextEditingController(text: widget.contact?.organization ?? "");
    _nicknameController = TextEditingController(text: widget.contact?.nickname ?? "");
    _isFavorite = widget.contact?.isFavorite ?? false;
    _isEditing = _isNew;
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final c = Contact(
        id: widget.contact?.id.isNotEmpty == true
            ? widget.contact!.id
            : DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(9999).toString(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nickname: _nicknameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        organization: _orgController.text.trim(),
        note: _noteController.text.trim(),
        isFavorite: _isFavorite,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      FFIBridge.saveContact(c.toJson());
      // Push to system
      ContactSyncService().pushToSystem(c);
      Navigator.pop(context, true);
    }
  }

  void _delete() async {
    if (widget.contact != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error, size: 32),
          title: const Text('Delete Contact?'),
          content: Text('Remove ${widget.contact!.fullName} permanently?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        FFIBridge.deleteContact(widget.contact!.id);
        // Sync with system (to remove it there too if possible, or just re-sync)
        ContactSyncService().syncWithSystem();
        Navigator.pop(context, true);
      }
    }
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    if (!_isNew && !_isEditing) {
      // Save immediately if just toggling favorite
      final c = widget.contact!.copyWith(
        isFavorite: _isFavorite,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      FFIBridge.saveContact(c.toJson());
      ContactSyncService().pushToSystem(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = _firstNameController.text.isNotEmpty
        ? _firstNameController.text
        : (widget.contact?.firstName ?? '');
    final int charCode = name.isNotEmpty ? name.codeUnitAt(0) : 63;
    final hue = (charCode * 37.0) % 360;
    final avatarColor = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Header
          SliverAppBar(
            expandedHeight: _isEditing ? 100 : 260,
            pinned: true,
            backgroundColor: colors.surfaceContainer,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _isFavorite ? Colors.amber : null,
                ),
                onPressed: _toggleFavorite,
                tooltip: 'Favorite',
              ),
              if (!_isNew && !_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: 'Edit',
                ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: _save,
                  tooltip: 'Save',
                ),
              if (!_isNew)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'delete') _delete();
                    if (val == 'share') _shareContact();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: colors.error)),
                    ),
                  ],
                ),
            ],
            flexibleSpace: _isEditing
                ? null
                : FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            avatarColor.withValues(alpha: 0.35),
                            avatarColor.withValues(alpha: 0.05),
                            colors.surface,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 32),
                            Hero(
                              tag: 'avatar_${widget.contact?.id ?? 'new'}',
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [avatarColor.withValues(alpha: 0.4), avatarColor.withValues(alpha: 0.1)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: avatarColor.withValues(alpha: 0.2),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: avatarColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.contact?.fullName ?? 'New Contact',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            if (widget.contact?.organization.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  widget.contact!.organization,
                                  style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant, fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Action Buttons Row (view mode)
          if (!_isEditing && !_isNew && (widget.contact?.phone.isNotEmpty == true))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionChip(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: Colors.green,
                      onTap: () => CallService().makeCall(
                        widget.contact!.phone,
                        contactName: widget.contact!.fullName,
                        contactId: widget.contact!.id,
                      ),
                    ),
                    _ActionChip(
                      icon: Icons.message_rounded,
                      label: 'Message',
                      color: colors.primary,
                      onTap: () => _launchUrl('sms:${widget.contact!.phone}'),
                    ),
                    if (widget.contact?.email.isNotEmpty == true)
                      _ActionChip(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        color: colors.tertiary,
                        onTap: () => _launchUrl('mailto:${widget.contact!.email}'),
                      ),
                  ],
                ),
              ),
            ),

          // Form / Detail Cards
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    if (_isEditing) ...[
                      _buildEditCard(colors),
                    ] else ...[
                      _buildViewCards(colors),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                prefixIcon: Icon(Icons.person_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                prefixIcon: Icon(Icons.face_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _orgController,
              decoration: const InputDecoration(
                labelText: 'Organization',
                prefixIcon: Icon(Icons.business_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                prefixIcon: Icon(Icons.note_rounded),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_isNew ? 'Create Contact' : 'Save Changes'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewCards(ColorScheme colors) {
    final c = widget.contact!;
    return Column(
      children: [
        if (c.phone.isNotEmpty)
          _InfoCard(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: c.phone,
            colors: colors,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.call_rounded, size: 20),
                  color: Colors.green,
                  onPressed: () => CallService().makeCall(c.phone, contactName: c.fullName, contactId: c.id),
                ),
                IconButton(
                  icon: const Icon(Icons.message_outlined, size: 20),
                  onPressed: () => _launchUrl('sms:${c.phone}'),
                ),
              ],
            ),
          ),
        if (c.email.isNotEmpty)
          _InfoCard(
            icon: Icons.email_rounded,
            label: 'Email',
            value: c.email,
            colors: colors,
            trailing: IconButton(
              icon: const Icon(Icons.send_rounded, size: 20),
              onPressed: () => _launchUrl('mailto:${c.email}'),
            ),
          ),
        if (c.organization.isNotEmpty)
          _InfoCard(icon: Icons.business_rounded, label: 'Organization', value: c.organization, colors: colors),
        if (c.nickname.isNotEmpty)
          _InfoCard(icon: Icons.face_rounded, label: 'Nickname', value: c.nickname, colors: colors),
        if (c.note.isNotEmpty)
          _InfoCard(icon: Icons.note_rounded, label: 'Note', value: c.note, colors: colors),
      ],
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _shareContact() {
    final c = widget.contact!;
    final text = '${c.fullName}\n${c.phone}\n${c.email}'.trim();
    Share.share(text, subject: c.fullName);
  }
}

// ─── Action Chip ─────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Info Card ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colors;
  final Widget? trailing;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colors.primary, size: 22),
        ),
        title: Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        trailing: trailing,
      ),
    );
  }
}
