import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';

class LogbookRecordsScreen extends StatefulWidget {
  final String internName;
  final String internId;

  const LogbookRecordsScreen({
    super.key,
    required this.internName,
    required this.internId,
  });

  @override
  State<LogbookRecordsScreen> createState() => _LogbookRecordsScreenState();
}

class _LogbookRecordsScreenState extends State<LogbookRecordsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _timeFilter = 'All Time';
  String _sortOrder = 'Newest First';
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  static const List<String> _timeFilters = [
    'All Time',
    'Last Week',
    'Last Month',
    'Last 3 Months',
  ];
  static const List<String> _sortOptions = ['Newest First', 'Oldest First'];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allRecords = await AdminApiService.fetchAllDailyRecords();

      // Filter records for this specific intern
      final internRecords = allRecords.where((record) {
        final recordInternId = record['traineeId']?.toString();
        return recordInternId == widget.internId;
      }).toList();

      setState(() {
        _allRecords = internRecords;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allRecords);

    // Apply search filter
    final searchQuery = _searchCtrl.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        final task = record['task']?.toString().toLowerCase() ?? '';
        final progress = record['progress']?.toString().toLowerCase() ?? '';
        final blockers = record['blockers']?.toString().toLowerCase() ?? '';
        final stack = record['stack']?.toString().toLowerCase() ?? '';
        return task.contains(searchQuery) ||
            progress.contains(searchQuery) ||
            blockers.contains(searchQuery) ||
            stack.contains(searchQuery);
      }).toList();
    }

    // Apply time filter
    final now = DateTime.now();
    filtered = filtered.where((record) {
      final recordDate = DateTime.tryParse(record['date']?.toString() ?? '');
      if (recordDate == null) return false;

      switch (_timeFilter) {
        case 'Last Week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return recordDate.isAfter(weekAgo);
        case 'Last Month':
          final monthAgo = DateTime(now.year, now.month - 1, now.day);
          return recordDate.isAfter(monthAgo);
        case 'Last 3 Months':
          final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
          return recordDate.isAfter(threeMonthsAgo);
        default:
          return true;
      }
    }).toList();

    // Apply sorting
    if (_sortOrder == 'Newest First') {
      filtered.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final bDate =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
    } else {
      filtered.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final bDate =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return aDate.compareTo(bDate);
      });
    }

    setState(() {
      _filteredRecords = filtered;
    });
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _onTimeFilterChanged(String? newFilter) {
    if (newFilter != null) {
      setState(() {
        _timeFilter = newFilter;
      });
      _applyFilters();
    }
  }

  void _onSortOrderChanged(String? newOrder) {
    if (newOrder != null) {
      setState(() {
        _sortOrder = newOrder;
      });
      _applyFilters();
    }
  }



  Color _tagBg(String tag) {
    switch (tag) {
      case 'WFH':
        return const Color(0xFFECFDF5);
      case 'Office':
        return const Color(0xFFEFF6FF);
      default:
        return AppColors.border;
    }
  }

  Color _tagFg(String tag) {
    switch (tag) {
      case 'WFH':
        return AppColors.iconGreen;
      case 'Office':
        return AppColors.iconBlue;
      default:
        return AppColors.textSecondary;
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
              'Logbook Records',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${widget.internName} - ${widget.internId}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Total Records',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
                Text(
                  '${_allRecords.length}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.1,
                  ),
                ),
              ],
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => _onSearchChanged(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Search in tasks, progress, and blockers...',
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
                            child: _StyledDropdown(
                              value: _timeFilter,
                              icon: Icons.filter_alt_rounded,
                              iconColor: AppColors.iconBlue,
                              bgColor: const Color(0xFFEFF6FF),
                              options: _timeFilters,
                              onChanged: _onTimeFilterChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StyledDropdown(
                              value: _sortOrder,
                              icon: Icons.swap_vert_rounded,
                              iconColor: AppColors.textSecondary,
                              bgColor: const Color(0xFFF8FAFC),
                              options: _sortOptions,
                              onChanged: _onSortOrderChanged,
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
                  child: Row(
                    children: [
                      const Text('📘 ', style: TextStyle(fontSize: 13)),
                      Text(
                        'Showing ${_filteredRecords.length} of ${_allRecords.length} records',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.border),
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No logbook records found',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredRecords.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _EntryCard(
                            entry: _filteredRecords[index],
                            tagBg: _tagBg,
                            tagFg: _tagFg,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
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
          onChanged: onChanged,
          items: options
              .map(
                (opt) => DropdownMenuItem<String>(
                  value: opt,
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          opt,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _EntryCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final Color Function(String) tagBg;
  final Color Function(String) tagFg;

  const _EntryCard({
    required this.entry,
    required this.tagBg,
    required this.tagFg,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _expanded = false;

  String _formatDateLabel(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  String _formatSubmittedDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final dateLabel = _formatDateLabel(e['date']?.toString() ?? '');
    final submittedDate = _formatSubmittedDate(
      e['createdAt']?.toString() ?? '',
    );
    final status = e['status']?.toString().toUpperCase() ?? 'N/A';
    final tags = status != 'N/A' ? [status] : <String>[];

    final tasksCompleted = e['task']?.toString() ?? '';
    final challengesFaced = e['blockers']?.toString() ?? '';
    final plansForTomorrow = e['progress']?.toString() ?? '';
    final stack = e['stack']?.toString() ?? '';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.cardBlueTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Submitted: $submittedDate',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBlueTint,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Daily Record',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: widget.tagBg(tag),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: widget.tagFg(tag),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.border),
          if (_expanded) ...[
            const SizedBox(height: 10),
            if (stack.isNotEmpty)
              _Section(
                icon: Icons.code_rounded,
                iconColor: AppColors.iconPurple,
                borderColor: AppColors.iconPurple,
                title: 'Technology Stack',
                body: stack,
              ),
            if (stack.isNotEmpty) const SizedBox(height: 8),
            if (tasksCompleted.isNotEmpty)
              _Section(
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.iconBlue,
                borderColor: AppColors.iconBlue,
                title: 'Tasks Completed',
                body: tasksCompleted,
              ),
            if (tasksCompleted.isNotEmpty) const SizedBox(height: 8),
            if (challengesFaced.isNotEmpty)
              _Section(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.iconGreen,
                borderColor: AppColors.iconGreen,
                title: 'Challenges / Blockers',
                body: challengesFaced,
              ),
            if (challengesFaced.isNotEmpty) const SizedBox(height: 8),
            if (plansForTomorrow.isNotEmpty)
              _Section(
                icon: Icons.wb_sunny_rounded,
                iconColor: AppColors.iconOrange,
                borderColor: AppColors.iconOrange,
                title: 'Progress / Plans',
                body: plansForTomorrow,
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String title;
  final String body;

  const _Section({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: borderColor, width: 3)),
          color: const Color(0xFFFAFBFC),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
