import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';
import 'package:slt_internship_attendance_portal/constants/app_colours.dart';

class InternLocationsScreen extends StatefulWidget {
  const InternLocationsScreen({super.key});

  @override
  State<InternLocationsScreen> createState() => _InternLocationsScreenState();
}

class _InternLocationsScreenState extends State<InternLocationsScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _idSearchCtrl = TextEditingController();
  final TextEditingController _listSearchCtrl = TextEditingController();

  String _selectedDistrict = 'All';
  Map<String, dynamic>? _highlightedIntern;
  Map<String, dynamic>? _popupIntern;
  String? _idSearchError;
  String _listSearch = '';

  List<Map<String, dynamic>> _allInterns = [];
  bool _isLoading = true;

  // District coordinates for centering
  final Map<String, LatLng> _districtCenters = {
    'Colombo': const LatLng(6.9271, 79.8612),
    'Gampaha': const LatLng(7.0873, 80.0144),
    'Kandy': const LatLng(7.2906, 80.6337),
    'Galle': const LatLng(6.0535, 80.2210),
    'Jaffna': const LatLng(9.6615, 80.0255),
    'Kurunegala': const LatLng(7.4818, 80.3609),
    'Anuradhapura': const LatLng(8.3114, 80.4037),
    'Matara': const LatLng(5.9549, 80.5550),
    'Ratnapura': const LatLng(6.6828, 80.3992),
    'Badulla': const LatLng(6.9934, 81.0550),
    'Trincomalee': const LatLng(8.5874, 81.2152),
    'Batticaloa': const LatLng(7.7170, 81.6924),
    'Kalutara': const LatLng(6.5854, 79.9607),
    'Hambantota': const LatLng(6.1241, 81.1185),
    'Nuwara Eliya': const LatLng(6.9497, 80.7891),
    'Kegalle': const LatLng(7.2527, 80.3456),
    'Ampara': const LatLng(7.2989, 81.6722),
    'Polonnaruwa': const LatLng(7.9403, 81.0188),
    'Puttalam': const LatLng(8.0362, 79.8283),
    'Vavuniya': const LatLng(8.7514, 80.4971),
    'Matale': const LatLng(7.4675, 80.6234),
    'Mannar': const LatLng(8.9810, 79.9044),
    'Kilinochchi': const LatLng(9.3803, 80.3999),
    'Monaragala': const LatLng(6.8728, 81.3506),
    'Mullaitivu': const LatLng(9.2677, 80.8122),
  };

  final List<String> _districts = [
    'All',
    'Ampara',
    'Anuradhapura',
    'Badulla',
    'Batticaloa',
    'Colombo',
    'Galle',
    'Gampaha',
    'Hambantota',
    'Jaffna',
    'Kalutara',
    'Kandy',
    'Kegalle',
    'Kilinochchi',
    'Kurunegala',
    'Mannar',
    'Matale',
    'Matara',
    'Monaragala',
    'Mullaitivu',
    'Nuwara Eliya',
    'Polonnaruwa',
    'Puttalam',
    'Ratnapura',
    'Trincomalee',
    'Vavuniya',
  ];

  List<Map<String, dynamic>> get _visibleInterns {
    if (_selectedDistrict == 'All') return _allInterns;
    return _allInterns
        .where((i) => i['district'] == _selectedDistrict)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredListInterns {
    final q = _listSearch.toLowerCase();
    return _visibleInterns
        .where(
          (i) =>
              (i['traineeId']?.toString().toLowerCase().contains(q) ?? false) ||
              (i['name']?.toString().toLowerCase().contains(q) ?? false) ||
              (i['address']?.toString().toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  int _countForDistrict(String district) {
    if (district == 'All') return _allInterns.length;
    return _allInterns.where((i) => i['district'] == district).length;
  }

  Future<void> _loadInternLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await AdminApiService.getInternLocations();

      final validLocations = locations.where((location) {
        return location['latitude'] != null &&
            location['longitude'] != null &&
            location['traineeId'] != null &&
            location['name'] != null;
      }).toList();

      setState(() {
        _allInterns = validLocations;
        _isLoading = false;
      });

      if (validLocations.isEmpty) {
        _showSnackbar('No intern locations found', isError: false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Failed to load intern locations: $e');
    }
  }

  void _handleIdSearch() {
    final query = _idSearchCtrl.text.trim().toUpperCase();
    if (query.isEmpty) return;

    final found = _allInterns.firstWhere(
      (i) => (i['traineeId'] ?? '').toString().toUpperCase() == query,
      orElse: () => {},
    );

    setState(() {
      if (found.isEmpty) {
        _idSearchError = 'No intern found with ID "$query"';
        _highlightedIntern = null;
      } else {
        _idSearchError = null;
        _highlightedIntern = found;
        _selectedDistrict = found['district'] ?? 'All';
        final lat = found['latitude'] ?? 7.8731;
        final lng = found['longitude'] ?? 80.7718;
        Future.delayed(
          const Duration(milliseconds: 200),
          () => _mapController.move(LatLng(lat, lng), 13),
        );
      }
    });
  }

  void _clearIdSearch() {
    _idSearchCtrl.clear();
    setState(() {
      _highlightedIntern = null;
      _idSearchError = null;
      _popupIntern = null;
    });
  }

  void _flyToIntern(Map<String, dynamic> intern) {
    final lat = intern['latitude'] ?? 7.8731;
    final lng = intern['longitude'] ?? 80.7718;
    _mapController.move(LatLng(lat, lng), 14);
    setState(() {
      _highlightedIntern = intern;
      _popupIntern = intern;
    });
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
  void initState() {
    super.initState();
    _loadInternLocations();
  }

  @override
  void dispose() {
    _idSearchCtrl.dispose();
    _listSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Intern Locations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Live overview of all registered intern locations',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 18,
              color: AppColors.iconBlue,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    _buildFilterCard(),
                    if (_idSearchError != null || _highlightedIntern != null)
                      _buildSearchBanner(),
                    const SizedBox(height: 16),
                    _buildMap(),
                    if (_selectedDistrict != 'All') ...[
                      const SizedBox(height: 16),
                      _buildDistrictList(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedDistrict == 'All'
                    ? 'Total Interns with Location'
                    : 'Interns in $_selectedDistrict',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${_visibleInterns.length}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _filterLabel(Icons.filter_alt_rounded, 'FILTER BY DISTRICT'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDistrict,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: _districts.map((d) {
                  final c = _countForDistrict(d);
                  return DropdownMenuItem(
                    value: d,
                    child: Text(
                      d == 'All' ? 'All Districts' : (c > 0 ? '$d ($c)' : d),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedDistrict = v;
                    _highlightedIntern = null;
                    _popupIntern = null;
                  });
                  if (v == 'All') {
                    _mapController.move(const LatLng(7.8731, 80.7718), 8);
                  } else if (_districtCenters.containsKey(v)) {
                    _mapController.move(_districtCenters[v]!, 11);
                  }
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.divider, height: 1),
          ),
          _filterLabel(Icons.search_rounded, 'FIND INTERN BY ID'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _idSearchCtrl,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Intern ID',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      suffixIcon: _idSearchCtrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: _clearIdSearch,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _handleIdSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _handleIdSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _filterLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBanner() {
    if (_idSearchError != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _idSearchError!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_highlightedIntern != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 16,
              color: Color(0xFFD97706),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF92400E),
                  ),
                  children: [
                    const TextSpan(text: 'Showing location for '),
                    TextSpan(
                      text: _highlightedIntern!['name'] ?? 'Intern',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          ' — ${_highlightedIntern!['district'] ?? 'Unknown'}',
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: _clearIdSearch,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFFD97706),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: const LatLng(7.8731, 80.7718),
                zoom: 7,
                minZoom: 5,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.slt.sap',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: _visibleInterns.map((intern) {
                    final isHL =
                        _highlightedIntern?['traineeId'] == intern['traineeId'];
                    final lat = intern['latitude'] ?? 7.8731;
                    final lng = intern['longitude'] ?? 80.7718;
                    return Marker(
                      width: isHL ? 38 : 30,
                      height: isHL ? 38 : 30,
                      point: LatLng(lat, lng),
                      builder: (ctx) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _highlightedIntern = intern;
                            _popupIntern = intern;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isHL
                                ? const Color(0xFFF97316)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isHL
                                            ? const Color(0xFFF97316)
                                            : AppColors.primary)
                                        .withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (_popupIntern != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildMapPopup(_popupIntern!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPopup(Map<String, dynamic> intern) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    intern['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _popupIntern = null),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ID: ${intern['traineeId'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'District: ${intern['district'] ?? 'Unknown'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              intern['address'] ?? 'Address not available',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interns in $_selectedDistrict',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_filteredListInterns.length} of ${_visibleInterns.length} interns shown',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _listSearchCtrl,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search name, ID or address…',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _listSearch.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _listSearchCtrl.clear();
                            setState(() => _listSearch = '');
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onChanged: (v) => setState(() => _listSearch = v),
              ),
            ),
          ),
          if (_filteredListInterns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No interns match your search.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredListInterns.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, idx) {
                final intern = _filteredListInterns[idx];
                final isHL =
                    _highlightedIntern?['traineeId'] == intern['traineeId'];
                return Container(
                  color: isHL ? const Color(0xFFFFFBEB) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              intern['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'ID: ${intern['traineeId'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          intern['address'] ?? 'Address not available',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _flyToIntern(intern),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
