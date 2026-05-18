import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:slt_internship_attendance_portal/core/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:slt_internship_attendance_portal/config/config.dart';
import 'dart:typed_data';

class TalentTrailAdminService {
  // Get interns count
  static Future<int> getInternCount() async {
    final response = await TalentTrailApiServices.get('/interns');

    if (response.statusCode == 200) {
      final List<dynamic> interns = jsonDecode(response.body);
      return interns.length;
    } else {
      throw Exception('Failed to fetch interns: ${response.statusCode}');
    }
  }

  // Get interns list
  static Future<List<dynamic>> getInterns() async {
    final response = await TalentTrailApiServices.get('/interns');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch interns: ${response.statusCode}');
    }
  }

  /// Create a new intern
  static Future<Map<String, dynamic>> addIntern({
    required String internCode,
    required String name,
    required String email,
    required String institute,
    required String trainingStartDate, // format: YYYY-MM-DD
    required String trainingEndDate, // format: YYYY-MM-DD
  }) async {
    final body = jsonEncode({
      'internCode': internCode,
      'name': name,
      'email': email,
      'institute': institute,
      'trainingStartDate': trainingStartDate,
      'trainingEndDate': trainingEndDate,
    });

    final response = await TalentTrailApiServices.post('/interns', body: body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to create intern: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Get intern by code
  static Future<Map<String, dynamic>> getInternByCode(String internCode) async {
    final code = Uri.encodeComponent(internCode);
    final response = await TalentTrailApiServices.get('/interns/code/$code');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to fetch intern $internCode: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Update intern
  static Future<Map<String, dynamic>> updateIntern({
    required int internId,
    String? internCode,
    String? name,
    String? email,
    String? institute,
    String? fieldOfSpecialization,
    String? trainingStartDate,
    String? trainingEndDate,
    String? status,
  }) async {
    final body = jsonEncode({
      if (internCode != null) 'internCode': internCode,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (institute != null) 'institute': institute,
      if (fieldOfSpecialization != null)
        'fieldOfSpecialization': fieldOfSpecialization,
      if (trainingStartDate != null) 'trainingStartDate': trainingStartDate,
      if (trainingEndDate != null) 'trainingEndDate': trainingEndDate,
      if (status != null) 'status': status,
    });

    final response = await TalentTrailApiServices.put(
      '/interns/$internId',
      body: body,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to update intern: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Delete intern
  static Future<void> deleteIntern(int internId) async {
    final response = await TalentTrailApiServices.delete('/interns/$internId');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      throw Exception(
        'Failed to delete intern: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Get active interns count
  static Future<int> getActiveInternCount() async {
    final response = await TalentTrailApiServices.get('/stats/active-interns');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // API returns { "count": 42 }
      return data['count'] ?? 0;
    } else {
      throw Exception('Failed to fetch active interns: ${response.statusCode}');
    }
  }

  /// Get projects count
  static Future<int> getProjectCount() async {
    final response = await TalentTrailApiServices.get('/projects');
    if (response.statusCode == 200) {
      final List<dynamic> projects = jsonDecode(response.body);
      return projects.length;
    } else {
      throw Exception('Failed to fetch projects: ${response.statusCode}');
    }
  }

  /// Get projects list
  static Future<List<dynamic>> getProjects() async {
    final response = await TalentTrailApiServices.get('/projects');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch projects: ${response.statusCode}');
    }
  }

  // Get ongoing project count
  static Future<int> getOngoingProjectCount() async {
    final response = await TalentTrailApiServices.get('/projects');

    if (response.statusCode == 200) {
      final List<dynamic> projects = jsonDecode(response.body);

      return projects.where((project) {
        final status = project['status'];
        return status == 'IN_PROGRESS' || status == 'PLANNED';
      }).length;
    } else {
      throw Exception(
        'Failed to fetch ongoing projects: ${response.statusCode}',
      );
    }
  }

  // Get completed project count
  static Future<int> getCompletedProjectCount() async {
    final response = await TalentTrailApiServices.get('/projects');

    if (response.statusCode == 200) {
      final List<dynamic> projects = jsonDecode(response.body);

      return projects
          .where((project) => project['status'] == 'COMPLETED')
          .length;
    } else {
      throw Exception(
        'Failed to fetch completed projects: ${response.statusCode}',
      );
    }
  }

  // Get project by ID
  static Future<Map<String, dynamic>> getProjectById(int projectId) async {
    final response = await TalentTrailApiServices.get('/projects/$projectId');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to fetch project $projectId: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Update project
  static Future<Map<String, dynamic>> updateProject(
    int projectId,
    Map<String, dynamic> payload,
  ) async {
    final response = await TalentTrailApiServices.put(
      '/projects/$projectId',
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to update project: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Create project
  static Future<Map<String, dynamic>> createProject(
    Map<String, dynamic> payload,
  ) async {
    final response = await TalentTrailApiServices.post(
      '/projects',
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to create project: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Delete project
  static Future<void> deleteProject(int projectId) async {
    final response = await TalentTrailApiServices.delete(
      '/projects/$projectId',
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      throw Exception(
        'Failed to delete project: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Get project requests
  static Future<List<dynamic>> getProjectRequests() async {
    final response = await TalentTrailApiServices.get('/project-requests');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } else {
      throw Exception('Failed to fetch project requests');
    }
  }

  // Update project request status
  static Future<void> updateProjectRequestStatus(
    int requestId,
    String status,
  ) async {
    final body = jsonEncode({'status': status});
    final response = await TalentTrailApiServices.put(
      '/project-requests/$requestId/status',
      body: body,
    );

    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Failed to update project request status');
    }
  }

  // Get teams count
  static Future<int> getTeamCount() async {
    final response = await TalentTrailApiServices.get('/teams');

    if (response.statusCode == 200) {
      final List<dynamic> teams = jsonDecode(response.body);
      return teams.length;
    } else {
      throw Exception('Failed to fetch teams: ${response.statusCode}');
    }
  }

  // Get teams list
  static Future<List<dynamic>> getTeams() async {
    final response = await TalentTrailApiServices.get('/teams');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch teams: ${response.statusCode}');
    }
  }

  // Get team by ID
  static Future<Map<String, dynamic>> getTeamById(int teamId) async {
    final response = await TalentTrailApiServices.get('/teams/$teamId');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to fetch team $teamId: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Update team
  static Future<Map<String, dynamic>> updateTeam(
    int teamId,
    Map<String, dynamic> payload,
  ) async {
    final response = await TalentTrailApiServices.put(
      '/teams/$teamId',
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to update team: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Create team
  static Future<Map<String, dynamic>> createTeam(
    Map<String, dynamic> payload,
  ) async {
    final response = await TalentTrailApiServices.post(
      '/teams',
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to create team: ${response.statusCode} ${response.body}',
      );
    }
  }

  // Delete team
  static Future<void> deleteTeam(int teamId) async {
    final response = await TalentTrailApiServices.delete('/teams/$teamId');

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      throw Exception(
        'Failed to delete team: ${response.statusCode} ${response.body}',
      );
    }
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await TalentTrailApiServices.get('/stats/dashboard');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'activeInterns': data['activeInterns'] ?? 0,
          'lastActiveInternsUpdate': data['lastActiveInternsUpdate'] ?? '',
          'pendingRepositoryInfo': data['pendingRepositoryInfo'] ?? 0,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token might be expired or invalid
        throw Exception(
          'Authentication failed. Please login again to TalentTrail.',
        );
      } else {
        throw Exception(
          'Failed to fetch dashboard stats: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error in getDashboardStats: $e');
      rethrow;
    }
  }

  // Get pending repository count
  static Future<int> getPendingRepositoryCount() async {
    final response = await TalentTrailApiServices.get('/stats/dashboard');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // API returns { "activeInterns": 42, "pendingRepositoryInfo": 3, ... }
      return data['pendingRepositoryInfo'] ?? 0;
    } else {
      throw Exception(
        'Failed to fetch pending repository info count: ${response.statusCode}',
      );
    }
  }

  // Get all teams assigned to a project
  static Future<List<dynamic>> getTeamsAssignedToProject(int projectId) async {
    final response = await TalentTrailApiServices.get(
      '/project-teams/project/$projectId',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } else {
      throw Exception(
        'Failed to fetch teams for project $projectId: ${response.statusCode}',
      );
    }
  }

  // Get all projects assigned to a team
  static Future<List<dynamic>> getProjectsAssignedToTeam(int teamId) async {
    final response = await TalentTrailApiServices.get(
      '/project-teams/team/$teamId',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      } else if (data is Map) {
        return data['data'] is List ? data['data'] : [];
      } else {
        return [];
      }
    } else {
      debugPrint(
        'Failed to fetch projects for team $teamId: ${response.statusCode}',
      );
      return [];
    }
  }

  // Get all team member associations
  static Future<List<dynamic>> getTeamMemberAssociations() async {
    final response = await TalentTrailApiServices.get('/team-members');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      } else if (data is Map) {
        return data['data'] is List ? data['data'] : [];
      } else {
        return [];
      }
    } else {
      debugPrint('Failed to fetch team members: ${response.statusCode}');
      return [];
    }
  }

  // Submit project attendance
  static Future<void> submitProjectAttendance({
    required int projectId,
    required String date,
    required String status,
  }) async {
    final body = jsonEncode({
      'projectId': projectId,
      'date': date,
      'status': status,
    });

    final response = await TalentTrailApiServices.post(
      '/project-attendance',
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else {
      throw Exception(
        'Failed to submit attendance: ${response.statusCode} ${response.body}',
      );
    }
  }

  static Future<Uint8List> exportInternsExcel(String apiKey) async {
    final uri = Uri.parse(
      '${Config.talentTrailBaseUrl}/bulk-import/export/excel',
    );

    final response = await http.get(
      uri,
      headers: {
        'X-API-Key': Config.apiKey,
        'Accept':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      },
    );

    if (response.statusCode == 200) {
      // response.bodyBytes is the Excel file bytes
      return response.bodyBytes;
    } else {
      throw Exception(
        'Failed to export interns Excel: ${response.statusCode} ${response.body}',
      );
    }
  }
}

// Notification Utils
class NotificationUtils {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Success: $message'),
        backgroundColor: Colors.green,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Info: $message'), backgroundColor: Colors.blue),
    );
  }
}
