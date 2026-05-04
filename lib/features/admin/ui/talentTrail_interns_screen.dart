import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talentTrail_admin_api.dart';
import 'package:go_router/go_router.dart';
import 'package:slt_internship_attendance_portal/core/services/api_service.dart';

class Intern {
  final int internId;
  final String id;
  final String name;
  final String email;
  final String institute;
  final String specialization;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? lastLogin;
  final String status;

  Intern({
    required this.internId,
    required this.id,
    required this.name,
    required this.email,
    required this.institute,
    required this.specialization,
    required this.startDate,
    required this.endDate,
    this.lastLogin,
    required this.status,
  });
}

class InternsManagementScreen extends StatefulWidget {
  const InternsManagementScreen({super.key});

  @override
  State<InternsManagementScreen> createState() =>
      _InternsManagementScreenState();
}

class _InternsManagementScreenState extends State<InternsManagementScreen> {
  bool isSidebarOpen = false;

  List<Intern> interns = [];
  bool isLoading = true;
  bool isAuthenticating = false;
  String? error;

  // Get unique specializations from interns
  List<String> get availableCategories {
    final categories = interns.map((i) => i.specialization).toSet();
    return ['All Categories', ...categories.where((c) => c.isNotEmpty)];
  }

  String searchQuery = '';
  String categoryFilter = 'All Categories';
  String sortOption = 'None';

  @override
  void initState() {
    super.initState();
    _initializeAndLoadInterns();
  }

