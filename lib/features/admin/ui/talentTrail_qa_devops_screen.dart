import 'package:flutter/material.dart';
import 'talentTrail_dashboard_sidebar.dart';

class TalentTrailQaDevopsScreen extends StatefulWidget {
  const TalentTrailQaDevopsScreen({super.key});

  @override
  State<TalentTrailQaDevopsScreen> createState() => _TalentTrailQaDevopsScreenState();
}

class _TalentTrailQaDevopsScreenState extends State<TalentTrailQaDevopsScreen> {
  bool _isSidebarOpen = false;
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> qaDevopsData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          isLoading = false;
          qaDevopsData = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'TalentTrail',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: _toggleSidebar,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0E27), Color(0xFF064E3B)], // Dark blue to green gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Header Area
                  const Text(
                    'QA & DevOps Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage interns, assign teams, and view progress logs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Filter Section
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            hintText: 'Search by name or ir...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: 'All Specializations',
                              items: ['All Specializations', 'QA', 'DevOps']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                // Handle specialization change
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Data Table Section
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF021B47)),
                        dataRowColor: WidgetStateProperty.all(Colors.white),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        border: TableBorder(
                          horizontalInside: BorderSide(color: Colors.grey.shade300),
                        ),
                        columns: const [
                          DataColumn(label: Text('Intern Code')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Specialization')),
                          DataColumn(label: Text('Projects')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          _buildMockDataRow(
                            code: '2876',
                            name: 'D.G.Dulansa Navindee',
                            email: 'dulansa@example.com',
                            specialization: 'QA',
                            projects: '2',
                          ),
                          _buildMockDataRow(
                            code: '2877',
                            name: 'Kasun Perera',
                            email: 'kasun@example.com',
                            specialization: 'DevOps',
                            projects: '1',
                          ),
                          _buildMockDataRow(
                            code: '2878',
                            name: 'Nimali Silva',
                            email: 'nimali@example.com',
                            specialization: 'QA',
                            projects: '3',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Sidebar Overlay
          TalentTrailSidebar(
            isOpen: _isSidebarOpen,
            onClose: _toggleSidebar,
          ),
        ],
      ),
    );
  }

  // Helper method to create mock data rows
  DataRow _buildMockDataRow({
    required String code,
    required String name,
    required String email,
    required String specialization,
    required String projects,
  }) {
    return DataRow(
      cells: [
        DataCell(Text(code)),
        DataCell(Text(name)),
        DataCell(Text(email)),
        DataCell(Text(specialization)),
        DataCell(Text(projects)),
        DataCell(
          OutlinedButton(
            onPressed: () {
              // Logs button action
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0F172A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
            child: const Text(
              'Logs',
              style: TextStyle(color: Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }
}
