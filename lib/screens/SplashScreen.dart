import 'package:flutter/material.dart';
import 'package:rocky_offline_sdk/screens/auth/device_registration_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RegistroIPSScreen(),
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF007BFF), // mismo color del yaml
      body: Center(
        child: Image.asset(
          "assets/images/imagenInicio.png",
          width: 220, // 🔥 aquí controlas el tamaño real
        ),
      ),
    );
  }
}
