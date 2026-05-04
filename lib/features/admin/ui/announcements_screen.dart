import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';

enum AnnouncementPriority { normal, important, urgent }

extension AnnouncementPriorityX on AnnouncementPriority {
  String get label {
    switch (this) {
      case AnnouncementPriority.normal:
        return 'normal';
      case AnnouncementPriority.important:
        return 'important';
      case AnnouncementPriority.urgent:
        return 'urgent';
    }
  }

  String get displayName {
    switch (this) {
      case AnnouncementPriority.normal:
        return 'Normal';
      case AnnouncementPriority.important:
        return 'Important';
      case AnnouncementPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case AnnouncementPriority.normal:
        return const Color(0xFF2563EB);
      case AnnouncementPriority.important:
        return const Color(0xFFF59E0B);
      case AnnouncementPriority.urgent:
        return const Color(0xFFDC2626);
    }
  }
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final String priority;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['_id'] ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      priority: json['priority'] ?? 'normal',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

  AnnouncementPriority _draftPriority = AnnouncementPriority.normal;
  AnnouncementPriority? _filterPriority;

  List<Announcement> _announcements = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final announcementsData = await AdminApiService.getAnnouncements();
      setState(() {
        _announcements = announcementsData
            .map((data) => Announcement.fromJson(data))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Failed to load announcements: $e');
    }
  }

  List<Announcement> get _filteredAnnouncements {
    final search = _searchController.text.trim().toLowerCase();
    return _announcements.where((a) {
      final matchesSearch =
          search.isEmpty ||
          a.title.toLowerCase().contains(search) ||
          a.content.toLowerCase().contains(search);
      final matchesPriority =
          _filterPriority == null ||
          a.priority.toLowerCase() == _filterPriority!.label.toLowerCase();
      return matchesSearch && matchesPriority;
    }).toList();
  }

