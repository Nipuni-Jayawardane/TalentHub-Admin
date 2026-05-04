import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({super.key});

  Future<Map<String, String>> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('name') ?? 'User',
      'email': prefs.getString('email') ?? 'Email not available',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    return Drawer(
      backgroundColor: const Color(0xFF00102F),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset('assets/images/slt_logo.png', height: 60),
                ),
                const SizedBox(height: 20),
                FutureBuilder<Map<String, String>>(
                  future: _getUserData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Text(
                        'Error loading user data',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      );
                    }
                    final userData = snapshot.data ??
                        {'name': 'User', 'email': 'Email not available'};
                    return Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 22,
                          child: Icon(Icons.person, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${userData['name']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userData['email']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                const SizedBox(height: 15),
                SidebarItem(
                  label: 'Dashboard',
                  icon: Icons.home,
                  isSelected: currentRoute == '/dashboard',
                  onTap: () => context.go('/dashboard'),
                ),
                SidebarItem(
                  label: 'QR Attendance',
                  icon: Icons.qr_code_scanner,
                  isSelected: currentRoute == '/attendance',
                  onTap: () => context.go('/attendance'),
                ),
                SidebarItem(
                  label: 'Availability',
                  icon: Icons.calendar_today,
                  isSelected: currentRoute == '/availability',
                  onTap: () => context.go('/availability'),
                ),
                SidebarItem(
                  label: 'Log Book',
                  icon: Icons.menu_book,
                  isSelected: currentRoute == '/logbook',
                  onTap: () => context.go('/logbook'),
                ),
                
                const SizedBox(height: 100),
                const Divider(color: Colors.white24),
                SidebarItem(
                  label: 'Logout',
                  icon: Icons.logout,
                  isSelected: false,
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Clear all stored preferences
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0), // Add margin for spacing
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: const Color.fromARGB(255, 0, 138, 166)) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
        leading: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          onTap();
        },
      ),
    );
  }
}