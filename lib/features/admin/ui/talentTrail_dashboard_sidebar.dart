import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'talentTrail_qa_devops_screen.dart';
import 'talentTrail_certificates_screen.dart';
import 'talentTrail_help_requests_screen.dart';

class TalentTrailSidebar extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const TalentTrailSidebar({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop overlay
        if (isOpen)
          GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),

        // Sidebar panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          left: isOpen ? 0 : -280,
          bottom: 0,
          child: Container(
            width: 280,
            decoration: const BoxDecoration(color: Color(0xFF0A0E27)),
            child: Column(
              children: [
                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Menu buttons
                        buildMenuButton(
                  context: context,
                  icon: LucideIcons.home,
                  label: 'Home',
                  route: '/talenttrail-dashboard',
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.user,
                  label: 'Interns',
                  route: '/talenttrail-interns',
                ),
                buildMenuButton(
                  context: context,
                  icon: Icons.show_chart_rounded,
                  label: 'QA & DevOps',
                  onTap: () {
                    onClose();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TalentTrailQaDevopsScreen(),
                      ),
                    );
                  },
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.users,
                  label: 'Intern Cover',
                  route: '/talenttrail-intern-cover',
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.users,
                  label: 'Teams',
                  route: '/talenttrail-teams',
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.folder,
                  label: 'Projects',
                  route: '/talenttrail-projects',
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.folder,
                  label: 'Project Attendance',
                  route: '/talenttrail-project-attendance',
                ),
                buildMenuButton(
                  context: context,
                  icon: Icons.support_agent_rounded,
                  label: 'Help Requests',
                  onTap: () {
                    onClose();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TalentTrailHelpRequestsScreen(),
                      ),
                    );
                  },
                ),
                buildMenuButton(
                  context: context,
                  icon: Icons.workspace_premium_outlined,
                  label: 'Certificates',
                  onTap: () {
                    onClose();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TalentTrailCertificatesScreen(),
                      ),
                    );
                  },
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  route: '/talenttrail-settings',
                ),
                buildMenuButton(
                  context: context,
                  icon: Icons.grid_view_rounded,
                  label: 'Back to Talenthub',
                  onTap: () {
                    // Close the sidebar drawer state overlay
                    onClose();
                    // Direct route navigation to the main admin dashboard
                    context.go('/admin-dashboard');
                  },
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.logOut,
                  label: 'Logout',
                  color: Colors.redAccent,
                  onTap: () {
                    // Standard Logout logic
                    onClose();
                    // AuthService.logout() implementation here if needed
                    context.go('/admin-dashboard');
                  },
                ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? route,
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {
        if (route != null) {
          context.go(route); // Use GoRouter for navigation
        }
        onClose();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
