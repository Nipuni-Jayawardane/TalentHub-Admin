import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talentTrail_admin_api.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_intern_details.dart';

class TeamLeader {
  final String name;
  final String id;
  const TeamLeader({required this.name, required this.id});
}

class ProjectItem {
  final int id;
  final String name;
  final String status;
  final String startDate;
  final String endDate;

  const ProjectItem({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
  });
}

class TeamMember {
  final String id; // Intern code
  final String name;
  final String email;
  final String institute;
  final String status;
  final String specialization;
  final int internId;

  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.institute,
    required this.status,
    required this.specialization,
    required this.internId,
  });
}

class Team {
  final int id;
  final String name;
  final TeamLeader leader;
  final int totalMembers;
  final int activeProjects;
  final List<ProjectItem> projects;
  final List<TeamMember> members;

  const Team({
    required this.id,
    required this.name,
    required this.leader,
    required this.totalMembers,
    required this.activeProjects,
    required this.projects,
    required this.members,
  });
}

/// --------------------
/// Colors
/// --------------------

class AppColors {
  static const Color primaryBlue = Color(0xFF4169E1);
  static const Color dangerRed = Color(0xFFDC3545);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color tealHeaderLeft = Color(0xFF0A3B4D);
  static const Color tealHeaderRight = Color(0xFF0D5F6F);
}

/// --------------------
/// Screen
/// --------------------

class TeamDetailScreen extends StatefulWidget {
  final int teamId;
  final VoidCallback? onBack;

  const TeamDetailScreen({super.key, required this.teamId, this.onBack});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  bool _editOpen = false;
  bool _deleteOpen = false;
  bool _isLoading = true;
  String? _error;
  Team? _team;
  List<TeamMember> _members = [];
  List<ProjectItem> _projects = [];
  bool _isLoadingMembers = true;
  bool _isLoadingProjects = true;

  late TextEditingController _teamNameCtrl;
  late TextEditingController _leaderSearchCtrl;
  late TextEditingController _memberSearchCtrl;
  String _selectedLeaderLabel = '';

