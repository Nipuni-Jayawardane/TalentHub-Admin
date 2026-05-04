import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';

class SeatManagementScreen extends StatefulWidget {
  const SeatManagementScreen({super.key});

  @override
  State<SeatManagementScreen> createState() => _SeatManagementScreenState();
}

class _SeatManagementScreenState extends State<SeatManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _historyMode = false;
  String? _historyName;
  DateTime _filterDate = DateTime.now();
  bool _isExporting = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _allBookings = [];
  int _lockedSeats = 0;
  int _totalSeats = 0;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _loadSeatStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleApiError(dynamic error) {
    String message = 'An error occurred';

    if (error.toString().contains('Unauthorized')) {
      message = 'Session expired. Please login again.';
    } else if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      message = 'Network error. Please check your connection.';
    } else if (error.toString().contains('timeout')) {
      message = 'Request timeout. Please try again.';
    } else {
      message = error.toString().replaceFirst('Exception: ', '');
    }

    _showSnackbar(message);
  }

  Future<void> _loadBookings() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final bookings = await AdminApiService.getSeatBookings(
        date: _filterDate.toIso8601String().split('T')[0],
      );

      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _handleApiError(e);
      }
    }
  }

  Future<void> _loadSeatStats() async {
    try {
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now();

      final stats = await AdminApiService.getSeatBookingStats(
        startDate: startDate.toIso8601String().split('T')[0],
        endDate: endDate.toIso8601String().split('T')[0],
      );

      debugPrint('Stats received: $stats');

      setState(() {
        _totalSeats = stats['totalSeats'] ?? 96;
        _lockedSeats = stats['lockedSeats'] ?? 20;
      });
    } catch (e) {
      debugPrint('Failed to load seat stats: $e');

      setState(() {
        _totalSeats = 96;
        _lockedSeats = 20;
      });
    }
  }

  Future<void> _searchBookingHistory(String searchTerm) async {
    if (searchTerm.trim().isEmpty) {
      setState(() {
        _historyMode = false;
        _historyName = null;
      });
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final history = await AdminApiService.getBookingHistory(searchTerm);

      if (mounted) {
        setState(() {
          _allBookings = history;
          _historyMode = true;
          _historyName = searchTerm;
          _isLoading = false;
        });

        if (history.isEmpty) {
          _showSnackbar(
            'No booking history found for "$searchTerm"',
            isError: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to load booking history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _handleApiError(e);
      }
    }
  }

  Future<void> _refreshBookings() async {
    await _loadBookings();
    await _loadSeatStats();
  }

  List<Map<String, dynamic>> get _todayBookings {
    final dateStr = _filterDate.toIso8601String().split('T')[0];
    return _allBookings.where((booking) {
      final bookingDate = booking['bookingDate']?.toString().split('T')[0];
      return bookingDate == dateStr && booking['status'] == 'active';
    }).toList();
  }

  List<Map<String, dynamic>> get _historyBookings {
    if (_historyName == null) return [];
    return _allBookings.where((booking) {
      final name = (booking['internName'] ?? booking['name'] ?? '')
          .toLowerCase();
      return name.contains(_historyName!.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get _displayBookings =>
      _historyMode ? _historyBookings : _todayBookings;

  int get _occupiedSeats => _todayBookings.length;
  int get _availableSeats => _totalSeats - _lockedSeats - _occupiedSeats;

  String? get _searchMatchName {
    if (_searchText.trim().isEmpty) return null;
    final matches = _allBookings.where((booking) {
      final name = (booking['internName'] ?? booking['name'] ?? '')
          .toLowerCase();
      final traineeId = (booking['traineeId'] ?? '').toLowerCase();
      return name.contains(_searchText.toLowerCase()) ||
          traineeId.contains(_searchText.toLowerCase());
    }).toList();
    if (matches.isEmpty) return null;
    return matches.first['internName'] ?? matches.first['name'];
  }

  int get _searchMatchCount {
    if (_searchMatchName == null) return 0;
    return _allBookings
        .where((booking) {
          final name = (booking['internName'] ?? booking['name'] ?? '')
              .toLowerCase();
          return name.contains(_searchMatchName!.toLowerCase());
        })
        .toList()
        .length;
  }

  String _formatDate(DateTime d) {
    return DateFormat('MMM d, yyyy').format(d);
  }

  String _formatDateTime(DateTime d) {
    return DateFormat('MMM d, yyyy, h:mm a').format(d);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchText = '';
      _historyMode = false;
      _historyName = null;
    });
    _loadBookings();
  }

  Future<void> _exportCsv({bool isHistory = false}) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final bookings = isHistory ? _historyBookings : _todayBookings;
      if (bookings.isEmpty) {
        _showSnackbar('No data to export', isError: false);
        return;
      }

      final csvContent = _generateCSV(bookings);

      final directory = await getApplicationDocumentsDirectory();
      final fileName = isHistory
          ? 'booking_history_${_historyName ?? 'export'}.csv'
          : 'seat_bookings_${_formatDate(_filterDate)}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvContent);

      _showSnackbar('File saved to: $filePath', isError: false);
    } catch (e) {
      _showSnackbar('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _generateCSV(List<Map<String, dynamic>> bookings) {
    final buffer = StringBuffer();

    buffer.writeln('Seat Number,Trainee ID,Name,Booking Date,Booked At,Status');

    for (final booking in bookings) {
      final seatNumber = booking['seatNumber'] ?? '';
      final traineeId = booking['traineeId'] ?? '';
      final name = booking['internName'] ?? booking['name'] ?? '';
      final bookingDate =
          booking['bookingDate']?.toString().split(' ')[0] ?? '';
      final bookedAt = booking['bookedAt']?.toString() ?? '';
      final status = booking['status'] ?? '';

      buffer.writeln(
        '$seatNumber,$traineeId,"$name",$bookingDate,$bookedAt,$status',
      );
    }

    return buffer.toString();
  }

  void _viewHistory() {
    final name = _searchMatchName;
    if (name == null) return;
    _searchBookingHistory(name);
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      await _loadBookings();
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 64,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seat Booking Monitor',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'View and monitor intern seat bookings',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.cardPinkTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.chair_rounded,
                color: AppColors.iconPink,
                size: 20,
              ),
              onPressed: _refreshBookings,
              tooltip: 'Refresh',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchCard(),
                  const SizedBox(height: 12),
                  _buildStatsRow(),
                  const SizedBox(height: 12),
                  if (!_historyMode) _buildFilterRow(),
                  if (!_historyMode) const SizedBox(height: 12),
                  if (_historyMode) _buildHistoryExportRow(),
                  if (_historyMode) const SizedBox(height: 12),
                  _buildBookingsTable(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchCard() {
    final matchName = _searchMatchName;
    final bool hasText = _searchText.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Intern',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Find by Trainee ID or Name',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchText = v),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search by Trainee ID or Name...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: hasText ? AppColors.primary : AppColors.textHint,
              ),
              suffixIcon: hasText
                  ? GestureDetector(
                      onTap: _clearSearch,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF2F7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFDDE3ED),
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: matchName != null ? _viewHistory : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: matchName != null
                      ? AppColors.primary
                      : const Color(0xFFF0F4F9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: matchName != null
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 17,
                      color: matchName != null
                          ? Colors.white
                          : AppColors.textHint,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View History',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: matchName != null
                            ? Colors.white
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (matchName != null && !_historyMode) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found $_searchMatchCount booking${_searchMatchCount != 1 ? "s" : ""} for $matchName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.success.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Locked Seats',
            value: '$_lockedSeats',
            icon: Icons.lock_rounded,
            iconColor: const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Occupied Seats',
            value: '$_occupiedSeats',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Available Seats',
            value: '$_availableSeats',
            icon: Icons.chair_rounded,
            iconColor: AppColors.iconGreen,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 26, color: iconColor),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Filter by Date:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _pickFilterDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(_filterDate),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildExportButton(
            label: 'Export to CSV',
            count: _todayBookings.length,
            onTap: () => _exportCsv(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryExportRow() {
    return _buildExportButton(
      label: 'Export History to CSV',
      count: _historyBookings.length,
      onTap: () => _exportCsv(isHistory: true),
    );
  }

  Widget _buildExportButton({
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _isExporting ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _isExporting
                ? AppColors.primary.withValues(alpha: 0.7)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isExporting) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Exporting CSV...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.download_rounded,
                  size: 17,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsTable() {
    final bookings = _displayBookings;
    final tableTitle = _historyMode
        ? 'Booking History - ${_historyName ?? ""}'
        : 'Seat Bookings - ${_formatDate(_filterDate)}';
    final footerText = _historyMode
        ? 'Showing ${bookings.length} booking${bookings.length != 1 ? "s" : ""} for ${_historyName ?? ""}'
        : 'Showing ${bookings.length} booking${bookings.length != 1 ? "s" : ""} for ${_formatDate(_filterDate)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              tableTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: _HeaderLabel('SEAT', center: true),
                        ),
                        SizedBox(
                          width: 72,
                          child: _HeaderLabel('TRAINEE ID', center: true),
                        ),
                        SizedBox(
                          width: 170,
                          child: _HeaderLabel('NAME', center: true),
                        ),
                        SizedBox(
                          width: 105,
                          child: _HeaderLabel('BOOKING DATE', center: true),
                        ),
                        SizedBox(
                          width: 155,
                          child: _HeaderLabel('BOOKED AT', center: true),
                        ),
                        SizedBox(
                          width: 72,
                          child: _HeaderLabel('STATUS', center: true),
                        ),
                      ],
                    ),
                  ),
                  if (bookings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No bookings found.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...bookings.map((b) => _buildRow(b)),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Center(
              child: Text(
                footerText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> booking) {
    final seatNumber = booking['seatNumber'] ?? 0;
    final traineeId = booking['traineeId'] ?? 'N/A';
    final name = booking['internName'] ?? booking['name'] ?? 'Unknown';
    final bookingDate = booking['bookingDate'] != null
        ? DateTime.parse(booking['bookingDate'].toString())
        : DateTime.now();
    final bookedAt = booking['bookedAt'] != null
        ? DateTime.parse(booking['bookedAt'].toString())
        : DateTime.now();
    final status = booking['status'] ?? 'inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 58,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$seatNumber',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              traineeId,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 105,
            child: Text(
              _formatDate(bookingDate),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 155,
            child: Text(
              _formatDateTime(bookedAt),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 72,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'active'
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: status == 'active'
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status == 'active'
                      ? AppColors.success
                      : AppColors.danger,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  final bool center;
  const _HeaderLabel(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
