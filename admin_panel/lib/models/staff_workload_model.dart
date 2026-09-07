class StaffWorkload {
  final String staffId;
  final String staffName;
  final String email;
  final String role;
  final String? department;
  final String status;
  final int assignedCustomersCount;
  final int pendingActionsCount;
  final int overdueFollowupsCount;
  final int todayFollowupsCount;
  final int openIssuesCount;
  final int installationTasksCount;
  final int completedTasksCount;

  const StaffWorkload({
    required this.staffId,
    required this.staffName,
    required this.email,
    required this.role,
    this.department,
    required this.status,
    this.assignedCustomersCount = 0,
    this.pendingActionsCount = 0,
    this.overdueFollowupsCount = 0,
    this.todayFollowupsCount = 0,
    this.openIssuesCount = 0,
    this.installationTasksCount = 0,
    this.completedTasksCount = 0,
  });

  int get totalWorkloadScore =>
      assignedCustomersCount + pendingActionsCount + openIssuesCount + installationTasksCount;

  /// Workload status level: Low, Moderate, High, Overloaded
  String get workloadLevel {
    if (totalWorkloadScore >= 25) return 'Overloaded';
    if (totalWorkloadScore >= 15) return 'High';
    if (totalWorkloadScore >= 5) return 'Moderate';
    return 'Light';
  }
}
