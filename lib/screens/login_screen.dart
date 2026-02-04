import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_manager.dart';
import '../services/update_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prompt for update on launch/login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GithubUpdateService.checkForUpdate(context, showNoUpdateMsg: false);
    });
  }

  void _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final dataManager = Provider.of<DataManager>(context, listen: false);
    
    try {
      // FIXED: removed 'bool success =' since login() returns void
      await dataManager.login();
      
      // If we get here, login was successful (no error thrown)
      // The DataManager listener will automatically switch screens.
      
    } catch (e) {
      // If login failed, an error is thrown, so we catch it here
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Sign-In Failed"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGuestLogin() {
    Provider.of<DataManager>(context, listen: false).continueAsGuest();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.account_balance_wallet_rounded, size: 80, color: Color(0xFF3F51B5)),
              const SizedBox(height: 20),
              const Text(
                "Pay Tracker", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Track your hours. Sync your pay.\nNever miss a cent.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: subTextColor),
              ),
              const Spacer(),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton.icon(
                  onPressed: _handleGoogleLogin,
                  icon: const Icon(Icons.g_mobiledata, size: 30),
                  label: const Text("Continue with Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    foregroundColor: textColor,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: _handleGuestLogin,
                  child: Text("Continue as Guest", style: TextStyle(color: subTextColor)),
                ),
              ],
              const Spacer(),
              Text("By continuing, you agree to our Terms & Privacy Policy.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: subTextColor)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}