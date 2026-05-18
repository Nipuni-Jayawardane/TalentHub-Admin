import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talent_trail_admin_api.dart';
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
      _loadAssignedTeams();
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
      if (days < 0) return 'Invalid timeline';
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
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Project Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/talenttrail-projects'),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
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

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionButtons(),
              const SizedBox(height: 16),
              _buildTitleCard(project),
              const SizedBox(height: 16),
              _buildSectionCard('Project Description', _buildDescription(project)),
              _buildSectionCard('Timeline', _buildTimeline(project)),
              _buildSectionCard(
                'PM & Team Assignments (${1 + _assignedTeams.fold<int>(0, (count, team) => count + team.members.length)})',
                _buildPMAndTeamAssignments(project),
              ),
              _buildSectionCard('Project Documentation', _buildDocumentation(project)),
              _buildSectionCard('Project Repository Information', _buildProjectRepositoryInfo(project)),
              _buildSectionCard('Commit Activity Heatmap', _buildCommitActivityHeatmap()),
              const SizedBox(height: 40),
            ],
          ),
        ),
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

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionBtn(
          bg: const Color(0xFF3B82F6),
          label: 'Edit Project',
          icon: Icons.edit,
          onTap: () => setState(() => isEditOpen = true),
        ),
        _ActionBtn(
          bg: const Color(0xFF10B981),
          label: 'Export Project',
          icon: Icons.file_download,
          onTap: () {},
        ),
        _ActionBtn(
          bg: const Color(0xFFEF4444),
          label: 'Delete Project',
          icon: Icons.delete,
          onTap: _deleteProject,
        ),
      ],
    );
  }

  Widget _buildTitleCard(ProjectDetailModel project) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              project.name.isNotEmpty ? project.name : 'Unnamed Project',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              project.status.toUpperCase(),
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildDescription(ProjectDetailModel project) {
    return Text(
      project.description.isEmpty ? 'No description provided.' : project.description,
      style: const TextStyle(color: Color(0xFF475569), height: 1.5, fontSize: 15),
    );
  }

  Widget _buildTimeline(ProjectDetailModel project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineRow('Start Date', _formatDate(project.startDate)),
        const SizedBox(height: 12),
        _buildTimelineRow('Target Date', _formatDate(project.targetDate)),
        const SizedBox(height: 12),
        _buildTimelineRow('Duration', _calculateDuration(project.startDate, project.targetDate)),
        const SizedBox(height: 12),
        _buildTimelineRow('Meeting Day', project.meetingDay.isNotEmpty ? project.meetingDay : 'Not configured'),
      ],
    );
  }

  Widget _buildTimelineRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 14)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildPMAndTeamAssignments(ProjectDetailModel project) {
    if (_isLoadingTeams) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
          ),
          title: const Text('Project Manager', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          subtitle: Text(project.supervisorName.isNotEmpty ? project.supervisorName : 'Not assigned', style: TextStyle(color: Colors.grey.shade600)),
        ),
        
        if (_assignedTeams.isEmpty)
           const Padding(
             padding: EdgeInsets.only(top: 16),
             child: Text('No teams assigned', style: TextStyle(color: Colors.grey)),
           ),

        ..._assignedTeams.expand((team) => [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              child: const Icon(Icons.people, color: Colors.white, size: 20),
            ),
            title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ),
          ...team.members.map((member) => ListTile(
            contentPadding: const EdgeInsets.only(left: 16),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
              child: Icon(Icons.person, color: Colors.grey.shade700, size: 18),
            ),
            title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
            subtitle: Text(member.role, style: TextStyle(color: Colors.grey.shade600)),
          )),
        ]),
      ],
    );
  }

  Widget _buildDocumentation(ProjectDetailModel project) {
    return Column(
      children: project.documents.map((doc) => _buildDocCard(doc)).toList(),
    );
  }

  Widget _buildDocCard(ProjectDoc doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: Colors.blue.shade600, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(doc.fullName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(doc.format, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text('Upload ${doc.name}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProjectRepositoryInfo(ProjectDetailModel project) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildRepoInfoCard('HOST:', Icons.cloud_outlined, 'GitHub'),
        _buildRepoInfoCard('REPOSITORY:', Icons.folder_outlined, project.repository ?? 'Lakindu24/TalentHub'),
        _buildRepoInfoCard('ACCESS TOKEN:', Icons.lock_outline, 'Configured'),
      ],
    );
  }

  Widget _buildRepoInfoCard(String label, IconData icon, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommitActivityHeatmap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All Contributors', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(52, (week) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Column(
                children: List.generate(7, (day) {
                  int intensity = (week * 7 + day) % 11;
                  Color c;
                  if (intensity < 4) c = Colors.grey.shade100;
                  else if (intensity < 6) c = Colors.blue.shade100;
                  else if (intensity < 8) c = Colors.blue.shade300;
                  else if (intensity < 10) c = Colors.blue.shade500;
                  else c = Colors.blue.shade700;
                  return Container(
                    width: 12, height: 12, margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                  );
                }),
              ),
            )),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Less', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 6),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue.shade500, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            const Text('More', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
        mainAxisAlignment: MainAxisAlignment.center,
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
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
