import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/admin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/intern_location_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/meeting_attendance_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/short_leave_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/admin_daily_records.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/overdue_list.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/seat_management_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/announcements_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/providers/dashboard_provider.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/home_bottom_navigation_bar.dart';
import 'package:go_router/go_router.dart';

// ----------------------------------------------------------------------
// New AppHeader matching the requested UI (Logo on left, Logout on right)
// ----------------------------------------------------------------------
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;

  const AppHeader({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 70,
      leadingWidth: 200,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 12, bottom: 12),
        // Placeholder for SLT Mobitel logo. Replace with exact asset path if different.
        child: Image.asset(
          'assets/images/slt_mobitel_logo.png', // Ensure this asset is in pubspec.yaml
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (context, error, stackTrace) => const Text(
            'SLT MOBITEL',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
              size: 20,
            ),
            onPressed: onLogout,
            tooltip: 'Logout',
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

// ----------------------------------------------------------------------
// Redesigned StatCard to match the new 2x2 grid UI
// ----------------------------------------------------------------------
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
              Icon(icon, color: iconColor, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Redesigned QuickActionCard (Centered icon and text)
// ----------------------------------------------------------------------
class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color cardColor;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All Status';
  String _sortBy = 'Sort by Name';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;
  int _selectedIndex = 0;

  // State for toggling the exports section
  bool _isExportsExpanded = false;

  final List<String> _statusOptions = [
    'All Status',
    'Submitted',
    'Not Submitted',
    'Overdue',
  ];

  final List<String> _sortOptions = [
    'Sort by Name',
    'Sort by Trainee ID',
    'Sort by Record Count',
    'Sort by Last Submission',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    await provider.fetchDashboardStats();
    await _loadInternReports();
  }

  Future<void> _loadInternReports() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    try {
      final reports = await AdminApiService.fetchInternReports();
      provider.updateInternReports(reports);
    } catch (e) {
      _showSnackbar('Failed to load intern reports: $e');
    }
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('admin_token');
              await prefs.remove('user_token');
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime? d) => d != null
      ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
      : 'Select date';

  Future<void> _showExportDialog(String title, ExportType type) async {
    DateTime? fromDate;
    DateTime? toDate;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDate(
            DateTime? initial,
            ValueChanged<DateTime> onPicked,
          ) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: initial ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => pickDate(
                                fromDate,
                                (d) => setDialogState(() => fromDate = d),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
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
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _fmtDate(fromDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: fromDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => pickDate(
                                toDate,
                                (d) => setDialogState(() => toDate = d),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
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
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _fmtDate(toDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: toDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _performExport(type, fromDate, toDate);
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Download CSV',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _performExport(
    ExportType type,
    DateTime? fromDate,
    DateTime? toDate,
  ) async {
    try {
      _showSnackbar('Preparing download...', isError: false);

      http.Response response;

      switch (type) {
        case ExportType.submissions:
          response = await AdminApiService.exportSubmissionsList(
            fromDate: fromDate,
            toDate: toDate,
          );
          await _saveFile(response, 'submissions_export.xlsx');
          _showSnackbar('Submissions exported successfully!', isError: false);
          break;
        case ExportType.nonSubmissions:
          response = await AdminApiService.exportNonSubmissionsListDirect();
          await _saveFile(response, 'non_submissions.csv');
          _showSnackbar(
            'Non-submissions exported successfully!',
            isError: false,
          );
          break;
        case ExportType.weeklyNonSubmissions:
          response = await AdminApiService.exportWeeklyNonSubmissions();
          await _saveFile(response, 'weekly_non_submissions.xlsx');
          _showSnackbar(
            'Weekly non-submissions exported successfully!',
            isError: false,
          );
          break;
        case ExportType.onLeave:
          response = await AdminApiService.downloadOnLeaveExcel();
          await _saveFile(response, 'on_leave_list.xlsx');
          _showSnackbar('On-leave list exported successfully!', isError: false);
          break;
      }
    } catch (e) {
      _showSnackbar('Export failed: ${e.toString()}');
    }
  }

  Future<void> _saveFile(http.Response response, String filename) async {
    try {
      if (response.bodyBytes.isEmpty) {
        throw Exception('File is empty');
      }

      final bytes = response.bodyBytes;
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      _showSnackbar('File saved successfully: $filename', isError: false);
    } catch (e) {
      debugPrint('Error saving file: $e');
      _showSnackbar('Failed to save file: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  Future<void> _searchInterns(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
    });

    try {
      final results = await AdminApiService.searchInterns(query);
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() {
        _isSearchLoading = false;
      });
      _showSnackbar('Search failed: $e');
    }
  }

  Future<void> _clearSearch() async {
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
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

  void _filterAndSortInterns(DashboardProvider provider) {
    List<Map<String, dynamic>> filtered = List.from(provider.internReports);

    if (_statusFilter != 'All Status') {
      filtered = filtered.where((intern) {
        return true; // Implement actual filter logic here
      }).toList();
    }

    switch (_sortBy) {
      case 'Sort by Name':
        filtered.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
        break;
      case 'Sort by Trainee ID':
        filtered.sort(
          (a, b) => (a['traineeId'] ?? '').compareTo(b['traineeId'] ?? ''),
        );
        break;
    }

    provider.updateFilteredInterns(filtered);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building DashboardScreen');
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(
            0xFFF0F8FF,
          ), // Light blue background from UI
          appBar: AppHeader(onLogout: _handleLogout),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Intern Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(
                            0xFF65B2E8,
                          ), // Matching the light blue text
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Monitor and manage intern logbook submissions',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats Grid (2x2)
                      if (provider.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: isTablet ? 2.5 : 1.7,
                          children: [
                            StatCard(
                              label: 'Total Interns',
                              value: provider.totalInterns.toString(),
                              icon: Icons.groups_rounded,
                              iconColor: AppColors.statBlue,
                            ),
                            StatCard(
                              label: 'Submitted Interns',
                              value: provider.submittedInterns.toString(),
                              icon: Icons.check_circle_rounded,
                              iconColor: AppColors.statGreen,
                              valueColor: AppColors.statGreen,
                            ),
                            StatCard(
                              label: 'Overdue Interns',
                              value: provider.overdueInterns.toString(),
                              icon: Icons.warning_rounded,
                              iconColor: AppColors.statOrange,
                              valueColor: AppColors.danger,
                            ),
                            StatCard(
                              label: 'Total Records',
                              value: provider.totalRecords.toString(),
                              icon: Icons.list_alt_rounded,
                              iconColor: AppColors.statPurple,
                              valueColor: AppColors.statPurple,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // White Container for Quick Actions & Exports
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QUICK ACTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textHint,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Actions Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isTablet ? 4 : 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0, // Square cards
                        children: [
                          QuickActionCard(
                            icon: Icons.calendar_today_rounded,
                            title: 'Daily Records',
                            iconColor: AppColors.statGreen,
                            cardColor: AppColors.statGreen.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DailyRecordsScreen(),
                              ),
                            ),
                          ),
                          QuickActionCard(
                            icon: Icons.directions_run_rounded,
                            title: 'Leave Requests',
                            iconColor: AppColors.statPurple,
                            cardColor: AppColors.statPurple.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ShortLeaveScreen(),
                              ),
                            ),
                          ),
                          QuickActionCard(
                            icon: Icons.access_time_filled_rounded,
                            title: 'Overdue List',
                            iconColor: AppColors.statOrange,
                            cardColor: AppColors.statOrange.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OverdueListScreen(),
                              ),
                            ),
                          ),
                          QuickActionCard(
                            icon: Icons.chair_rounded,
                            title: 'Seat Layout',
                            iconColor: Colors.pink,
                            cardColor: Colors.pink.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SeatManagementScreen(),
                              ),
                            ),
                          ),
                          QuickActionCard(
                            icon: Icons.campaign_rounded,
                            title: 'Announce',
                            iconColor: Colors.cyan,
                            cardColor: Colors.cyan.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AnnouncementsScreen(),
                              ),
                            ),
                          ),
                          QuickActionCard(
                            icon: Icons.location_on_rounded,
                            title: 'Intern Locations',
                            iconColor: AppColors.statBlue,
                            cardColor: AppColors.statBlue.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InternLocationsScreen(),
                              ),
                            ),
                          ),
                          QuickActionCard(
                            icon: Icons.event_available_rounded,
                            title: 'Attendance',
                            iconColor: Colors.indigo,
                            cardColor: Colors.indigo.withOpacity(0.1),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MeetingAttendanceScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Expandable Exports Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExportsExpanded = !_isExportsExpanded;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Exports',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Icon(
                                _isExportsExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expanded Exports Options
                      if (_isExportsExpanded) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildExportMiniCard(
                                title: 'Submissions',
                                icon: Icons
                                    .description_rounded, // Similar to excel
                                iconColor: AppColors.statGreen,
                                bgColor: AppColors.statGreen.withOpacity(0.1),
                                onTap: () => _showExportDialog(
                                  'Export Submissions List',
                                  ExportType.submissions,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildExportMiniCard(
                                title: 'Non-Submissions',
                                icon: Icons.download_rounded,
                                iconColor: AppColors.danger,
                                bgColor: AppColors.danger.withValues(alpha: 0.1),
                                onTap: () => _performExport(
                                  ExportType.nonSubmissions,
                                  null,
                                  null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildExportMiniCard(
                                title: 'On-Leave',
                                icon: Icons.description_rounded,
                                iconColor: AppColors.statPurple,
                                bgColor: AppColors.statPurple.withOpacity(0.1),
                                onTap: () => _performExport(
                                  ExportType.onLeave,
                                  null,
                                  null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Search & Filter Fields
                      _buildSearchField(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildStatusDropdown(provider)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSortDropdown(provider)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Dynamic Search Results Content
                      _buildSearchContent(provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: HomeBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              if (index == 1) {
                context.go('/talenttrail-dashboard');
              }
            },
          ),
        );
      },
    );
  }

  // Mini card for expanded exports
  Widget _buildExportMiniCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _searchInterns(value),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by name, trainee ID, or email (min 2 char)',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textHint,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textHint,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(DashboardProvider provider) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: _statusOptions
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(s),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _statusFilter = v!);
            _filterAndSortInterns(provider);
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown(DashboardProvider provider) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: _sortOptions
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.unfold_more_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(s),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _sortBy = v!);
            _filterAndSortInterns(provider);
          },
        ),
      ),
    );
  }

  Widget _buildSearchContent(DashboardProvider provider) {
    if (_isSearchLoading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Searching...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isNotEmpty) {
      return _buildSearchResultsList(_searchResults);
    }

    // Default Empty State matching Image 5
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_rounded, size: 40, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'Search for Interns',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter a name, trainee ID, or email to find specific interns and view their records.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 11, color: AppColors.statBlue),
                children: [
                  TextSpan(
                    text: '💡 Tip: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        'Type at least 2 characters to start searching or use the filter dropdown to see all interns by status',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(List<Map<String, dynamic>> results) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final intern = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                intern['name']?.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              intern['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              intern['traineeId'] ?? 'ID: ${intern['id']}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              try {
                final internDetails = await AdminApiService.fetchInternDetails(
                  intern['_id'] ?? intern['id'].toString(),
                );
                _showInternDetailsDialog(internDetails);
              } catch (e) {
                _showSnackbar('Failed to load intern details: $e');
              }
            },
          ),
        );
      },
    );
  }

  void _showInternDetailsDialog(Map<String, dynamic> intern) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          intern['name'] ?? 'Intern Details',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Trainee ID', intern['traineeId'] ?? 'N/A'),
              _buildDetailRow('Email', intern['email'] ?? 'N/A'),
              _buildDetailRow('Phone', intern['phone'] ?? 'N/A'),
              _buildDetailRow('Department', intern['department'] ?? 'N/A'),
              _buildDetailRow('University', intern['university'] ?? 'N/A'),
              _buildDetailRow('Status', intern['status'] ?? 'Active'),
              const SizedBox(height: 8),
              if (intern['totalSubmissions'] != null)
                _buildDetailRow(
                  'Total Submissions',
                  intern['totalSubmissions'].toString(),
                ),
              if (intern['lastSubmissionDate'] != null)
                _buildDetailRow(
                  'Last Submission',
                  DateTime.parse(
                    intern['lastSubmissionDate'],
                  ).toLocal().toString().split(' ')[0],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ExportType { submissions, nonSubmissions, weeklyNonSubmissions, onLeave }
