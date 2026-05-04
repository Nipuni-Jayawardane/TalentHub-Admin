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
import 'package:slt_internship_attendance_portal/features/admin/ui/short_leave_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/admin_daily_records.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/overdue_list.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/seat_management_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/announcements_screen.dart';
import 'package:slt_internship_attendance_portal/features/admin/providers/dashboard_provider.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/home_bottom_navigation_bar.dart';
import 'package:go_router/go_router.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;
  final VoidCallback onLogout;

  const AppHeader({super.key, required this.subtitle, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 70,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SLT Admin Portal',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color cardColor;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
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


  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.headingGradient.createShader(bounds),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
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
      // Implement your filtering logic here
      filtered = filtered.where((intern) {
        return true;
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
          backgroundColor: AppColors.background,
          appBar: AppHeader(subtitle: 'Dashboard', onLogout: _handleLogout),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE8F4FD), Color(0xFFF0F4F8)],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFDBEAFE),
                          child: Icon(
                            Icons.person_rounded,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back,',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Text(
                              'Administrator',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    'Intern Management',
                    'Monitor and manage intern logbook submissions',
                  ),
                  const SizedBox(height: 20),

                  // Stats Cards - Responsive layout using MediaQuery
                  if (provider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;

                        if (width < 400) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: StatCard(
                                  label: 'Total Interns',
                                  value: provider.totalInterns.toString(),
                                  icon: Icons.groups_rounded,
                                  iconColor: AppColors.statBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: StatCard(
                                  label: 'Submitted Today',
                                  value: provider.submittedInterns.toString(),
                                  icon: Icons.check_circle_rounded,
                                  iconColor: AppColors.statGreen,
                                  valueColor: AppColors.statGreen,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: StatCard(
                                  label: 'Overdue',
                                  value: provider.overdueInterns.toString(),
                                  icon: Icons.warning_rounded,
                                  iconColor: AppColors.statOrange,
                                  valueColor: AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: StatCard(
                                  label: 'Total Records',
                                  value: provider.totalRecords.toString(),
                                  icon: Icons.list_alt_rounded,
                                  iconColor: AppColors.statPurple,
                                  valueColor: AppColors.statPurple,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: width > 1200
                                ? 4
                                : (width > 800 ? 3 : 2),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: width > 800 ? 1.2 : 1.0,
                            children: [
                              StatCard(
                                label: 'Total Interns',
                                value: provider.totalInterns.toString(),
                                icon: Icons.groups_rounded,
                                iconColor: AppColors.statBlue,
                              ),
                              StatCard(
                                label: 'Submitted Today',
                                value: provider.submittedInterns.toString(),
                                icon: Icons.check_circle_rounded,
                                iconColor: AppColors.statGreen,
                                valueColor: AppColors.statGreen,
                              ),
                              StatCard(
                                label: 'Overdue',
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
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 24),

                  // Quick Actions Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Responsive Quick Actions Grid (same pattern as Exports)
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount:
                              MediaQuery.of(context).size.width < 400
                              ? 1
                              : (MediaQuery.of(context).size.width < 600
                                    ? 2
                                    : (MediaQuery.of(context).size.width < 900
                                          ? 3
                                          : 4)),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio:
                              MediaQuery.of(context).size.width < 400
                              ? 1.8
                              : (MediaQuery.of(context).size.width < 600
                                    ? 0.8
                                    : (MediaQuery.of(context).size.width < 900
                                          ? 0.7
                                          : 0.6)),
                          children: [
                            QuickActionCard(
                              icon: Icons.calendar_month_rounded,
                              title: 'Daily Records',
                              subtitle: 'All intern records',
                              iconColor: AppColors.iconGreen,
                              cardColor: AppColors.cardGreenTint,
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
                              subtitle: 'Manage short leave requests',
                              iconColor: AppColors.iconPurple,
                              cardColor: AppColors.cardPurpleTint,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ShortLeaveScreen(),
                                ),
                              ),
                            ),
                            QuickActionCard(
                              icon: Icons.access_time_rounded,
                              title: 'Overdue List',
                              subtitle: 'View overdue interns',
                              iconColor: AppColors.iconOrange,
                              cardColor: AppColors.cardYellowTint,
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
                              subtitle: 'Manage seating arrangements',
                              iconColor: AppColors.iconPink,
                              cardColor: AppColors.cardPinkTint,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SeatManagementScreen(),
                                ),
                              ),
                            ),
                            QuickActionCard(
                              icon: Icons.announcement_rounded,
                              title: 'Announcements',
                              subtitle: 'Important notices and updates',
                              iconColor: AppColors.iconBlue,
                              cardColor: AppColors.cardBlueTint,
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
                              subtitle: 'View intern locations map',
                              iconColor: const Color(0xFF0891B2),
                              cardColor: const Color(0xFFECFEFF),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InternLocationsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Exports Section
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 16),
                        const Text(
                          'Exports',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount:
                              MediaQuery.of(context).size.width < 400
                              ? 1
                              : (MediaQuery.of(context).size.width < 600
                                    ? 2
                                    : 3),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio:
                              MediaQuery.of(context).size.width < 400
                              ? 1.8
                              : 0.6,
                          children: [
                            QuickActionCard(
                              icon: Icons.upload_file_rounded,
                              title: 'Export Submissions List',
                              subtitle: 'Export submissions with date range',
                              iconColor: const Color(0xFF4F46E5),
                              cardColor: const Color(0xFFEEF2FF),
                              onTap: () => _showExportDialog(
                                'Export Submissions List',
                                ExportType.submissions,
                              ),
                            ),
                            QuickActionCard(
                              icon: Icons.upload_file,
                              title: 'Export Non Submissions List',
                              subtitle: 'Trigger Excel report to email',
                              iconColor: const Color(0xFFDC2626),
                              cardColor: const Color(0xFFFEE2E2),
                              onTap: () => _performExport(
                                ExportType.nonSubmissions,
                                null,
                                null,
                              ),
                            ),
                            QuickActionCard(
                              icon: Icons.insert_drive_file_rounded,
                              title: 'On Leave List',
                              subtitle: 'Export list of interns on leave',
                              iconColor: AppColors.iconTeal,
                              cardColor: AppColors.cardTealTint,
                              onTap: () => _performExport(
                                ExportType.onLeave,
                                null,
                                null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isTablet
                            ? Row(
                                children: [
                                  Expanded(child: _buildSearchField()),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 120,
                                      maxWidth: 150,
                                    ),
                                    child: _buildStatusDropdown(provider),
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 120,
                                      maxWidth: 150,
                                    ),
                                    child: _buildSortDropdown(provider),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildSearchField(),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatusDropdown(provider),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildSortDropdown(provider),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                        const SizedBox(height: 20),
                        _buildSearchContent(provider),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: HomeBottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });

              if (index == 1) {
                // Navigate to TalentTrail Dashboard
                context.go('/talenttrail-dashboard');
              }

              if (index == 0) {}
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => _searchInterns(value),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by name, Trainee ID, or email',
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.textHint,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textHint,
                ),
                onPressed: _clearSearch,
              )
            : null,
      ),
    );
  }

  Widget _buildStatusDropdown(DashboardProvider provider) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(
            Icons.filter_alt_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: _statusOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          icon: const Icon(
            Icons.swap_vert,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: _sortOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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

    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(
                Icons.search_off,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching with a different name or ID',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'Search for Interns',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Use the search bar above to find specific interns or select a filter option',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(36),
          ),
          child: const Icon(Icons.search, size: 36, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Search for Interns',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter a name, trainee ID, or email to find specific interns and view their records.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: AppColors.statBlue,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Tip: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statBlue,
                        ),
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
        ),
        const SizedBox(height: 16),
      ],
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
            side: BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                intern['name']?.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              intern['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              intern['traineeId'] ?? 'ID: ${intern['id']}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
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
