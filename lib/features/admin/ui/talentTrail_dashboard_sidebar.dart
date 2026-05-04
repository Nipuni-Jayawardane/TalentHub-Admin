import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

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
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  route: '/talenttrail-settings',
                ),
                buildMenuButton(
                  context: context,
                  icon: LucideIcons.logOut,
                  label: 'Logout',
                  route: '/admin-dashboard',
                  color: Colors.redAccent,
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
    required String route,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: () {
        context.go(route); // Use GoRouter for navigation
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