  Future<void> _initializeAndLoadInterns() async {
    setState(() {
      isLoading = true;
      isAuthenticating = true;
      error = null;
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

      await _loadInterns();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Authentication failed: $e';
          isLoading = false;
          isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _loadInterns() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await TalentTrailAdminService.getInterns();

      final mapped = data.map<Intern>((json) {
        return Intern(
          internId: json['internId'] ?? 0,
          id: json['internCode']?.toString() ?? '',
          name: json['name']?.toString() ?? '',
          email: json['email']?.toString() ?? '',
          institute: json['institute']?.toString() ?? '',
          specialization:
              json['fieldOfSpecialization']?.toString() ?? 'Not Specified',
          startDate: json['trainingStartDate'] != null
              ? DateTime.parse(json['trainingStartDate'].toString())
              : DateTime.now(),
          endDate: json['trainingEndDate'] != null
              ? DateTime.parse(json['trainingEndDate'].toString())
              : DateTime.now(),
          lastLogin: json['lastLoginAt'] != null
              ? DateTime.tryParse(json['lastLoginAt'].toString())
              : null,
          status: json['status']?.toString() ?? 'UNKNOWN',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        interns = mapped;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        interns = [];
        isLoading = false;
      });
    }
  }

  List<Intern> get filteredInterns {
    List<Intern> result = [...interns];

    // Apply search filter
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((i) {
        return i.name.toLowerCase().contains(query) ||
            i.id.toLowerCase().contains(query) ||
            i.email.toLowerCase().contains(query);
      }).toList();
    }

    // Apply category filter
    if (categoryFilter != 'All Categories') {
      result = result
          .where(
            (i) =>
                i.specialization.toLowerCase() == categoryFilter.toLowerCase(),
          )
          .toList();
    }

    // Apply sorting
    switch (sortOption) {
      case 'Intern Code (Ascending)':
        result.sort((a, b) => a.id.compareTo(b.id));
        break;
      case 'Intern Code (Descending)':
        result.sort((a, b) => b.id.compareTo(a.id));
        break;
      case 'Name (Ascending)':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Name (Descending)':
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Start Date (Ascending)':
        result.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case 'Start Date (Descending)':
        result.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
      case 'End Date (Ascending)':
        result.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case 'End Date (Descending)':
        result.sort((a, b) => b.endDate.compareTo(a.endDate));
        break;
      case 'Last Login (Newest First)':
        result.sort((a, b) {
          final aTime = a.lastLogin ?? DateTime(1900);
          final bTime = b.lastLogin ?? DateTime(1900);
          return bTime.compareTo(aTime);
        });
        break;
      case 'Last Login (Oldest First)':
        result.sort((a, b) {
          final aTime = a.lastLogin ?? DateTime(1900);
          final bTime = b.lastLogin ?? DateTime(1900);
          return aTime.compareTo(bTime);
        });
        break;
    }

    return result;
  }

  String formatDate(DateTime d) => DateFormat('MMM dd, yyyy').format(d);
  String formatLastLogin(DateTime? d) =>
      d != null ? DateFormat('MMM dd, yyyy, hh:mm a').format(d) : '-';

  Future<void> _openEditIntern(Intern intern) async {
    try {
      final latest = await TalentTrailAdminService.getInternByCode(intern.id);

      final codeController = TextEditingController(
        text: (latest['internCode'] ?? intern.id).toString(),
      );
      final nameController = TextEditingController(
        text: (latest['name'] ?? intern.name).toString(),
      );
      final emailController = TextEditingController(
        text: (latest['email'] ?? intern.email).toString(),
      );
      final instituteController = TextEditingController(
        text: (latest['institute'] ?? intern.institute).toString(),
      );
      final specController = TextEditingController(
        text: (latest['fieldOfSpecialization'] ?? intern.specialization)
            .toString(),
      );
      final startDateStr = latest['trainingStartDate']?.toString() ?? '';
      final endDateStr = latest['trainingEndDate']?.toString() ?? '';
      final startController = TextEditingController(text: startDateStr);
      final endController = TextEditingController(text: endDateStr);
      final statusController = TextEditingController(
        text: (latest['status'] ?? intern.status).toString(),
      );

      if (!mounted) return;
      final updated = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Intern'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Intern Code'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: instituteController,
                    decoration: const InputDecoration(labelText: 'Institute'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: specController,
                    decoration: const InputDecoration(
                      labelText: 'Specialization',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'Start Date (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'End Date (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: statusController,
                    decoration: const InputDecoration(
                      labelText: 'Status (ACTIVE/INACTIVE)',
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
                child: const Text('Update'),
              ),
            ],
          );
        },
      );

      if (updated != true) return;

      await TalentTrailAdminService.updateIntern(
        internId: intern.internId,
        internCode: codeController.text.trim(),
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        institute: instituteController.text.trim(),
        fieldOfSpecialization: specController.text.trim(),
        trainingStartDate: startController.text.trim(),
        trainingEndDate: endController.text.trim(),
        status: statusController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intern updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadInterns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteIntern(Intern intern) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Intern'),
        content: Text('Delete intern ${intern.name} (${intern.id})?'),
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
      await TalentTrailAdminService.deleteIntern(intern.internId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intern deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadInterns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadInterns,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Interns Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      color: Color.fromARGB(255, 15, 15, 79),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage intern profiles, training schedules, and progress tracking',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 112, 112, 112),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(
                          255,
                          101,
                          186,
                          239,
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(LucideIcons.plus),
                      label: const Text(
                        'Add New Intern',
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed: () async {
                        final internData = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (context) {
                            final codeController = TextEditingController();
                            final nameController = TextEditingController();
                            final emailController = TextEditingController();
                            final instituteController = TextEditingController();
                            final startController = TextEditingController();
                            final endController = TextEditingController();

                            return AlertDialog(
                              title: const Text('Add New Intern'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: codeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Intern Code',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Name',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: instituteController,
                                      decoration: const InputDecoration(
                                        labelText: 'Institute',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: startController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Training Start Date (YYYY-MM-DD)',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: endController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Training End Date (YYYY-MM-DD)',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, null),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context, {
                                      'internCode': codeController.text,
                                      'name': nameController.text,
                                      'email': emailController.text,
                                      'institute': instituteController.text,
                                      'trainingStartDate': startController.text,
                                      'trainingEndDate': endController.text,
                                    });
                                  },
                                  child: const Text('Add Intern'),
                                ),
                              ],
                            );
                          },
                        );

                        if (internData != null) {
                          try {
                            await TalentTrailAdminService.addIntern(
                              internCode: internData['internCode']!,
                              name: internData['name']!,
                              email: internData['email']!,
                              institute: internData['institute']!,
                              trainingStartDate:
                                  internData['trainingStartDate']!,
                              trainingEndDate: internData['trainingEndDate']!,
                            );

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Intern created successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _loadInterns();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create intern: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, intern code, or email',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => searchQuery = v),
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: categoryFilter,
                    isExpanded: true,
                    items: availableCategories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => categoryFilter = v!),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Filter by Specialization',
                    ),
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    initialValue: sortOption,
                    isExpanded: true,
                    items:
                        const [
                              'None',
                              'Intern Code (Ascending)',
                              'Intern Code (Descending)',
                              'Name (Ascending)',
                              'Name (Descending)',
                              'Start Date (Ascending)',
                              'Start Date (Descending)',
                              'End Date (Ascending)',
                              'End Date (Descending)',
                              'Last Login (Newest First)',
                              'Last Login (Oldest First)',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => sortOption = v!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All Interns (${filteredInterns.length})',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (isAuthenticating)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Authenticating with TalentTrail...'),
                        ],
                      ),
                    )
                  else if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadInterns,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (filteredInterns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No interns found matching your criteria.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    _internsTable(),
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

  Widget _internsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            _internsHeader(),
            ...filteredInterns.map(_internRow),
          ],
        ),
      ),
    );
  }

  Widget _internsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A3B4D), Color(0xFF1A6B5F)],
        ),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 120,
            child: Text('INTERN CODE', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 250,
            child: Text('NAME & EMAIL', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 200,
            child: Text('INSTITUTE', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 300,
            child: Text('TIMELINE', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 100,
            child: Text('STATUS', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 200,
            child: Text(
              'SPECIALIZATION',
              style: TextStyle(color: Colors.white),
            ),
          ),
          SizedBox(
            width: 230,
            child: Text('LAST LOGIN', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(
            width: 120,
            child: Text('ACTIONS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _internRow(Intern i) {
    return InkWell(
      onTap: () => context.go('/talenttrail-intern/${i.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(i.id)),
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.name),
                  Text(
                    i.email,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(width: 200, child: Text(i.institute)),
            SizedBox(
              width: 300,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatDate(i.startDate),
                      style: const TextStyle(color: Colors.green),
                    ),
                    const TextSpan(
                      text: ' - ',
                      style: TextStyle(color: Colors.grey),
                    ),
                    TextSpan(
                      text: formatDate(i.endDate),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: i.status == "ACTIVE"
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  i.status,
                  style: TextStyle(
                    color: i.status == "ACTIVE" ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(width: 200, child: Text(i.specialization)),
            SizedBox(width: 230, child: Text(formatLastLogin(i.lastLogin))),
            SizedBox(
              width: 120,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _openEditIntern(i),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => _confirmDeleteIntern(i),
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
