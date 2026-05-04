import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';

class OverdueListScreen extends StatefulWidget {
  const OverdueListScreen({super.key});

  @override
  State<OverdueListScreen> createState() => _OverdueListScreenState();
}

class _OverdueListScreenState extends State<OverdueListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _isExporting = false;
  bool _isReminding = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _overdueInterns = [];
  List<Map<String, dynamic>> _filteredInterns = [];

  @override
  void initState() {
    super.initState();
    _loadOverdueInterns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOverdueInterns() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final overdue = await AdminApiService.getOverdueInterns();

      debugPrint('Received overdue interns: ${overdue.length}');

      if (mounted) {
        setState(() {
          _overdueInterns = overdue;
          _filteredInterns = overdue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading overdue interns: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar('Failed to load overdue interns: $e');
      }
    }
  }

  void _filterInterns() {
    final query = _searchText.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredInterns = _overdueInterns;
      });
      return;
    }

    setState(() {
      _filteredInterns = _overdueInterns.where((intern) {
        final name = (intern['name'] ?? '').toLowerCase();
        final traineeId =
            (intern['traineeId'] ?? intern['_id']?.toString() ?? '')
                .toLowerCase();
        final email = (intern['email'] ?? '').toLowerCase();

        return name.contains(query) ||
            traineeId.contains(query) ||
            email.contains(query);
      }).toList();
    });
  }

  Future<void> _exportList() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      if (_filteredInterns.isEmpty) {
        _showSnackbar('No data to export', isError: false);
        return;
      }

      // Generate CSV content
      final csvContent = _generateCSV();

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final fileName =
          'overdue_interns_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvContent);

      // Share the file
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Overdue Interns List - ${_filteredInterns.length} interns');

      _showSnackbar(
        'Exported ${_filteredInterns.length} records successfully!',
        isError: false,
      );
    } catch (e) {
      _showSnackbar('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _generateCSV() {
    final buffer = StringBuffer();

    // Add headers
    buffer.writeln('Name,Trainee ID,Email,Last Submission Date,Overdue Days');

    // Add data rows
    for (final intern in _filteredInterns) {
      final name = intern['name'] ?? '';
      final traineeId = intern['traineeId'] ?? intern['_id']?.toString() ?? '';
      final email = intern['email'] ?? '';
      final lastSubmission =
          intern['lastSubmissionDate'] ?? intern['lastSubmission'] ?? '';
      final overdueDays = intern['overdueDays']?.toString() ?? '';

      buffer.writeln('"$name",$traineeId,$email,$lastSubmission,$overdueDays');
    }

    return buffer.toString();
  }

  Future<void> _remindAll() async {
    if (_isReminding) return;
    setState(() => _isReminding = true);

    try {
      if (_filteredInterns.isEmpty) {
        _showSnackbar('No overdue interns to remind', isError: false);
        return;
      }

      // Prepare notifications data
      final notifications = _filteredInterns.map((intern) {
        return {
          'internId': intern['_id'] ?? intern['id'],
          'name': intern['name'],
          'email': intern['email'],
          'overdueDays': intern['overdueDays'] ?? 1,
        };
      }).toList();

      await AdminApiService.sendOverdueNotifications(notifications);

      _showSnackbar(
        'Reminder emails sent to ${_filteredInterns.length} interns successfully!',
        isError: false,
      );
    } catch (e) {
      _showSnackbar('Failed to send reminders: $e');
    } finally {
      if (mounted) setState(() => _isReminding = false);
    }
  }



  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
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
    final filtered = _filteredInterns;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 24,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Show Overdue List',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'View and manage overdue interns',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.cardBlueTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.iconBlue,
                size: 20,
              ),
              onPressed: _loadOverdueInterns,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              tooltip: 'Refresh',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                size: 22,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Overdue Interns',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${filtered.length} pending ${filtered.length == 1 ? 'submission' : 'submissions'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _exportList,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _isExporting
                                      ? AppColors.primary
                                      : AppColors.cardBlueTint,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _isExporting
                                        ? [
                                            const SizedBox(
                                              width: 13,
                                              height: 13,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Exporting...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ]
                                        : [
                                            const Icon(
                                              Icons.ios_share_rounded,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 5),
                                            const Text(
                                              'Export Overdue List',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: _remindAll,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _isReminding
                                      ? AppColors.danger.withValues(alpha: 0.75)
                                      : AppColors.danger,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.danger.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _isReminding
                                        ? [
                                            const SizedBox(
                                              width: 13,
                                              height: 13,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Sending...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ]
                                        : [
                                            const Icon(
                                              Icons.send_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 5),
                                            const Text(
                                              'Remind All',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() {
                        _searchText = v;
                        _filterInterns();
                      });
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name, Trainee ID or email...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      suffixIcon: _searchText.isNotEmpty
                          ? GestureDetector(
                              onTap: () => setState(() {
                                _searchController.clear();
                                _searchText = '';
                                _filterInterns();
                              }),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textHint,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(height: 1, color: AppColors.border),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 52,
                                color: AppColors.success.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchText.isNotEmpty
                                    ? 'No matching interns found'
                                    : 'No overdue interns found',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_searchText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchText = '';
                                      _filterInterns();
                                    });
                                  },
                                  child: const Text(
                                    'Clear search',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) => _OverdueCard(
                            intern: filtered[i],
                            onRemind: () => _remindSingle(filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _remindSingle(Map<String, dynamic> intern) async {
    try {
      final notifications = [
        {
          'internId': intern['_id'] ?? intern['id'],
          'name': intern['name'],
          'email': intern['email'],
          'overdueDays': intern['overdueDays'] ?? 1,
        },
      ];

      await AdminApiService.sendOverdueNotifications(notifications);

      if (mounted) {
        _showSnackbar('Reminder sent to ${intern['name']}', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to send reminder: $e');
      }
    }
  }
}

class _OverdueCard extends StatelessWidget {
  final Map<String, dynamic> intern;
  final VoidCallback onRemind;

  const _OverdueCard({required this.intern, required this.onRemind});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateOverdueDays(String? dateStr) {
    if (dateStr == null) return 0;
    try {
      final lastDate = DateTime.parse(dateStr);
      final today = DateTime.now();
      return today.difference(lastDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = intern['name'] ?? 'Unknown';
    final traineeId = intern['traineeId'] ?? intern['_id']?.toString() ?? 'N/A';
    final email = intern['email'] ?? 'No email';
    final lastSubmission =
        intern['lastSubmissionDate'] ?? intern['lastSubmission'];
    final overdueDays =
        intern['overdueDays'] ?? _calculateOverdueDays(lastSubmission);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$overdueDays day${overdueDays != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: $traineeId',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Last: ${_formatDate(lastSubmission)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onRemind,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Remind',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
