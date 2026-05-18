import 'package:flutter/material.dart';
import 'talentTrail_dashboard_sidebar.dart';

class TalentTrailCertificatesScreen extends StatefulWidget {
  const TalentTrailCertificatesScreen({super.key});

  @override
  State<TalentTrailCertificatesScreen> createState() => _TalentTrailCertificatesScreenState();
}

class _TalentTrailCertificatesScreenState extends State<TalentTrailCertificatesScreen> {
  bool _isSidebarOpen = false;
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> certificates = [];

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
          certificates = [];
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
      backgroundColor: const Color(0xFFF8FAFC), // Background Color
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
                    'Certificate Requests',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A), // Bold, dark blue/black
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Review intern requests and generate professional certificates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Status Filter Section
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
                            items: ['All', 'Approved', 'Pending']
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
                          minWidth: MediaQuery.of(context).size.width - 32, // Responsive minimum width
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header Row
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF064E3B), // Dark Green background
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                children: [
                                  _buildHeaderCell('INTERN', 200),
                                  _buildHeaderCell('REQUESTED', 180),
                                  _buildHeaderCell('STATUS', 100),
                                  _buildHeaderCell('PROJECTS', 80, alignCenter: true),
                                  _buildHeaderCell('ATTENDANCE', 100, alignCenter: true),
                                  _buildHeaderCell('ACTIONS', 180),
                                ],
                              ),
                            ),
                            
                            // Table Data Rows
                            _buildDataRow(
                              intern: 'D.G.Dulansa Navindee', // Default mock name
                              requestedDate: 'May 14, 2026, 8:12 PM',
                              status: 'Approved',
                              projects: '1',
                              attendance: '-',
                            ),
                            // Feel free to add more mock rows here following the exact same structure if needed
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

  // Helper for Header Cells
  Widget _buildHeaderCell(String text, double width, {bool alignCenter = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: alignCenter ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // Helper for Data Rows
  Widget _buildDataRow({
    required String intern,
    required String requestedDate,
    required String status,
    required String projects,
    required String attendance,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200), // Thin grey bottom border
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          // Intern Column (Link style)
          SizedBox(
            width: 200,
            child: Text(
              intern,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Requested Column
          SizedBox(
            width: 180,
            child: Text(
              requestedDate,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),
          
          // Status Column (Bold Green text)
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                status,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Projects Column (Centered number)
          SizedBox(
            width: 80,
            child: Text(
              projects,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),
          
          // Attendance Column (Centered text)
          SizedBox(
            width: 100,
            child: Text(
              attendance,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF333333)),
            ),
          ),
          
          // Actions Column (Two side-by-side buttons)
          SizedBox(
            width: 180,
            child: Row(
              children: [
                // Review Button (Small grey button, black text)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      // Review action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Download Button (Small blue button, white text)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      // Download action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Download',
                      style: TextStyle(fontSize: 12),
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
