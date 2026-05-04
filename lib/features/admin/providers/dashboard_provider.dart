import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/features/admin/api/admin_api.dart';

class DashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  int _totalInterns = 0;
  int _submittedInterns = 0;
  int _overdueInterns = 0;
  int _totalRecords = 0;
  List<Map<String, dynamic>> _internReports = [];
  List<Map<String, dynamic>> _filteredInterns = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  bool get isLoading => _isLoading;
  int get totalInterns => _totalInterns;
  int get submittedInterns => _submittedInterns;
  int get overdueInterns => _overdueInterns;
  int get totalRecords => _totalRecords;
  List<Map<String, dynamic>> get internReports => _internReports;
  List<Map<String, dynamic>> get filteredInterns => _filteredInterns;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final stats = await AdminApiService.fetchDashboardStats();

      _totalInterns = stats['totalInterns'] ?? 0;
      _submittedInterns = stats['submittedInterns'] ?? 0;
      _overdueInterns = stats['overdueInterns'] ?? 0;
      _totalRecords = stats['totalRecords'] ?? 0;
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateInternReports(List<Map<String, dynamic>> reports) {
    _internReports = reports;
    _filteredInterns = reports;
    notifyListeners();
  }

  void updateFilteredInterns(List<Map<String, dynamic>> filtered) {
    _filteredInterns = filtered;
    notifyListeners();
  }

  Future<void> searchInterns(String query) async {
    if (query.length < 2) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await AdminApiService.searchInterns(query);
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
