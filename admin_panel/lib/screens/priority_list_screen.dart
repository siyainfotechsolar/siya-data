export 'action_center_screen.dart';

// Compatibility alias so that existing callers using PriorityListScreen still compile.
// ignore: unused_element
// See action_center_screen.dart for the real implementation.
import 'package:flutter/material.dart';
import 'action_center_screen.dart';

class PriorityListScreen extends StatelessWidget {
  final String? initialPriorityFilter;

  const PriorityListScreen({super.key, this.initialPriorityFilter});

  @override
  Widget build(BuildContext context) {
    return ActionCenterScreen(initialStageFilter: initialPriorityFilter);
  }
}
