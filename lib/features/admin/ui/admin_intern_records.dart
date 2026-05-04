import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';

class AdminInternRecords extends StatefulWidget {
  final String internId;

  const AdminInternRecords({super.key, required this.internId});

  @override
  State<AdminInternRecords> createState() => _AdminInternRecordsState();
}

class _AdminInternRecordsState extends State<AdminInternRecords> {
  Map<String, dynamic>? internDetails;
  bool loading = true;
  String? error;
  String searchTerm = '';
  String filterPeriod = 'all';
  String sortBy = 'date';

  @override
  void initState() {
    super.initState();
    fetchInternDetails();
  }

  Future<void> fetchInternDetails() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Check for auth token
      final prefs = await SharedPreferences.getInstance();
      final adminToken = prefs.getString('admin_token');
      final userToken = prefs.getString('user_token');
      if (adminToken == null && userToken == null) {
        setState(() {
          error = 'Authentication required';
          loading = false;
        });
        if (mounted) {
          context.go('/admin-login');
        }
        return;
      }

      // Fetch real-time data using AdminApiService
      final data = await AdminApiService.fetchInternDetails(widget.internId);
      //print('Intern Details Response: $data'); // Debug log
      //print('Extracted internId from response: ${data['intern']?['internId']}');

      setState(() {
        internDetails = data;
        loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching intern details: $e'); // Debug log
      setState(() {
        error = 'Failed to load intern records';
        loading = false;
      });
      if (e.toString().contains('401') || e.toString().contains('403')) {
        // Clear tokens and redirect to login
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('admin_token');
        await prefs.remove('user_token');
        await prefs.remove('talentHubToken');
        if (mounted) {
          context.go('/admin-login');
        }
      }
    }
  }

