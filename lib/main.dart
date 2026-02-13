import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'services/data_manager.dart';
import 'services/update_service.dart';
import 'services/audio_service.dart'; 

// --- SCREEN IMPORTS ---
import 'screens/dashboard_screen.dart'; 
import 'screens/login_screen.dart';

// 1. GLOBAL NAVIGATOR KEY - Allows dialogs from anywhere (updates, alerts)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Preload sounds for instant playback
  await AudioService().init(); 

  runApp(
    MultiProvider(
      providers: [
        // Initialize DataManager immediately and start loading data
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
    // 3. Auto-update check on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use the global key's context to show dialogs safely
      final contextToUse = navigatorKey.currentContext; 
      if (contextToUse != null) {
        // We pass 'false' so it doesn't annoy the user if no update is found
        GithubUpdateService.checkForUpdate(contextToUse, showNoUpdateMsg: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to DataManager for changes (Auth status, Theme, Settings)
    return Consumer<DataManager>(
      builder: (context, dataManager, child) {
        
        // 4. Show loading screen while SharedPrefs/GoogleSignIn initializes
        if (!dataManager.isInitialized) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          navigatorKey: navigatorKey, 
          debugShowCheckedModeBanner: false,
          title: kDebugMode ? 'Pay Tracker (Dev)' : 'Pay Tracker',
          
          // 5. Theme Logic
          themeMode: dataManager.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF5F7FA),
              surfaceTintColor: Colors.transparent, // Fix for washed out appbars
              centerTitle: false,
            ),
            cardColor: Colors.white,
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF536DFE),
              onPrimary: Colors.white, 
              secondary: Color(0xFF82B1FF),
              surface: Color(0xFF1E1E1E),
              background: Color(0xFF121212),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212), 
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
            ),
            cardColor: const Color(0xFF1E1E1E),
          ),

          // 6. ROUTING LOGIC
          home: dataManager.isAuthenticated 
            ? PayPeriodListScreen(
                use24HourFormat: dataManager.use24HourFormat,
                isDarkMode: dataManager.isDarkMode,
                shiftStart: dataManager.shiftStart,
                shiftEnd: dataManager.shiftEnd,
                onUpdateSettings: ({
                  isDark, is24h, hideMoney, currencySymbol, 
                  shiftStart, shiftEnd, enableLate, enableOt, defaultRate,
                  snapToGrid // <--- NEW PARAMETER
                }) {
                  // Bridge Settings Screen -> Data Manager
                  dataManager.updateSettings(
                    isDark: isDark,
                    is24h: is24h,
                    enableLate: enableLate,
                    enableOt: enableOt,
                    defaultRate: defaultRate,
                    shiftStart: shiftStart,
                    shiftEnd: shiftEnd,
                    snapToGrid: snapToGrid, // <--- Pass to Manager
                  );
                },
              )
            : const LoginScreen(),
        );
      },
    );
  }
}