import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../screens/sync_center_screen.dart';

/// Global interactive chip/badge indicating current connectivity and sync status
class SyncStatusIndicator extends StatelessWidget {
  final bool compact;

  const SyncStatusIndicator({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncMode>(
      valueListenable: ConnectivityService.modeNotifier,
      builder: (context, mode, _) {
        Color bgColor;
        Color textColor;
        Color dotColor;
        IconData? icon;

        switch (mode) {
          case SyncMode.online:
            bgColor = const Color(0xFFDCFCE7); // Soft Green
            textColor = const Color(0xFF166534);
            dotColor = const Color(0xFF22C55E);
            break;
          case SyncMode.offline:
            bgColor = const Color(0xFFFEE2E2); // Soft Red
            textColor = const Color(0xFF991B1B);
            dotColor = const Color(0xFFEF4444);
            break;
          case SyncMode.syncing:
            bgColor = const Color(0xFFE0F2FE); // Soft Blue
            textColor = const Color(0xFF075985);
            dotColor = const Color(0xFF0284C7);
            icon = Icons.sync_rounded;
            break;
          case SyncMode.syncError:
            bgColor = const Color(0xFFFEF3C7); // Soft Amber
            textColor = const Color(0xFF92400E);
            dotColor = const Color(0xFFF59E0B);
            icon = Icons.warning_amber_rounded;
            break;
        }

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dotColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(icon, size: 13, color: dotColor),
                  )
                else
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  compact
                      ? (mode == SyncMode.offline ? 'Offline' : mode.label)
                      : mode.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