  List<Map<String, dynamic>> getFilteredRecords() {
    if (internDetails?['records'] == null) return [];

    List<Map<String, dynamic>> filtered = List.from(internDetails!['records']);

    // Search filter
    if (searchTerm.isNotEmpty) {
      final searchLower = searchTerm.toLowerCase();
      filtered = filtered.where((record) {
        return (record['task']?.toLowerCase().contains(searchLower) ?? false) ||
            (record['progress']?.toLowerCase().contains(searchLower) ??
                false) ||
            (record['blockers']?.toLowerCase().contains(searchLower) ??
                false) ||
            (record['date']?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Period filter
    if (filterPeriod != 'all') {
      final now = DateTime.now();
      DateTime filterDate;

      switch (filterPeriod) {
        case 'week':
          filterDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          filterDate = now.subtract(const Duration(days: 30));
          break;
        case '3months':
          filterDate = now.subtract(const Duration(days: 90));
          break;
        default:
          filterDate = now;
      }

      filtered = filtered.where((record) {
        final recordDate = DateTime.parse(record['createdAt']);
        return recordDate.isAfter(filterDate);
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['createdAt']);
      final dateB = DateTime.parse(b['createdAt']);
      switch (sortBy) {
        case 'date':
          return dateB.compareTo(dateA); // Newest first
        case 'dateOld':
          return dateA.compareTo(dateB); // Oldest first
        default:
          return 0;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = getFilteredRecords();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/admin-dashboard');
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF00102F),
          elevation: 4,
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.go('/admin-dashboard'),
                  child: Image.asset('assets/images/slt_logo.png', height: 32),
                ),
                const Spacer(),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color.fromARGB(84, 30, 136, 229),
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 15),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () => context.go('/admin-login'),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
        body: loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'Loading intern records...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : error != null
            ? Center(
                child: Card(
                  elevation: 2,
                  color: const Color(0xFF00102F).withValues(alpha: 0.8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: fetchInternDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => context.go('/admin-dashboard'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade800,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Back to Dashboard'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => context.go('/admin/daily-records'),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logbook Records',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent.shade200,
                                  ),
                                ),
                                Text(
                                  '${internDetails?['intern']['traineeName']} - ${internDetails?['intern']['traineeId']}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Total Records',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${internDetails?['records']?.length ?? 0}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Navigate to intern details
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: ElevatedButton(
                          onPressed: () {
                            // Use widget.internId directly (it's the valid ID passed via router)
                            if (widget.internId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invalid intern ID'),
                                ),
                              );
                              return;
                            }
                            context.go(
                              '/admin/intern/${widget.internId}/details',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              54,
                              72,
                              229,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'View Intern Details',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      // Search and Filter
                      Card(
                        elevation: 2,
                        color: const Color(0xFF00102F).withValues(alpha: 0.8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Search and Filter',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                decoration: InputDecoration(
                                  hintText:
                                      'Search tasks, progress, blockers...',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.white70,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.1),
                                ),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (value) =>
                                    setState(() => searchTerm = value),
                              ),
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.filter_list,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 150,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: filterPeriod,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'all',
                                            child: Text('All Time'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'week',
                                            child: Text('Last Week'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'month',
                                            child: Text('Last Month'),
                                          ),
                                          DropdownMenuItem(
                                            value: '3months',
                                            child: Text('Last 3 Months'),
                                          ),
                                        ],
                                        onChanged: (value) => setState(
                                          () => filterPeriod = value!,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white.withValues(alpha: 
                                            0.1,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        dropdownColor: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.sort,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 150,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: sortBy,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'date',
                                            child: Text('Newest First'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'dateOld',
                                            child: Text('Oldest First'),
                                          ),
                                        ],
                                        onChanged: (value) =>
                                            setState(() => sortBy = value!),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white.withValues(alpha: 
                                            0.1,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        dropdownColor: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Showing ${filteredRecords.length} of ${internDetails?['records']?.length ?? 0} records',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Records List
                      filteredRecords.isEmpty
                          ? Card(
                              elevation: 2,
                              color: const Color(0xFF00102F).withValues(alpha: 0.8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.list_alt,
                                      size: 48,
                                      color: Colors.white38,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No records found',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      searchTerm.isNotEmpty ||
                                              filterPeriod != 'all'
                                          ? 'Try adjusting your search or filter criteria.'
                                          : 'This intern hasn\'t submitted any logbook entries yet.',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: filteredRecords.asMap().entries.map((
                                entry,
                              ) {
                                final record = entry.value;
                                return Card(
                                  elevation: 2,
                                  color: const Color(
                                    0xFF00102F,
                                  ).withValues(alpha: 0.8),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.1),
                                              child: const Icon(
                                                Icons.calendar_today,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    DateTime.parse(
                                                      record['date'],
                                                    ).toString().split(' ')[0],
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Submitted: ${DateTime.parse(record['createdAt']).toString().split(' ')[0]}',
                                                    style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (record['stack'] != null)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue
                                                            .withValues(alpha: 0.2),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        record['stack'],
                                                        style: const TextStyle(
                                                          color:
                                                              Colors.blueAccent,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.list_alt,
                                                    size: 14,
                                                    color: Colors.blueAccent,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Daily Record',
                                                    style: TextStyle(
                                                      color: Colors.blueAccent,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (record['task'] != null)
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: Colors.blueAccent,
                                                  width: 4,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Tasks Completed',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  record['task'],
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (record['progress'] != null &&
                                            record['progress'] !=
                                                'No challenges faced')
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: Colors.greenAccent,
                                                  width: 4,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Challenges Faced',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  record['progress'],
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (record['blockers'] != null &&
                                            record['blockers'] !=
                                                'No specific plans')
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: Colors.orangeAccent,
                                                  width: 4,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Plans for Tomorrow',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  record['blockers'],
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (record['task'] == null &&
                                            (record['progress'] == null ||
                                                record['progress'] ==
                                                    'No challenges faced') &&
                                            (record['blockers'] == null ||
                                                record['blockers'] ==
                                                    'No specific plans'))
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.error,
                                                  color: Colors.white60,
                                                  size: 32,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'No detailed information available for this record',
                                                  style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
              ),
        backgroundColor: const Color(0xFF00102F),
      ),
    );
  }
}
