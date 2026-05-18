import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talent_trail_admin_api.dart';
import 'package:intl/intl.dart';
import 'package:slt_internship_attendance_portal/core/services/api_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

class TalentTrailHomeScreen extends StatefulWidget {
  const TalentTrailHomeScreen({super.key});

  @override
  State<TalentTrailHomeScreen> createState() => _TalentTrailHomeScreenState();
}

class _TalentTrailHomeScreenState extends State<TalentTrailHomeScreen> {
  bool isDropdownOpen = false;
  bool isSidebarOpen = false;
  String _exportOption = 'All';
  final List<String> _exportOptions = ['All', 'Assigned', 'Unassigned'];
  bool _isExporting = false;

  // Dashboard state variables
  bool isLoading = true;
  bool isRefreshing = false;
  String? error;
  bool isAuthenticating = false;

  // Stats from various APIs
  int totalInterns = 0;
  int activeInterns = 0;
  int unassignedInterns = 0;
  int totalTeams = 0;
  int totalProjects = 0;
  int ongoingProjects = 0;
  int completedProjects = 0;
  int pendingRepositoryInfo = 0;
  String lastActiveInternsUpdate = '';

  // Project requests state
  List<dynamic> projectRequests = [];
  bool isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeAndLoadData() async {
    setState(() {
      isLoading = true;
      error = null;
      isAuthenticating = true;
    });

    try {
      // Ensure we have a valid TalentTrail token
      final hasToken = await TalentTrailAuthService.isAuthenticated();

      if (!hasToken) {
        debugPrint('No TalentTrail token found, attempting federated login...');
        await TalentTrailAuthService.federatedLogin();
        debugPrint('Federated login successful');
      } else {
        debugPrint('TalentTrail token found');
      }

      setState(() {
        isAuthenticating = false;
      });

      // Load the dashboard data after authentication
      await _loadAllDashboardData();
    } catch (e) {
      debugPrint('Authentication error: $e');
      if (mounted) {
        setState(() {
          error =
              'Authentication failed: $e\nPlease check if you have access to TalentTrail.';
          isLoading = false;
          isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _loadAllDashboardData() async {
    try {
      await Future.wait([_loadDashboardStats(), _loadProjectRequests()]);
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        _safeApiCall(() => TalentTrailAdminService.getInternCount(), 0),
        _safeApiCall(() => TalentTrailAdminService.getActiveInternCount(), 0),
        _safeApiCall(() => TalentTrailAdminService.getProjectCount(), 0),
        _safeApiCall(() => TalentTrailAdminService.getTeamCount(), 0),
        _safeApiCall(() => TalentTrailAdminService.getOngoingProjectCount(), 0),
        _safeApiCall(
          () => TalentTrailAdminService.getCompletedProjectCount(),
          0,
        ),
        _safeApiCall(
          () => TalentTrailAdminService.getPendingRepositoryCount(),
          0,
        ),
        _safeApiCall(() => _getUnassignedInternsCount(), 0),
      ]);

      // Fetch specific dashboard stats separately
      Map<String, dynamic> dashboardStats = {};
      try {
        dashboardStats = await TalentTrailAdminService.getDashboardStats();
      } catch (e) {
        debugPrint('Error fetching dashboard stats: $e');
        dashboardStats = {
          'lastActiveInternsUpdate': DateFormat(
            'dd/MM/yyyy HH:mm:ss',
          ).format(DateTime.now()),
        };
      }

      if (mounted) {
        setState(() {
          totalInterns = results[0];
          activeInterns = results[1];
          totalProjects = results[2];
          totalTeams = results[3];
          ongoingProjects = results[4];
          completedProjects = results[5];
          pendingRepositoryInfo = results[6];
          unassignedInterns = results[7];
          lastActiveInternsUpdate =
              dashboardStats['lastActiveInternsUpdate'] ??
              DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      rethrow;
    }
  }

  // Safe wrapper for API calls to prevent complete UI failure on single endpoint failure
  Future<T> _safeApiCall<T>(
    Future<T> Function() apiCall,
    T defaultValue,
  ) async {
    try {
      return await apiCall();
    } catch (e) {
      debugPrint('API call failed: $e');
      return defaultValue;
    }
  }

  Future<int> _getUnassignedInternsCount() async {
    try {
      final allInterns = await TalentTrailAdminService.getInterns();
      final teamMembers =
          await TalentTrailAdminService.getTeamMemberAssociations();

      // Collect all intern IDs currently assigned to teams
      final assignedInternIds = teamMembers
          .map((tm) => tm['internId'] as int?)
          .where((id) => id != null)
          .toSet();

      // Count interns not present in the assigned set
      return allInterns.where((intern) {
        final internId = intern['internId'] as int?;
        return internId != null && !assignedInternIds.contains(internId);
      }).length;
    } catch (e) {
      debugPrint('Error getting unassigned interns: $e');
      return 0;
    }
  }

  Future<void> _loadProjectRequests() async {
    setState(() {
      isLoadingRequests = true;
    });

    try {
      final requests = await TalentTrailAdminService.getProjectRequests();
      if (mounted) {
        setState(() {
          projectRequests = requests;
        });
      }
    } catch (e) {
      debugPrint('Error loading project requests: $e');
      // Do not throw, default to an empty list on failure
      if (mounted) {
        setState(() {
          projectRequests = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
    });

    try {
      // Verify token and re-authenticate if necessary
      final hasToken = await TalentTrailAuthService.isAuthenticated();
      if (!hasToken) {
        await TalentTrailAuthService.federatedLogin();
      }

      await _loadDashboardStats();
      await _loadProjectRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    }
  }

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0000CD), // Dark blue background
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () {
          // Placeholder for import functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Import Data feature coming soon!'),
              backgroundColor: Colors.blue,
            ),
          );
        },
        child: const Text(
          'IMPORT DATA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildExportDropdown() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF00C853),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(canvasColor: Colors.white),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _exportOption,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            icon: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.arrow_drop_down, color: Colors.white),
            ),
            items: _exportOptions.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        option == 'All'
                            ? Icons.people
                            : option == 'Assigned'
                            ? Icons.check_circle
                            : Icons.person_off,
                        color: option == 'All'
                            ? Colors.blue
                            : option == 'Assigned'
                            ? Colors.green
                            : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        option,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) async {
              if (newValue != null && mounted) {
                setState(() {
                  _exportOption = newValue;
                });
                await _handleExportData();
              }
            },
            selectedItemBuilder: (BuildContext context) {
              return _exportOptions.map((String option) {
                return Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Spacer(),
                      const Icon(Icons.download, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'EXPORT DATA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight
                              .bold, // Updated to bold to match Import
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        option,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportData() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Display loading dialog to user
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Exporting interns data...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Fetch required data for export mapping
      final allInterns = await TalentTrailAdminService.getInterns();
      final List<dynamic> internsList = allInterns;

      final teamMembershipsRaw =
          await TalentTrailAdminService.getTeamMemberAssociations();
      final List<dynamic> teamMemberships = teamMembershipsRaw;

      final allProjectsRaw = await TalentTrailAdminService.getProjects();
      final List<dynamic> allProjects = allProjectsRaw;

      // Construct intern data map
      final Map<int, Map<String, dynamic>> internData = {};

      for (var intern in internsList) {
        if (intern is Map<String, dynamic>) {
          final internId = intern['internId'] as int?;
          if (internId != null) {
            internData[internId] = {
              'intern_code': intern['internCode']?.toString() ?? '',
              'name': intern['name']?.toString() ?? '',
              'email': intern['email']?.toString() ?? '',
              'team_name': <String>[],
              'project_name': <String>[],
              'status': 'Unassigned',
            };
          }
        }
      }

      // Map team memberships and assigned projects
      final Set<int> assignedInternIds = {};

      for (var membership in teamMemberships) {
        if (membership is Map<String, dynamic>) {
          final internId = membership['internId'] as int?;
          final teamId = membership['teamId'] as int?;
          final teamName = membership['teamName']?.toString() ?? '';

          if (internId != null && internData.containsKey(internId)) {
            assignedInternIds.add(internId);

            if (teamName.isNotEmpty) {
              final teamNames = List<String>.from(
                internData[internId]!['team_name'],
              );
              if (!teamNames.contains(teamName)) {
                internData[internId]!['team_name'].add(teamName);
              }
            }

            if (teamId != null) {
              final teamProjects = allProjects.where((project) {
                if (project is Map<String, dynamic>) {
                  final assignedTeamIds = List<int>.from(
                    project['assignedTeamIds'] ?? [],
                  );
                  return assignedTeamIds.contains(teamId);
                }
                return false;
              }).toList();

              for (var project in teamProjects) {
                if (project is Map<String, dynamic>) {
                  final projectName = project['projectName']?.toString() ?? '';
                  if (projectName.isNotEmpty) {
                    final projectNames = List<String>.from(
                      internData[internId]!['project_name'],
                    );
                    if (!projectNames.contains(projectName)) {
                      internData[internId]!['project_name'].add(projectName);
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Apply assigned status
      for (var internId in assignedInternIds) {
        if (internData.containsKey(internId)) {
          internData[internId]!['status'] = 'Assigned';
        }
      }

      // Filter dataset based on selected dropdown option
      List<Map<String, dynamic>> exportList = [];

      switch (_exportOption) {
        case 'All':
          exportList = internData.values.toList();
          break;
        case 'Assigned':
          exportList = internData.values
              .where((data) => data['status'] == 'Assigned')
              .toList();
          break;
        case 'Unassigned':
          exportList = internData.values
              .where((data) => data['status'] == 'Unassigned')
              .toList();
          break;
      }

      // Format data and trigger download
      final exportData = await _prepareExportData(exportList);
      final csvString = await _generateCSV(exportData);
      await _saveAndOpenCSV(csvString);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${exportList.length} interns ($_exportOption) successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _prepareExportData(
    List<Map<String, dynamic>> data,
  ) async {
    final List<Map<String, dynamic>> formattedData = [];

    for (var item in data) {
      final teamNames = List<String>.from(item['team_name'] ?? []);
      final projectNames = List<String>.from(item['project_name'] ?? []);

      if (teamNames.isEmpty && projectNames.isEmpty) {
        // Single row for interns with no associations
        formattedData.add({
          'intern_code': item['intern_code']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'email': item['email']?.toString() ?? '',
          'team_name': '',
          'project_name': '',
          'status': item['status']?.toString() ?? 'Unassigned',
        });
      } else if (teamNames.isNotEmpty && projectNames.isEmpty) {
        // Row for each associated team
        for (var team in teamNames) {
          formattedData.add({
            'intern_code': item['intern_code']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'email': item['email']?.toString() ?? '',
            'team_name': team.toString(),
            'project_name': '',
            'status': item['status']?.toString() ?? 'Assigned',
          });
        }
      } else if (teamNames.isEmpty && projectNames.isNotEmpty) {
        // Row for each associated project
        for (var project in projectNames) {
          formattedData.add({
            'intern_code': item['intern_code']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'email': item['email']?.toString() ?? '',
            'team_name': '',
            'project_name': project.toString(),
            'status': item['status']?.toString() ?? 'Assigned',
          });
        }
      } else {
        // Cartesian product rows for both teams and projects
        for (var team in teamNames) {
          for (var project in projectNames) {
            formattedData.add({
              'intern_code': item['intern_code']?.toString() ?? '',
              'name': item['name']?.toString() ?? '',
              'email': item['email']?.toString() ?? '',
              'team_name': team.toString(),
              'project_name': project.toString(),
              'status': item['status']?.toString() ?? 'Assigned',
            });
          }
        }
      }
    }

    return formattedData;
  }

  Future<String> _generateCSV(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) {
      return 'intern_code,name,email,team_name,project_name,status\nNo data available,,,,,';
    }

    final headers = [
      'intern_code',
      'name',
      'email',
      'team_name',
      'project_name',
      'status',
    ];

    final StringBuffer csvBuffer = StringBuffer();

    // Insert headers
    csvBuffer.writeln(headers.join(','));

    // Insert data row by row
    for (var row in data) {
      final List<String> values = [];
      for (var header in headers) {
        var value = row[header]?.toString() ?? '';
        // Ensure CSV safety by escaping quotes
        if (value.contains(',') ||
            value.contains('"') ||
            value.contains('\n')) {
          value = '"${value.replaceAll('"', '""')}"';
        }
        values.add(value);
      }
      csvBuffer.writeln(values.join(','));
    }

    return csvBuffer.toString();
  }

  Future<void> _saveAndOpenCSV(String csvString) async {
    try {
      final directory = await _getDownloadDirectory();
      final timestamp = DateFormat(
        'yyyy-MM-dd_HH-mm-ss',
      ).format(DateTime.now());
      final fileName =
          'interns_export_${_exportOption.toLowerCase()}_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';

      final File file = File(filePath);
      await file.writeAsString(csvString, encoding: utf8);

      // Trigger native file opening
      await OpenFile.open(filePath);
    } catch (e) {
      debugPrint('Error saving file: $e');
      rethrow;
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Request storage permission for Android
        if (await Permission.storage.request().isGranted) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            return downloadsDir;
          }

          // Fallback mechanism for Android storage
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final downloadsPath =
                '${externalDir.path.split('Android')[0]}Download';
            final fallbackDir = Directory(downloadsPath);
            if (!await fallbackDir.exists()) {
              await fallbackDir.create(recursive: true);
            }
            return fallbackDir;
          }
        }
      } else if (Platform.isIOS) {
        // Fallback to Documents directory for iOS sandboxing
        final documentsDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory('${documentsDir.path}/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null && await downloadsDir.exists()) {
          return downloadsDir;
        }
      }

      // Final fallback
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('Error getting download directory: $e');
      return await getApplicationDocumentsDirectory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The newly added back navigation button
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/');
            }
          },
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 70,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 4, 2, 34),
                Color.fromARGB(255, 24, 17, 86),
                Color.fromARGB(255, 41, 150, 107),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Title configuration
        title: Image.asset(
          'assets/images/TalentTrail_logo.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.analytics, size: 40, color: Colors.white);
          },
        ),
        // Actions configuration containing the hamburger menu
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, size: 30, color: Colors.white),
            onPressed: () => setState(() => isSidebarOpen = true),
          ),
          const SizedBox(width: 8), // Added subtle padding for aesthetics
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [_buildHeaderSection(), _buildDashboardOverview()],
              ),
            ),
          ),
          if (isSidebarOpen)
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

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF40E0A0), Color(0xFF20B8A8), Color(0xFF2060D0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "Welcome to TalentTrail",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Track & manage interns, teams, and projects with ease and clarity!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 30),

          // Added the Import Data Button
          _buildImportButton(),
          const SizedBox(height: 12),

          // Existing Export Dropdown
          _buildExportDropdown(),
        ],
      ),
    );
  }

  Widget _buildDashboardOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35),
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          const Text(
            "Dashboard Overview",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _refreshButton(),
          const SizedBox(height: 20),
          const Text(
            "Get a quick snapshot of key metrics including intern status, "
            "team distribution, and project progress — all updated in real time.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
          const SizedBox(height: 25),
          _autoRefreshBanner(),
          const SizedBox(height: 25),
          if (isAuthenticating)
            const Center(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(height: 16),
                  Text('Authenticating with TalentTrail...'),
                ],
              ),
            )
          else if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    "Failed to load dashboard data\n$error",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshData,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _metricCard(
                  gradient: const [Color(0xFF90CAF9), Color(0xFF64B5F6)],
                  iconBg: const Color(0xFF1976D2),
                  icon: LucideIcons.user,
                  number: totalInterns.toString(),
                  label: "TOTAL INTERNS",
                  textColor: const Color(0xFF0D47A1),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFFA5D6A7), Color(0xFF81C784)],
                  iconBg: const Color(0xFF388E3C),
                  icon: LucideIcons.userCheck,
                  number: activeInterns.toString(),
                  label: "ACTIVE INTERNS",
                  textColor: const Color(0xFF1B5E20),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFFEF9A9A), Color(0xFFE57373)],
                  iconBg: const Color(0xFFC62828),
                  icon: LucideIcons.userX,
                  number: '80', // Example placeholder
                  label: "UNASSIGNED INTERNS",
                  textColor: const Color(0xFFB71C1C),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFF90CAF9), Color(0xFF64B5F6)],
                  iconBg: const Color(0xFF1976D2),
                  icon: LucideIcons.users,
                  number: totalTeams.toString(),
                  label: "TOTAL TEAMS",
                  textColor: const Color(0xFF0D47A1),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFFCE93D8), Color(0xFFBA68C8)],
                  iconBg: const Color(0xFF7B1FA2),
                  icon: LucideIcons.folder,
                  number: totalProjects.toString(),
                  label: "TOTAL PROJECTS",
                  textColor: const Color(0xFF4A148C),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFFFFE082), Color(0xFFFFD54F)],
                  iconBg: const Color(0xFFF57C00),
                  icon: LucideIcons.folderOpen,
                  number: ongoingProjects.toString(),
                  label: "ONGOING PROJECTS",
                  textColor: const Color(0xFFBF360C),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFFB2EBF2), Color(0xFF80DEEA)],
                  iconBg: const Color(0xFF00838F),
                  icon: LucideIcons.checkCircle,
                  number: completedProjects.toString(),
                  label: "COMPLETED PROJECTS",
                  textColor: const Color(0xFF006064),
                ),
                const SizedBox(height: 15),
                _metricCard(
                  gradient: const [Color(0xFFFFCDD2), Color(0xFFEF9A9A)],
                  iconBg: const Color(0xFFC62828),
                  icon: LucideIcons.alertTriangle,
                  number: pendingRepositoryInfo.toString(),
                  label: "PENDING REPOSITORY INFO",
                  textColor: const Color(0xFFB71C1C),
                ),
              ],
            ),
          const SizedBox(height: 25),
          Text(
            "Latest Active Interns Update: $lastActiveInternsUpdate",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          _projectRequestsSection(),
        ],
      ),
    );
  }

  Widget _refreshButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      onPressed: isRefreshing ? null : _refreshData,
      icon: isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(LucideIcons.refreshCw),
      label: const Text("Refresh"),
    );
  }

  Widget _autoRefreshBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.autorenew, color: Color(0xFF1976D2), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Auto-refresh: Data is synced daily at 8:00 AM",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1976D2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required List<Color> gradient,
    required Color iconBg,
    required IconData icon,
    required String number,
    required String label,
    required Color textColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final iconRadius = isSmallScreen ? 24.0 : 30.0;
    final iconSize = isSmallScreen ? 24.0 : 32.0;
    final fontSize = isSmallScreen ? 28.0 : 36.0;
    final padding = isSmallScreen ? 12.0 : 20.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: iconRadius,
            backgroundColor: iconBg.withValues(alpha: 0.2),
            child: Icon(icon, size: iconSize, color: iconBg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectRequestsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final titleFontSize = isSmallScreen ? 22.0 : 28.0;
    final subtitleFontSize = isSmallScreen ? 14.0 : 18.0;
    final padding = isSmallScreen ? 16.0 : 25.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          Text(
            "Project & Team requests",
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "See what interns are proposing and approve the best ideas.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: subtitleFontSize, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
                vertical: isSmallScreen ? 10 : 12,
              ),
            ),
            onPressed: isLoadingRequests ? null : _loadProjectRequests,
            icon: isLoadingRequests
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(
              isSmallScreen ? "Refresh" : "Refresh Requests",
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
          const SizedBox(height: 30),
          if (isLoadingRequests)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (projectRequests.isEmpty)
            _buildEmptyRequestsState()
          else
            _buildRequestsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyRequestsState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final padding = isSmallScreen ? 30.0 : 50.0;
    final emojiSize = isSmallScreen ? 40.0 : 50.0;
    final titleFontSize = isSmallScreen ? 20.0 : 24.0;
    final subtitleFontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Text("🎉", style: TextStyle(fontSize: emojiSize)),
          const SizedBox(height: 10),
          Text(
            "All clear!",
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 0),
            child: Text(
              "There are no pending project requests at the moment.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: subtitleFontSize, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Column(
      children: projectRequests.map((request) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          width: double.infinity,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                _showRequestDetails(request);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header identifying the project request
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.request_page,
                            size: isSmallScreen ? 20 : 24,
                            color: const Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['projectName'] ?? 'Untitled Project',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2C3E50),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    request['status'] ?? 'PENDING',
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  request['status']?.toString().toUpperCase() ??
                                      'PENDING',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 12,
                                    color: _getStatusColor(
                                      request['status'] ?? 'PENDING',
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Specific details regarding the request
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            label: "Requested by",
                            value:
                                request['internName']?.toString() ?? 'Unknown',
                            isSmallScreen: isSmallScreen,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            label: "Request Date",
                            value: _formatDate(
                              request['createdAt']?.toString(),
                            ),
                            isSmallScreen: isSmallScreen,
                          ),
                          if (request['description'] != null &&
                              request['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              icon: Icons.description_outlined,
                              label: "Description",
                              value: request['description'].toString(),
                              isSmallScreen: isSmallScreen,
                              isMultiline: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action controls for approval/rejection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _rejectRequest(request),
                          icon: Icon(
                            Icons.close,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          label: Text(
                            "Reject",
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _approveRequest(request),
                          icon: Icon(
                            Icons.check,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          label: Text(
                            "Approve",
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 8 : 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: isSmallScreen ? 14 : 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: isSmallScreen ? 70 : 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: isMultiline
              ? Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: const Color(0xFF2C3E50),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: const Color(0xFF2C3E50),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
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

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    try {
      final requestId = request['id'] ?? request['requestId'];
      if (requestId != null) {
        await TalentTrailAdminService.updateProjectRequestStatus(
          requestId as int,
          'APPROVED',
        );
      }

      if (mounted) {
        setState(() {
          projectRequests.remove(request);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      final requestId = request['id'] ?? request['requestId'];
      if (requestId != null) {
        await TalentTrailAdminService.updateProjectRequestStatus(
          requestId as int,
          'REJECTED',
        );
      }

      if (mounted) {
        setState(() {
          projectRequests.remove(request);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRequestDetails(Map<String, dynamic> request) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isSmallScreen ? screenWidth - 32 : 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.request_page,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request['projectName'] ?? 'Project Request',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                'Requested by',
                request['internName'] ?? 'Unknown',
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Status', request['status'] ?? 'PENDING'),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Request Date',
                _formatDate(request['createdAt']?.toString()),
              ),
              if (request['description'] != null &&
                  request['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Description',
                  request['description'].toString(),
                  isMultiline: true,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isMultiline
              ? Text(value, style: const TextStyle(color: Color(0xFF2C3E50)))
              : Text(value, style: const TextStyle(color: Color(0xFF2C3E50))),
        ),
      ],
    );
  }
}
