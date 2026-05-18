import 'package:flutter/material.dart';
import 'talentTrail_dashboard_sidebar.dart';

class TalentTrailHelpRequestsScreen extends StatefulWidget {
  const TalentTrailHelpRequestsScreen({super.key});

  @override
  State<TalentTrailHelpRequestsScreen> createState() => _TalentTrailHelpRequestsScreenState();
}

class _TalentTrailHelpRequestsScreenState extends State<TalentTrailHelpRequestsScreen> {
  bool _isSidebarOpen = false;
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> helpRequests = [];

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
          helpRequests = [];
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
      backgroundColor: const Color(0xFFF8FAFC), // Light Grey/Blue Background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                    'Help Requests',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A), // Dark blue text
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'View and manage intern help requests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey, // Grey text
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Status Filter Row
                  Row(
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: 'All',
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            items: ['All', 'Resolved', 'Pending']
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              // Handle status change
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Custom Table Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 32, // Ensure it fills screen if small
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header Row
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF064E3B), // Dark Green/Navy background
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  _buildHeaderCell('INTERN', 180),
                                  _buildHeaderCell('PROJECT', 180),
                                  _buildHeaderCell('SUBJECT', 150),
                                  _buildHeaderCell('STATUS', 120),
                                  _buildHeaderCell('CREATED', 180),
                                ],
                              ),
                            ),
                            
                            // Table Data Row (Exact Match)
                            _buildDataRow(
                              intern: 'Ranuja Thamira Liyanaarachchi',
                              project: 'TalentHub and Trail Mobile App',
                              subject: 'testing',
                              status: 'Resolved',
                              createdDate: 'May 14, 2026, 8:17 PM',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
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

  // Helper method for Header Cells
  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // Helper method for Data Rows
  Widget _buildDataRow({
    required String intern,
    required String project,
    required String subject,
    required String status,
    required String createdDate,
  }) {
    // Styling the 'Resolved' badge
    Color badgeBgColor = Colors.green.shade50; // Light green background
    Color badgeTextColor = Colors.green.shade800; // Dark green text
    if (status != 'Resolved') {
      badgeBgColor = Colors.orange.shade50;
      badgeTextColor = Colors.orange.shade800;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // White background
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200), // Very thin grey bottom border
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          // Intern Column (Link style blue)
          SizedBox(
            width: 180,
            child: Text(
              intern,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Project Column
          SizedBox(
            width: 180,
            child: Text(
              project,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),

          // Subject Column
          SizedBox(
            width: 150,
            child: Text(
              subject,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),
          
          // Status Column (Badge)
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: badgeTextColor, // Dark green bold text
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          
          // Created Date Column
          SizedBox(
            width: 180,
            child: Text(
              createdDate,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }
}
