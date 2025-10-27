import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../role_selection/role.dart';
import '../dashboard.dart'; 

class AuthLogReg extends StatefulWidget {
  const AuthLogReg({super.key});

  @override
  State<AuthLogReg> createState() => _AuthLogRegState();
}

class _AuthLogRegState extends State<AuthLogReg> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isConnected = false;
  bool _isLoading = false;

  
  final TextEditingController _loginUserController = TextEditingController();
  final TextEditingController _loginPassController = TextEditingController();
  String? _loginUserError;
  String? _loginPassError;

  
  final TextEditingController _regUserController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPassController = TextEditingController();
  final TextEditingController _regConfirmPassController = TextEditingController();
  String? _regUserError;
  String? _regEmailError;
  String? _regPassError;
  String? _regConfirmPassError;
  bool _agreeToTerms = false;

  bool _loginObscure = true;
  bool _regObscure = true;
  bool _regConfirmObscure = true;
  double _passwordStrength = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!mounted) return;
      setState(() {
        _isConnected = results.any((result) => result != ConnectivityResult.none);
        if (!_isConnected) {
          _showErrorDialog("No Network", "You are not connected to a network. Please check your Wi-Fi or mobile data.");
        }
      });
    });

    _loginUserController.addListener(() => setState(() => _loginUserError = null));
    _loginPassController.addListener(() => setState(() => _loginPassError = null));
    _regUserController.addListener(() => setState(() => _regUserError = null));
    _regEmailController.addListener(() => setState(() => _regEmailError = null));
    _regPassController.addListener(() {
      setState(() {
        _regPassError = null;
        _updatePasswordStrength();
      });
    });
    _regConfirmPassController.addListener(() => setState(() => _regConfirmPassError = null));

    _tabController.addListener(() {
      if (_tabController.indexIsChanging && mounted) {
        _fadeController.reset();
        _fadeController.forward();
        _clearAllErrors();
      }
    });

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoginCheck();
    });
  }

  Future<void> _autoLoginCheck() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final profileCompleted = prefs.getBool('profileCompleted') ?? false;

      if (token != null && token.isNotEmpty) {
      
        if (profileCompleted) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const RoleSelectionPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        }
        return;
      }
    } catch (e) {
      debugPrint("Auto-login check error: $e");
      _showErrorDialog("Auto-Login Error", "Failed to check stored session: ${e.toString()}. Please log in manually.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      
      // ignore: unrelated_type_equality_checks
      _isConnected = connectivityResult != ConnectivityResult.none;
      if (!_isConnected) {
        _showErrorDialog("No Network", "You are not connected to a network. Please check your Wi-Fi or mobile data.");
      }
    });
  }

  void _updatePasswordStrength() {
    String pass = _regPassController.text;
    if (pass.isEmpty) {
      _passwordStrength = 0.0;
      return;
    }
    double strength = 0.0;
    if (pass.length >= 6) strength += 0.3;
    if (pass.length >= 8) strength += 0.3;
    if (RegExp(r'[A-Z]').hasMatch(pass)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pass)) strength += 0.1;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)) strength += 0.1;
    _passwordStrength = strength.clamp(0.0, 1.0);
  }

  void _clearAllErrors() {
    setState(() {
      _loginUserError = null;
      _loginPassError = null;
      _regUserError = null;
      _regEmailError = null;
      _regPassError = null;
      _regConfirmPassError = null;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _loginUserController.dispose();
    _loginPassController.dispose();
    _regUserController.dispose();
    _regEmailController.dispose();
    _regPassController.dispose();
    _regConfirmPassController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))),
            ],
          ),
          content: SingleChildScrollView(child: Text(message, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String title, String message, {bool switchToLogin = false, bool goToRole = false, String? email}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<Widget> actions = [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (switchToLogin && mounted) {
                _tabController.animateTo(0);
              }
              if (goToRole && mounted) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const RoleSelectionPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                );
              }
            },
            child: Text("OK", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
          ),
        ];
        if (email != null) {
          actions.insert(
            0,
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resendVerification(email);
                if (mounted) {
                  _tabController.animateTo(0);
                }
              },
              child: Text("Resend Verification", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
            ),
          );
        }
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))),
            ],
          ),
          content: SingleChildScrollView(child: Text(message, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87))),
          actions: actions,
        );
      },
    );
  }

  Future<void> _resendVerification(String email) async {
    if (!_isConnected) {
      _showErrorDialog("No Network", "Cannot resend verification without a network connection.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse("https://server.awarcrown.com/api?action=resend-verification");
      final response = await http.post(
        url,
        body: {"email": email},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 30));

      debugPrint("Resend Verification Response Status: ${response.statusCode}");
      debugPrint("Resend Verification Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? "Verification email sent!"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          final message = data['message'] ?? "Unable to resend verification email.";
          _showErrorDialog("Resend Failed", message);
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final message = data['message'] ?? "Invalid request.";
        _showErrorDialog("Resend Failed", message);
      } else if (response.statusCode == 404) {
        _showErrorDialog("Resend Failed", "Email not found.");
      } else if (response.statusCode == 500) {
        _showErrorDialog("Server Error", "Internal server issue. Please try again later.");
      } else {
        _showErrorDialog("Server Error", "Unexpected error (${response.statusCode}). Please try again.");
      }
    } catch (e) {
      debugPrint("Resend Verification Error: $e");
      final errorMsg = e.toString().contains('TimeoutException') ? "Request timed out. Check your connection." : "Failed to connect: ${e.toString()}. Check your internet.";
      _showErrorDialog("Connection Error", errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _refreshTokens() async {
    if (!_isConnected) {
      _showErrorDialog("No Network", "Cannot refresh tokens without a network connection.");
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        _showErrorDialog("Token Refresh Failed", "No refresh token available. Please log in again.");
        return false;
      }

      final url = Uri.parse("https://vanguard.awarcrown.com/auth/api?action=refresh");
      final response = await http.post(
        url,
        body: json.encode({"refresh_token": refreshToken}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      debugPrint("Refresh Response Status: ${response.statusCode}");
      debugPrint("Refresh Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final newAccessToken = data['access_token'] as String?;
          final newRefreshToken = data['refresh_token'] as String?;
          if (newAccessToken != null) {
            await prefs.setString('token', newAccessToken);
          }
          if (newRefreshToken != null) {
            await prefs.setString('refresh_token', newRefreshToken);
          }
          debugPrint("Tokens refreshed successfully.");
          return true;
        } else {
          final message = data['message'] ?? "Unknown refresh error.";
          _showErrorDialog("Token Refresh Failed", message);
          // Clear invalid tokens
          await prefs.remove('token');
          await prefs.remove('refresh_token');
          return false;
        }
      } else {
        final message = response.statusCode == 401
            ? "Refresh token invalid or expired."
            : response.statusCode == 400
                ? "Invalid refresh request."
                : "Server error during refresh: ${response.statusCode}";
        _showErrorDialog("Token Refresh Failed", message);
        return false;
      }
    } catch (e) {
      debugPrint("Refresh Error: $e");
      _showErrorDialog("Connection Error", "Failed to refresh tokens: ${e.toString()}. Check your internet.");
      return false;
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    String? emailError;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("Forgot Password", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Enter your email to reset password.", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: emailError,
                      errorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setDialogState(() {
                            emailError = emailController.text.trim().isEmpty
                                ? "Please enter email"
                                : (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(emailController.text.trim())
                                    ? "Invalid email address"
                                    : null);
                          });
                          if (emailError != null) return;

                          if (!_isConnected) {
                            Navigator.of(context).pop();
                            _showErrorDialog("No Network", "Cannot send reset request without a network connection.");
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            final url = Uri.parse("https://vanguard.awarcrown.com/auth/api?action=forgot-password");
                            final response = await http.post(
                              url,
                              body: {"email": emailController.text.trim()},
                              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                            ).timeout(const Duration(seconds: 30));

                            debugPrint("Forgot Password Response Status: ${response.statusCode}");
                            debugPrint("Forgot Password Response Body: ${response.body}");

                            if (response.statusCode == 200) {
                              final data = json.decode(response.body);
                              if (data['success'] == true) {
                                Navigator.of(context).pop();
                                _showSuccessDialog("Reset Link Sent", data['message'] ?? "Check your email for the password reset link.", goToRole: false);
                              } else {
                                final message = data['message'] ?? "Unable to process reset request.";
                                setDialogState(() => emailError = message);
                              }
                            } else if (response.statusCode == 400) {
                              final data = json.decode(response.body);
                              final message = data['message'] ?? "Invalid request.";
                              setDialogState(() => emailError = message);
                            } else if (response.statusCode == 404) {
                              setDialogState(() => emailError = "Email not found in our records.");
                            } else if (response.statusCode == 500) {
                              setDialogState(() => emailError = "Server error: Internal server issue. Please try again later.");
                            } else {
                              setDialogState(() => emailError = "Server error: ${response.statusCode}. Please try again.");
                            }
                          } catch (e) {
                            debugPrint("Forgot Password Error: $e");
                            setDialogState(() => emailError = "Failed to connect to server: ${e.toString()}. Check your internet.");
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Send"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _login() async {
    bool hasError = false;
    setState(() {
      _loginUserError = _loginUserController.text.trim().isEmpty ? "Please enter username or email" : null;
      _loginPassError = _loginPassController.text.trim().isEmpty ? "Please enter password" : null;
      if (_loginUserError != null || _loginPassError != null) hasError = true;
    });

    if (hasError) return;

    if (!_isConnected) {
      _showErrorDialog("No Network", "Cannot login without a network connection.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse("https://vanguard.awarcrown.com/auth/api?action=login");
      final response = await http.post(
        url,
        body: {
          "username": _loginUserController.text.trim(),
          "password": _loginPassController.text.trim(),
        },
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 30));

      debugPrint("Login Response Status: ${response.statusCode}");
      debugPrint("Login Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final userData = data['user'] as Map<String, dynamic>? ?? {};
          final accessToken = data['access_token'] as String?;
          final refreshToken = data['refresh_token'] as String?;

          if (accessToken == null || accessToken.isEmpty) {
            _showErrorDialog("Login Failed", "Access token missing from server response. Please try again.");
            return;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('id', userData['id']?.toString() ?? '');
          await prefs.setString('username', userData['username'] as String? ?? '');
          await prefs.setString('email', userData['email'] as String? ?? '');
          await prefs.setString('token', accessToken); // Store as 'token' for compatibility
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await prefs.setString('refresh_token', refreshToken);
          } else {
            debugPrint("Warning: No refresh token received.");
          }

          setState(() {
            _loginUserController.clear();
            _loginPassController.clear();
          });

          // Check profile completion
          final profileCompleted = prefs.getBool('profileCompleted') ?? false;
          final nextPage = profileCompleted ? const DashboardPage() : const RoleSelectionPage();

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => nextPage,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          final message = data['message'] ?? "Invalid credentials. Please check your username/email and password.";
          if (message.contains("username") || message.contains("email")) {
            setState(() => _loginUserError = message);
          } else if (message.contains("password")) {
            setState(() => _loginPassError = message);
          } else {
            _showErrorDialog("Login Failed", message);
          }
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final message = data['message'] ?? "Invalid login request. Please check your input.";
        if (message.contains("username") || message.contains("email")) {
          setState(() => _loginUserError = message);
        } else if (message.contains("password")) {
          setState(() => _loginPassError = message);
        } else {
          _showErrorDialog("Login Failed", message);
        }
      } else if (response.statusCode == 401) {
        final data = json.decode(response.body);
        final message = data['message'] ?? "Invalid credentials. Please check your username/email and password.";
        _showErrorDialog("Login Failed", message);
      } else if (response.statusCode == 403) {
        final data = json.decode(response.body);
        final message = data['message'] ?? "Account not verified. Please check your email for verification link.";
        _showErrorDialog("Login Failed", message);
      } else if (response.statusCode == 500) {
        _showErrorDialog("Server Error", "Internal server error (500). Please try again later or contact support.");
      } else {
        _showErrorDialog("Server Error", "Unexpected error (HTTP ${response.statusCode}). Please try again.");
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      final errorMsg = e.toString().contains('TimeoutException') ? "Request timed out. Check your connection." : "Failed to connect to server: ${e.toString()}. Check your internet.";
      _showErrorDialog("Connection Error", errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    bool hasError = false;
    setState(() {
      _regUserError = _regUserController.text.trim().isEmpty ? "Please enter username" : null;
      _regEmailError = _regEmailController.text.trim().isEmpty
          ? "Please enter email"
          : (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(_regEmailController.text.trim())
              ? "Invalid email address"
              : null);
      _regPassError = _regPassController.text.trim().isEmpty
          ? "Please enter password"
          : (_regPassController.text.length < 6 ? "Password must be at least 6 characters" : null);
      _regConfirmPassError = _regConfirmPassController.text.trim() != _regPassController.text.trim() ? "Passwords do not match" : null;
      if (!_agreeToTerms) {
        _showErrorDialog("Terms Error", "You must agree to the Terms of Service and Privacy Policy to register.");
        hasError = true;
      }
      if (_regUserError != null || _regEmailError != null || _regPassError != null || _regConfirmPassError != null) hasError = true;
    });

    if (hasError) return;

    if (!_isConnected) {
      _showErrorDialog("No Network", "Cannot register without a network connection.");
      return;
    }

    setState(() => _isLoading = true);

    final String registeredEmail = _regEmailController.text.trim();

    try {
      final url = Uri.parse("https://vanguard.awarcrown.com/auth/api?action=register");
      final response = await http.post(
        url,
        body: {
          "username": _regUserController.text.trim(),
          "email": registeredEmail,
          "password": _regPassController.text.trim(),
        },
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 30));
      debugPrint("Register Response Status: ${response.statusCode}");
      debugPrint("Register Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final userData = data['user'] as Map<String, dynamic>? ?? {};
          final accessToken = data['access_token'] as String?;
          final refreshToken = data['refresh_token'] as String?;

          if (accessToken == null || accessToken.isEmpty) {
            _showErrorDialog("Registration Failed", "Access token missing from server response. Please try logging in.");
            return;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('id', userData['id']?.toString() ?? '');
          await prefs.setString('username', userData['username'] as String? ?? _regUserController.text.trim());
          await prefs.setString('email', userData['email'] as String? ?? registeredEmail);
          await prefs.setString('token', accessToken); // Store as 'token' for compatibility
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await prefs.setString('refresh_token', refreshToken);
          } else {
            debugPrint("Warning: No refresh token received on register.");
          }
          // For register, always go to role selection (first time)
          await prefs.setBool('profileCompleted', false);

          _showSuccessDialog(
            "Registration Successful",
            data['message'] ?? "Account created! Please verify your email to continue.",
            switchToLogin: true,
            goToRole: false,
            email: registeredEmail,
          );

          setState(() {
            _regUserController.clear();
            _regEmailController.clear();
            _regPassController.clear();
            _regConfirmPassController.clear();
            _agreeToTerms = false;
            _passwordStrength = 0.0;
          });
        } else {
          final message = data['message'] ?? "Unable to create account. Please check your input and try again.";
          if (message.contains("username")) {
            setState(() => _regUserError = message);
          } else if (message.contains("email")) {
            setState(() => _regEmailError = message);
          } else if (message.contains("password")) {
            setState(() => _regPassError = message);
          } else {
            _showErrorDialog("Registration Failed", message);
          }
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final message = data['message'] ?? "Invalid registration request. Please check your input.";
        if (message.contains("username")) {
          setState(() => _regUserError = message);
        } else if (message.contains("email")) {
          setState(() => _regEmailError = message);
        } else if (message.contains("password")) {
          setState(() => _regPassError = message);
        } else {
          _showErrorDialog("Registration Failed", message);
        }
      } else if (response.statusCode == 409) {
        _showErrorDialog("Registration Failed", "Username or email already exists. Please choose different ones.");
      } else if (response.statusCode == 500) {
        _showErrorDialog("Server Error", "Internal server error (500). Please try again later or contact support.");
      } else {
        _showErrorDialog("Server Error", "Unexpected error (HTTP ${response.statusCode}). Please try again.");
      }
    } catch (e) {
      debugPrint("Register Error: $e");
      final errorMsg = e.toString().contains('TimeoutException') ? "Request timed out. Check your connection." : "Failed to connect to server: ${e.toString()}. Check your internet.";
      _showErrorDialog("Connection Error", errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    String? error,
    IconData? suffixIcon,
    VoidCallback? onSuffixPressed,
    TextInputType? keyboardType,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          errorText: error,
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: suffixIcon != null
              ? IconButton(
                  icon: AnimatedCrossFade(
                    firstChild: Icon(Icons.visibility, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                    secondChild: Icon(Icons.visibility_off, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
                    crossFadeState: obscure ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 300),
                  ),
                  onPressed: onSuffixPressed,
                )
              : null,
        ),
        enabled: !_isLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black87 : Colors.black,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Awarcrown Auth",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.wifi,
              color: _isConnected
                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white)
                  : Colors.grey,
              size: 24,
              semanticLabel: _isConnected ? 'Connected to network' : 'No network connection',
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Login"),
            Tab(text: "Register"),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (!_isConnected)
            Banner(
              message: "Offline: Please connect to a network",
              location: BannerLocation.topEnd,
              color: Colors.red,
            ),
          TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 80,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                        semanticLabel: 'Login icon',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _loginUserController,
                      label: "Username or Email",
                      error: _loginUserError,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _loginPassController,
                      label: "Password",
                      obscure: _loginObscure,
                      error: _loginPassError,
                      suffixIcon: _loginObscure ? Icons.visibility : Icons.visibility_off,
                      onSuffixPressed: () => setState(() => _loginObscure = !_loginObscure),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Login",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              semanticsLabel: 'Login button',
                            ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Icon(
                        Icons.person_add_outlined,
                        size: 80,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                        semanticLabel: 'Register icon',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _regUserController,
                      label: "Username",
                      error: _regUserError,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _regEmailController,
                      label: "Email",
                      error: _regEmailError,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _regPassController,
                      label: "Password",
                      obscure: _regObscure,
                      error: _regPassError,
                      suffixIcon: _regObscure ? Icons.visibility : Icons.visibility_off,
                      onSuffixPressed: () => setState(() => _regObscure = !_regObscure),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                      ),
                      semanticsLabel: 'Password strength indicator',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Password Strength: ${_passwordStrength < 0.4 ? 'Weak' : _passwordStrength < 0.7 ? 'Medium' : 'Strong'}",
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      semanticsLabel: 'Password strength: ${_passwordStrength < 0.4 ? 'Weak' : _passwordStrength < 0.7 ? 'Medium' : 'Strong'}',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _regConfirmPassController,
                      label: "Confirm Password",
                      obscure: _regConfirmObscure,
                      error: _regConfirmPassError,
                      suffixIcon: _regConfirmObscure ? Icons.visibility : Icons.visibility_off,
                      onSuffixPressed: () => setState(() => _regConfirmObscure = !_regConfirmObscure),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: _isLoading ? null : (value) => setState(() => _agreeToTerms = value!),
                          checkColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                          activeColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          semanticLabel: 'Agree to terms checkbox',
                        ),
                        Expanded(
                          child: Text(
                            "I agree to the Terms of Service and Privacy Policy",
                            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Register",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              semanticsLabel: 'Register button',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}