import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slt_internship_attendance_portal/config/config.dart';

class AdminApiService {
  static const String baseUrl = Config.backendBaseUrl;

  // Helper to get auth token
  static Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    // First try admin token
    final adminToken = prefs.getString('admin_token');
    if (adminToken != null) return adminToken;

    // Fallback to regular user token
    final userToken = prefs.getString('user_token');
    return userToken;
  }

  // Create headers with authorization
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Create headers for file downloads
  static Future<Map<String, String>> _getFileHeaders() async {
    final token = await _getAuthToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  // ==================== DASHBOARD STATS ====================

  // Get TalentHub dashboard statistics
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard/stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch dashboard stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching dashboard stats: $e');
    }
  }

  static Future<Map<String, String>> getHeaders() async {
    return await _getHeaders();
  }

  // Get TalentHub intern report for dashboard
  static Future<List<Map<String, dynamic>>> fetchInternReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/report/interns'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['interns'] is List) {
          return (data['interns'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to fetch intern report: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching intern report: $e');
    }
  }

  // ==================== NOTIFICATIONS ====================

  // Send notifications to overdue interns
  static Future<void> sendOverdueNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final url = '${Config.backendBaseUrl}/admin/notifications/overdue';
      final headers = await _getHeaders();

      // The API might expect a specific format
      final body = jsonEncode({"notifications": notifications});

      debugPrint('[API] Sending to: $url');
      debugPrint('[API] Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint('[API] Response status: ${response.statusCode}');
      debugPrint('[API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return;
        } else {
          throw Exception(
            responseData['message'] ?? 'Failed to send notifications',
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception('Failed to send notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending notifications: $e');
      rethrow;
    }
  }

  // ==================== INTERN MANAGEMENT ====================

  // Get individual intern details
  static Future<Map<String, dynamic>> fetchInternDetails(
    String internId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/intern/$internId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to fetch intern details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching intern details: $e');
    }
  }

  // Search interns by query
  static Future<List<Map<String, dynamic>>> searchInterns(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/search/interns?q=${Uri.encodeComponent(query)}',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['interns'] is List) {
          return (data['interns'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to search interns: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error searching interns: $e');
    }
  }

  // ==================== DAILY RECORDS ====================

  // Get paginated daily records with filters
  static Future<Map<String, dynamic>> fetchPaginatedDailyRecords({
    required String date,
    int page = 1,
    int limit = 100,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      String url =
          '$baseUrl/admin/daily-records?page=$page&limit=$limit&date=$date';

      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }
      if (sortBy != null) {
        url += '&sortBy=$sortBy&sortOrder=${sortOrder ?? 'desc'}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch daily records: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      List<Map<String, dynamic>> records = [];

      if (data.containsKey('records') && data['records'] is List) {
        final List<dynamic> recordsList = data['records'];
        for (var record in recordsList) {
          if (record is Map) {
            records.add(Map<String, dynamic>.from(record));
          }
        }
      }

      // Get pagination info
      final pagination = data['pagination'] as Map<String, dynamic>?;
      final int total = pagination?['total'] ?? records.length;

      return {'records': records, 'total': total};
    } catch (e) {
      debugPrint('Error fetching daily records by date: $e');
      throw Exception('Error fetching daily records by date: $e');
    }
  }

  // Get all daily records
  // Get all daily records with full pagination handling
  static Future<List<Map<String, dynamic>>> fetchAllDailyRecords() async {
    try {
      // Check cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('daily_records_cache');
      final cachedTimestamp = prefs.getInt('daily_records_timestamp') ?? 0;
      final cacheDuration = Duration(minutes: 5).inMilliseconds;

      if (cachedData != null &&
          DateTime.now().millisecondsSinceEpoch - cachedTimestamp <
              cacheDuration) {
        final decoded = jsonDecode(cachedData);
        if (decoded is List) {
          List<Map<String, dynamic>> result = [];
          for (var item in decoded) {
            if (item is Map) {
              result.add(Map<String, dynamic>.from(item));
            }
          }
          return result;
        }
        return [];
      }

      // First, get the first page to understand pagination
      final firstResponse = await http.get(
        Uri.parse('$baseUrl/admin/daily-records?page=1&limit=50'),
        headers: await _getHeaders(),
      );

      if (firstResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch daily records: ${firstResponse.statusCode}',
        );
      }

      final Map<String, dynamic> firstData = jsonDecode(firstResponse.body);
      List<Map<String, dynamic>> allRecords = [];

      // Extract records from first page
      if (firstData.containsKey('records') && firstData['records'] is List) {
        final List<dynamic> recordsList = firstData['records'];
        for (var record in recordsList) {
          if (record is Map) {
            allRecords.add(Map<String, dynamic>.from(record));
          }
        }

        // Get pagination info
        final pagination = firstData['pagination'] as Map<String, dynamic>;
        final int totalPages = pagination['totalPages'] ?? 1;
        final int limit = pagination['limit'] ?? 50;

        // Fetch remaining pages
        for (int page = 2; page <= totalPages; page++) {
          final pageResponse = await http.get(
            Uri.parse('$baseUrl/admin/daily-records?page=$page&limit=$limit'),
            headers: await _getHeaders(),
          );

          if (pageResponse.statusCode == 200) {
            final Map<String, dynamic> pageData = jsonDecode(pageResponse.body);
            if (pageData.containsKey('records') &&
                pageData['records'] is List) {
              final List<dynamic> pageRecordsList = pageData['records'];
              for (var record in pageRecordsList) {
                if (record is Map) {
                  allRecords.add(Map<String, dynamic>.from(record));
                }
              }
            }
          }
        }
      }

      debugPrint('Fetched ${allRecords.length} total daily records');

      // Transform records to extract intern details properly
      final List<Map<String, dynamic>> transformedRecords = [];

      for (var record in allRecords) {
        dynamic internData = record['internId'];
        Map<String, dynamic> internMap = {};

        if (internData is Map) {
          internMap = Map<String, dynamic>.from(internData);
        }

        final Map<String, dynamic> transformed = {
          '_id': record['_id'],
          'date': record['date'],
          'traineeName':
              internMap['Trainee_Name'] ?? record['traineeName'] ?? 'Unknown',
          'traineeId':
              internMap['Trainee_ID']?.toString() ??
              record['traineeId']?.toString() ??
              'N/A',
          'internEmail': internMap['Trainee_Email'] ?? '',
          'internId': internMap['_id'] ?? record['internId'],
          'stack': record['stack'] ?? '',
          'task': record['task'] ?? '',
          'progress': record['progress'] ?? '',
          'blockers': record['blockers'] ?? '',
          'status': record['status'] ?? '',
          'attendance': record['attendance'] ?? '',
          'attendanceTime': record['attendanceTime'],
          'meetingAttendance': record['meetingAttendance'] ?? [],
          'createdAt': record['createdAt'],
          'updatedAt': record['updatedAt'],
        };
        transformedRecords.add(transformed);
      }

      // Cache the transformed data
      await prefs.setString(
        'daily_records_cache',
        jsonEncode(transformedRecords),
      );
      await prefs.setInt(
        'daily_records_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      return transformedRecords;
    } catch (e) {
      debugPrint('Error fetching daily records: $e');
      throw Exception('Error fetching daily records: $e');
    }
  }

  // Get all daily records (for export)
  static Future<List<Map<String, dynamic>>> fetchAllAdminDailyRecords() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/daily-records'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data.containsKey('records')) {
          return List<Map<String, dynamic>>.from(data['records']);
        } else if (data is Map && data.containsKey('data')) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          return [];
        }
      } else {
        throw Exception(
          'Failed to fetch all daily records: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching all daily records: $e');
    }
  }

  // Export daily records to CSV
  static Future<http.Response> exportDailyRecordsToCSV({
    String? searchTerm,
    String? dateFilter,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      // Get all records
      final allRecords = await fetchAllDailyRecords();

      // Apply filters
      List<Map<String, dynamic>> filteredRecords = List.from(allRecords);

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        filteredRecords = filteredRecords.where((record) {
          return (record['traineeName']?.toString().toLowerCase().contains(
                    searchLower,
                  ) ??
                  false) ||
              (record['traineeId']?.toString().toLowerCase().contains(
                    searchLower,
                  ) ??
                  false);
        }).toList();
      }

      if (dateFilter != null && dateFilter.isNotEmpty) {
        filteredRecords = filteredRecords.where((record) {
          final recordDate = record['date']?.toString() ?? '';
          return recordDate == dateFilter;
        }).toList();
      }

      // Sort
      if (sortBy != null) {
        filteredRecords.sort((a, b) {
          dynamic aValue, bValue;
          switch (sortBy) {
            case 'date':
              aValue = a['date']?.toString() ?? '';
              bValue = b['date']?.toString() ?? '';
              break;
            case 'name':
              aValue = a['traineeName']?.toString().toLowerCase() ?? '';
              bValue = b['traineeName']?.toString().toLowerCase() ?? '';
              break;
            case 'traineeId':
              aValue = a['traineeId']?.toString() ?? '';
              bValue = b['traineeId']?.toString() ?? '';
              break;
            default:
              return 0;
          }

          final comparison = aValue.toString().compareTo(bValue.toString());
          return sortOrder == 'desc' ? -comparison : comparison;
        });
      }

      // Generate CSV
      final csvContent = _generateDailyRecordsCSV(filteredRecords);

      return http.Response.bytes(
        utf8.encode(csvContent),
        200,
        headers: {
          'Content-Type': 'text/csv',
          'Content-Disposition':
              'attachment; filename=daily_records_${DateTime.now().toIso8601String().split('T').first}.csv',
        },
      );
    } catch (e) {
      throw Exception('Error exporting daily records: $e');
    }
  }

  static String _generateDailyRecordsCSV(List<Map<String, dynamic>> records) {
    final buffer = StringBuffer();

    buffer.write('\uFEFF'); // UTF-8 BOM for Excel compatibility
    buffer.writeln(
      'Date,Trainee Name,Trainee ID,Stack,Task,Progress,Blockers,Status,Attendance,Created At',
    );

    for (final record in records) {
      final date = _escapeCSV(record['date']?.toString() ?? '');
      final traineeName = _escapeCSV(record['traineeName']?.toString() ?? '');
      final traineeId = _escapeCSV(record['traineeId']?.toString() ?? '');
      final stack = _escapeCSV(record['stack']?.toString() ?? '');
      final task = _escapeCSV(record['task']?.toString() ?? '');
      final progress = _escapeCSV(record['progress']?.toString() ?? '');
      final blockers = _escapeCSV(record['blockers']?.toString() ?? '');
      final status = _escapeCSV(record['status']?.toString() ?? '');
      final attendance = _escapeCSV(record['attendance']?.toString() ?? '');
      final createdAt = _escapeCSV(record['createdAt']?.toString() ?? '');

      buffer.writeln(
        '$date,$traineeName,$traineeId,$stack,$task,$progress,$blockers,$status,$attendance,$createdAt',
      );
    }

    return buffer.toString();
  }

  static String _escapeCSV(String value) {
    String cleaned = value.replaceAll('"', '""');
    if (cleaned.contains(',') ||
        cleaned.contains('\n') ||
        cleaned.contains('"')) {
      return '"$cleaned"';
    }
    return cleaned;
  }

  // Get previous day submissions
  static Future<List<Map<String, dynamic>>>
  fetchPreviousDaySubmissions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/previous-day-submissions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to fetch previous day submissions: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching previous day submissions: $e');
    }
  }

  // ==================== EXPORTS ====================

  // Download on-leave interns as Excel
  static Future<http.Response> downloadOnLeaveExcel() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/on-leave/export'),
        headers: await _getFileHeaders(),
      );

      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception(
          'Failed to download on-leave Excel: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error downloading on-leave Excel: $e');
    }
  }

  // Export weekly non-submissions as CSV/Excel
  static Future<http.Response> exportWeeklyNonSubmissions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/weekly-non-submissions/export'),
        headers: await _getFileHeaders(),
      );

      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception(
          'Failed to export weekly non-submissions: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error exporting weekly non-submissions: $e');
    }
  }

  // Export submissions list with date range
  static Future<http.Response> exportSubmissionsList({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      String url = '$baseUrl/admin/export/submissions';
      final params = <String, String>{};

      if (fromDate != null) {
        params['fromDate'] = fromDate.toIso8601String().split('T').first;
      }
      if (toDate != null) {
        params['toDate'] = toDate.toIso8601String().split('T').first;
      }

      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      debugPrint('Export Submissions URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getFileHeaders(),
      );

      debugPrint('Export Submissions Response Status: ${response.statusCode}');
      debugPrint('Export Submissions Response Headers: ${response.headers}');
      debugPrint('Export Submissions Body Length: ${response.bodyBytes.length}');

      // Print first 100 chars of response body if it's not binary
      if (response.bodyBytes.length < 1000 && response.body.isNotEmpty) {
        debugPrint(
          'Export Submissions Response Body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}',
        );
      }

      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception(
          'Failed to export submissions list: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error exporting submissions list: $e');
      throw Exception('Error exporting submissions list: $e');
    }
  }

  static Future<http.Response> exportNonSubmissionsListDirect() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard/stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('overdueList') && data['overdueList'] is List) {
          final List<dynamic> overdueList = data['overdueList'];
          final csvContent = _generateNonSubmissionsCSV(overdueList);

          return http.Response.bytes(
            utf8.encode(csvContent),
            200,
            headers: {
              'Content-Type': 'text/csv',
              'Content-Disposition': 'attachment; filename=non_submissions.csv',
            },
          );
        }
      }

      throw Exception('Failed to fetch non-submissions data');
    } catch (e) {
      throw Exception('Error exporting non-submissions: $e');
    }
  }

  static String _generateNonSubmissionsCSV(List<dynamic> overdueList) {
    final buffer = StringBuffer();

    buffer.write('\uFEFF');

    buffer.writeln(
      'Name,Trainee ID,Email,Last Submission Date,Days Overdue,Field of Specialization,Institute',
    );

    for (final intern in overdueList) {
      final name = _escapeCSV(intern['traineeName'] ?? '');
      final traineeId = _escapeCSV(intern['traineeId']?.toString() ?? '');
      final email = _escapeCSV(intern['email'] ?? '');
      final lastSubmission = _escapeCSV(
        intern['lastSubmission'] ?? intern['lastSubmissionDate'] ?? '',
      );
      final daysOverdue = _escapeCSV(
        intern['daysSinceLastSubmission']?.toString() ?? '',
      );
      final field = _escapeCSV(intern['fieldOfSpecialization'] ?? '');
      final institute = _escapeCSV(intern['institute'] ?? '');

      buffer.writeln(
        '$name,$traineeId,$email,$lastSubmission,$daysOverdue,$field,$institute',
      );
    }

    return buffer.toString();
  }

  // ==================== WEEKLY NON-SUBMISSIONS ====================

  // Get weekly non-submissions (Monday to Friday of current week)
  static Future<List<Map<String, dynamic>>> getWeeklyNonSubmissions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/weekly-non-submissions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['data'] is List) {
          return (data['data'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to fetch weekly non-submissions: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching weekly non-submissions: $e');
    }
  }

  // Get interns who haven't submitted within the last 5 working days
  static Future<List<Map<String, dynamic>>>
  getNonSubmissionsWithinWeek() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/non-submissions-within-week'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['data'] is List) {
          return (data['data'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to fetch non-submissions within week: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching non-submissions within week: $e');
    }
  }

  // ==================== SYNC TRIGGERS ====================

  // Manually trigger SLT API sync
  static Future<Map<String, dynamic>> triggerSLTSync() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/sync/slt-api'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to trigger SLT sync: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error triggering SLT sync: $e');
    }
  }

  // Manually trigger weekly non-submission check
  static Future<Map<String, dynamic>> triggerWeeklyNonSubmissionCheck() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/trigger/weekly-non-submission-check'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to trigger weekly check: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error triggering weekly check: $e');
    }
  }

  // Trigger weekly non-submission check and send Excel report
  static Future<Map<String, dynamic>>
  triggerWeeklyNonSubmissionCheckWithExcel() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/trigger/weekly-non-submission-check-excel'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to trigger weekly check with Excel: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error triggering weekly check with Excel: $e');
    }
  }

  // INTERN LOCATIONS

  // Get all intern locations
  static Future<List<Map<String, dynamic>>> getInternLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/intern-locations'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        List<Map<String, dynamic>> locations = [];

        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> dataList = responseData['data'] as List<dynamic>;

          for (var item in dataList) {
            final Map<String, dynamic> itemMap = (item is Map<dynamic, dynamic>)
                ? Map<String, dynamic>.from(item)
                : Map<String, dynamic>.from(item as Map);

            List<dynamic> coordinates =
                itemMap['coordinates'] ?? [80.7718, 7.8731];
            double longitude = (coordinates.isNotEmpty)
                ? (coordinates[0] as num).toDouble()
                : 80.7718;
            double latitude = (coordinates.length > 1)
                ? (coordinates[1] as num).toDouble()
                : 7.8731;

            locations.add({
              'traineeId': itemMap['id']?.toString() ?? 'N/A',
              'name': itemMap['name'] ?? 'Unknown',
              'address': itemMap['address'] ?? 'Address not available',
              'district': itemMap['district'] ?? 'Unknown',
              'latitude': latitude,
              'longitude': longitude,
            });
          }
        }

        debugPrint('Loaded ${locations.length} intern locations');
        return locations;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to fetch intern locations: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching intern locations: $e');
      throw Exception('Error fetching intern locations: $e');
    }
  }

  // Get intern counts grouped by district
  static Future<Map<String, dynamic>> getDistrictCounts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/district-counts'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to fetch district counts: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching district counts: $e');
    }
  }

  // Get location of a specific intern by trainee ID
  static Future<Map<String, dynamic>> getInternLocation(
    String traineeId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/intern-location/$traineeId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to fetch intern location: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching intern location: $e');
    }
  }
  // SEAT BOOKINGS

  // Get all seat bookings with optional date filter
  static Future<List<Map<String, dynamic>>> getSeatBookings({
    String? date,
  }) async {
    try {
      String url = '${Config.backendBaseUrl}/admin/seat-bookings';
      if (date != null && date.isNotEmpty) {
        url += '?date=$date';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true &&
            responseData['bookings'] != null) {
          return List<Map<String, dynamic>>.from(responseData['bookings']);
        } else if (responseData.containsKey('data') &&
            responseData['data'] is List) {
          return (responseData['data'] as List).cast<Map<String, dynamic>>();
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to fetch seat bookings: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching seat bookings: $e');
      return [];
    }
  }

  // Get seat booking statistics for a date range
  static Future<Map<String, dynamic>> getSeatBookingStats({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Config.backendBaseUrl}/admin/seat-bookings/stats?startDate=$startDate&endDate=$endDate',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['stats'] != null) {
          final statsData = responseData['stats'];

          return {
            'totalSeats': 96,
            'lockedSeats': 20,
            'occupiedSeats': statsData['occupiedSeats'] ?? 0,
            'availableSeats': statsData['availableSeats'] ?? 0,
            'totalBookings': statsData['totalBookings'] ?? 0,
          };
        }

        if (responseData.containsKey('data') && responseData['data'] is Map) {
          return responseData['data'];
        }

        return responseData;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to fetch seat booking stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching seat booking stats: $e');
      return {
        'totalSeats': 96,
        'lockedSeats': 20,
        'occupiedSeats': 0,
        'availableSeats': 0,
      };
    }
  }

  // Get booking history for a specific intern
  static Future<List<Map<String, dynamic>>> getBookingHistory(
    String search,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Config.backendBaseUrl}/admin/seat-bookings/history?search=${Uri.encodeComponent(search)}',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Handle the actual response structure
        if (responseData['success'] == true &&
            responseData['bookings'] != null) {
          return List<Map<String, dynamic>>.from(responseData['bookings']);
        } else if (responseData.containsKey('data') &&
            responseData['data'] is List) {
          return (responseData['data'] as List).cast<Map<String, dynamic>>();
        } else {
          debugPrint('Unexpected response format: ${response.body}');
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to fetch booking history: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching booking history: $e');
      return [];
    }
  }

  // Get booking details for a specific seat
  static Future<Map<String, dynamic>> getSeatBookingDetails(
    int seatNumber, {
    String? date,
  }) async {
    try {
      String url =
          '${Config.backendBaseUrl}/admin/seat-bookings/seat/$seatNumber';
      if (date != null && date.isNotEmpty) {
        url += '?date=$date';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('data') && data['data'] is Map) {
          return data['data'];
        }
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Seat not found');
      } else {
        throw Exception(
          'Failed to fetch seat booking details: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching seat booking details: $e');
      throw Exception('Error fetching seat booking details: $e');
    }
  }

  // Get today's attendance statistics
  static Future<Map<String, dynamic>> getTodayAttendanceStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/interns/attendance-stats-today'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to fetch today\'s attendance stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching today\'s attendance stats: $e');
    }
  }

  // Get overall attendance statistics
  static Future<Map<String, dynamic>> getOverallAttendanceStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/interns/attendance-stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to fetch overall attendance stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching overall attendance stats: $e');
    }
  }

  // Get weekly attendance statistics
  static Future<Map<String, dynamic>> getWeeklyAttendanceStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/interns/weekly-attendance-stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception(
          'Failed to fetch weekly attendance stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching weekly attendance stats: $e');
    }
  }
  // ==================== NON-SUBMISSIONS (DATE RANGE) ====================

  // Fetch non-submissions for a date range using existing daily-records endpoint
  static Future<List<Map<String, dynamic>>> fetchNonSubmissions({
    required String startDate,
    required String endDate,
  }) async {
    try {
      // First, get all interns from the intern report
      final internsResponse = await http.get(
        Uri.parse('$baseUrl/admin/report/interns'),
        headers: await _getHeaders(),
      );

      if (internsResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch interns: ${internsResponse.statusCode}',
        );
      }

      final internsData = jsonDecode(internsResponse.body);
      List<Map<String, dynamic>> allInterns = [];

      if (internsData is List) {
        allInterns = internsData.cast<Map<String, dynamic>>();
      } else if (internsData is Map && internsData['interns'] is List) {
        allInterns = (internsData['interns'] as List)
            .cast<Map<String, dynamic>>();
      }

      // Get all daily records
      final recordsResponse = await http.get(
        Uri.parse('$baseUrl/admin/daily-records'),
        headers: await _getHeaders(),
      );

      if (recordsResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch daily records: ${recordsResponse.statusCode}',
        );
      }

      final List<dynamic> allRecords = jsonDecode(recordsResponse.body);

      // Parse dates for filtering
      final startDateTime = DateTime.parse(startDate);
      final endDateTime = DateTime.parse(endDate);

      // Create a list to track non-submissions
      List<Map<String, dynamic>> nonSubmissions = [];

      // For each intern, check each day in the date range
      for (final intern in allInterns) {
        final internId = intern['_id'] ?? intern['id'];
        final internName = intern['name'] ?? 'Unknown';
        final internEmail = intern['email'] ?? 'Unknown';

        // Check each day in the range
        DateTime currentDate = startDateTime;
        while (currentDate.isBefore(endDateTime.add(Duration(days: 1)))) {
          final dateStr = currentDate.toIso8601String().split(
            'T',
          )[0]; // YYYY-MM-DD format

          // Check if there's a record for this intern on this date
          final hasRecord = allRecords.any((record) {
            final recordDate = record['date']?.toString().split('T')[0];
            final recordInternId =
                record['internId']?.toString() ??
                record['intern_id']?.toString();
            return recordDate == dateStr && recordInternId == internId;
          });

          // If no record found, it's a non-submission
          if (!hasRecord) {
            nonSubmissions.add({
              'internId': internId,
              'internName': internName,
              'internEmail': internEmail,
              'date': dateStr,
              'status': 'No Submission',
            });
          }

          currentDate = currentDate.add(Duration(days: 1));
        }
      }

      return nonSubmissions;
    } catch (e) {
      throw Exception('Error fetching non-submissions: $e');
    }
  }

  // OVERDUE INTERNS

  // Get overdue interns list
  static Future<List<Map<String, dynamic>>> getOverdueInterns() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.backendBaseUrl}/admin/dashboard/stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('overdueList') && data['overdueList'] is List) {
          final List<dynamic> overdueList = data['overdueList'];

          return overdueList.map((intern) {
            return {
              'name': intern['traineeName'] ?? 'Unknown',
              'traineeId': intern['traineeId'] ?? 'N/A',
              'email': intern['email'] ?? 'No email',
              '_id': intern['_id'],
              'lastSubmissionDate':
                  intern['lastSubmissionDate'] ?? intern['lastSubmission'],
              'overdueDays':
                  intern['daysSinceLastSubmission'] ??
                  intern['overdueDays'] ??
                  1,
              'fieldOfSpecialization': intern['fieldOfSpecialization'] ?? '',
              'institute': intern['institute'] ?? '',
              'status': intern['status'] ?? '',
            };
          }).toList();
        }

        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to fetch dashboard stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching dashboard stats: $e');
    }
  }

  // ANNOUNCEMENTS

  // Get all announcements
  static Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/announcements'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['data'] is List) {
          return (data['data'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
          'Failed to fetch announcements: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching announcements: $e');
    }
  }

  // Create announcement
  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    String? priority,
  }) async {
    try {
      final body = jsonEncode({
        'title': title,
        'content': content,
        'priority': priority ?? 'normal',
      });

      final response = await http.post(
        Uri.parse('$baseUrl/admin/announcements'),
        headers: await _getHeaders(),
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to create announcement: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error creating announcement: $e');
    }
  }

  // Update announcement
  static Future<Map<String, dynamic>> updateAnnouncement(
    String announcementId, {
    String? title,
    String? content,
    String? priority,
  }) async {
    try {
      final body = jsonEncode({
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (priority != null) 'priority': priority,
      });

      final response = await http.put(
        Uri.parse('$baseUrl/admin/announcements/$announcementId'),
        headers: await _getHeaders(),
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to update announcement: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error updating announcement: $e');
    }
  }

  // Delete announcement
  static Future<void> deleteAnnouncement(String announcementId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/announcements/$announcementId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete announcement: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error deleting announcement: $e');
    }
  }

  // SHORT LEAVE REQUESTS

  // Get all short leave requests
  static Future<List<Map<String, dynamic>>> getShortLeaveRequests() async {
    try {
      List<Map<String, dynamic>> allRequests = [];
      int currentPage = 1;
      int totalPages = 1;

      do {
        final response = await http.get(
          Uri.parse('$baseUrl/leave-requests/all?page=$currentPage&limit=100'),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);

          if (responseData.containsKey('pagination')) {
            final pagination =
                responseData['pagination'] as Map<String, dynamic>;
            totalPages = pagination['totalPages'] ?? 1;
          }

          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            final List<dynamic> dataList =
                responseData['data'] as List<dynamic>;

            for (var item in dataList) {
              final Map<String, dynamic> itemMap =
                  (item is Map<dynamic, dynamic>)
                  ? Map<String, dynamic>.from(item)
                  : Map<String, dynamic>.from(item as Map);

              final Map<String, dynamic> transformedRequest = {
                '_id': itemMap['_id'],
                'id': itemMap['_id'],
                'status': itemMap['status'] ?? 'Pending',
                'internName': itemMap['internName'] ?? 'Unknown',
                'name': itemMap['internName'] ?? 'Unknown',
                'internId': itemMap['internTraineeId']?.toString() ?? 'N/A',
                'traineeId': itemMap['internTraineeId']?.toString() ?? 'N/A',
                'department': 'General',
                'reason':
                    itemMap['reason'] ?? itemMap['purpose'] ?? 'Not specified',
                'purpose': itemMap['purpose'],
                'leaveTime': itemMap['leaveTime'],
                'timeFrom': _extractStartTime(itemMap['leaveTime']?.toString()),
                'timeTo': _extractEndTime(itemMap['leaveTime']?.toString()),
                'date': itemMap['leaveDate'],
                'leaveDate': itemMap['leaveDate'],
                'submittedAt': itemMap['submittedAt'],
                'createdAt': itemMap['createdAt'],
                'proofDocument': itemMap['proofDocument'],
                'nationalId': itemMap['nationalId'],
                'adminResponse': itemMap['adminResponse'],
                'reviewedBy': itemMap['reviewedBy'],
                'reviewedAt': itemMap['reviewedAt'],
                'passUsed': itemMap['passUsed'] ?? false,
                'passUsedAt': itemMap['passUsedAt'],
              };

              allRequests.add(transformedRequest);
            }
          }

          currentPage++;
        } else if (response.statusCode == 401) {
          throw Exception('Unauthorized: Please login again');
        } else {
          throw Exception(
            'Failed to fetch short leave requests: ${response.statusCode} - ${response.body}',
          );
        }
      } while (currentPage <= totalPages);

      return allRequests;
    } catch (e) {
      throw Exception('Error fetching short leave requests: $e');
    }
  }

  // Helper methods to extract time
  static String _extractStartTime(String? leaveTime) {
    if (leaveTime == null) return '09:00';
    if (leaveTime.contains('-')) {
      return leaveTime.split('-').first.trim();
    }
    return leaveTime;
  }

  static String _extractEndTime(String? leaveTime) {
    if (leaveTime == null) return '17:00';
    if (leaveTime.contains('-')) {
      return leaveTime.split('-').last.trim();
    }
    return leaveTime;
  }

  static Future<List<Map<String, dynamic>>> getShortLeaveRequestsByDate(
    String date,
  ) async {
    try {
      final allRequests = await getShortLeaveRequests();

      return allRequests.where((request) {
        final requestDate =
            request['startDate']?.toString().split('T')[0] ??
            request['date']?.toString().split('T')[0];
        return requestDate == date;
      }).toList();
    } catch (e) {
      throw Exception('Error filtering short leave requests by date: $e');
    }
  }

  // Update short leave request status
  static Future<Map<String, dynamic>> updateShortLeaveStatus(
    String requestId,
    String status,
  ) async {
    try {
      final body = jsonEncode({'status': status.toLowerCase()});

      final response = await http.patch(
        Uri.parse('$baseUrl/leave-requests/$requestId/status'),
        headers: await _getHeaders(),
        body: body,
      );

      debugPrint('=== UPDATE STATUS RESPONSE ===');
      debugPrint('Request ID: $requestId');
      debugPrint('Status: $status');
      debugPrint('Response code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      debugPrint('==============================');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          return data;
        } else {
          return {
            'success': true,
            'message': 'Status updated successfully',
            'id': requestId,
            'status': status,
          };
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Leave request not found');
      } else {
        throw Exception(
          'Failed to update leave request status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error updating leave request status: $e');
      throw Exception('Error updating leave request status: $e');
    }
  }

  // Bulk update short leave request statuses
  static Future<Map<String, dynamic>> bulkUpdateShortLeaveStatus(
    List<String> requestIds,
    String status,
  ) async {
    try {
      final body = jsonEncode({
        'ids': requestIds,
        'status': status.toLowerCase(),
      });

      final response = await http.patch(
        Uri.parse('$baseUrl/leave-requests/bulk/status'),
        headers: await _getHeaders(),
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to bulk update leave request status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error bulk updating leave request status: $e');
      throw Exception('Error bulk updating leave request status: $e');
    }
  }

  // Get leave request statistics (Admin only)
  static Future<Map<String, dynamic>> getLeaveRequestStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests/stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          if (data.containsKey('pending') ||
              data.containsKey('approved') ||
              data.containsKey('denied')) {
            return data;
          } else if (data.containsKey('data') &&
              data['data'] is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data['data']);
          } else if (data.containsKey('stats') &&
              data['stats'] is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data['stats']);
          } else {
            return Map<String, dynamic>.from(data);
          }
        } else if (data is Map<dynamic, dynamic>) {
          final Map<String, dynamic> convertedMap = {};
          data.forEach((key, value) {
            convertedMap[key.toString()] = value;
          });
          return convertedMap;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to fetch leave request stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching leave request stats: $e');
      throw Exception('Error fetching leave request stats: $e');
    }
  }

  // Export approved leaves as PDF (Admin only)
  static Future<http.Response> exportApprovedLeavesPDF() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests/report/approved'),
        headers: await _getFileHeaders(),
      );

      if (response.statusCode == 200) {
        return response;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to export approved leaves PDF: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error exporting approved leaves PDF: $e');
      throw Exception('Error exporting approved leaves PDF: $e');
    }
  }

  // Get a single leave request by ID
  static Future<Map<String, dynamic>> getLeaveRequestById(
    String requestId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leave-requests/$requestId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is Map<dynamic, dynamic>) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final Map<String, dynamic> convertedMap = {};
          data.forEach((key, value) {
            convertedMap[key.toString()] = value;
          });
          return convertedMap;
        } else if (data is Map &&
            data.containsKey('data') &&
            data['data'] is Map) {
          final innerData = data['data'];
          if (innerData is Map<String, dynamic>) {
            return innerData;
          } else if (innerData is Map<dynamic, dynamic>) {
            final Map<String, dynamic> convertedMap = {};
            innerData.forEach((key, value) {
              convertedMap[key.toString()] = value;
            });
            return convertedMap;
          }
        }

        // If we can't parse the data, throw an exception
        throw Exception('Unexpected response format: ${response.body}');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Leave request not found');
      } else {
        throw Exception(
          'Failed to fetch leave request: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching leave request: $e');
      throw Exception('Error fetching leave request: $e');
    }
  }
}

// Notification Utils
class NotificationUtils {
  // Show success notification
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Success: $message'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show error notification
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
    );
  }

  // Show info notification
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Info: $message'), backgroundColor: Colors.blue),
    );
  }

  // Show loading notification
  static void showLoading(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
