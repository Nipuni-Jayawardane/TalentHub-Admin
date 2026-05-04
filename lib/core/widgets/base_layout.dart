import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sidebar_drawer.dart';

class BaseLayout extends StatefulWidget {
  final Widget child;
  const BaseLayout({super.key, required this.child});

  @override
  State<BaseLayout> createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
  String? internName;

  @override
  void initState() {
    super.initState();
    _loadInternName();
  }

  Future<void> _loadInternName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      internName = prefs.getString('name') ?? 'User';
    });
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return parts.map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SidebarDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00102F),
        elevation: 4,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: [
              Image.asset('assets/images/slt_logo.png', height: 32),
              const Spacer(),

              // Avatar with initials instead of Icon
              Builder(
                builder: (context) {
                  return GestureDetector(
                    //onTap: () => Scaffold.of(context).openDrawer(),
                    child: internName == null
                        ? const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color.fromARGB(236, 33, 149, 243),
                            ),
                          )
                        : CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color.fromARGB(
                              84,
                              30,
                              136,
                              229,
                            ),
                            child: Text(
                              _getInitials(internName!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  );
                },
              ),

              const SizedBox(width: 8),

              // Hamburger icon
              Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: widget.child),
    );
  }
}
