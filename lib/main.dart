import 'package:cimage_attendance/pages/home_page.dart';
import 'package:cimage_attendance/services/firebase_services.dart';
import 'package:cimage_attendance/services/attendance_services.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseServices.initialize();
  await AttendanceServices.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cimage Attendance',
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: HomePage(
        title: "CIMAGE",
        url: "$baseUrl/user-student/attendance",
      ),
    );
  }
}
