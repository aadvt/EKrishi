import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'utils/language_provider.dart';
import 'constants/app_theme.dart';
import 'models/scan_history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ScanHistoryAdapter());
  
  // Open Hive boxes
  await Hive.openBox('settings');
  await Hive.openBox('location');
  await Hive.openBox('history');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const EKrishiApp(),
    ),
  );
}

class EKrishiApp extends StatelessWidget {
  const EKrishiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Krishi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
