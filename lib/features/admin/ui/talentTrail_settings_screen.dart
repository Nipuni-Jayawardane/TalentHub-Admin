import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/ui/talentTrail_dashboard_sidebar.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/talentTrail_admin_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:slt_internship_attendance_portal/config/config.dart';

// MODELS
class Specialization {
  final String id;
  final String name;
  final int internCount;

  Specialization(this.id, this.name, this.internCount);
}

class Category {
  final String id;
  final String name;
  final String description;
  final List<String> specializations;

  Category(this.id, this.name, this.description, this.specializations);
}

class ApiKeyModel {
  final String id;
  final String name;
  final String description;
  final int endpoints;
  final String created;
  final String expires;
  final String lastUsed;
  final String createdBy;
  final String status;

  ApiKeyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.endpoints,
    required this.created,
    required this.expires,
    required this.lastUsed,
    required this.createdBy,
    required this.status,
  });
}

// PAGE
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool showActiveOnly = true;
  bool exportActiveOnly = true;
  bool isSidebarOpen = false;
  bool _isLoading = true;
  String? _error;

  List<Specialization> specializations = [];
  List<Category> categories = [];
  List<ApiKeyModel> apiKeys = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserPreferences();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load specializations
      await _loadSpecializations();

      // Load categories
      await _loadCategories();

      // Load API keys
      await _loadApiKeys();

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

  Future<void> _loadSpecializations() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.talentTrailBaseUrl}/specialization-categories'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Parse categories if needed, but here we just get interns
        // final List<dynamic> categoriesData = jsonDecode(response.body);

        // Extract all specializations from categories
        final Map<String, int> specializationCounts = {};

        // Get interns to count specializations
        final interns = await TalentTrailAdminService.getInterns();

        for (var intern in interns) {
          final spec = intern['fieldOfSpecialization']?.toString();
          if (spec != null && spec.isNotEmpty) {
            specializationCounts[spec] = (specializationCounts[spec] ?? 0) + 1;
          }
        }

        // Create specializations list
        final List<Specialization> tempSpecializations = [];
        for (var entry in specializationCounts.entries) {
          tempSpecializations.add(
            Specialization(entry.key, entry.key, entry.value),
          );
        }

        // Sort by name
        tempSpecializations.sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          specializations = tempSpecializations;
        });
      }
    } catch (e) {
      debugPrint('Error loading specializations: $e');
      // Fallback to empty list
      setState(() {
        specializations = [];
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.talentTrailBaseUrl}/specialization-categories'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesData = jsonDecode(response.body);

        final List<Category> tempCategories = categoriesData.map((cat) {
          return Category(
            cat['id'].toString(),
            cat['categoryName'] ?? '',
            cat['description'] ?? '',
            List<String>.from(cat['specializations'] ?? []),
          );
        }).toList();

        setState(() {
          categories = tempCategories;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() {
        categories = [];
      });
    }
  }

  Future<void> _loadApiKeys() async {
    // API keys might not be available in the current API
    // This is a placeholder - implement if your API has key management endpoints
    setState(() {
      apiKeys = [];
    });
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('talentTrailToken') ?? '';
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showActiveOnly = prefs.getBool('showActiveOnly') ?? true;
      exportActiveOnly = prefs.getBool('exportActiveOnly') ?? true;
    });
  }

  Future<void> _saveUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showActiveOnly', showActiveOnly);
    await prefs.setBool('exportActiveOnly', exportActiveOnly);
  }

  Future<void> _createCategory() async {
    final nameCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final specializationsCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Category Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specializationsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Specializations (comma separated)',
                  hintText: 'e.g., Java, Python, React',
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
      final specializations = specializationsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final payload = {
        'categoryName': nameCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'specializations': specializations,
      };

      final response = await http.post(
        Uri.parse('${Config.talentTrailBaseUrl}/specialization-categories'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category created successfully')),
          );
          await _loadCategories();
        }
      } else {
        throw Exception('Failed to create category');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editCategory(Category category) async {
    final nameCtrl = TextEditingController(text: category.name);
    final descriptionCtrl = TextEditingController(text: category.description);
    final specializationsCtrl = TextEditingController(
      text: category.specializations.join(', '),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Category Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specializationsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Specializations (comma separated)',
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
      ),
    );

    if (ok != true) return;

    try {
      final specializations = specializationsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final payload = {
        'categoryName': nameCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'specializations': specializations,
      };

      final response = await http.put(
        Uri.parse(
          '${Config.talentTrailBaseUrl}/specialization-categories/${category.id}',
        ),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category updated successfully')),
          );
          await _loadCategories();
        }
      } else {
        throw Exception('Failed to update category');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
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
      final response = await http.delete(
        Uri.parse(
          '${Config.talentTrailBaseUrl}/specialization-categories/${category.id}',
        ),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
          );
          await _loadCategories();
        }
      } else {
        throw Exception('Failed to delete category');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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

      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(error: _error!, onRetry: _loadData)
                : SingleChildScrollView(
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
                            const SizedBox(height: 48),
                            _userPreferences(),
                            const SizedBox(height: 48),
                            _specializationManagement(),
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

  // SECTIONS

  Widget _header() {
    return Column(
      children: const [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 15, 15, 79),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Manage specialization categories and API keys',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _userPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User Preferences',
          style: TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Customize your view and export options for intern data',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _switchRow(
                title: 'Show Active Interns Only',
                description:
                    'Filter the Interns table to display only active interns by default',
                value: showActiveOnly,
                onChanged: (v) {
                  setState(() => showActiveOnly = v);
                  _saveUserPreferences();
                },
                showDivider: true,
              ),
              _switchRow(
                title: 'Consider and Export Active Interns Only',
                description:
                    'When viewing the dashboard or assignments, include only active interns',
                value: exportActiveOnly,
                onChanged: (v) {
                  setState(() => exportActiveOnly = v);
                  _saveUserPreferences();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: Colors.grey.shade300))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _specializationManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Field of Specialization Management',
                    style: TextStyle(fontSize: 22, color: Colors.black),
                    softWrap: true,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create categories and organize specializations',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _primaryButton('Create Category', onPressed: _createCategory),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          'Available Specializations from API',
          style: TextStyle(fontSize: 20, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 16),
        if (specializations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No specializations found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...specializations.map(_specializationCard),
        const SizedBox(height: 48),
        _categoriesSection(),
      ],
    );
  }

  Widget _specializationCard(Specialization s) {
    final isCategorized = categories.any(
      (cat) => cat.specializations.contains(s.name),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isCategorized ? const Color(0xFFE8F5F3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCategorized ? const Color(0xFF5DCCB8) : Colors.grey.shade300,
          width: isCategorized ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.name,
                style: const TextStyle(fontSize: 18, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 4),
              Text(
                '${s.internCount} interns',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          if (isCategorized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '✓ Categorized',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Categories (${categories.length})',
            style: const TextStyle(fontSize: 24, color: Color(0xFF2C3E50)),
          ),
        ),
        const SizedBox(height: 24),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No categories created yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...categories.map((c) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Check if screen is small (mobile)
                  final isSmallScreen = constraints.maxWidth < 600;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row - stacks vertically on small screens
                      if (isSmallScreen)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _outlineButton(
                                  'Edit',
                                  const Color(0xFF4169E1),
                                  onPressed: () => _editCategory(c),
                                ),
                                const SizedBox(width: 8),
                                _outlineButton(
                                  'Delete',
                                  Colors.red,
                                  onPressed: () => _deleteCategory(c),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _outlineButton(
                                  'Edit',
                                  const Color(0xFF4169E1),
                                  onPressed: () => _editCategory(c),
                                ),
                                const SizedBox(width: 8),
                                _outlineButton(
                                  'Delete',
                                  Colors.red,
                                  onPressed: () => _deleteCategory(c),
                                ),
                              ],
                            ),
                          ],
                        ),

                      if (c.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          c.description,
                          style: const TextStyle(
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Specializations - responsive wrap
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: c.specializations
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(
                                    255,
                                    65,
                                    166,
                                    225,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            );
          }),
      ],
    );
  }

  // Helper method for outline buttons (responsive)
  Widget _outlineButton(
    String text,
    Color color, {
    required VoidCallback onPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return SizedBox(
          width: isSmallScreen ? 80 : null,
          height: isSmallScreen ? 36 : null,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: isSmallScreen
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: isSmallScreen ? const Size(70, 36) : null,
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
            ),
          ),
        );
      },
    );
  }

  // UI HELPERS

  Widget _primaryButton(
    String text, {
    bool fullWidth = false,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 65, 153, 225),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed ?? () {},
        child: Text(text),
      ),
    );
  }
}

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
              'Failed to load settings',
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

