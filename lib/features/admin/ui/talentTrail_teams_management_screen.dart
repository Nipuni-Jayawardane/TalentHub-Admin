import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talent_trail_admin_api.dart';
import 'package:go_router/go_router.dart';
import 'package:slt_internship_attendance_portal/core/services/api_service.dart';

class Team {
  final int teamId;
  final String teamName;
  final String teamLeaderName;
  final int teamLeaderId;
  final int memberCount;
  final List<String> assignedProjects;

  Team({
    required this.teamId,
    required this.teamName,
    required this.teamLeaderName,
    required this.teamLeaderId,
    required this.memberCount,
    required this.assignedProjects,
  });

  factory Team.fromTeamsJson(Map<String, dynamic> json) {
    return Team(
      teamId: json['teamId'] ?? 0,
      teamName: json['teamName']?.toString() ?? '',
      teamLeaderName: json['teamLeaderName']?.toString() ?? '—',
      teamLeaderId: json['teamLeaderId'] ?? 0,
      memberCount: 0,
      assignedProjects: const [],
    );
  }

  Team copyWith({
    String? teamName,
    String? teamLeaderName,
    int? memberCount,
    List<String>? assignedProjects,
  }) {
    return Team(
      teamId: teamId,
      teamName: teamName ?? this.teamName,
      teamLeaderName: teamLeaderName ?? this.teamLeaderName,
      teamLeaderId: teamLeaderId,
      memberCount: memberCount ?? this.memberCount,
      assignedProjects: assignedProjects ?? this.assignedProjects,
    );
  }
}

class TeamsManagementScreen extends StatefulWidget {
  const TeamsManagementScreen({super.key});

  @override
  State<TeamsManagementScreen> createState() => _TeamsManagementScreenState();
}

class _TeamsManagementScreenState extends State<TeamsManagementScreen> {
  bool isSidebarOpen = false;
  bool isAuthenticating = false;

  final TextEditingController _searchController = TextEditingController();

  String teamFilter = 'All Teams';
  String sortOption = 'None';

  bool _isLoading = true;
  String? _error;

  List<Team> _teams = [];
  final Map<int, List<String>> _projectsCache = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoadTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoadTeams() async {
    setState(() {
      _isLoading = true;
      isAuthenticating = true;
      _error = null;
    });

    try {
      // Check authentication
      final hasToken = await TalentTrailAuthService.isAuthenticated();
      if (!hasToken) {
        await TalentTrailAuthService.federatedLogin();
      }

      setState(() {
        isAuthenticating = false;
      });

      await _loadTeams();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Authentication failed: $e';
          _isLoading = false;
          isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rawTeams = await TalentTrailAdminService.getTeams();

      final baseTeams = rawTeams
          .whereType<Map<String, dynamic>>()
          .map((t) => Team.fromTeamsJson(t))
          .where((t) => t.teamId != 0)
          .toList();

      final updatedTeams = await Future.wait(
        baseTeams.map((t) async {
          final memberCount = await _getMemberCountForTeam(t.teamId);
          final projects = await _getAssignedProjectsForTeam(t.teamId);
          return Team(
            teamId: t.teamId,
            teamName: t.teamName,
            teamLeaderName: t.teamLeaderName,
            teamLeaderId: t.teamLeaderId,
            memberCount:
                memberCount, // Use the actual count from team-members API
            assignedProjects: projects,
          );
        }),
      );

      if (!mounted) return;
      setState(() {
        _teams = updatedTeams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<int> _getMemberCountForTeam(int teamId) async {
    try {
      final allTeamMembers =
          await TalentTrailAdminService.getTeamMemberAssociations();
      final teamMembers = allTeamMembers
          .where((tm) => tm['teamId'] == teamId)
          .toList();
      return teamMembers.length;
    } catch (e) {
      debugPrint('Error getting member count for team $teamId: $e');
      return 0;
    }
  }

  Future<List<String>> _getAssignedProjectsForTeam(int teamId) async {
    if (_projectsCache.containsKey(teamId)) return _projectsCache[teamId]!;

    try {
      // Get projects assigned to this team
      final rows = await TalentTrailAdminService.getProjectsAssignedToTeam(
        teamId,
      );

      final names = <String>[];
      for (final r in rows) {
        if (r is Map<String, dynamic>) {
          final name = r['projectName'];
          if (name != null && name.toString().trim().isNotEmpty) {
            names.add(name.toString().trim());
          }
        }
      }

      final seen = <String>{};
      final deduped = <String>[];
      for (final n in names) {
        if (seen.add(n)) deduped.add(n);
      }

      _projectsCache[teamId] = deduped;
      return deduped;
    } catch (_) {
      _projectsCache[teamId] = const [];
      return const [];
    }
  }

  List<Team> get filteredTeams {
    List<Team> list = List<Team>.from(_teams);

    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) {
        final teamName = t.teamName.toLowerCase();
        final leader = t.teamLeaderName.toLowerCase();
        final projects = t.assignedProjects.join(' ').toLowerCase();
        return teamName.contains(q) ||
            leader.contains(q) ||
            projects.contains(q);
      }).toList();
    }

    switch (sortOption) {
      case 'Member Count (Ascending)':
        list.sort((a, b) => a.memberCount.compareTo(b.memberCount));
        break;
      case 'Member Count (Descending)':
        list.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        break;
      case 'Team Leader (A-Z)':
        list.sort(
          (a, b) => a.teamLeaderName.toLowerCase().compareTo(
            b.teamLeaderName.toLowerCase(),
          ),
        );
        break;
      case 'Team Leader (Z-A)':
        list.sort(
          (a, b) => b.teamLeaderName.toLowerCase().compareTo(
            a.teamLeaderName.toLowerCase(),
          ),
        );
        break;
      case 'Team Name (A-Z)':
        list.sort(
          (a, b) =>
              a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase()),
        );
        break;
      case 'Team Name (Z-A)':
        list.sort(
          (a, b) =>
              b.teamName.toLowerCase().compareTo(a.teamName.toLowerCase()),
        );
        break;
      default:
        break;
    }

    return list;
  }

