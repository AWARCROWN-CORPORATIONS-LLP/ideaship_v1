import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_log_reg.dart';

Future<void> forceLogout(
  BuildContext context, {
  String? reason,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  if (reason != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason)),
    );
  }

  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthLogReg()),
      (_) => false,
    );
  }
}
