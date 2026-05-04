import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ShortLeaveScreen extends StatefulWidget {
  const ShortLeaveScreen({super.key});

  @override
  State<ShortLeaveScreen> createState() => _ShortLeaveScreenState();
}

class _ShortLeaveScreenState extends State<ShortLeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDownloading = false;
  bool _isRefreshing = false;
  bool _isLoading = true;

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];

  String _sortOrder = 'Newest First';
  final _sortOptions = ['Newest First', 'Oldest First', 'Urgent First (Today)'];

  bool _autoRefresh = false;
  Timer? _autoRefreshTimer;

  final List<String> _tabs = ['Pending', 'Approved', 'Denied', 'All'];

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dow = days[d.weekday - 1];
    return '$dow, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtDateShort(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm / $dd / ${d.year}';
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await AdminApiService.getShortLeaveRequests();
      setState(() {
        _allRequests = requests;
        _filterRequestsByDate();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Failed to load leave requests: $e');
    }
  }

  void _filterRequestsByDate() {
    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    setState(() {
      _filteredRequests = _allRequests.where((req) {
        String? reqDate = req['date']?.toString().split('T')[0];
        reqDate ??= req['leaveDate']?.toString().split('T')[0];
        reqDate ??= req['startDate']?.toString().split('T')[0];

        return reqDate == dateStr;
      }).toList();
    });
  }

  List<Map<String, dynamic>> _getRequestsForTab(String tab) {
    if (tab == 'All') return _filteredRequests;
    return _filteredRequests.where((r) => r['status'] == tab).toList();
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    if (_sortOrder == 'Oldest First') {
      return copy.reversed.toList();
    } else if (_sortOrder == 'Urgent First (Today)') {
      copy.sort((a, b) {
        const order = {'Pending': 0, 'Approved': 1, 'Denied': 2};
        return (order[a['status']] ?? 3).compareTo(order[b['status']] ?? 3);
      });
    }
    return copy;
  }

  int _count(String tab) => _getRequestsForTab(tab).length;

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refresh();
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _downloadApprovedLeavesPDF() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final approvedRequests = _allRequests
          .where((r) => r['status'] == 'Approved')
          .toList();

      if (approvedRequests.isEmpty) {
        _showSnackbar('No approved leave requests to download');
        return;
      }

      _showSnackbar('Downloading approved leaves...', isError: false);

      // Use the API to download PDF
      final response = await AdminApiService.exportApprovedLeavesPDF();

      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }

      // Get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final downloadsPath = directory.path;

      // Create a unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'approved_leaves_$timestamp.pdf';
      final filePath = '$downloadsPath/$fileName';

      // Save the PDF file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Show success message with file location
      _showSnackbar(
        'Download completed! Saved to Documents/$fileName',
        isError: false,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Download error: $e');
      _showSnackbar('Download failed: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _loadLeaveRequests();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _updateStatus(
    Map<String, dynamic> request,
    String newStatus,
  ) async {
    try {
      await AdminApiService.updateShortLeaveStatus(
        request['_id'] ?? request['id'].toString(),
        newStatus,
      );

      setState(() {
        request['status'] = newStatus;
        _filterRequestsByDate();
      });

      _showSnackbar(
        'Request ${newStatus.toLowerCase()} successfully',
        isError: false,
      );
    } catch (e) {
      _showSnackbar('Failed to update status: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadLeaveRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _showSnackbar(
    String message, {
    bool isError = true,
    Duration duration = const Duration(seconds: 3),
  }) {
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
    final totalCount = _filteredRequests.length;
    final pendingCount = _count('Pending');
    final approvedCount = _count('Approved');
    final deniedCount = _count('Denied');

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
              'Short Leave Request Management',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Review and manage intern short leave requests',
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.cardPurpleTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.directions_run_rounded,
                color: AppColors.iconPurple,
                size: 20,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatCard(
                                  value: '$totalCount',
                                  label: 'Total Requests',
                                  sublabel: 'for ${_fmtDate(_selectedDate)}',
                                  valueColor: AppColors.textPrimary,
                                  bgColor: Colors.white,
                                  borderColor: AppColors.border,
                                  icon: null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  value: '$pendingCount',
                                  label: 'Pending Review',
                                  sublabel: null,
                                  valueColor: AppColors.statOrange,
                                  bgColor: const Color(0xFFFFFBEB),
                                  borderColor: const Color(0xFFFDE68A),
                                  icon: Icons.alarm_rounded,
                                  iconColor: AppColors.statOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _StatCard(
                                  value: '$approvedCount',
                                  label: 'Approved',
                                  sublabel: null,
                                  valueColor: AppColors.success,
                                  bgColor: const Color(0xFFF0FDF4),
                                  borderColor: const Color(0xFFBBF7D0),
                                  icon: Icons.check_rounded,
                                  iconColor: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  value: '$deniedCount',
                                  label: 'Denied',
                                  sublabel: null,
                                  valueColor: AppColors.danger,
                                  bgColor: const Color(0xFFFFF1F2),
                                  borderColor: const Color(0xFFFECACA),
                                  icon: Icons.close_rounded,
                                  iconColor: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.border),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.filter_alt_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Filter by Date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppColors.iconPurple,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                              _filterRequestsByDate();
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppColors.iconPurple,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _fmtDateShort(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _downloadApprovedLeavesPDF,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _isDownloading
                                  ? AppColors.iconPurple.withValues(alpha: 0.7)
                                  : AppColors.iconPurple,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.iconPurple.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _isDownloading
                                  ? [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Downloading...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ]
                                  : [
                                      const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Download Approved Leaves PDF',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (ctx) {
                            final now = DateTime.now();
                            final isToday =
                                _selectedDate.year == now.year &&
                                _selectedDate.month == now.month &&
                                _selectedDate.day == now.day;
                            final label = _fmtDate(_selectedDate);
                            return RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Showing requests for: ',
                                  ),
                                  TextSpan(
                                    text: isToday ? '$label (Today)' : label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.border),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _autoRefresh = !_autoRefresh;
                              if (_autoRefresh) {
                                _startAutoRefresh();
                              } else {
                                _stopAutoRefresh();
                              }
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _autoRefresh
                                  ? AppColors.iconPurple.withValues(alpha: 0.05)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _autoRefresh
                                    ? AppColors.iconPurple.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _autoRefresh,
                                    onChanged: (v) {
                                      setState(() {
                                        _autoRefresh = v ?? false;
                                        if (_autoRefresh) {
                                          _startAutoRefresh();
                                        } else {
                                          _stopAutoRefresh();
                                        }
                                      });
                                    },
                                    activeColor: AppColors.iconPurple,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Auto-refresh (30s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _autoRefresh
                                        ? AppColors.iconPurple
                                        : AppColors.textSecondary,
                                    fontWeight: _autoRefresh
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (_autoRefresh) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.iconPurple,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'ON',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            PopupMenuButton<String>(
                              initialValue: _sortOrder,
                              onSelected: (v) => setState(() => _sortOrder = v),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              itemBuilder: (_) => _sortOptions
                                  .map(
                                    (opt) => PopupMenuItem(
                                      value: opt,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _sortOrder == opt
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            size: 16,
                                            color: _sortOrder == opt
                                                ? AppColors.iconPurple
                                                : AppColors.textHint,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            opt,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: _sortOrder == opt
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: _sortOrder == opt
                                                  ? AppColors.iconPurple
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _sortOrder,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _refresh,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.iconBlue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _isRefreshing
                                        ? const SizedBox(
                                            width: 13,
                                            height: 13,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.8,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.iconBlue,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.refresh_rounded,
                                            size: 14,
                                            color: AppColors.iconBlue,
                                          ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Refresh',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.iconBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _TabChip(
                                label: 'Pending',
                                count: pendingCount,
                                isSelected: _tabController.index == 0,
                                onTap: () => _tabController.animateTo(0),
                                activeColor: AppColors.iconPurple,
                              ),
                              const SizedBox(width: 8),
                              _TabChip(
                                label: 'Approved',
                                count: approvedCount,
                                isSelected: _tabController.index == 1,
                                onTap: () => _tabController.animateTo(1),
                                activeColor: AppColors.success,
                              ),
                              const SizedBox(width: 8),
                              _TabChip(
                                label: 'Denied',
                                count: deniedCount,
                                isSelected: _tabController.index == 2,
                                onTap: () => _tabController.animateTo(2),
                                activeColor: AppColors.danger,
                              ),
                              const SizedBox(width: 8),
                              _TabChip(
                                label: 'All',
                                count: totalCount,
                                isSelected: _tabController.index == 3,
                                onTap: () => _tabController.animateTo(3),
                                activeColor: AppColors.textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.border),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Builder(
                      builder: (ctx) {
                        final list = _sorted(
                          _getRequestsForTab(_tabs[_tabController.index]),
                        );
                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 56,
                                  color: AppColors.textHint.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No short leave requests found\nfor ${_fmtDate(_selectedDate)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton(
                                  onPressed: () => _tabController.animateTo(3),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.iconPurple,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 11,
                                    ),
                                  ),
                                  child: const Text(
                                    "View Today's Requests",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 0),
                          itemBuilder: (ctx, i) => _RequestCard(
                            request: list[i],
                            onStatusChanged: _updateStatus,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? sublabel;
  final Color valueColor;
  final Color bgColor;
  final Color borderColor;
  final IconData? icon;
  final Color? iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.valueColor,
    required this.bgColor,
    required this.borderColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColor ?? AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: const TextStyle(fontSize: 10.5, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _TabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final void Function(Map<String, dynamic>, String) onStatusChanged;

  const _RequestCard({required this.request, required this.onStatusChanged});

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved':
        return AppColors.success;
      case 'Denied':
        return AppColors.danger;
      default:
        return AppColors.statOrange;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'Approved':
        return const Color(0xFFF0FDF4);
      case 'Denied':
        return const Color(0xFFFFF1F2);
      default:
        return const Color(0xFFFFFBEB);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? 'Pending';
    final internName = request['internName'] ?? request['name'] ?? 'Unknown';
    final internId = request['internId'] ?? request['traineeId'] ?? 'N/A';
    final department = request['department'] ?? 'General';
    final reason = request['reason'] ?? 'Not specified';
    final timeFrom = request['timeFrom'] ?? '09:00';
    final timeTo = request['timeTo'] ?? '17:00';
    final date = request['date'] ?? DateTime.now().toIso8601String();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.iconPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      internName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.iconPurple,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        internName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: $internId  •  $department',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Reason',
                    value: reason,
                    color: AppColors.iconPurple,
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(
                  child: _DetailItem(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: '$timeFrom – $timeTo',
                    color: AppColors.iconBlue,
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(
                  child: _DetailItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: _formatDate(date),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'Pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onStatusChanged(request, 'Denied'),
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text(
                        'Deny',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        foregroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onStatusChanged(request, 'Approved'),
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text(
                        'Approve',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
