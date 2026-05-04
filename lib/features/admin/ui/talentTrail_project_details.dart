import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talentTrail_admin_api.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_team_details.dart';

class ProjectMember {
  final String name;
  final String role;
  final String avatar;
  const ProjectMember({
    required this.name,
    required this.role,
    required this.avatar,
  });
}

class ProjectTeam {
  final int teamId;
  final String name;
  final List<ProjectMember> members;
  const ProjectTeam({
    required this.teamId,
    required this.name,
    required this.members,
  });
}

class ProjectDoc {
  final String name;
  final String fullName;
  final String format;
  const ProjectDoc({
    required this.name,
    required this.fullName,
    required this.format,
  });
}

class ProjectDetailModel {
  final int id;
  final String name;
  final String status;
  final String description;
  final String startDate;
  final String targetDate;
  final String supervisorName;
  final String meetingDay;
  final ProjectTeam? team;
  final List<ProjectTeam> assignedTeams;
  final List<ProjectDoc> documents;
  final String? repository;

  const ProjectDetailModel({
    required this.id,
    required this.name,
    required this.status,
    required this.description,
    required this.startDate,
    required this.targetDate,
    required this.supervisorName,
    required this.meetingDay,
    this.team,
    required this.assignedTeams,
    required this.documents,
    required this.repository,
  });

