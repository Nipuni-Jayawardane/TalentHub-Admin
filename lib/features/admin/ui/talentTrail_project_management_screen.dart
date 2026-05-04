import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talentTrail_admin_api.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class Project {
  final String id;
  final String name;
  final String manager;
  final String status;
  final DateTime startDate;
  final DateTime targetDate;

  Project({
    required this.id,
    required this.name,
    required this.manager,
    required this.status,
    required this.startDate,
    required this.targetDate,
  });

  bool get isOverdue => targetDate.isBefore(DateTime.now());

  String get daysRemaining {
    final diff = targetDate.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Overdue by ${diff.abs()} days';
    return '$diff days remaining';
  }
}

class ProjectsManagementScreen extends StatefulWidget {
  const ProjectsManagementScreen({super.key});

  @override
  State<ProjectsManagementScreen> createState() =>
      _ProjectsManagementScreenState();
}

class _ProjectsManagementScreenState extends State<ProjectsManagementScreen> {
  bool isSidebarOpen = false;

  final TextEditingController _searchController = TextEditingController();

  String projectFilter = 'All Projects';
  String sortOption = 'None';

  List<Project> projects = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await TalentTrailAdminService.getProjects();

      projects = data.map<Project>((json) {
        return Project(
          id: json['projectId'].toString(),
          name: json['projectName'] ?? '',
          manager: json['projectManagerName'] ?? 'N/A',
          status: json['status'] ?? 'UNKNOWN',
          startDate: DateTime.parse(json['startDate']),
          targetDate: DateTime.parse(json['targetDate']),
        );
      }).toList();
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<Project> get filteredProjects {
    List<Project> result = [...projects];

    // Search filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                p.manager.toLowerCase().contains(query),
          )
          .toList();
    }

    // Status filter
    if (projectFilter != 'All Projects') {
      result = result
          .where(
            (p) =>
                p.status.toLowerCase().trim() ==
                projectFilter.toLowerCase().trim(),
          )
          .toList();
    }

    // Sorting
    switch (sortOption) {
      case 'Project Name (Ascending)':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Project Name (Descending)':
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Start Date (Ascending)':
        result.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case 'Start Date (Descending)':
        result.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
      case 'Target Date (Ascending)':
        result.sort((a, b) => a.targetDate.compareTo(b.targetDate));
        break;
      case 'Target Date (Descending)':
        result.sort((a, b) => b.targetDate.compareTo(a.targetDate));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 24),
                      _createButton(),
                      const SizedBox(height: 16),
                      _searchField(),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status Filter Dropdown
                          _dropdown(
                            hint: 'Filter by Status',
                            value: projectFilter,
                            items: [
                              'All Projects',
                              'Planned',
                              'In Progress',
                              'Completed',
                              'On Hold',
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => projectFilter = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // Sort Dropdown
                          _dropdown(
                            hint: 'Sort Projects',
                            value: sortOption,
                            items: [
                              'None',
                              'Project Name (Ascending)',
                              'Project Name (Descending)',
                              'Start Date (Ascending)',
                              'Start Date (Descending)',
                              'Target Date (Ascending)',
                              'Target Date (Descending)',
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => sortOption = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _projectsTable(),
                    ],
                  ),
                ),
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

  Widget _header() {
    return Column(
      children: const [
        Text(
          'Projects Management',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 15, 15, 79),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Track project progress, manage assignments, and monitor deliverables',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _createButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 65, 148, 225),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _openCreateProject(),
      icon: const Icon(Icons.add),
      label: const Text('Create New Project'),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search projects...',
        hintStyle: const TextStyle(color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _projectsTable() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('Failed to load projects\n$error')),
      );
    }

    if (filteredProjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No projects found.')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            _tableHeader(),
            ...filteredProjects.map(_tableRow),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateProject() async {
    final nameCtrl = TextEditingController();
    final supervisorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final meetingDayCtrl = TextEditingController();
    final requiredInternsCtrl = TextEditingController(text: '0');
    final statusCtrl = TextEditingController(text: 'PLANNING');
    final pmIdCtrl = TextEditingController();
    final repoHostCtrl = TextEditingController(text: 'GITHUB');
    final repoNameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Project'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Project Name'),
              ),
              TextField(
                controller: supervisorCtrl,
                decoration: const InputDecoration(labelText: 'Supervisor Name'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target Date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: meetingDayCtrl,
                decoration: const InputDecoration(
                  labelText: 'Meeting Day (e.g., Monday)',
                ),
              ),
              TextField(
                controller: requiredInternsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Required Interns',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: statusCtrl,
                decoration: const InputDecoration(
                  labelText: 'Status (PLANNING/IN_PROGRESS/...)',
                ),
              ),
              TextField(
                controller: pmIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project Manager ID',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: repoHostCtrl,
                decoration: const InputDecoration(
                  labelText: 'Repo Host (GITHUB/GITLAB/...)',
                ),
              ),
              TextField(
                controller: repoNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Repo Name (org/repo)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final payload = <String, dynamic>{
        'projectName': nameCtrl.text.trim(),
        'supervisorName': supervisorCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'startDate': startCtrl.text.trim(),
        'targetDate': targetCtrl.text.trim(),
        'meetingDay': meetingDayCtrl.text.trim(),
        'requiredInterns': int.tryParse(requiredInternsCtrl.text.trim()) ?? 0,
        'status': statusCtrl.text.trim(),
        'projectManagerId': int.tryParse(pmIdCtrl.text.trim()) ?? 0,
        'repoHost': repoHostCtrl.text.trim(),
        'repoName': repoNameCtrl.text.trim(),
      };

      await TalentTrailAdminService.createProject(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project created')));
      await _loadProjects();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openEditProject(Project p) async {
    final projectId = int.tryParse(p.id) ?? 0;
    if (projectId == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid project id')));
      return;
    }

    final latest = await TalentTrailAdminService.getProjectById(projectId);

    final nameCtrl = TextEditingController(
      text: (latest['projectName'] ?? p.name).toString(),
    );
    final supervisorCtrl = TextEditingController(
      text: (latest['supervisorName'] ?? '').toString(),
    );
    final descCtrl = TextEditingController(
      text: (latest['description'] ?? '').toString(),
    );
    final startCtrl = TextEditingController(
      text: (latest['startDate'] ?? '').toString(),
    );
    final targetCtrl = TextEditingController(
      text: (latest['targetDate'] ?? '').toString(),
    );
    final meetingDayCtrl = TextEditingController(
      text: (latest['meetingDay'] ?? '').toString(),
    );
    final requiredInternsCtrl = TextEditingController(
      text: (latest['requiredInterns'] ?? '').toString(),
    );
    final statusCtrl = TextEditingController(
      text: (latest['status'] ?? p.status).toString(),
    );
    final pmIdCtrl = TextEditingController(
      text: (latest['projectManagerId'] ?? '').toString(),
    );
    final repoHostCtrl = TextEditingController(
      text: (latest['repoHost'] ?? '').toString(),
    );
    final repoNameCtrl = TextEditingController(
      text: (latest['repoName'] ?? '').toString(),
    );

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Project'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Project Name'),
              ),
              TextField(
                controller: supervisorCtrl,
                decoration: const InputDecoration(labelText: 'Supervisor Name'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Start Date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Target Date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: meetingDayCtrl,
                decoration: const InputDecoration(labelText: 'Meeting Day'),
              ),
              TextField(
                controller: requiredInternsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Required Interns',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: statusCtrl,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              TextField(
                controller: pmIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project Manager ID',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: repoHostCtrl,
                decoration: const InputDecoration(labelText: 'Repo Host'),
              ),
              TextField(
                controller: repoNameCtrl,
                decoration: const InputDecoration(labelText: 'Repo Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final payload = <String, dynamic>{
        'projectName': nameCtrl.text.trim(),
        'supervisorName': supervisorCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'startDate': startCtrl.text.trim(),
        'targetDate': targetCtrl.text.trim(),
        'meetingDay': meetingDayCtrl.text.trim(),
        'requiredInterns': int.tryParse(requiredInternsCtrl.text.trim()) ?? 0,
        'status': statusCtrl.text.trim(),
        'projectManagerId': int.tryParse(pmIdCtrl.text.trim()) ?? 0,
        'repoHost': repoHostCtrl.text.trim(),
        'repoName': repoNameCtrl.text.trim(),
      };

      await TalentTrailAdminService.updateProject(projectId, payload);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project updated')));
      await _loadProjects();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmDeleteProject(Project p) async {
    final projectId = int.tryParse(p.id) ?? 0;
    if (projectId == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete project "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await TalentTrailAdminService.deleteProject(projectId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project deleted')));
      await _loadProjects();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _tableHeader() {
    return Container(
      width: 900,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3B4D), Color(0xFF1A6B5F)],
        ),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              'PROJECT NAME & MANAGER',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Text('STATUS', style: TextStyle(color: Colors.white)),
          ),
          Expanded(
            flex: 2,
            child: Text('TIMELINE', style: TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: Text(
              'DAYS REMAINING',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Text('ACTIONS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(Project p) {
    return InkWell(
      onTap: () {
        context.go('/talenttrail-projects/${p.id}');
      },
      child: Container(
        width: 900,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.manager,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.status,
                  style: const TextStyle(
                    color: Color(0xFF856404),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: DateFormat('MMM dd, yyyy').format(p.startDate),
                      style: const TextStyle(color: Colors.green),
                    ),
                    const TextSpan(text: ' - '),
                    TextSpan(
                      text: DateFormat('MMM dd, yyyy').format(p.targetDate),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.daysRemaining,
                  style: TextStyle(
                    color: p.isOverdue ? Colors.red : Colors.grey,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _openEditProject(p),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => _confirmDeleteProject(p),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
