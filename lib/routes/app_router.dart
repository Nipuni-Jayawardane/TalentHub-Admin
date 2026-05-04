import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/ui/splash_screen.dart';
import '../features/admin/ui/admin_login_screen.dart';
import '../features/admin/ui/admindashboard.dart';
import '../features/admin/ui/admin_daily_records.dart';
import '../features/admin/ui/admin_intern_records.dart';
import '../features/admin/ui/admin_intern_details.dart';
import '../features/admin/ui/talentTrail_admin_dashboard.dart';
import '../features/admin/ui/talentTrail_interns_screen.dart';
import '../features/admin/ui/talentTrail_teams_management_screen.dart';
import '../features/admin/ui/talentTrail_project_management_screen.dart';
import '../features/admin/ui/talentTrail_settings_screen.dart';
import '../features/admin/ui/talentTrail_intern_cover.dart';
import '../features/admin/ui/talentTrail_project_attendance.dart';
import '../features/admin/ui/talentTrail_intern_details.dart';
import '../features/admin/ui/talentTrail_team_details.dart';
import '../features/admin/ui/talentTrail_project_details.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/admin-login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/admin/daily-records',
      builder: (context, state) => const DailyRecordsScreen(),
    ),
    GoRoute(
      path: '/admin/intern/:internId/records',
      builder: (context, state) =>
          AdminInternRecords(internId: state.pathParameters['internId']!),
    ),
    GoRoute(
      path: '/admin/intern/:internId/details',
      builder: (context, state) {
        final internId = state.pathParameters['internId'];
        if (internId == null || internId.isEmpty) {
          return const Scaffold(body: Center(child: Text('Invalid intern ID')));
        }
        return AdminInternDetailsScreen(internId: internId);
      },
    ),

    // TALENT TRAIL ROUTES
    GoRoute(
      path: '/talenttrail-dashboard',
      builder: (context, state) => const TalentTrailHomeScreen(),
    ),
    GoRoute(
      path: '/talenttrail-interns',
      builder: (context, state) => const InternsManagementScreen(),
    ),
    GoRoute(
      path: '/talenttrail-intern-cover',
      builder: (context, state) => const InternCoverPage(),
    ),
    GoRoute(
      path: '/talenttrail-teams',
      builder: (context, state) => const TeamsManagementScreen(),
    ),
    GoRoute(
      path: '/talenttrail-projects',
      builder: (context, state) => const ProjectsManagementScreen(),
    ),
    GoRoute(
      path: '/talenttrail-project-attendance',
      builder: (context, state) => const ProjectAttendancePage(),
    ),
    GoRoute(
      path: '/talenttrail-settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/talenttrail-intern/:internId',
      builder: (context, state) {
        final internId = state.pathParameters['internId'];
        if (internId == null || internId.isEmpty) {
          return const Scaffold(body: Center(child: Text('Invalid intern ID')));
        }
        return InternDetailScreen(internId: internId);
      },
    ),
    GoRoute(
      path: '/talenttrail-teams/:teamId',
      builder: (context, state) {
        final teamId = int.tryParse(state.pathParameters['teamId'] ?? '');

        if (teamId == null) {
          return const Scaffold(body: Center(child: Text('Invalid team ID')));
        }

        return TeamDetailScreen(teamId: teamId);
      },
    ),
    GoRoute(
      path: '/talenttrail-projects/:id',
      builder: (context, state) {
        final idString = state.pathParameters['id'];
        final projectId = int.tryParse(idString ?? '');

        if (projectId == null) {
          return const Scaffold(
            body: Center(child: Text('Invalid project ID')),
          );
        }

        return ProjectDetailScreen(projectId: projectId);
      },
    ),
  ],
);