  factory ProjectDetailModel.fromJson(Map<String, dynamic> json) {
    return ProjectDetailModel(
      id: json['projectId'] ?? 0,
      name: json['projectName'] ?? '',
      status: json['status'] ?? 'PLANNED',
      description: json['description'] ?? '',
      startDate: json['startDate'] ?? '',
      targetDate: json['targetDate'] ?? '',
      supervisorName: json['supervisorName'] ?? '',
      meetingDay: json['meetingDay'] ?? '',
      team: null,
      assignedTeams: [],
      documents: const [
        ProjectDoc(
          name: 'BRD',
          fullName: 'Business Requirement Document',
          format: 'PDF, PNG, JPG, or JPEG (Max 10MB)',
        ),
        ProjectDoc(
          name: 'LLD',
          fullName: 'Low Level Diagram',
          format: 'PDF, PNG, JPG, or JPEG (Max 10MB)',
        ),
        ProjectDoc(
          name: 'HLD',
          fullName: 'High Level Diagram',
          format: 'PDF, PNG, JPG, or JPEG (Max 10MB)',
        ),
        ProjectDoc(
          name: 'DAD',
          fullName: 'Deployment Architecture Diagram',
          format: 'PDF, PNG, JPG, or JPEG (Max 10MB)',
        ),
      ],
      repository: json['repoName'] != null
          ? '${json['repoHost'] ?? ''}/${json['repoName']}'
          : null,
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool isEditOpen = false;
  bool _isLoading = true;
  String? _error;
  ProjectDetailModel? _project;
  List<ProjectTeam> _assignedTeams = [];
  bool _isLoadingTeams = true;

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
  }

  Future<void> _loadProjectDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await TalentTrailAdminService.getProjectById(
        widget.projectId,
      );

      setState(() {
        _project = ProjectDetailModel.fromJson(response);
        _isLoading = false;
      });

      // Load assigned teams
      await _loadAssignedTeams();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAssignedTeams() async {
    setState(() => _isLoadingTeams = true);

    try {
      final teamsData = await TalentTrailAdminService.getTeamsAssignedToProject(
        widget.projectId,
      );

      final teams = <ProjectTeam>[];
      for (var teamData in teamsData) {
        final teamId = teamData['teamId'] ?? teamData['id'];
        final teamName = teamData['teamName'] ?? '';

        // Fetch team members
        final teamDetails = await TalentTrailAdminService.getTeamById(teamId);
        final memberIds = List<int>.from(teamDetails['memberIds'] ?? []);

        // Fetch intern details for members
        final allInterns = await TalentTrailAdminService.getInterns();
        final members = allInterns
            .where((intern) => memberIds.contains(intern['internId']))
            .map((intern) {
              final isLeader =
                  (teamDetails['teamLeaderId'] ?? 0) == intern['internId'];
              return ProjectMember(
                name: intern['name'] ?? '',
                role: isLeader ? 'Team Leader' : 'Team Member',
                avatar: intern['name']?.isNotEmpty == true
                    ? intern['name'][0].toUpperCase()
                    : '?',
              );
            })
            .toList();

        teams.add(
          ProjectTeam(teamId: teamId, name: teamName, members: members),
        );
      }

      setState(() {
        _assignedTeams = teams;
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeams = false);
      debugPrint('Error loading assigned teams: $e');
    }
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${_project?.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TalentTrailAdminService.deleteProject(widget.projectId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete project: $e')));
      }
    }
  }

  Future<void> _updateProject(Map<String, dynamic> payload) async {
    try {
      await TalentTrailAdminService.updateProject(widget.projectId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project updated successfully')),
        );
        await _loadProjectDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update project: $e')));
      }
    }
  }

  String _calculateDuration(String startDate, String targetDate) {
    if (startDate.isEmpty || targetDate.isEmpty) return '—';
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(targetDate);
      final days = end.difference(start).inDays;
      final weeks = days ~/ 7;
      final remainingDays = days % 7;
      return '$weeks weeks, $remainingDays days';
    } catch (e) {
      return '—';
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateString);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(
                error: _error!,
                onRetry: _loadProjectDetails,
                onBack: () => context.go('/talenttrail-projects'),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final project = _project!;
    final formattedStartDate = _formatDate(project.startDate);
    final formattedTargetDate = _formatDate(project.targetDate);
    final duration = _calculateDuration(project.startDate, project.targetDate);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back bar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => context.go('/talenttrail-projects'),
                      child: Row(
                        children: const [
                          Icon(Icons.arrow_back, size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Back', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ActionBtn(
                          bg: const Color(0xFF4169E1),
                          label: 'Edit Project',
                          icon: Icons.edit,
                          onTap: () => setState(() => isEditOpen = true),
                        ),
                        _ActionBtn(
                          bg: const Color(0xFF10B981),
                          label: 'Export Project',
                          icon: Icons.file_download,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Export Project clicked'),
                              ),
                            );
                          },
                        ),
                        _ActionBtn(
                          bg: const Color(0xFFDC3545),
                          label: 'Delete Project',
                          icon: Icons.delete,
                          onTap: _deleteProject,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Project Header
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusPill(status: project.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Project Description
                  _Card(
                    title: 'Project Description',
                    child: Text(
                      project.description,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),

                  // Timeline
                  _Card(
                    title: 'Timeline',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Start Date:', formattedStartDate),
                        _kv('Target Date:', formattedTargetDate),
                        _kv('Duration:', duration),
                        _kv(
                          'Meeting Day:',
                          project.meetingDay.isEmpty
                              ? 'Not set'
                              : project.meetingDay,
                        ),
                      ],
                    ),
                  ),

                  // Supervisor Information
                  _Card(
                    title: 'Supervisor Information',
                    child: _kv(
                      'Supervisor:',
                      project.supervisorName.isEmpty
                          ? 'Not assigned'
                          : project.supervisorName,
                    ),
                  ),

                  // Assigned Teams
                  _Card(
                    title: 'Assigned Teams (${_assignedTeams.length})',
                    child: _isLoadingTeams
                        ? const Center(child: CircularProgressIndicator())
                        : _assignedTeams.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No teams assigned',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : Column(
                            children: _assignedTeams
                                .map((team) => _TeamCard(team: team))
                                .toList(),
                          ),
                  ),

                  // Project Documentation
                  _Card(
                    title: 'Project Documentation',
                    child: Column(
                      children: project.documents
                          .map((d) => _DocUploadCard(doc: d))
                          .toList(),
                    ),
                  ),

                  // Repository Information
                  _Card(
                    title: 'Repository Information',
                    child: Row(
                      children: [
                        const Text('📁', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            project.repository ?? 'No repository configured',
                            style: TextStyle(
                              color: project.repository != null
                                  ? const Color(0xFF2C3E50)
                                  : Colors.grey,
                              fontStyle: project.repository == null
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // Edit Dialog
        if (isEditOpen && _project != null)
          ProjectEditDialog(
            project: _project!,
            onClose: () => setState(() => isEditOpen = false),
            onUpdate: (payload) async {
              await _updateProject(payload);
              setState(() => isEditOpen = false);
            },
          ),
      ],
    );
  }

  Widget _kv(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            v,
            style: TextStyle(color: valueColor ?? const Color(0xFF2C3E50)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          InkWell(
            onTap: () => context.go('/talenttrail-projects'),
            child: Row(
              children: const [
                Icon(Icons.arrow_back, size: 20, color: Colors.grey),
                SizedBox(width: 8),
                Text('Back', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error loading project details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4169E1),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final Color bg;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.bg,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusUpper = status.toUpperCase();
    Color bg;
    Color fg;

    switch (statusUpper) {
      case 'PLANNED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFF59E0B);
        break;
      case 'COMPLETED':
        bg = const Color(0xFFC8E6C9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'ON_HOLD':
        bg = const Color(0xFFFFCDD2);
        fg = const Color(0xFFC62828);
        break;
      default:
        bg = const Color(0xFFE0E0E0);
        fg = const Color(0xFF616161);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final ProjectTeam team;
  const _TeamCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(teamId: team.teamId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    team.name,
                    style: const TextStyle(
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: team.members.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          m.avatar,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.role,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocUploadCard extends StatelessWidget {
  final ProjectDoc doc;
  const _DocUploadCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            doc.name,
            style: const TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 4),
          Text(
            doc.fullName,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            doc.format,
            style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4169E1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Upload ${doc.name} clicked')),
                );
              },
              icon: const Icon(Icons.upload, size: 16),
              label: Text('Upload ${doc.name}'),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectEditDialog extends StatefulWidget {
  final ProjectDetailModel project;
  final VoidCallback onClose;
  final Future<void> Function(Map<String, dynamic> payload) onUpdate;

  const ProjectEditDialog({
    super.key,
    required this.project,
    required this.onClose,
    required this.onUpdate,
  });

  @override
  State<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<ProjectEditDialog> {
  late final TextEditingController projectNameCtrl;
  final TextEditingController supervisorCtrl = TextEditingController();
  late final TextEditingController descriptionCtrl;

  final TextEditingController startDateCtrl = TextEditingController();
  final TextEditingController targetDateCtrl = TextEditingController();

  String meetingDay = '';
  String status = '';

  final TextEditingController teamSearchCtrl = TextEditingController();
  final TextEditingController pmSearchCtrl = TextEditingController();

  String repoHost = '';
  final TextEditingController repoNameCtrl = TextEditingController();
  final TextEditingController repoTokenCtrl = TextEditingController();

  bool team1 = false;
  bool team2 = false;
  bool team3 = false;

  @override
  void initState() {
    super.initState();
    projectNameCtrl = TextEditingController(text: widget.project.name);
    descriptionCtrl = TextEditingController(text: widget.project.description);
    status = widget.project.status;
  }

  @override
  void dispose() {
    projectNameCtrl.dispose();
    supervisorCtrl.dispose();
    descriptionCtrl.dispose();
    startDateCtrl.dispose();
    targetDateCtrl.dispose();
    teamSearchCtrl.dispose();
    pmSearchCtrl.dispose();
    repoNameCtrl.dispose();
    repoTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit Project',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Project Name', required: true),
                            TextField(
                              controller: projectNameCtrl,
                              decoration: _inpDeco(),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel(
                              'Supervisor Name',
                              required: true,
                              redLabel: true,
                            ),
                            TextField(
                              controller: supervisorCtrl,
                              decoration: _inpDeco(
                                hint: 'Enter supervisor name',
                              ),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel(
                              'Description',
                              required: true,
                              redLabel: true,
                            ),
                            TextField(
                              controller: descriptionCtrl,
                              minLines: 4,
                              maxLines: 6,
                              decoration: _inpDeco(),
                            ),

                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel('Start Date', required: true),
                                      TextField(
                                        controller: startDateCtrl,
                                        decoration: _inpDeco(
                                          hint: 'yyyy-mm-dd',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _fieldLabel(
                                        'Target Date',
                                        required: true,
                                      ),
                                      TextField(
                                        controller: targetDateCtrl,
                                        decoration: _inpDeco(
                                          hint: 'yyyy-mm-dd',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Meeting Days'),
                            DropdownButtonFormField<String>(
                              initialValue: meetingDay.isEmpty
                                  ? null
                                  : meetingDay,
                              decoration: _inpDeco(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'monday',
                                  child: Text('Monday'),
                                ),
                                DropdownMenuItem(
                                  value: 'tuesday',
                                  child: Text('Tuesday'),
                                ),
                                DropdownMenuItem(
                                  value: 'wednesday',
                                  child: Text('Wednesday'),
                                ),
                                DropdownMenuItem(
                                  value: 'thursday',
                                  child: Text('Thursday'),
                                ),
                                DropdownMenuItem(
                                  value: 'friday',
                                  child: Text('Friday'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => meetingDay = v ?? ''),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Status'),
                            DropdownButtonFormField<String>(
                              initialValue: status.isEmpty ? null : status,
                              decoration: _inpDeco(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PLANNED',
                                  child: Text('Planned'),
                                ),
                                DropdownMenuItem(
                                  value: 'IN_PROGRESS',
                                  child: Text('In Progress'),
                                ),
                                DropdownMenuItem(
                                  value: 'COMPLETED',
                                  child: Text('Completed'),
                                ),
                                DropdownMenuItem(
                                  value: 'ON HOLD',
                                  child: Text('On Hold'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => status = v ?? ''),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Assigned Teams'),
                            TextField(
                              controller: teamSearchCtrl,
                              decoration: _inpDeco(
                                hint:
                                    'Search teams by name, leader, or create new teams',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 190,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _teamRow(
                                        checked: team1,
                                        onChanged: (v) =>
                                            setState(() => team1 = v),
                                        title:
                                            'TMForum - Omni Channel Service Hub',
                                        sub:
                                            '(Leader: Mohamadachchi Chamidu Lakshan)',
                                        titleColor: const Color(0xFF4169E1),
                                      ),
                                      _teamRow(
                                        checked: team2,
                                        onChanged: (v) =>
                                            setState(() => team2 = v),
                                        title:
                                            'Sales Incentive Automation System',
                                        sub: '(Leader: H.G Vasitha Nadugala)',
                                      ),
                                      _teamRow(
                                        checked: team3,
                                        onChanged: (v) =>
                                            setState(() => team3 = v),
                                        title: 'Internship Management System',
                                        sub: '(Leader: K A Ojana Darnith)',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ⓘ Search and select multiple teams that will work on this project. You can also create a new team when no matches appear.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Project Manager'),
                            TextField(
                              controller: pmSearchCtrl,
                              decoration: _inpDeco(
                                hint:
                                    'Search project manager by name or code...',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "ⓘ Choose who will manage this project. This person doesn't need to be on an assigned team.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Text(
                              'Repository Information',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 10),

                            _fieldLabel('Repository Host'),
                            DropdownButtonFormField<String>(
                              initialValue: repoHost.isEmpty ? null : repoHost,
                              decoration: _inpDeco(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'github',
                                  child: Text('GitHub'),
                                ),
                                DropdownMenuItem(
                                  value: 'gitlab',
                                  child: Text('GitLab'),
                                ),
                                DropdownMenuItem(
                                  value: 'bitbucket',
                                  child: Text('Bitbucket'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => repoHost = v ?? ''),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'ⓘ Choose the platform where your project repository is hosted.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Repository Name'),
                            TextField(
                              controller: repoNameCtrl,
                              decoration: _inpDeco(
                                hint:
                                    'e.g. username/repo-name or workspace/repo-slug',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'ⓘ For GitHub: owner/repository-name | For Bitbucket: workspace/repository-slug',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),

                            const SizedBox(height: 14),
                            _fieldLabel('Repository Access Token'),
                            TextField(
                              controller: repoTokenCtrl,
                              obscureText: true,
                              decoration: _inpDeco(
                                hint: 'Enter access token for API access',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '🔒 Personal access token for accessing repository data and commits.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Fixed bottom actions
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: widget.onClose,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final payload = {
                                'projectName': projectNameCtrl.text.trim(),
                                'description': descriptionCtrl.text.trim(),
                                'supervisorName': supervisorCtrl.text.trim(),
                                'startDate': startDateCtrl.text.trim(),
                                'targetDate': targetDateCtrl.text.trim(),
                                'meetingDay': meetingDay,
                                'status': status,
                                'repoHost': repoHost,
                                'repoName': repoNameCtrl.text.trim(),
                              };

                              await widget.onUpdate(payload);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4169E1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Update Project'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inpDeco({String? hint}) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _fieldLabel(
    String text, {
    bool required = false,
    bool redLabel = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: redLabel ? Colors.red.shade700 : Colors.black87,
            fontFamily: 'Roboto',
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamRow({
    required bool checked,
    required ValueChanged<bool> onChanged,
    required String title,
    required String sub,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: checked, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: titleColor ?? Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
