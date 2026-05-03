import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/contact.dart';
import '../../core/ffi_bridge.dart';
import '../../core/call_service.dart';
import 'contact_detail_page.dart';

class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  List<Contact> contacts = [];
  bool loading = true;
  String searchQuery = "";

  bool isSelectionMode = false;
  Set<String> selectedContactIds = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() async {
    try {
      final jsonList = FFIBridge.getContacts();
      setState(() {
        contacts = jsonList.map((j) => Contact.fromJson(j)).toList();
        loading = false;
        selectedContactIds.removeWhere((id) => !contacts.any((c) => c.id == id));
        if (selectedContactIds.isEmpty) isSelectionMode = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vcf', 'csv', 'ldif'],
    );
    if (result != null && mounted) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final ext = result.files.single.extension!.toLowerCase();
      final status = FFIBridge.importFromFile(content, ext);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
      _loadContacts();
    }
  }

  void _export(String format) async {
    final data = FFIBridge.exportToFile(format);
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to export.')));
      return;
    }
    if (format == 'vcf') {
      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/contacts_export.vcf');
      await file.writeAsString(data);
      await Share.shareXFiles([XFile(file.path)], subject: 'Contacts Export');
    } else {
      await Share.share(data, subject: 'Contacts Export ($format)');
    }
  }

  void _batchDelete() async {
    if (selectedContactIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, size: 32),
        title: const Text('Delete Contacts?'),
        content: Text('Delete ${selectedContactIds.length} contact(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in selectedContactIds) {
        FFIBridge.deleteContact(id);
      }
      _clearSelection();
      _loadContacts();
    }
  }

  void _clearSelection() {
    setState(() {
      selectedContactIds.clear();
      isSelectionMode = false;
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selectedContactIds.contains(id)) {
        selectedContactIds.remove(id);
        if (selectedContactIds.isEmpty) isSelectionMode = false;
      } else {
        selectedContactIds.add(id);
      }
    });
  }

  List<Contact> get _filtered {
    if (searchQuery.isEmpty) return contacts;
    final q = searchQuery.toLowerCase();
    return contacts
        .where((c) =>
            c.fullName.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.organization.toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<Contact>> get _groupedContacts {
    final filtered = _filtered;
    final Map<String, List<Contact>> groups = {};

    // Favorites first
    final favs = filtered.where((c) => c.isFavorite).toList();
    if (favs.isNotEmpty) {
      groups['★ Favorites'] = favs;
    }

    for (final c in filtered) {
      final letter = c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '#';
      final key = RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(c);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: colors.primaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${selectedContactIds.length} selected',
                  style: TextStyle(color: colors.onPrimaryContainer)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  onPressed: () {
                    setState(() {
                      final all = filtered.map((c) => c.id).toSet();
                      if (selectedContactIds.length == all.length) {
                        selectedContactIds.clear();
                        isSelectionMode = false;
                      } else {
                        selectedContactIds.addAll(all);
                      }
                    });
                  },
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                  onPressed: _batchDelete,
                  tooltip: 'Delete',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.share_rounded),
                  onSelected: _export,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'vcf', child: Text('Share VCF')),
                    const PopupMenuItem(value: 'csv', child: Text('Share CSV')),
                  ],
                ),
              ],
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                if (!isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 8, left: 16, right: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: SearchBar(
                            hintText: 'Search contacts',
                            leading: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.search),
                            ),
                            trailing: [
                              if (searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() => searchQuery = ''),
                                ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (val) {
                                  if (val == 'import') {
                                    _import();
                                  } else {
                                    _export(val);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'import', child: Text('Import')),
                                  const PopupMenuItem(value: 'vcf', child: Text('Export VCF')),
                                  const PopupMenuItem(value: 'csv', child: Text('Export CSV')),
                                  const PopupMenuItem(value: 'md', child: Text('Export Markdown')),
                                ],
                              ),
                            ],
                            elevation: const WidgetStatePropertyAll(0), // Removed elevation for glass effect
                            backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHighest.withValues(alpha: 0.5)),
                            constraints: const BoxConstraints(minHeight: 56, maxHeight: 56), // Increased height
                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100), // Perfect pill shape
                            )),
                            onChanged: (val) => setState(() => searchQuery = val),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Contact Count
                if (!isSelectionMode && contacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${contacts.length} contacts',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                // Contact List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (contacts.isEmpty && searchQuery.isEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.outlineVariant.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/empty_mascot.png',
                                    width: 200,
                                    height: 200,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No Contacts... yet!',
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This space is ready for your first\nconnection.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                FilledButton.icon(
                                  onPressed: () => _navigateToDetail(null),
                                  icon: const Icon(Icons.person_add_rounded),
                                  label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF63C2B6), // Matching the button color from screenshot
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ] else ...[
                                Icon(Icons.search_off_rounded,
                                    size: 72, color: colors.onSurface.withValues(alpha: 0.15)),
                                const SizedBox(height: 16),
                                Text(
                                  'No results',
                                  style: TextStyle(
                                    color: colors.onSurface.withValues(alpha: 0.5),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : _buildContactList(filtered, colors),
                ),
              ],
            ),
      floatingActionButton: isSelectionMode
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _navigateToDetail(null),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                elevation: 0,
                backgroundColor: Colors.transparent,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
              ),
            ),
    );
  }

  Widget _buildContactList(List<Contact> filtered, ColorScheme colors) {
    // Group by first letter
    final groups = <String, List<Contact>>{};
    final favs = filtered.where((c) => c.isFavorite).toList();

    if (favs.isNotEmpty && searchQuery.isEmpty) {
      groups['★'] = favs;
    }

    for (final c in filtered) {
      final letter = c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '#';
      final key = RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
      groups.putIfAbsent(key, () => []);
      if (!groups[key]!.any((existing) => existing.id == c.id)) {
        groups[key]!.add(c);
      }
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '★') return -1;
        if (b == '★') return 1;
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: sortedKeys.fold<int>(0, (sum, key) => sum + 1 + groups[key]!.length),
      itemBuilder: (context, index) {
        int cursor = 0;
        for (final key in sortedKeys) {
          if (index == cursor) {
            return _SectionHeader(letter: key, colors: colors);
          }
          cursor++;
          final list = groups[key]!;
          if (index < cursor + list.length) {
            final c = list[index - cursor];
            final isSelected = selectedContactIds.contains(c.id);
            return Dismissible(
              key: Key('swipe_${c.id}'),
              direction: DismissDirection.startToEnd,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                color: Colors.green.withValues(alpha: 0.8),
                child: const Icon(Icons.call, color: Colors.white, size: 32),
              ),
              confirmDismiss: (direction) async {
                CallService().makeCall(c.phone, contactName: c.fullName, contactId: c.id);
                return false; // Don't actually dismiss the tile
              },
              child: _ContactTile(
                contact: c,
                isSelected: isSelected,
                isSelectionMode: isSelectionMode,
                onTap: () {
                  if (isSelectionMode) {
                    _toggleSelection(c.id);
                  } else {
                    _navigateToDetail(c);
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    isSelectionMode = true;
                    selectedContactIds.add(c.id);
                  });
                },
                onCall: () => CallService().makeCall(c.phone, contactName: c.fullName, contactId: c.id),
              ),
            );
          }
          cursor += list.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _navigateToDetail(Contact? c) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContactDetailPage(contact: c)),
    );
    if (changed == true) _loadContacts();
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String letter;
  final ColorScheme colors;

  const _SectionHeader({required this.letter, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
      child: Text(
        letter == '★' ? '★ Favorites' : letter,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: colors.primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Contact Tile ────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCall;

  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final int charCode = contact.firstName.isNotEmpty ? contact.firstName.codeUnitAt(0) : 63;

    // Generate harmonious avatar color from name
    final hue = (charCode * 37.0) % 360;
    final avatarColor = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55).toColor();
    final avatarColorEnd = HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.5, 0.45).toColor();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isSelected ? colors.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                shape: const CircleBorder(),
              )
            : Hero(
                tag: 'avatar_${contact.id}',
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [avatarColor.withValues(alpha: 0.3), avatarColorEnd.withValues(alpha: 0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    contact.firstName.isNotEmpty ? contact.firstName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarColorEnd,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
        title: Text(
          contact.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), // Bolded as requested
        ),
        subtitle: contact.phone.isNotEmpty
            ? Text(contact.phone, style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant)) // Increased from 13
            : null,
        trailing: isSelectionMode
            ? null
            : contact.phone.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.call_outlined, size: 28), // Increased from 24
                    color: Colors.green.shade400,
                    onPressed: onCall,
                    tooltip: 'Call',
                  )
                : null,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
