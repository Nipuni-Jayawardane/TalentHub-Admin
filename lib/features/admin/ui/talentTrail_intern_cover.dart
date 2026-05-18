import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talent_trail_admin_api.dart';

class InternCoverPage extends StatefulWidget {
  const InternCoverPage({super.key});

  @override
  State<InternCoverPage> createState() => _InternCoverPageState();
}

class _InternCoverPageState extends State<InternCoverPage> {
  bool isSidebarOpen = false;
  bool _isLoading = true;
  String? _error;

  // Stats data
  int _totalInterns = 0;
  int _activeInterns = 0;
  int _endingSoonCount = 0;

  // Interns ending soon
  List<Map<String, dynamic>> _internsEndingSoon = [];

  // All interns for filtering
  List<Map<String, dynamic>> _allInterns = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all interns
      final interns = await TalentTrailAdminService.getInterns();
      _allInterns = List<Map<String, dynamic>>.from(interns);

      // Calculate stats
      _totalInterns = _allInterns.length;
      _activeInterns = _allInterns.where((intern) {
        final status = intern['status']?.toString().toUpperCase() ?? '';
        return status == 'ACTIVE';
      }).length;

      // Find interns ending within 15 days
      final today = DateTime.now();
      final fifteenDaysLater = today.add(const Duration(days: 15));

      _internsEndingSoon = _allInterns.where((intern) {
        final endDateStr = intern['trainingEndDate']?.toString();
        if (endDateStr == null || endDateStr.isEmpty) return false;

        try {
          final endDate = DateTime.parse(endDateStr);
          return endDate.isAfter(today) && endDate.isBefore(fifteenDaysLater);
        } catch (e) {
          return false;
        }
      }).toList();

      _endingSoonCount = _internsEndingSoon.length;

      // Fetch projects for each intern
      await _loadProjectsForInterns();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProjectsForInterns() async {
    try {
      // Get all projects
      final allProjects = await TalentTrailAdminService.getProjects();

      // Get team memberships for interns
      final teamMemberships =
          await TalentTrailAdminService.getTeamMemberAssociations();

      // Create a map of intern ID to their assigned projects
      final Map<int, List<String>> internProjects = {};

      for (var membership in teamMemberships) {
        final internId = membership['internId'];
        final teamId = membership['teamId'];

        if (internId != null && teamId != null) {
          // Find projects assigned to this team
          final teamProjects = allProjects.where((project) {
            final assignedTeamIds = List<int>.from(
              project['assignedTeamIds'] ?? [],
            );
            return assignedTeamIds.contains(teamId);
          }).toList();

          final projectNames = teamProjects
              .map((p) => p['projectName']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .toList();

          if (projectNames.isNotEmpty) {
            if (internProjects.containsKey(internId)) {
              internProjects[internId]!.addAll(projectNames);
            } else {
              internProjects[internId] = projectNames;
            }
          }
        }
      }

      // Update interns ending soon with their projects
      for (var i = 0; i < _internsEndingSoon.length; i++) {
        final intern = _internsEndingSoon[i];
        final internId = intern['internId'];
        final projects = internProjects[internId] ?? [];

        // Remove duplicates while preserving order
        final uniqueProjects = projects.toSet().toList();

        _internsEndingSoon[i]['projects'] = uniqueProjects;
      }

      setState(() {});
    } catch (e) {
      debugPrint('Error loading projects: $e');
      // If projects loading fails, still show interns without projects
    }
  }

  Future<void> _refreshPage() async {
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Page refreshed")));
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
          /// MAIN CONTENT
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(error: _error!, onRetry: _loadData)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Intern Cover",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Refresh button - icon only
                            IconButton(
                              onPressed: _refreshPage,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Metric cards - one under another
                        Column(
                          children: [
                            MetricCard(
                              title: "Total interns",
                              value: _totalInterns.toString(),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF3F4F6), Color(0xFFE0F2FE)],
                              ),
                            ),
                            const SizedBox(height: 16),
                            MetricCard(
                              title: "Active interns",
                              value: _activeInterns.toString(),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF7ED), Color(0xFFFDE68A)],
                              ),
                            ),
                            const SizedBox(height: 16),
                            MetricCard(
                              title: "Ending soon (15 days or less)",
                              value: _endingSoonCount.toString(),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFBFDBFE), Color(0xFF93C5FD)],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Interns ending within 15 days",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_internsEndingSoon.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                      'No interns ending within 15 days',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  itemCount: _internsEndingSoon.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return InternCard(
                                      intern: _internsEndingSoon[index],
                                      formatDate: _formatDate,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          /// SIDEBAR
          Positioned.fill(
            child: TalentTrailSidebar(
              isOpen: isSidebarOpen,
              onClose: () {
                setState(() => isSidebarOpen = false);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ERROR VIEW WIDGET
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to load data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4169E1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// METRIC CARD WIDGET - Updated to be full width and responsive
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Gradient gradient;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final fontSize = isSmallScreen ? 32.0 : 40.0;
    final padding = isSmallScreen ? 16.0 : 20.0;

    return Container(
      width: double.infinity, // Takes full width
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black54,
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// INTERN CARD WIDGET
class InternCard extends StatelessWidget {
  final Map<String, dynamic> intern;
  final String Function(String?) formatDate;

  const InternCard({super.key, required this.intern, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final projects = List<String>.from(intern['projects'] ?? []);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Name & ID
          Row(
            children: [
              Expanded(
                child: Text(
                  intern['name'] ?? '',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                intern['internCode']?.toString() ??
                    intern['id']?.toString() ??
                    '',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// End date & Email
          if (!isSmallScreen)
            Row(
              children: [
                Text(
                  "Ends: ${formatDate(intern['trainingEndDate'])}",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    intern['email'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ends: ${formatDate(intern['trainingEndDate'])}",
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  intern['email'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),

          const SizedBox(height: 12),

          /// Projects
          if (projects.isNotEmpty) ...[
            const Text(
              "Assigned projects",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: projects.map((project) {
                return Chip(
                  label: Text(
                    project,
                    style: TextStyle(fontSize: isSmallScreen ? 11 : 13),
                  ),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                  labelStyle: TextStyle(color: Colors.blue.shade700),
                );
              }).toList(),
            ),
          ] else ...[
            const Text(
              "No projects assigned",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
