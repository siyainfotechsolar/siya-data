
class ReportFilterOptions {
  final DateTime? applicationDateFrom;
  final DateTime? applicationDateTo;
  final DateTime? submitDateFrom;
  final DateTime? submitDateTo;
  final String? workStage;
  final String? status;
  final String? priority;
  final String? loanStatus;
  final String? loanSubStage;
  final String? installationStatus;
  final String? rtsStatus;
  final String? subsidyStatus;
  final String? assignedStaff;
  final String customerScope; // 'Active', 'Completed', 'All'
  final String searchQuery;
  final String sortBy; // 'days', 'app_date', 'submit_date', 'priority', 'stage', 'status', 'name'
  final bool sortAscending;

  const ReportFilterOptions({
    this.applicationDateFrom,
    this.applicationDateTo,
    this.submitDateFrom,
    this.submitDateTo,
    this.workStage,
    this.status,
    this.priority,
    this.loanStatus,
    this.loanSubStage,
    this.installationStatus,
    this.rtsStatus,
    this.subsidyStatus,
    this.assignedStaff,
    this.customerScope = 'Active',
    this.searchQuery = '',
    this.sortBy = 'days',
    this.sortAscending = false,
  });

  bool get hasActiveFilters =>
      applicationDateFrom != null ||
      applicationDateTo != null ||
      submitDateFrom != null ||
      submitDateTo != null ||
      (workStage != null && workStage!.isNotEmpty) ||
      (status != null && status!.isNotEmpty) ||
      (priority != null && priority!.isNotEmpty) ||
      (loanStatus != null && loanStatus!.isNotEmpty) ||
      (loanSubStage != null && loanSubStage!.isNotEmpty) ||
      (installationStatus != null && installationStatus!.isNotEmpty) ||
      (rtsStatus != null && rtsStatus!.isNotEmpty) ||
      (subsidyStatus != null && subsidyStatus!.isNotEmpty) ||
      (assignedStaff != null && assignedStaff!.isNotEmpty) ||
      searchQuery.trim().isNotEmpty;

  ReportFilterOptions copyWith({
    DateTime? applicationDateFrom,
    DateTime? applicationDateTo,
    DateTime? submitDateFrom,
    DateTime? submitDateTo,
    String? workStage,
    String? status,
    String? priority,
    String? loanStatus,
    String? loanSubStage,
    String? installationStatus,
    String? rtsStatus,
    String? subsidyStatus,
    String? assignedStaff,
    String? customerScope,
    String? searchQuery,
    String? sortBy,
    bool? sortAscending,
    bool clearAppDate = false,
    bool clearSubmitDate = false,
    bool clearStage = false,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearLoan = false,
    bool clearLoanSubStage = false,
    bool clearInstallation = false,
    bool clearRts = false,
    bool clearSubsidy = false,
    bool clearStaff = false,
  }) {
    return ReportFilterOptions(
      applicationDateFrom: clearAppDate ? null : (applicationDateFrom ?? this.applicationDateFrom),
      applicationDateTo: clearAppDate ? null : (applicationDateTo ?? this.applicationDateTo),
      submitDateFrom: clearSubmitDate ? null : (submitDateFrom ?? this.submitDateFrom),
      submitDateTo: clearSubmitDate ? null : (submitDateTo ?? this.submitDateTo),
      workStage: clearStage ? null : (workStage ?? this.workStage),
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      loanStatus: clearLoan ? null : (loanStatus ?? this.loanStatus),
      loanSubStage: clearLoanSubStage ? null : (loanSubStage ?? this.loanSubStage),
      installationStatus: clearInstallation ? null : (installationStatus ?? this.installationStatus),
      rtsStatus: clearRts ? null : (rtsStatus ?? this.rtsStatus),
      subsidyStatus: clearSubsidy ? null : (subsidyStatus ?? this.subsidyStatus),
      assignedStaff: clearStaff ? null : (assignedStaff ?? this.assignedStaff),
      customerScope: customerScope ?? this.customerScope,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}
