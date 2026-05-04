import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminInternDetailsScreen extends StatefulWidget {
  final String internId;

  const AdminInternDetailsScreen({super.key, required this.internId});

  @override
  State<AdminInternDetailsScreen> createState() =>
      _AdminInternDetailsScreenState();
}

class _AdminInternDetailsScreenState extends State<AdminInternDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? internDetails;
  bool isLoading = true;
  String? error;
  List<dynamic> recentRecords = [];

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email client')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchInternDetails();
  }

  Future<void> fetchInternDetails() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await AdminApiService.fetchInternDetails(widget.internId);
      setState(() {
        internDetails = data;
        if (data['records'] != null && data['records'] is List) {
          recentRecords = (data['records'] as List).take(5).toList();
        }
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
      if (e.toString().contains('401') || e.toString().contains('403')) {
        await _logout();
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      context.go('/admin-login');
    }
  }

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget getStatusBadge(Map<String, dynamic> statistics) {
    if (statistics['isOverdue'] == true) {
      return Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(FontAwesomeIcons.triangleExclamation, size: 16),
            SizedBox(width: 4),
            Text('Overdue'),
          ],
        ),
        backgroundColor: Colors.red.withValues(alpha: 0.2),
        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
      );
    } else if (statistics['totalRecords'] == 0) {
      return Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(FontAwesomeIcons.circleXmark, size: 16),
            SizedBox(width: 4),
            Text('Inactive'),
          ],
        ),
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
      );
    } else {
      return Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(FontAwesomeIcons.circleCheck, size: 16),
            SizedBox(width: 4),
            Text('Active'),
          ],
        ),
        backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
        side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.3)),
      );
    }
  }

  BarChartData getWeeklyActivityData() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final activityCount = List<int>.filled(7, 0);

    if (internDetails?['records'] != null &&
        internDetails!['records'] is List) {
      for (var record in internDetails!['records']) {
        final day =
            DateTime.parse(record['createdAt']).weekday - 1; // Adjust for Mon=0
        if (day >= 0 && day < 7) activityCount[day]++;
      }
    }

    return BarChartData(
      barGroups: List.generate(
        7,
        (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: activityCount[index].toDouble(),
              color: Colors.cyanAccent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) => Text(
              days[value.toInt()],
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ),
      ),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      maxY:
          activityCount.reduce((a, b) => a > b ? a : b) + 1.0, // Dynamic max Y
    );
  }

  PieChartData? getMonthlyStackData() {
    if (internDetails?['records'] == null ||
        internDetails!['records'] is! List) {
      return null;
    }

    final now = DateTime.now();
    final monthlyRecords = (internDetails!['records'] as List).where((r) {
      final d = DateTime.parse(r['createdAt']);
      return d.month == now.month && d.year == now.year && r['stack'] != null;
    }).toList();

    if (monthlyRecords.isEmpty) {
      return null;
    }

    final stackCounts = <String, int>{};
    for (var r in monthlyRecords) {
      stackCounts[r['stack']] = (stackCounts[r['stack']] ?? 0) + 1;
    }

    final colors = [
      Colors.cyanAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      const Color(0xFFFBBF24),
      const Color(0xFFF87171),
      const Color(0xFFF472B6),
      const Color(0xFF60A5FA),
      const Color(0xFFFACC15),
      const Color(0xFF4ADE80),
      const Color(0xFF818CF8),
    ];
    final entriesList = stackCounts.entries.toList();
    final sections = entriesList
        .asMap()
        .entries
        .map(
          (entry) => PieChartSectionData(
            value: entry.value.value.toDouble(),
            title: entry.value.key, // Kept for legend, not displayed on chart
            color: colors[entry.key % colors.length],
            radius: 40, // Reduced radius for better fit
            showTitle: false, // Remove labels on the pie chart
          ),
        )
        .toList();

    return PieChartData(
      sections: sections,
      centerSpaceRadius: 30, // Reduced center space for more visible sections
      sectionsSpace: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    if (error != null || internDetails == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/admin-dashboard');
        },
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  FontAwesomeIcons.triangleExclamation,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  error ?? 'Intern details not found',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: fetchInternDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
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
          ),
        ),
      );
    }

    final intern = internDetails!['intern'];
    final statistics = internDetails!['statistics'];

    return Scaffold(
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
      body: SingleChildScrollView(
        child: Container(
          color: const Color(0xFF0A1A3A),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => context.go('/admin/daily-records'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Intern Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      getStatusBadge(statistics),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Activity'),
                      Tab(text: 'Records'),
                    ],
                    indicatorColor: Colors.cyanAccent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(isMobile, intern, statistics),
                        _buildActivityTab(isMobile),
                        _buildRecordsTab(isMobile),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    bool isMobile,
    Map<String, dynamic> intern,
    Map<String, dynamic> statistics,
  ) {
    return Flexible(
      child: ListView(
        children: [
          Card(
            color: Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.cyanAccent,
                    child: Icon(
                      FontAwesomeIcons.user,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    intern['traineeName'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Trainee ID: ${intern['traineeId']}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _launchEmail(intern['email']),
                        icon: const Icon(FontAwesomeIcons.envelope),
                        label: const Text('Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.cyanAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 1 : 3,
                    childAspectRatio: isMobile
                        ? 3.0
                        : 1.5, // Adjust aspect ratio for compactness
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    children: [
                      _buildDetailCard(
                        'Email',
                        intern['email'],
                        FontAwesomeIcons.envelope,
                      ),
                      _buildDetailCard(
                        'Specialization',
                        intern['fieldOfSpecialization'] ?? 'Not specified',
                        FontAwesomeIcons.building,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            children: [
              _statCard(
                'Total Records',
                statistics['totalRecords'].toString(),
                FontAwesomeIcons.fileLines,
                Colors.greenAccent,
              ),
              _statCard(
                'This Week',
                statistics['weeklyRecords'].toString(),
                FontAwesomeIcons.listCheck,
                Colors.cyanAccent,
              ),
              _statCard(
                'This Month',
                statistics['monthlyRecords'].toString(),
                FontAwesomeIcons.calendarDays,
                Colors.purpleAccent,
              ),
              _statCard(
                'Days Since Last',
                statistics['daysSinceLastSubmission']?.toString() ?? 'Never',
                FontAwesomeIcons.clock,
                Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: BarChart(getWeeklyActivityData()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: getMonthlyStackData() != null
                        ? PieChart(getMonthlyStackData()!)
                        : const Center(
                            child: Text(
                              'No data',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentRecords.isNotEmpty)
            Card(
              color: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white10),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentRecords.length,
                itemBuilder: (context, index) {
                  final record = recentRecords[index];
                  return ListTile(
                    title: Text(
                      record['taskDescription'] ?? record['task'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      formatDate(record['createdAt']),
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: Chip(
                      label: Text(
                        record['stack'] ?? 'N/A',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Reduced padding for compactness
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white60, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 2, // Limit to 2 lines with ellipsis
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 13),
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: color.withValues(alpha: 0.8))),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTab(bool isMobile) {
    final weeklyData = getWeeklyActivityData();
    final monthlyData = getMonthlyStackData();

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final counts = weeklyData.barGroups
        .map((e) => e.barRods[0].toY.toInt())
        .toList();
    final maxDayIdx = counts.isNotEmpty
        ? counts.indexOf(counts.reduce(max))
        : 0;
    final avgPerWeek = counts.isNotEmpty
        ? (counts.reduce((a, b) => a + b) / 7).toStringAsFixed(2)
        : '0.00';
    final stacksUsed = monthlyData?.sections.length ?? 0;

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Weekly Activity (Records per Day)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 180, // Adjusted height to accommodate label
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      weeklyData.barGroups.any(
                        (group) => group.barRods[0].toY > 0,
                      )
                      ? BarChart(weeklyData)
                      : const Center(
                          child: Text(
                            'No weekly activity data',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Monthly Stack Distribution',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: monthlyData != null && monthlyData.sections.isNotEmpty
                      ? Column(
                          children: [
                            Expanded(child: PieChart(monthlyData)),
                            if (monthlyData.sections.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Wrap(
                                  spacing: 8.0,
                                  children: monthlyData.sections.map((section) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          color: section.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${section.title} (${(section.value / monthlyData.sections.map((s) => s.value).reduce((a, b) => a + b) * 100).toStringAsFixed(1)}%)',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        )
                      : const Center(
                          child: Text(
                            'No monthly stack data',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 3,
          children: [
            _statCard(
              'Most Active Day',
              days[maxDayIdx],
              FontAwesomeIcons.calendarDays,
              Colors.greenAccent,
            ),
            _statCard(
              'Avg. Records/Week',
              avgPerWeek,
              FontAwesomeIcons.chartBar,
              Colors.cyanAccent,
            ),
            _statCard(
              'Stacks Used (Month)',
              stacksUsed.toString(),
              FontAwesomeIcons.chartPie,
              Colors.purpleAccent,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecordsTab(bool isMobile) {
    final records = internDetails!['records'] ?? [];
    if (records.isEmpty) {
      return const Center(
        child: Text('No records', style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(
          title: Text(
            record['taskDescription'] ?? record['task'] ?? 'N/A',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            formatDate(record['createdAt']),
            style: const TextStyle(color: Colors.white60),
          ),
          trailing: Chip(
            label: Text(
              record['stack'] ?? 'N/A',
              style: const TextStyle(color: Color.fromARGB(255, 28, 0, 0)),
            ),
            backgroundColor: Colors.white10,
          ),
        );
      },
    );
  }
}