  @override
  void initState() {
    super.initState();
    _teamNameCtrl = TextEditingController();
    _leaderSearchCtrl = TextEditingController();
    _memberSearchCtrl = TextEditingController();
    _fetchTeamDetails();
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _leaderSearchCtrl.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTeamDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch team details, team members, and projects in parallel
      final results = await Future.wait([
        TalentTrailAdminService.getTeamById(widget.teamId),
        TalentTrailAdminService.getTeamMemberAssociations(),
        TalentTrailAdminService.getProjectsAssignedToTeam(widget.teamId),
      ]);

      final teamResponse = results[0] as Map<String, dynamic>;
      final allTeamMembersRaw = results[1];
      final assignedProjectsRaw = results[2];

      debugPrint('Team API Response: $teamResponse');

      // Convert to List safely
      final List<dynamic> allTeamMembers = allTeamMembersRaw is List
          ? allTeamMembersRaw
          : [];

      final List<dynamic> assignedProjects = assignedProjectsRaw is List
          ? assignedProjectsRaw
          : [];

      debugPrint('All team members count: ${allTeamMembers.length}');
      debugPrint('Assigned projects count: ${assignedProjects.length}');

      // Filter members for this specific team from team-members API
      final teamSpecificMembers = allTeamMembers
          .where((tm) => tm is Map && tm['teamId'] == widget.teamId)
          .toList();

      debugPrint('Found ${teamSpecificMembers.length} members for this team');

      // Get all interns for member details
      final allInterns = await TalentTrailAdminService.getInterns();
      final List<dynamic> internsList = allInterns;

      // Build team members list
      final teamMembersList = <TeamMember>[];
      for (var tm in teamSpecificMembers) {
        final internId = tm['internId'] as int?;
        final intern = internsList.firstWhere(
          (i) => i['internId'] == internId,
          orElse: () => null,
        );

        if (intern != null) {
          teamMembersList.add(
            TeamMember(
              id: intern['internCode']?.toString() ?? '',
              name:
                  intern['name']?.toString() ??
                  tm['internName']?.toString() ??
                  '',
              email: intern['email']?.toString() ?? '',
              institute: intern['institute']?.toString() ?? '',
              status: intern['status']?.toString() ?? 'ACTIVE',
              specialization:
                  intern['fieldOfSpecialization']?.toString() ?? '-',
              internId: intern['internId'] ?? 0,
            ),
          );
        } else {
          teamMembersList.add(
            TeamMember(
              id: '',
              name: tm['internName']?.toString() ?? 'Unknown',
              email: '',
              institute: '',
              status: 'ACTIVE',
              specialization: '-',
              internId: tm['internId'] ?? 0,
            ),
          );
        }
      }

      // Build projects list
      final projectsList = assignedProjects.map((project) {
        return ProjectItem(
          id: project['projectId'] ?? 0,
          name: project['projectName']?.toString() ?? '',
          status: project['status']?.toString() ?? 'PLANNED',
          startDate: project['startDate']?.toString() ?? '',
          endDate: project['targetDate']?.toString() ?? '',
        );
      }).toList();

      final activeProjectsCount = projectsList.length;

      final team = Team(
        id: teamResponse['teamId'] ?? 0,
        name: teamResponse['teamName']?.toString() ?? '',
        leader: TeamLeader(
          name: teamResponse['teamLeaderName']?.toString() ?? '',
          id: (teamResponse['teamLeaderId'] ?? 0).toString(),
        ),
        totalMembers: teamMembersList.length,
        activeProjects: activeProjectsCount,
        projects: projectsList,
        members: teamMembersList,
      );

      setState(() {
        _team = team;
        _members = teamMembersList;
        _projects = projectsList;
        _isLoading = false;
        _isLoadingMembers = false;
        _isLoadingProjects = false;
      });
    } catch (e) {
      debugPrint('Error fetching team details: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTeam() async {
    try {
      await TalentTrailAdminService.deleteTeam(widget.teamId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _back();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTeam() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final payload = {
        'teamName': _teamNameCtrl.text,
        'teamLeaderId': int.tryParse(
          _getLeaderIdFromSelectedLabel(_selectedLeaderLabel),
        ),
      };

      await TalentTrailAdminService.updateTeam(widget.teamId, payload);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchTeamDetails();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getLeaderIdFromSelectedLabel(String label) {
    if (label.contains('(') && label.contains(')')) {
      final start = label.indexOf('(');
      final end = label.indexOf(')');
      return label.substring(start + 1, end);
    }
    return label;
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!.call();
      return;
    }
    context.go('/talenttrail-teams');
  }

  void _navigateToIntern(String internCode) {
    if (internCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intern code not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternDetailScreen(
          internId: internCode,
          onBack: () {
            _fetchTeamDetails();
          },
        ),
      ),
    );
  }

  void _navigateToProject(int projectId) {
    // TODO: Navigate to project detail screen when available
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Navigate to project: $projectId')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(
                error: _error!,
                onRetry: _fetchTeamDetails,
                onBack: _back,
              )
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_team == null) {
      return _TeamNotFound(onBack: _back);
    }

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final isLg = width >= 1024;

        _teamNameCtrl.text = _teamNameCtrl.text.isEmpty
            ? _team!.name
            : _teamNameCtrl.text;
        if (_selectedLeaderLabel.isEmpty) {
          _selectedLeaderLabel = '${_team!.leader.name} (${_team!.leader.id})';
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BackButton(onTap: _back),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _PrimaryButton(
                            text: 'Edit Team',
                            icon: Icons.edit_outlined,
                            background: AppColors.primaryBlue,
                            onTap: () => setState(() => _editOpen = true),
                          ),
                          _PrimaryButton(
                            text: 'Delete Team',
                            icon: Icons.delete_outline,
                            background: AppColors.dangerRed,
                            onTap: () => setState(() => _deleteOpen = true),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.green.withValues(alpha: 0.08),
                          Colors.green.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _team!.name,
                          style: const TextStyle(
                            fontSize: 36,
                            height: 1.15,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_team!.totalMembers} Members • ${_team!.activeProjects} Project${_team!.activeProjects != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (isLg)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TeamInfoCard(
                            team: _team!,
                            memberCount: _team!.totalMembers,
                            activeProjects: _team!.activeProjects,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _ProjectsCard(
                            projects: _projects,
                            isLoading: _isLoadingProjects,
                            onOpenProject: _navigateToProject,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _TeamInfoCard(
                          team: _team!,
                          memberCount: _team!.totalMembers,
                          activeProjects: _team!.activeProjects,
                        ),
                        const SizedBox(height: 18),
                        _ProjectsCard(
                          projects: _projects,
                          isLoading: _isLoadingProjects,
                          onOpenProject: _navigateToProject,
                        ),
                      ],
                    ),

                  const SizedBox(height: 18),

                  _MembersTableCard(
                    members: _members,
                    isLoading: _isLoadingMembers,
                    onOpenIntern: _navigateToIntern,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_deleteOpen) {
        _deleteOpen = false;
        await _showDeleteDialog();
      }
      if (_editOpen) {
        _editOpen = false;
        await _showEditDialog();
      }
    });
  }

  Future<void> _showDeleteDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 425),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you sure?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This action cannot be undone. This will permanently delete the team and all of its data.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _SolidButton(
                        text: 'Cancel',
                        background: const Color(0xFF6B7280),
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                      const SizedBox(width: 10),
                      _SolidButton(
                        text: 'Delete Team',
                        background: AppColors.dangerRed,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _deleteTeam();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog() async {
    if (_team == null) return;

    TextEditingController memberSearchCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _FixedActionDialog(
                  title: 'Edit Team',
                  content: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),
                        _FieldLabel(title: 'Team Name', required: true),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _teamNameCtrl,
                          hint: 'Enter team name...',
                        ),
                        const SizedBox(height: 18),
                        _FieldLabel(title: 'Team Leader', required: true),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _leaderSearchCtrl,
                          hint: 'Search team leader by name or code...',
                        ),
                        const SizedBox(height: 10),
                        _SelectedChip(
                          text: 'Selected: $_selectedLeaderLabel',
                          onClear: () =>
                              setDialogState(() => _selectedLeaderLabel = ''),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.only(
                            left: 14,
                            top: 12,
                            bottom: 12,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                width: 4,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Manage Members',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TextField(
                                      controller: memberSearchCtrl,
                                      hint: 'Search interns by name or code...',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _SolidButton(
                                    text: 'Add',
                                    background: AppColors.primaryBlue,
                                    onTap: () {
                                      // TODO: Implement member search and add logic
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Add member functionality coming soon',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._members.map((member) {
                                if (member.id == _team!.leader.id) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _MemberRemoveRow(
                                    name: '${member.name} (${member.id})',
                                    onRemove: () {
                                      setDialogState(() {
                                        _members.remove(member);
                                      });
                                    },
                                  ),
                                );
                              }),
                              const SizedBox(height: 10),
                              const Text(
                                '* Team leader will be automatically included as a member',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryBlue,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                  cancelText: 'Cancel',
                  confirmText: 'Update Team',
                  onCancel: () => Navigator.of(ctx).pop(),
                  onConfirm: () {
                    Navigator.of(ctx).pop();
                    _updateTeam();
                  },
                  confirmBackground: AppColors.primaryBlue,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// -------------------- UI Components (same as before, keep them unchanged) --------------------

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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackButton(onTap: onBack),
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading team details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamNotFound extends StatelessWidget {
  final VoidCallback onBack;
  const _TeamNotFound({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BackButton(onTap: onBack),
              const SizedBox(height: 60),
              const Center(
                child: Text(
                  'Team not found',
                  style: TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.arrow_back, size: 20, color: Color(0xFF4B5563)),
            SizedBox(width: 8),
            Text('Back', style: TextStyle(color: Color(0xFF4B5563))),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  final String text;
  final Color background;
  final VoidCallback onTap;

  const _SolidButton({
    required this.text,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(text),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _TeamInfoCard extends StatelessWidget {
  final Team team;
  final int memberCount;
  final int activeProjects;

  const _TeamInfoCard({
    required this.team,
    required this.memberCount,
    required this.activeProjects,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Team Information',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _InfoRow(label: 'Team Name:', value: team.name),
          const SizedBox(height: 14),
          _InfoRow(
            label: 'Team Leader:',
            value: '${team.leader.name} (${team.leader.id})',
            valueColor: AppColors.primaryBlue,
            underline: true,
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Total Members:', value: '$memberCount'),
          const SizedBox(height: 14),
          _InfoRow(label: 'Active Projects:', value: '$activeProjects'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool underline;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textDark,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            decoration: underline
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _ProjectsCard extends StatelessWidget {
  final List<ProjectItem> projects;
  final bool isLoading;
  final void Function(int projectId) onOpenProject;

  const _ProjectsCard({
    required this.projects,
    required this.isLoading,
    required this.onOpenProject,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Projects',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No projects assigned',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            ...projects.map(
              (p) => _ProjectRow(project: p, onTap: () => onOpenProject(p.id)),
            ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final ProjectItem project;
  final VoidCallback onTap;

  const _ProjectRow({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.work_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    project.status,
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${project.startDate} - ${project.endDate}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
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

class _MembersTableCard extends StatelessWidget {
  final List<TeamMember> members;
  final bool isLoading;
  final void Function(String internId) onOpenIntern;

  const _MembersTableCard({
    required this.members,
    required this.isLoading,
    required this.onOpenIntern,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Team Members (${members.length})',
              style: const TextStyle(
                fontSize: 20,
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No members in this team',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1280,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.tealHeaderLeft,
                            AppColors.tealHeaderRight,
                          ],
                        ),
                      ),
                      child: Row(
                        children: const [
                          _HeaderCell('INTERN CODE', w: 120),
                          _HeaderCell('NAME & EMAIL', w: 250),
                          _HeaderCell('INSTITUTE', w: 200),
                          _HeaderCell('STATUS', w: 100),
                          _HeaderCell('SPECIALIZATION', w: 150),
                        ],
                      ),
                    ),
                    ...List.generate(members.length, (i) {
                      final m = members[i];
                      final bg = i.isEven
                          ? Colors.white
                          : const Color(0xFFF9FAFB);

                      return InkWell(
                        onTap: () => onOpenIntern(m.id),
                        child: Container(
                          color: bg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              _Cell(
                                w: 120,
                                child: Text(
                                  m.id,
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                              _Cell(
                                w: 250,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.email,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _Cell(w: 200, child: Text(m.institute)),
                              _Cell(
                                w: 100,
                                child: _StatusPill(status: m.status),
                              ),
                              _Cell(
                                w: 150,
                                child: Text(
                                  m.specialization,
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double w;
  const _HeaderCell(this.text, {required this.w});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double w;
  final Widget child;
  const _Cell({required this.w, required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(width: w, child: child);
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toUpperCase() == 'ACTIVE';
    final bg = isActive ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2);
    final fg = isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FixedActionDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color confirmBackground;

  const _FixedActionDialog({
    required this.title,
    required this.content,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    required this.confirmBackground,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.90,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(child: content)),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(cancelText),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmBackground,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(confirmText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String title;
  final bool required;
  const _FieldLabel({required this.title, required this.required});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        children: [
          TextSpan(text: title),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _TextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryBlue),
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String text;
  final VoidCallback onClear;
  const _SelectedChip({required this.text, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1D4ED8)),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Color(0xFF1D4ED8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRemoveRow extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _MemberRemoveRow({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
          ElevatedButton(
            onPressed: onRemove,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
