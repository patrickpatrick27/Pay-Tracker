import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Required for kDebugMode
import 'package:provider/provider.dart';
import 'services/data_manager.dart';
import 'services/update_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DataManager()..initApp()),
      ],
      child: const PayTrackerApp(),
    ),
  );
}

class PayTrackerApp extends StatefulWidget {
  const PayTrackerApp({super.key});

  @override
  State<PayTrackerApp> createState() => _PayTrackerAppState();
}

class _PayTrackerAppState extends State<PayTrackerApp> {
  
  @override
  void initState() {
    super.initState();
    // Auto-update check on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GithubUpdateService.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch DataManager for Auth & Settings
    final dataManager = Provider.of<DataManager>(context);

    // 1. Loading Screen (while initializing local data & auth)
    if (!dataManager.isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 2. Main App Logic
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Logic: Use "Dev" name if running in Debug mode from VS Code
      title: kDebugMode ? 'Pay Tracker (Dev)' : 'Pay Tracker',
      
      // Dynamic Theme based on DataManager
      themeMode: dataManager.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        cardColor: Colors.white,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF536DFE),
          onPrimary: Colors.white,
          secondary: Color(0xFF00BFA5),
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
          background: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFF1E1E1E),
      ),

      // 3. Routing Logic: Login vs Dashboard
      home: dataManager.isAuthenticated 
        ? PayPeriodListScreen(
            use24HourFormat: dataManager.use24HourFormat,
            isDarkMode: dataManager.isDarkMode,
            shiftStart: dataManager.shiftStart,
            shiftEnd: dataManager.shiftEnd,
            
            // FIXED: Added missing arguments to match the updated dashboard signature
            onUpdateSettings: ({
              isDark, 
              is24h, 
              hideMoney, 
              currencySymbol, 
              shiftStart, 
              shiftEnd, 
              enableLate, 
              enableOt, 
              defaultRate
            }) {
              // Pass all relevant settings back to DataManager for global persistence
              dataManager.updateSettings(
                isDark: isDark,
                is24h: is24h,
                enableLate: enableLate,
                enableOt: enableOt,
                defaultRate: defaultRate, // Global Base Pay
                shiftStart: shiftStart,
                shiftEnd: shiftEnd,
              );
            },
          )
        : const LoginScreen(),
    );
  }
}