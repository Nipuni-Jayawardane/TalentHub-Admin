import 'package:flutter/material.dart';
import 'logbook_records_screen.dart';
import '../api/admin_api.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class DailyRecordsScreen extends StatefulWidget {
  const DailyRecordsScreen({super.key});

  @override
  State<DailyRecordsScreen> createState() => _DailyRecordsScreenState();
}

class _DailyRecordsScreenState extends State<DailyRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _sortOrder = 'Newest first';
  bool _isExporting = false;
  bool _isLoading = true;
  String? _error;
  List<dynamic> dailyRecords = [];
  bool searchLoading = false;
  String? error;
  String searchTerm = '';
  String dateFilter = '';
  String sortBy = 'date';
  String sortOrder = 'desc';
  int currentPage = 1;
  int itemsPerPage = 10;
  int totalRecords = 0;
  bool paginationLoading = false;

  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await AdminApiService.fetchAllDailyRecords();
      setState(() {
        _allRecords = records;
        _filterRecords();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> fetchDailyRecords({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        error = null;
        paginationLoading = false;
      });
    } else {
      setState(() {
        paginationLoading = true;
      });
    }

    try {
      // Check for auth token
      final prefs = await SharedPreferences.getInstance();
      final adminToken = prefs.getString('admin_token');
      final userToken = prefs.getString('user_token');
      if (adminToken == null && userToken == null) {
        setState(() {
          error = 'Authentication required';
          _isLoading = false;
          paginationLoading = false;
        });
        if (mounted) {
          context.go('/admin-login');
        }
        return;
      }

      // Format date for API (YYYY-MM-DD)
      final formattedDate = dateFilter.isNotEmpty
          ? dateFilter
          : _selectedDate.toIso8601String().split('T').first;

      // Fetch data for the selected date with pagination
      final response = await AdminApiService.fetchPaginatedDailyRecords(
        date: formattedDate,
        page: currentPage,
        limit: itemsPerPage,
        search: searchTerm.isNotEmpty ? searchTerm : null,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      setState(() {
        dailyRecords = response['records'] ?? [];
        totalRecords = response['total'] ?? 0;
        _isLoading = false;
        paginationLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching daily records: $e');
      setState(() {
        error = 'Failed to load daily records';
        _isLoading = false;
        paginationLoading = false;
      });
      if (e.toString().contains('401') || e.toString().contains('403')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('admin_token');
        await prefs.remove('user_token');
        if (mounted) {
          context.go('/admin-login');
        }
      }
    }
  }

  void _filterRecords() {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final selectedDateStr = _selectedDate.toIso8601String().split('T').first;

    // Filter by date first
    List<Map<String, dynamic>> filtered = _allRecords.where((record) {
      final recordDate = record['date']?.toString() ?? '';
      return recordDate == selectedDateStr;
    }).toList();

    // Then filter by search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        final name = record['traineeName']?.toString().toLowerCase() ?? '';
        final id = record['traineeId']?.toString().toLowerCase() ?? '';
        return name.contains(searchQuery) || id.contains(searchQuery);
      }).toList();
    }

    // Sort records
    if (_sortOrder == 'Newest first') {
      filtered.sort((a, b) {
        final aCreated =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        final bCreated =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        return bCreated.compareTo(aCreated);
      });
    } else {
      filtered.sort((a, b) {
        final aCreated =
            DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        final bCreated =
            DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime(2000);
        return aCreated.compareTo(bCreated);
      });
    }

    setState(() {
      _filteredRecords = filtered;
    });
  }

  void _onSearchChanged() {
    _filterRecords();
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    _filterRecords();
  }

  void _onSortOrderChanged(String newOrder) {
    setState(() {
      _sortOrder = newOrder;
    });
    _filterRecords();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String _fmtDate(DateTime d) {
    const months = [
      '',
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
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  String _fmtDateInput(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day/${d.year}';
  }

  String _weekdayLabel(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(d.year, d.month, d.day);
    final diff = sel.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return days[d.weekday - 1];
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'WFH':
        return AppColors.iconBlue;
      case 'Office':
        return AppColors.iconGreen;
      default:
        return AppColors.iconOrange;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'WFH':
        return AppColors.cardBlueTint;
      case 'Office':
        return AppColors.cardGreenTint;
      default:
        return AppColors.cardYellowTint;
    }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (p != null) _onDateChanged(p);
  }

  Future<void> _exportCSV() async {
    setState(() => _isExporting = true);

    try {
      final selectedDateStr = _selectedDate.toIso8601String().split('T').first;

      final response = await AdminApiService.exportDailyRecordsToCSV(
        searchTerm: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        dateFilter: selectedDateStr,
        sortBy: 'date',
        sortOrder: _sortOrder == 'Newest first' ? 'desc' : 'asc',
      );

      await _saveFile(response, 'daily_records_$selectedDateStr.csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported: daily_records_$selectedDateStr.csv'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _saveFile(http.Response response, String filename) async {
    try {
      if (response.bodyBytes.isEmpty) {
        throw Exception('File is empty');
      }

      final bytes = response.bodyBytes;
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Records',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Browse submissions day by day',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.cardBlueTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: AppColors.iconBlue,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRecords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _NavBtn(
                            label: '< Prev Day',
                            onTap: () => _onDateChanged(
                              _selectedDate.subtract(const Duration(days: 1)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 13,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _fmtDateInput(_selectedDate),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_weekdayLabel(_selectedDate)} — ${_fmtDate(_selectedDate)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!_isToday) ...[
                            const SizedBox(width: 8),
                            _NavBtn(
                              label: 'Next Day >',
                              onTap: () => _onDateChanged(
                                _selectedDate.add(const Duration(days: 1)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!_isToday) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _onDateChanged(DateTime.now()),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.today_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Jump to Today',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.border),

                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fact_check_rounded,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Submissions on this date',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_filteredRecords.length} records found',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => _onSearchChanged(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by name or Trainee ID...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.textHint,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortOrder,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: AppColors.textHint,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  onChanged: (v) =>
                                      _onSortOrderChanged(v ?? _sortOrder),
                                  items: ['Newest first', 'Oldest first']
                                      .map(
                                        (opt) => DropdownMenuItem<String>(
                                          value: opt,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.swap_vert_rounded,
                                                size: 15,
                                                color: AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                opt,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isExporting ? null : _exportCSV,
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isExporting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Export CSV',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    bottom: 10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filteredRecords.length} records · ${_selectedDate.toIso8601String().split('T').first}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Container(height: 1, color: AppColors.border),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Submissions — ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: _fmtDate(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_filteredRecords.length} records total',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_filteredRecords.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'No records found for this date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth:
                                        MediaQuery.of(context).size.width - 28,
                                  ),
                                  child: IntrinsicWidth(
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF8FAFC),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: AppColors.border,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _Hdr(label: '#', width: 32),
                                              _Hdr(label: 'INTERN', width: 190),
                                              _Hdr(label: 'STATUS', width: 80),
                                              _Hdr(
                                                label: 'SUBMITTED AT',
                                                width: 106,
                                              ),
                                              _Hdr(
                                                label: 'ACTIONS',
                                                width: 120,
                                              ),
                                            ],
                                          ),
                                        ),
                                        ..._filteredRecords.asMap().entries.map((
                                          entry,
                                        ) {
                                          final i = entry.key;
                                          final rec = entry.value;
                                          final isLast =
                                              i == _filteredRecords.length - 1;
                                          final submittedAt =
                                              rec['createdAt'] != null
                                              ? DateFormat('hh:mm:ss a').format(
                                                  DateTime.parse(
                                                    rec['createdAt'],
                                                  ),
                                                )
                                              : 'N/A';
                                          final status =
                                              rec['status']
                                                  ?.toString()
                                                  .toUpperCase() ??
                                              'N/A';

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: i.isEven
                                                  ? Colors.white
                                                  : const Color(0xFFFAFBFC),
                                              borderRadius: isLast
                                                  ? const BorderRadius.vertical(
                                                      bottom: Radius.circular(
                                                        14,
                                                      ),
                                                    )
                                                  : BorderRadius.zero,
                                              border: isLast
                                                  ? null
                                                  : const Border(
                                                      bottom: BorderSide(
                                                        color: Color(
                                                          0xFFF1F5F9,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 32,
                                                  child: Text(
                                                    '${i + 1}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 190,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 30,
                                                        height: 30,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: AppColors
                                                                  .primary
                                                                  .withValues(alpha: 
                                                                    0.10,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons
                                                                .person_rounded,
                                                            size: 17,
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 7),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              rec['traineeName'] ??
                                                                  'Unknown',
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppColors
                                                                    .textPrimary,
                                                              ),
                                                              maxLines: 2,
                                                              softWrap: true,
                                                              overflow:
                                                                  TextOverflow
                                                                      .visible,
                                                            ),
                                                            Text(
                                                              'ID: ${rec['traineeId'] ?? 'N/A'}',
                                                              style: const TextStyle(
                                                                fontSize: 10.5,
                                                                color: AppColors
                                                                    .textSecondary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 80,
                                                  child: Center(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _statusBg(
                                                          status,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: _statusColor(
                                                            status,
                                                          ),
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 106,
                                                  child: Text(
                                                    submittedAt,
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 120,
                                                  child: Center(
                                                    child: GestureDetector(
                                                      onTap: () => Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => LogbookRecordsScreen(
                                                            internName:
                                                                rec['traineeName'] ??
                                                                'Unknown',
                                                            internId:
                                                                rec['traineeId']
                                                                    ?.toString() ??
                                                                '',
                                                          ),
                                                        ),
                                                      ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                                colors: [
                                                                  Color(
                                                                    0xFF2563EB,
                                                                  ),
                                                                  Color(
                                                                    0xFF1D4ED8,
                                                                  ),
                                                                ],
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          boxShadow: const [
                                                            BoxShadow(
                                                              color: Color(
                                                                0x302563EB,
                                                              ),
                                                              blurRadius: 6,
                                                              offset: Offset(
                                                                0,
                                                                2,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .visibility_rounded,
                                                              size: 13,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'View',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    ),
  );
}

class _Hdr extends StatelessWidget {
  final String label;
  final double width;
  const _Hdr({required this.label, required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