  Future<void> _sendAnnouncement() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _showSnackbar('Please enter title and message.');
      return;
    }

    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final result = await AdminApiService.createAnnouncement(
        title: title,
        content: message,
        priority: _draftPriority.label,
      );

      final newAnnouncement = Announcement.fromJson(result);
      setState(() {
        _announcements.insert(0, newAnnouncement);
        _titleController.clear();
        _messageController.clear();
        _draftPriority = AnnouncementPriority.normal;
        _searchController.clear();
        _filterPriority = null;
      });

      _showSnackbar(
        'Announcement sent to all interns successfully!',
        isError: false,
      );
    } catch (e) {
      _showSnackbar('Failed to send announcement: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _editAnnouncement(Announcement announcement) async {
    AnnouncementPriority priority = _getPriorityFromString(
      announcement.priority,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EditAnnouncementDialog(
        title: announcement.title,
        content: announcement.content,
        priority: priority,
      ),
    );

    if (result != null && mounted) {
      try {
        final updated = await AdminApiService.updateAnnouncement(
          announcement.id,
          title: result['title'],
          content: result['content'],
          priority: result['priority'],
        );

        setState(() {
          final index = _announcements.indexWhere(
            (a) => a.id == announcement.id,
          );
          if (index != -1) {
            _announcements[index] = Announcement.fromJson(updated);
          }
        });

        _showSnackbar('Announcement updated successfully!', isError: false);
      } catch (e) {
        _showSnackbar('Failed to update announcement: $e');
      }
    }
  }

  Future<void> _deleteAnnouncement(Announcement announcement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Announcement',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${announcement.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await AdminApiService.deleteAnnouncement(announcement.id);
        setState(() {
          _announcements.removeWhere((a) => a.id == announcement.id);
        });
        _showSnackbar('Announcement deleted successfully!', isError: false);
      } catch (e) {
        _showSnackbar('Failed to delete announcement: $e');
      }
    }
  }

  AnnouncementPriority _getPriorityFromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'important':
        return AnnouncementPriority.important;
      case 'urgent':
        return AnnouncementPriority.urgent;
      default:
        return AnnouncementPriority.normal;
    }
  }



  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcements = _filteredAnnouncements;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Announcements',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const Text(
              'Important notices for all interns',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.cardBlueTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppColors.iconBlue,
                ),
              ),
              onPressed: _loadAnnouncements,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildComposerCard()),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: _buildSentCard(announcements),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildComposerCard(),
                            const SizedBox(height: 16),
                            _buildSentCard(announcements),
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _buildComposerCard() {
    final titleCount = _titleController.text.length;
    final messageCount = _messageController.text.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Announcement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Compose and send to all interns',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Monthly Review Reminder',
              hintStyle: const TextStyle(color: AppColors.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              counterText: '$titleCount/100',
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            onChanged: (_) => setState(() {}),
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Write your announcement here...',
              hintStyle: const TextStyle(color: AppColors.textHint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(14),
              counterText: '$messageCount/1000',
            ),
            maxLength: 1000,
          ),
          const SizedBox(height: 12),
          const Text(
            'Priority',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Responsive priority boxes using Wrap
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AnnouncementPriority.values.map((priority) {
                  final isSelected = priority == _draftPriority;
                  return GestureDetector(
                    onTap: () => setState(() => _draftPriority = priority),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? priority.color.withValues(alpha: 0.13)
                            : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? priority.color
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: priority.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            priority.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? priority.color
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendAnnouncement,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                _isSending ? 'Sending...' : 'Send to All Interns',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentCard(List<Announcement> announcements) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search announcements...',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AnnouncementPriority?>(
                    value: _filterPriority,
                    items: [
                      const DropdownMenuItem<AnnouncementPriority?>(
                        value: null,
                        child: Text('All Priorities'),
                      ),
                      ...AnnouncementPriority.values.map(
                        (p) => DropdownMenuItem<AnnouncementPriority?>(
                          value: p,
                          child: Text(p.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterPriority = value;
                      });
                    },
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textHint,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: const Text(
                  'Sent Announcements',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Text(
                '${announcements.length} total',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (announcements.isEmpty)
            SizedBox(
              height: 220,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 40,
                    color: AppColors.textHint.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No announcements yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Compose and send your first announcement above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: announcements.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _AnnouncementTile(
                  announcement: announcements[index],
                  onEdit: () => _editAnnouncement(announcements[index]),
                  onDelete: () => _deleteAnnouncement(announcements[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementTile({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  AnnouncementPriority _getPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'important':
        return AnnouncementPriority.important;
      case 'urgent':
        return AnnouncementPriority.urgent;
      default:
        return AnnouncementPriority.normal;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final priority = _getPriority(announcement.priority);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container - fixed width
          SizedBox(
            width: 34,
            height: 34,
            child: Container(
              decoration: BoxDecoration(
                color: priority.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                priority == AnnouncementPriority.urgent
                    ? Icons.priority_high_rounded
                    : Icons.announcement_rounded,
                color: priority.color,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Expanded content area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with priority badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priority.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: priority.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  announcement.content,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Date and action buttons row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(announcement.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    // Action buttons with smaller hit area
                    Container(
                      constraints: const BoxConstraints(minWidth: 60),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onEdit,
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onDelete,
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditAnnouncementDialog extends StatefulWidget {
  final String title;
  final String content;
  final AnnouncementPriority priority;

  const _EditAnnouncementDialog({
    required this.title,
    required this.content,
    required this.priority,
  });

  @override
  State<_EditAnnouncementDialog> createState() =>
      _EditAnnouncementDialogState();
}

class _EditAnnouncementDialogState extends State<_EditAnnouncementDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late AnnouncementPriority _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _contentController = TextEditingController(text: widget.content);
    _priority = widget.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Edit Announcement',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AnnouncementPriority>(
              initialValue: _priority,
              decoration: InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: AnnouncementPriority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: priority.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(priority.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
              'priority': _priority.label,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
