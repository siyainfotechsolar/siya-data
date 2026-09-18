import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized helper for consistent, safe Android back button navigation
/// across the entire Siya Data mobile application.
class BackNavigationHelper {
  BackNavigationHelper._();

  /// Shows the standard "Unsaved Changes" confirmation dialog.
  ///
  /// Returns `true` if the user chose to DISCARD changes and proceed with exit.
  /// Returns `false` if the user chose to STAY on the current form.
  static Future<bool> showDiscardDialog(
    BuildContext context, {
    String title = 'Unsaved Changes',
    String message = 'Unsaved changes will be lost.',
    String stayLabel = 'Stay',
    String discardLabel = 'Discard',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 26),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(stayLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(discardLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows the standard "Operation in Progress" confirmation dialog
  /// when an upload or background processing task is actively running.
  ///
  /// Returns `true` if the user confirms leaving despite active processing.
  /// Returns `false` if the user chooses to stay.
  static Future<bool> showProcessingDialog(
    BuildContext context, {
    String title = 'Operation in Progress',
    String message =
        'A document or upload is currently being processed. Leaving now may interrupt processing. Do you want to leave?',
    String stayLabel = 'Stay',
    String leaveLabel = 'Leave',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, color: Color(0xFFD97706), size: 26),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(stayLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(leaveLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Standard exit confirmation dialog for root / home screen.
  static Future<bool> showExitAppDialog(
    BuildContext context, {
    String title = 'Exit App',
    String message = 'Are you sure you want to exit Siya Solar?',
    String cancelLabel = 'Cancel',
    String exitLabel = 'Exit',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app_rounded, color: Color(0xFF059669), size: 26),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(exitLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Double-back exit handler for the Home / Root screen.
  ///
  /// On first press: displays "Press back again to exit" floating snackbar.
  /// On second press within [timeout] (default 2 seconds): calls [SystemNavigator.pop]
  /// to cleanly exit the Android application without unexpected state resets.
  static bool handleDoubleBackPress({
    required BuildContext context,
    required DateTime? lastBackPressTime,
    required void Function(DateTime) onTimeUpdated,
    Duration timeout = const Duration(seconds: 2),
    String snackbarMessage = 'Press back again to exit',
  }) {
    final now = DateTime.now();
    if (lastBackPressTime == null || now.difference(lastBackPressTime) > timeout) {
      onTimeUpdated(now);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackbarMessage),
          duration: timeout,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return false;
    }

    // Second back within timeout: exit app cleanly
    SystemNavigator.pop();
    return true;
  }
}
