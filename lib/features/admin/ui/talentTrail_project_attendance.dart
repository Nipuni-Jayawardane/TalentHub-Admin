import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talent_trail_admin_api.dart';

class ProjectAttendancePage extends StatefulWidget {
  const ProjectAttendancePage({super.key});

  @override
  State<ProjectAttendancePage> createState() => _ProjectAttendancePageState();
}

class _ProjectAttendancePageState extends State<ProjectAttendancePage> {
  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  String projectFilter = 'All Projects';
  String secondFilter = 'None';

  bool isSidebarOpen = false;
  bool isLoading = true;
  bool isSubmitting = false;
  String? error;

  // Projects fetched from the API
  List<Map<String, dynamic>> allProjects = [];
  List<Map<String, dynamic>> filteredByDayProjects = [];

  // Attendance records for the selected date
  Map<int, String> attendanceRecords = {};

  // Map days to their order for sorting
  final Map<String, int> dayOrder = {
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
    'Sunday': 7,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Fetch all projects
      final projectsData = await TalentTrailAdminService.getProjects();
      allProjects = projectsData.cast<Map<String, dynamic>>();

      // Filter projects by the selected date's meeting day
      _filterProjectsByDay(selectedDate);

      // Load attendance records for the selected date
      await _loadAttendanceForDate(selectedDate);

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _filterProjectsByDay(DateTime date) {
    // Get the day name for the selected date
    final dayName = DateFormat(
      'EEEE',
    ).format(date); // Returns full day name like "Tuesday"

    debugPrint('Selected date: ${DateFormat('yyyy-MM-dd').format(date)}');
    debugPrint('Day name: $dayName');

    // Filter projects that have meeting day matching the selected date's day
    filteredByDayProjects = allProjects.where((project) {
      final meetingDay = project['meetingDay']?.toString();
      if (meetingDay == null || meetingDay.isEmpty) return false;

      // Case-insensitive comparison
      return meetingDay.toLowerCase() == dayName.toLowerCase();
    }).toList();

    debugPrint('Projects found for $dayName: ${filteredByDayProjects.length}');
  }

  Future<void> _loadAttendanceForDate(DateTime date) async {
    try {
      attendanceRecords.clear();
    } catch (e) {
      debugPrint('Error loading attendance: $e');
    }
  }

  Future<void> _markAttendance(int projectId, String status) async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

      await TalentTrailAdminService.submitProjectAttendance(
        projectId: projectId,
        date: dateStr,
        status: status,
      );

      // Update local record
      setState(() {
        attendanceRecords[projectId] = status;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance marked as $status for ${_getProjectName(projectId)}',
          ),
          backgroundColor: status == 'PRESENT' ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  String _getProjectName(int projectId) {
    final project = filteredByDayProjects.firstWhere(
      (p) => p['projectId'] == projectId,
      orElse: () => {},
    );
    return project['projectName']?.toString() ?? 'Project';
  }

  List<Map<String, dynamic>> get _filteredAndSearchedProjects {
    List<Map<String, dynamic>> result = List.from(filteredByDayProjects);

    // Apply search filter
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result
          .where(
            (p) =>
                (p['projectName'] ?? '').toString().toLowerCase().contains(q),
          )
          .toList();
    }

    // Apply status filter
    if (projectFilter != 'All Projects') {
      final statusMap = {
        'Planned': 'PLANNING',
        'In Progress': 'IN_PROGRESS',
        'Completed': 'COMPLETED',
        'On Hold': 'ON_HOLD',
      };
      final apiStatus = statusMap[projectFilter];
      if (apiStatus != null) {
        result = result.where((p) => p['status'] == apiStatus).toList();
      }
    }

    // Apply sorting
    switch (secondFilter) {
      case 'Project Name (Ascending)':
        result.sort(
          (a, b) => (a['projectName'] ?? '').compareTo(b['projectName'] ?? ''),
        );
        break;
      case 'Project Name (Descending)':
        result.sort(
          (a, b) => (b['projectName'] ?? '').compareTo(a['projectName'] ?? ''),
        );
        break;
      case 'Start Date (Ascending)':
        result.sort(
          (a, b) => (a['startDate'] ?? '').compareTo(b['startDate'] ?? ''),
        );
        break;
      case 'Start Date (Descending)':
        result.sort(
          (a, b) => (b['startDate'] ?? '').compareTo(a['startDate'] ?? ''),
        );
        break;
      case 'Target Date (Ascending)':
        result.sort(
          (a, b) => (a['targetDate'] ?? '').compareTo(b['targetDate'] ?? ''),
        );
        break;
      case 'Target Date (Descending)':
        result.sort(
          (a, b) => (b['targetDate'] ?? '').compareTo(a['targetDate'] ?? ''),
        );
        break;
    }

    return result;
  }

  Future<void> _generateReport() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final dayName = DateFormat('EEEE').format(selectedDate);
      final projectCount = filteredByDayProjects.length;

      // Show summary dialog instead of just a snackbar
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Attendance Report - $dayName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $dateStr'),
              const SizedBox(height: 8),
              Text('Day: $dayName'),
              const SizedBox(height: 8),
              Text('Total Projects: $projectCount'),
              const SizedBox(height: 16),
              const Text('Attendance Summary:'),
              const SizedBox(height: 8),
              ...filteredByDayProjects.map((project) {
                final projectId = project['projectId'];
                final status = attendanceRecords[projectId];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text('• ${project['projectName']}: '),
                      Text(
                        status ?? 'Not marked',
                        style: TextStyle(
                          color: status == 'PRESENT'
                              ? Colors.green
                              : status == 'ABSENT'
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 70,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 3, 10, 22),
                Color.fromARGB(255, 11, 7, 67),
                Color.fromARGB(255, 41, 150, 107),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/TalentTrail_logo.png',
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.analytics,
                  size: 40,
                  color: Colors.white,
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.menu, size: 30, color: Colors.white),
              onPressed: () {
                setState(() => isSidebarOpen = true);
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildFilters(),
                  const SizedBox(height: 24),

                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (error != null)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Failed to load projects\n$error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildTable(),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: TalentTrailSidebar(
              isOpen: isSidebarOpen,
              onClose: () => setState(() => isSidebarOpen = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: const [
          Text(
            'Project Attendance',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 15, 15, 79),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'Record meeting attendance and view history logs for ongoing projects',
            style: TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Date:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 12),
                _datePicker(),
              ],
            ),
            _inputField(
              hint: 'Search projects...',
              width: 260,
              onChanged: (v) => setState(() => searchQuery = v),
            ),
            _dropdown(
              value: projectFilter,
              items: const [
                'All Projects',
                'Planned',
                'In Progress',
                'Completed',
                'On Hold',
              ],
              onChanged: (v) => setState(() => projectFilter = v!),
            ),
            _dropdown(
              value: secondFilter,
              items: const [
                'None',
                'Project Name (Ascending)',
                'Project Name (Descending)',
                'Start Date (Ascending)',
                'Start Date (Descending)',
                'Target Date (Ascending)',
                'Target Date (Descending)',
              ],
              onChanged: (v) => setState(() => secondFilter = v!),
            ),

            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 83, 121, 204),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _generateReport,
                child: const Text(
                  'Generate Report',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (date != null && date != selectedDate) {
          setState(() {
            selectedDate = date;
          });
          _filterProjectsByDay(date);
          await _loadAttendanceForDate(date);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(selectedDate),
          style: const TextStyle(color: Color(0xFF374151)),
        ),
      ),
    );
  }

  Widget _inputField({
    required String hint,
    required double width,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    final data = _filteredAndSearchedProjects;

    if (data.isEmpty) {
      final dayName = DateFormat('EEEE').format(selectedDate);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.event_busy, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No projects scheduled for $dayName',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a different date to view projects',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF0A1F44)),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
          columns: const [
            DataColumn(label: Text('PROJECT NAME')),
            DataColumn(label: Text('MEETING DAY')),
            DataColumn(label: Text('MEMBERS')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('DETAILS')),
            DataColumn(label: Text('MARK ATTENDANCE')),
          ],
          rows: List.generate(data.length, (index) {
            final p = data[index];
            final projectId = p['projectId'] ?? 0;
            final members = (p['currentInternsCount'] ?? '-').toString();
            final meetingDay = (p['meetingDay'] ?? '-').toString();
            final status = (p['status'] ?? '-').toString();

            // Check if attendance already marked for this project on selected date
            final attendanceStatus = attendanceRecords[projectId];
            final isPresent = attendanceStatus == 'PRESENT';
            final isAbsent = attendanceStatus == 'ABSENT';

            return DataRow(
              color: WidgetStateProperty.all(
                index.isEven ? Colors.white : const Color(0xFFF9FAFB),
              ),
              cells: [
                DataCell(Text((p['projectName'] ?? '-').toString())),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      meetingDay,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                DataCell(
                  Text(
                    members,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'IN_PROGRESS'
                          ? Colors.green.withValues(alpha: 0.1)
                          : status == 'COMPLETED'
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: status == 'IN_PROGRESS'
                            ? Colors.green.shade700
                            : status == 'COMPLETED'
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  _circleButton(
                    Icons.info,
                    Colors.blue,
                    onTap: () {
                      _showProjectDetails(p);
                    },
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      if (isPresent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Present',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        )
                      else if (isAbsent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Absent',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        )
                      else
                        Row(
                          children: [
                            GestureDetector(
                              onTap: isSubmitting
                                  ? null
                                  : () => _markAttendance(projectId, 'PRESENT'),
                              child: _circleButton(Icons.check, Colors.green),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: isSubmitting
                                  ? null
                                  : () => _markAttendance(projectId, 'ABSENT'),
                              child: _circleButton(Icons.close, Colors.red),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _showProjectDetails(Map<String, dynamic> project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(project['projectName'] ?? 'Project Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Description', project['description'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Supervisor', project['supervisorName'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Start Date', project['startDate'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Target Date', project['targetDate'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Meeting Day', project['meetingDay'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Current Interns',
                (project['currentInternsCount'] ?? 'N/A').toString(),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Repository',
                project['repoName'] ?? 'Not configured',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF6B7280))),
        ),
      ],
    );
  }
}
