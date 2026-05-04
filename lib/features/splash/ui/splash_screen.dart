import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  bool _showSubtitle = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _logoController.forward();

    // Show subtitle after delay
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showSubtitle = true;
      });
    });

    // Navigate to login
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      context.go('/admin-login');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 3, 21, 57), Color(0xFF0A1A3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo fade-in
            FadeTransition(
              opacity: _logoController,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset('assets/images/slt_logo.png', height: 100),
              ),
            ),
            const SizedBox(height: 30),

            // Typewriter title animation
            AnimatedTextKit(
              totalRepeatCount: 1,
              animatedTexts: [
                TypewriterAnimatedText(
                  'Internship Attendance Portal',
                  textStyle: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  speed: const Duration(milliseconds: 80),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Subtitle + Indicator (fade in)
            AnimatedOpacity(
              opacity: _showSubtitle ? 1 : 0,
              duration: const Duration(milliseconds: 1000),
              child: Column(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      'Track your daily attendance, view history,\nand manage your internship progress all in one place.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Dot extends StatelessWidget {
  final bool active;
  const Dot({super.key, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: 10,
      decoration: BoxDecoration(
        color: active ? Colors.greenAccent : Colors.white70,
        shape: BoxShape.circle,
      ),
    );
  }
}
