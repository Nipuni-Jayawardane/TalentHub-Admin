import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';

class OnLeaveListScreen extends StatefulWidget {
  const OnLeaveListScreen({super.key});

  @override
  State<OnLeaveListScreen> createState() => _OnLeaveListScreenState();
}

class _OnLeaveListScreenState extends State<OnLeaveListScreen> {
  List<Map<String, dynamic>> _onLeaveInterns = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadOnLeaveInterns();
  }

  Future<void> _loadOnLeaveInterns() async {
    setState(() => _isLoading = true);
    try {
      // Get all interns and filter those on leave
      final interns = await AdminApiService.fetchInternReports();
      final onLeave = interns.where((intern) {
        return intern['status'] == 'On Leave' ||
            intern['leaveStatus'] == 'Approved' ||
            (intern['onLeave'] == true);
      }).toList();

      setState(() {
        _onLeaveInterns = onLeave;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Failed to load on-leave interns: $e');
    }
  }

  Future<void> _exportOnLeaveList() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final response = await AdminApiService.downloadOnLeaveExcel();
      if (response.bodyBytes.isNotEmpty) {
        _showSnackbar('On-leave list exported successfully!', isError: false);
      }
    } catch (e) {
      _showSnackbar('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'On-Leave List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Export list of interns on leave',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.cardBlueTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 18,
              color: AppColors.iconBlue,
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
          // Export button
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _exportOnLeaveList,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isExporting
                          ? AppColors.iconBlue.withValues(alpha: 0.7)
                          : AppColors.iconBlue,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.iconBlue.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _isExporting
                          ? [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Exporting...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ]
                          : [
                              const Icon(
                                Icons.download_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Export On-Leave List (Excel)',
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.iconBlue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Interns on approved leave will appear here. You can export the list as an Excel file.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // Stats
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBlueTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.beach_access_rounded,
                    color: AppColors.iconBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total On Leave',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${_onLeaveInterns.length}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.iconBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _onLeaveInterns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.beach_access_rounded,
                          size: 64,
                          color: AppColors.textHint.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No interns on leave',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All interns are currently active',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _onLeaveInterns.length,
                    itemBuilder: (context, index) {
                      final intern = _onLeaveInterns[index];
                      return _OnLeaveCard(intern: intern);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OnLeaveCard extends StatelessWidget {
  final Map<String, dynamic> intern;

  const _OnLeaveCard({required this.intern});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = intern['name'] ?? 'Unknown';
    final traineeId = intern['traineeId'] ?? intern['_id']?.toString() ?? 'N/A';
    final department = intern['department'] ?? 'General';
    final leaveType = intern['leaveType'] ?? intern['reason'] ?? 'On Leave';
    final fromDate = intern['leaveFrom'] ?? intern['startDate'];
    final toDate = intern['leaveTo'] ?? intern['endDate'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.statBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.statBlue,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$traineeId • $department',
                      style: const TextStyle(
                        fontSize: 12,
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
                  color: AppColors.cardBlueTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.statBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  leaveType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _dateInfo('From', _formatDate(fromDate)),
                Container(width: 1, height: 24, color: AppColors.border),
                _dateInfo('To', _formatDate(toDate)),
                Container(width: 1, height: 24, color: AppColors.border),
                _dateInfo('Status', 'On Leave'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textHint),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
