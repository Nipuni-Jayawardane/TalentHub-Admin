import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talentTrail_admin_api.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_team_details.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_project_details.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:slt_internship_attendance_portal/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InternDetailScreen extends StatefulWidget {
  final String internId;
  final VoidCallback? onBack;

  const InternDetailScreen({super.key, required this.internId, this.onBack});

  @override
  State<InternDetailScreen> createState() => _InternDetailScreenState();
}

class _InternDetailScreenState extends State<InternDetailScreen> {
  bool _isEditDialogOpen = false;
  bool _isLoading = true;
  Map<String, dynamic>? _intern;
  String? _error;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _instituteCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchIntern();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _instituteCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchIntern() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await TalentTrailAdminService.getInternByCode(
        widget.internId,
      );
      if (!mounted) return;
      setState(() {
        _intern = data;
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

  Future<void> _handleUpdate() async {
    try {
      final internId = int.tryParse((_intern?['internId'] ?? '').toString());
      if (internId == null || internId == 0) {
        throw Exception('Intern ID not found');
      }

      await TalentTrailAdminService.updateIntern(
        internId: internId,
        internCode: _codeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        institute: _instituteCtrl.text.trim(),
        trainingStartDate: _startDateCtrl.text.trim(),
        trainingEndDate: _endDateCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intern updated successfully')),
      );
      setState(() => _isEditDialogOpen = false);
      await _fetchIntern();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _handleDelete() async {
    final internId = int.tryParse((_intern?['internId'] ?? '').toString());
    if (internId == null || internId == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Intern'),
        content: const Text('Are you sure you want to delete this intern?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TalentTrailAdminService.deleteIntern(internId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Intern deleted successfully')),
      );
      (widget.onBack ?? () => context.go('/talenttrail-interns'))();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  int _daysRemaining(String? endDate) {
    if (endDate == null || endDate.isEmpty) return 0;
    final today = DateTime.now();
    final end = DateTime.tryParse(endDate) ?? today;
    return end.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  String _duration(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return '-';
    final start = DateTime.tryParse(startDate) ?? DateTime.now();
    final end = DateTime.tryParse(endDate) ?? DateTime.now();
    final totalDays = end.difference(start).inDays;
    return '${totalDays ~/ 7} weeks, ${totalDays % 7} days';
  }

  String _formatPrettyDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    final d = DateTime.tryParse(dateString);
    if (d == null) return dateString;
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatForInput(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final d = DateTime.tryParse(dateString);
    if (d == null) return dateString;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _openEditDialog(Map<String, dynamic> intern) {
    _codeCtrl.text = (intern['internCode'] ?? '').toString();
    _nameCtrl.text = (intern['name'] ?? '').toString();
    _emailCtrl.text = (intern['email'] ?? '').toString();
    _instituteCtrl.text = (intern['institute'] ?? '').toString();
    _startDateCtrl.text = _formatForInput(
      intern['trainingStartDate']?.toString(),
    );
    _endDateCtrl.text = _formatForInput(intern['trainingEndDate']?.toString());
    setState(() => _isEditDialogOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final intern = _intern;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null
                  ? _NotFound(
                      onBack:
                          widget.onBack ??
                          () => context.go('/talenttrail-interns'),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final isMobile = w < 640;
                        final isTablet = w >= 640 && w < 1024;
                        final maxContentWidth = w >= 1200
                            ? 1100.0
                            : (w >= 1024 ? 980.0 : w);

                        final pagePadding = EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 24,
                          vertical: isMobile ? 16 : 24,
                        );

                        final startDate = intern!['trainingStartDate']
                            ?.toString();
                        final endDate = intern['trainingEndDate']?.toString();

                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxContentWidth,
                            ),
                            child: Padding(
                              padding: pagePadding,
                              child: _Content(
                                intern: intern,
                                isMobile: isMobile,
                                isTablet: isTablet,
                                onBack:
                                    widget.onBack ??
                                    () => context.go('/talenttrail-interns'),
                                onEdit: () => _openEditDialog(intern),
                                onDelete: _handleDelete,
                                daysRemaining: _daysRemaining(endDate),
                                duration: _duration(startDate, endDate),
                                formatDate: _formatPrettyDate,
                                showEditDialog: _isEditDialogOpen,
                                onCloseDialog: () =>
                                    setState(() => _isEditDialogOpen = false),
                                formControllers: (
                                  code: _codeCtrl,
                                  name: _nameCtrl,
                                  email: _emailCtrl,
                                  institute: _instituteCtrl,
                                  startDate: _startDateCtrl,
                                  endDate: _endDateCtrl,
                                ),
                                onUpdate: () async {
                                  await _handleUpdate();
                                  setState(() => _isEditDialogOpen = false);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    )),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  final VoidCallback onBack;
  const _NotFound({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopBar(onBack: onBack, right: const SizedBox.shrink()),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Intern not found",
                  style: TextStyle(fontSize: 18, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final Map<String, dynamic> intern;
  final bool isMobile;
  final bool isTablet;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onUpdate;

  final int daysRemaining;
  final String duration;
  final String Function(String?) formatDate;

  final bool showEditDialog;
  final VoidCallback onCloseDialog;

  final ({
    TextEditingController code,
    TextEditingController name,
    TextEditingController email,
    TextEditingController institute,
    TextEditingController startDate,
    TextEditingController endDate,
  })
  formControllers;

  const _Content({
    required this.intern,
    required this.isMobile,
    required this.isTablet,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.daysRemaining,
    required this.duration,
    required this.formatDate,
    required this.showEditDialog,
    required this.onCloseDialog,
    required this.formControllers,
    required this.onUpdate,
  });

  Future<List<dynamic>> _fetchInternTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('talentTrailToken');
    if (token == null) throw Exception('TalentTrail token not found.');

    final response = await http.get(
      Uri.parse('${Config.talentTrailBaseUrl}/team-members'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final members = jsonDecode(response.body);
    return members.where((m) => m['internId'] == intern['internId']).toList();
  }

  Future<List<dynamic>> _fetchInternProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('talentTrailToken');
    if (token == null) throw Exception('TalentTrail token not found.');

    final responses = await Future.wait([
      http.get(
        Uri.parse('${Config.talentTrailBaseUrl}/team-members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
      http.get(
        Uri.parse('${Config.talentTrailBaseUrl}/projects'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    ]);

    final members = jsonDecode(responses[0].body);
    final projects = jsonDecode(responses[1].body);

    final internTeamIds = members
        .where((m) => m['internId'] == intern['internId'])
        .map((m) => m['teamId'])
        .toSet();

    return projects.where((p) {
      final assignedTeamIds = List<int>.from(p['assignedTeamIds'] ?? []);
      return assignedTeamIds.any((id) => internTeamIds.contains(id));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayId = (intern['internCode'] ?? intern['internId'] ?? '-')
        .toString();
    final displayName = (intern['name'] ?? '-').toString();
    final displayEmail = (intern['email'] ?? '-').toString();
    final displayInstitute = (intern['institute'] ?? '-').toString();
    final displayStartDate = intern['trainingStartDate']?.toString();
    final displayEndDate = intern['trainingEndDate']?.toString();

    final gridGap = isMobile ? 12.0 : 16.0;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(onBack: onBack, right: const SizedBox.shrink()),
            const SizedBox(height: 12),

            Center(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _PrimaryButton(
                    label: "Edit Intern",
                    icon: Icons.edit,
                    background: const Color(0xFF4169E1),
                    onPressed: onEdit,
                  ),
                  _PrimaryButton(
                    label: "Delete Intern",
                    icon: Icons.delete_outline,
                    background: const Color(0xFFDC3545),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Information grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final twoCols = c.maxWidth >= 760;
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: gridGap,
                      runSpacing: gridGap,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _HeaderCard(
                            name: displayName,
                            id: displayId,
                            daysRemaining: daysRemaining,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Card(
                          title: "Personal Information",
                          width: twoCols
                              ? (c.maxWidth - gridGap) / 2
                              : c.maxWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _KV(label: 'Email:', value: displayEmail),
                              const SizedBox(height: 14),
                              _KV(label: 'Institute:', value: displayInstitute),
                              const SizedBox(height: 14),
                              _KV(
                                label: 'Specialization:',
                                value: (intern['fieldOfSpecialization'] ?? '-')
                                    .toString(),
                              ),
                              const SizedBox(height: 14),
                              _KV(
                                label: 'Status:',
                                value: (intern['status'] ?? '-').toString(),
                              ),
                            ],
                          ),
                        ),
                        _Card(
                          title: "Training Period",
                          width: twoCols
                              ? (c.maxWidth - gridGap) / 2
                              : c.maxWidth,
                          child: LayoutBuilder(
                            builder: (context, cc) {
                              // Two columns inside this card when possible
                              final innerTwoCols = cc.maxWidth >= 520;
                              final itemW = innerTwoCols
                                  ? (cc.maxWidth - 16) / 2
                                  : cc.maxWidth;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(
                                    width: itemW,
                                    child: _KV(
                                      label: 'Start Date:',
                                      value: formatDate(displayStartDate),
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemW,
                                    child: _KV(
                                      label: 'End Date:',
                                      value: formatDate(displayEndDate),
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemW,
                                    child: _KV(
                                      label: "Duration:",
                                      value: duration,
                                    ),
                                  ),
                                  SizedBox(
                                    width: itemW,
                                    child: _KV(
                                      label: "Status:",
                                      value: "$daysRemaining days remaining",
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        _Card(
                          title: "Team Assignments",
                          width: twoCols
                              ? (c.maxWidth - gridGap) / 2
                              : c.maxWidth,
                          child: FutureBuilder<List<dynamic>>(
                            future: _fetchInternTeams(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text("Error: ${snapshot.error}"),
                                );
                              }

                              final internTeams = snapshot.data!;
                              if (internTeams.isEmpty) {
                                return const _EmptyLine(
                                  text: "No team assignments",
                                );
                              }

                              return Column(
                                children: [
                                  for (var team in internTeams)
                                    _AssignmentTile(
                                      iconBg: const Color(0xFF10B981),
                                      icon: Icons.group,
                                      title: team['teamName'],
                                      subtitle: "Team Member",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TeamDetailScreen(
                                              teamId: team['teamId'],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        _Card(
                          title: "Project Assignments",
                          width: twoCols
                              ? (c.maxWidth - gridGap) / 2
                              : c.maxWidth,
                          child: FutureBuilder<List<dynamic>>(
                            future: _fetchInternProjects(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text("Error: ${snapshot.error}"),
                                );
                              }

                              final internProjects = snapshot.data!;
                              if (internProjects.isEmpty) {
                                return const _EmptyLine(
                                  text: "No project assignments",
                                );
                              }

                              return Column(
                                children: [
                                  for (var project in internProjects)
                                    _AssignmentTile(
                                      iconBg: const Color(0xFF4169E1),
                                      icon: Icons.work_outline,
                                      title: project['projectName'],
                                      subtitle: "Status: ${project['status']}",
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProjectDetailScreen(
                                              projectId: project['projectId'],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: isMobile ? 8 : 12,
                          width: double.infinity,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Edit dialog
        if (showEditDialog)
          _EditDialog(
            onClose: onCloseDialog,
            onUpdate: onUpdate,
            controllers: formControllers,
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Widget right;

  const _TopBar({required this.onBack, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back, size: 20, color: Color(0xFF4B5563)),
                SizedBox(width: 8),
                Text(
                  "Back to Interns",
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        right,
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String id;
  final int daysRemaining;

  const _HeaderCard({
    required this.name,
    required this.id,
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  id,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${daysRemaining.abs()} DAYS REMAINING",
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "Not recorded yet",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;

  const _Card({required this.title, required this.child, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;

  const _KV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AssignmentTile({
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _EditDialog extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function() onUpdate;

  final ({
    TextEditingController code,
    TextEditingController name,
    TextEditingController email,
    TextEditingController institute,
    TextEditingController startDate,
    TextEditingController endDate,
  })
  controllers;

  const _EditDialog({
    required this.onClose,
    required this.onUpdate,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        child: SafeArea(
          child: Center(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + mq.viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  maxHeight: mq.size.height - 32,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final twoCols = c.maxWidth >= 620;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Edit Intern",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: onClose,
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(18),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(
                                    width: twoCols
                                        ? (c.maxWidth - 36 - 16) / 2
                                        : c.maxWidth,
                                    child: _Field(
                                      label: "Intern Code",
                                      requiredStar: true,
                                      controller: controllers.code,
                                    ),
                                  ),
                                  SizedBox(
                                    width: twoCols
                                        ? (c.maxWidth - 36 - 16) / 2
                                        : c.maxWidth,
                                    child: _Field(
                                      label: "Full Name",
                                      requiredStar: true,
                                      controller: controllers.name,
                                    ),
                                  ),
                                  SizedBox(
                                    width: twoCols
                                        ? (c.maxWidth - 36 - 16) / 2
                                        : c.maxWidth,
                                    child: _Field(
                                      label: "Email",
                                      requiredStar: true,
                                      controller: controllers.email,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                  SizedBox(
                                    width: twoCols
                                        ? (c.maxWidth - 36 - 16) / 2
                                        : c.maxWidth,
                                    child: _Field(
                                      label: "Institute",
                                      requiredStar: true,
                                      controller: controllers.institute,
                                    ),
                                  ),
                                  SizedBox(
                                    width: c.maxWidth,
                                    child: _Field(
                                      label: "Training Start Date",
                                      requiredStar: true,
                                      controller: controllers.startDate,
                                      keyboardType: TextInputType.datetime,
                                      hint: "YYYY-MM-DD",
                                    ),
                                  ),
                                  SizedBox(
                                    width: c.maxWidth,
                                    child: _Field(
                                      label: "Training End Date",
                                      requiredStar: true,
                                      controller: controllers.endDate,
                                      keyboardType: TextInputType.datetime,
                                      hint: "YYYY-MM-DD",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Divider(height: 1),

                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton(
                                  onPressed: onClose,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    await onUpdate();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4169E1),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    "Update Intern",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final bool requiredStar;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hint;

  const _Field({
    required this.label,
    required this.requiredStar,
    required this.controller,
    this.keyboardType,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
            children: [
              TextSpan(text: label),
              if (requiredStar)
                const TextSpan(
                  text: " *",
                  style: TextStyle(color: Color(0xFFEF4444)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF93C5FD)),
            ),
          ),
        ),
      ],
    );
  }
}
