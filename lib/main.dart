import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'screens/home_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackgroundService();
  runApp(const GpsTrackerApp());
}

class GpsTrackerApp extends StatelessWidget {
  const GpsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2EA043),
          secondary: Color(0xFF388BFD),
          surface: Color(0xFF161B22),
        ),
        cardColor: const Color(0xFF161B22),
        dividerColor: const Color(0xFF30363D),
      ),
      home: const HomeScreen(),
    );
  }
}