  Future<void> _createTeam(
    String teamName,
    int teamLeaderId,
    List<int> memberIds,
  ) async {
    try {
      final payload = {
        'teamName': teamName,
        'teamLeaderId': teamLeaderId,
        'memberIds': memberIds,
      };

      await TalentTrailAdminService.createTeam(payload);
      await _loadTeams();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCreateTeamDialog() async {
    // First fetch all interns for selection
    List<dynamic> allInterns = [];
    try {
      allInterns = await TalentTrailAdminService.getInterns();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load interns: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CreateTeamDialog(allInterns: allInterns),
    );

    if (result != null && mounted) {
      await _createTeam(
        result['teamName'],
        result['teamLeaderId'],
        result['memberIds'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onPressed: () => setState(() => isSidebarOpen = true),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadTeams,
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const SizedBox(height: 28),
                        _createButton(),
                        const SizedBox(height: 20),
                        _searchBox(),
                        const SizedBox(height: 16),
                        _dropdown(teamFilter, const [
                          'All Teams',
                        ], (v) => setState(() => teamFilter = v!)),
                        const SizedBox(height: 16),
                        _dropdown(sortOption, const [
                          'None',
                          'Team Name (A-Z)',
                          'Team Name (Z-A)',
                          'Member Count (Ascending)',
                          'Member Count (Descending)',
                          'Team Leader (A-Z)',
                          'Team Leader (Z-A)',
                        ], (v) => setState(() => sortOption = v!)),
                        const SizedBox(height: 28),
                        _teamsCount(),
                        const SizedBox(height: 12),
                        if (isAuthenticating) _authenticatingState(),
                        if (!isAuthenticating && _isLoading) _loadingState(),
                        if (!isAuthenticating && !_isLoading && _error != null)
                          _errorState(),
                        if (!isAuthenticating &&
                            !_isLoading &&
                            _error == null) ...[
                          _teamsTable(),
                          if (filteredTeams.isEmpty) _emptyState(),
                        ],
                      ],
                    ),
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
          'Teams Management',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 15, 15, 79),
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Create and manage teams, assign team leaders, and track team performance',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _createButton() {
    return ElevatedButton.icon(
      onPressed: _openCreateTeamDialog,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Create New Team'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 65, 158, 225),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search teams, leaders, or projects...',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
    );
  }

  Widget _teamsCount() {
    final total = _teams.length;
    final shown = filteredTeams.length;

    final label = _isLoading
        ? 'All Teams (Loading...)'
        : _error != null
        ? 'All Teams (Error)'
        : 'All Teams ($shown${shown != total ? " of $total" : ""})';

    return Text(
      label,
      style: const TextStyle(fontSize: 22, color: Color(0xFF2C3E50)),
    );
  }

  Widget _teamsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [_tableHeader(), ...filteredTeams.map(_tableRow)],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      width: 760,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3B4D), Color(0xFF1A6B5F)],
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 40),
          SizedBox(
            width: 200,
            child: Text('TEAM NAME', style: TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: Text('TEAM LEADER', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 110,
            child: Text('MEMBERS', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 240,
            child: Text(
              'ASSIGNED PROJECTS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(Team t) {
    final projects = t.assignedProjects.isEmpty
        ? const ['—']
        : t.assignedProjects;
    final memberText = '${t.memberCount}';

    final List<Widget> projectWidgets = projects
        .take(2)
        .toList()
        .asMap()
        .entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 13,
                color: e.key == 0 ? const Color(0xFF2C3E50) : Colors.grey,
                fontStyle: e.key == 0 ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        )
        .toList();

    if (projects.length > 2) {
      projectWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '+${projects.length - 2} more',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => context.go('/talenttrail-teams/${t.teamId}'),
      child: Container(
        width: 760,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 40,
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
            SizedBox(
              width: 200,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t.teamName,
                  style: const TextStyle(color: Color(0xFF2C3E50)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t.teamLeaderName.isEmpty ? '—' : t.teamLeaderName,
                  style: const TextStyle(color: Color(0xFF1976D2)),
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    memberText,
                    style: const TextStyle(color: Color(0xFF2C3E50)),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 240,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: projectWidgets,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'view') {
                        context.go('/talenttrail-teams/${t.teamId}');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authenticatingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Authenticating with TalentTrail...'),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Loading teams...'),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFFEBEE),
      ),
      child: Column(
        children: [
          const Text(
            'Failed to load teams',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: ElevatedButton.icon(
              onPressed: _loadTeams,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          'No teams found matching your criteria.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

// Updated CreateTeamDialog with API integration
class CreateTeamDialog extends StatefulWidget {
  final List<dynamic> allInterns;
  const CreateTeamDialog({super.key, required this.allInterns});

  @override
  State<CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends State<CreateTeamDialog> {
  final _teamName = TextEditingController();
  int? _selectedLeaderId;
  String _selectedLeaderName = '';
  final List<int> _selectedMemberIds = [];
  final List<Map<String, dynamic>> _selectedMembers = [];
  String _memberSearchQuery = '';
  String _leaderSearchQuery = '';

  List<Map<String, dynamic>> get _filteredLeaders {
    if (_leaderSearchQuery.isEmpty) return [];
    return widget.allInterns
        .where((intern) {
          final name = (intern['name'] ?? '').toString().toLowerCase();
          final code = (intern['internCode'] ?? '').toString().toLowerCase();
          final query = _leaderSearchQuery.toLowerCase();
          return name.contains(query) || code.contains(query);
        })
        .map(
          (intern) => {
            'id': intern['internId'],
            'name': intern['name'],
            'code': intern['internCode'],
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_memberSearchQuery.isEmpty) return [];
    return widget.allInterns
        .where((intern) {
          final isSelected = _selectedMemberIds.contains(intern['internId']);
          if (isSelected) return false;
          if (_selectedLeaderId != null &&
              intern['internId'] == _selectedLeaderId) {
            return false;
          }
          final name = (intern['name'] ?? '').toString().toLowerCase();
          final code = (intern['internCode'] ?? '').toString().toLowerCase();
          final query = _memberSearchQuery.toLowerCase();
          return name.contains(query) || code.contains(query);
        })
        .map(
          (intern) => {
            'id': intern['internId'],
            'name': intern['name'],
            'code': intern['internCode'],
            'email': intern['email'],
          },
        )
        .toList();
  }

  void _addMember(Map<String, dynamic> member) {
    setState(() {
      _selectedMemberIds.add(member['id']);
      _selectedMembers.add(member);
      _memberSearchQuery = '';
    });
  }

  void _removeMember(int memberId) {
    setState(() {
      _selectedMemberIds.remove(memberId);
      _selectedMembers.removeWhere((m) => m['id'] == memberId);
    });
  }

  void _selectLeader(Map<String, dynamic> leader) {
    setState(() {
      _selectedLeaderId = leader['id'];
      _selectedLeaderName = '${leader['name']} (${leader['code']})';
      _leaderSearchQuery = '';
    });
  }

  @override
  void dispose() {
    _teamName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const Text(
                'Create New Team',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team Name *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _teamName,
                      decoration: InputDecoration(
                        hintText: 'Enter team name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Team Leader *',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedLeaderId != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedLeaderName,
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () => setState(() {
                                _selectedLeaderId = null;
                                _selectedLeaderName = '';
                              }),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      onChanged: (v) => setState(() => _leaderSearchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by name or code...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (_leaderSearchQuery.isNotEmpty &&
                        _filteredLeaders.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _filteredLeaders
                              .map(
                                (leader) => ListTile(
                                  title: Text(leader['name']),
                                  subtitle: Text(leader['code']),
                                  onTap: () => _selectLeader(leader),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: const Color(0xFF4169E1),
                            width: 4,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Team Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedMembers.isNotEmpty)
                            ..._selectedMembers.map(
                              (member) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${member['name']} (${member['code']})',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _removeMember(member['id']),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          TextField(
                            onChanged: (v) =>
                                setState(() => _memberSearchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search interns by name or code...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          if (_memberSearchQuery.isNotEmpty &&
                              _filteredMembers.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: _filteredMembers
                                    .map(
                                      (member) => ListTile(
                                        title: Text(member['name']),
                                        subtitle: Text(member['code']),
                                        trailing: const Icon(
                                          Icons.add_circle_outline,
                                          color: Colors.green,
                                        ),
                                        onTap: () => _addMember(member),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '* Team leader will be automatically included',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_teamName.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter team name'),
                          ),
                        );
                        return;
                      }
                      if (_selectedLeaderId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a team leader'),
                          ),
                        );
                        return;
                      }
                      final allMemberIds = [..._selectedMemberIds];
                      if (!allMemberIds.contains(_selectedLeaderId)) {
                        allMemberIds.add(_selectedLeaderId!);
                      }
                      Navigator.pop(context, {
                        'teamName': _teamName.text.trim(),
                        'teamLeaderId': _selectedLeaderId,
                        'memberIds': allMemberIds,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4169E1),
                    ),
                    child: const Text('Create Team'),
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
