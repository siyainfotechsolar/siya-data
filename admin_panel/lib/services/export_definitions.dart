import '../models/consumer_record.dart';
import '../models/lead_record.dart';
import '../models/customer_issue.dart';
import '../models/customer_misc_action.dart';
import '../models/customer_payment.dart';
import 'excel_export_service.dart';

class ExportDefinitions {
  /// 1. Comprehensive Consumer Records Columns
  static final List<ExcelColumnDef<ConsumerRecord>> consumerRecordColumns = [
    ExcelColumnDef<ConsumerRecord>(header: 'Customer Name', valueExtractor: (r) => r.name),
    ExcelColumnDef<ConsumerRecord>(header: 'Consumer No', valueExtractor: (r) => r.consumerNo),
    ExcelColumnDef<ConsumerRecord>(header: 'Application ID', valueExtractor: (r) => r.applicationId),
    ExcelColumnDef<ConsumerRecord>(header: 'Mobile', valueExtractor: (r) => r.mobile),
    ExcelColumnDef<ConsumerRecord>(header: 'Address / Village', valueExtractor: (r) => r.address),
    ExcelColumnDef<ConsumerRecord>(header: 'Application Date', valueExtractor: (r) => r.applicationDate ?? r.submitDate),
    ExcelColumnDef<ConsumerRecord>(header: 'Application Days', valueExtractor: (r) => r.applicationDays),
    ExcelColumnDef<ConsumerRecord>(header: 'Current Work Stage', valueExtractor: (r) => r.overallStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Sub-Stage', valueExtractor: (r) => r.currentSubStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Days in Stage', valueExtractor: (r) => r.daysInCurrentStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Priority', valueExtractor: (r) => r.priorityCategory),
    ExcelColumnDef<ConsumerRecord>(header: 'Action Required', valueExtractor: (r) => r.actionRequired),
    ExcelColumnDef<ConsumerRecord>(header: 'Next Action', valueExtractor: (r) => r.nextAction),
    ExcelColumnDef<ConsumerRecord>(header: 'Assigned Staff', valueExtractor: (r) => r.assignedStaff),
    ExcelColumnDef<ConsumerRecord>(header: 'Installer Team', valueExtractor: (r) => r.installerTeam),
    ExcelColumnDef<ConsumerRecord>(header: 'Agreement Status', valueExtractor: (r) => r.agreementStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'Loan Required', valueExtractor: (r) => r.loanRequired),
    ExcelColumnDef<ConsumerRecord>(header: 'Loan Status', valueExtractor: (r) => r.loanStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'Installation Status', valueExtractor: (r) => r.installationStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'RTS Status', valueExtractor: (r) => r.rtsStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'Subsidy Status', valueExtractor: (r) => r.subsidyStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'Total Amount', valueExtractor: (r) => r.totalAmount, isCurrency: true),
    ExcelColumnDef<ConsumerRecord>(header: 'Paid Amount', valueExtractor: (r) => r.paidAmount, isCurrency: true),
    ExcelColumnDef<ConsumerRecord>(header: 'Pending Amount', valueExtractor: (r) => r.pendingAmount, isCurrency: true),
    ExcelColumnDef<ConsumerRecord>(header: 'Payment Status', valueExtractor: (r) => r.paymentStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'Follow-up Date', valueExtractor: (r) => r.followupDate),
    ExcelColumnDef<ConsumerRecord>(header: 'Follow-up Remarks', valueExtractor: (r) => r.followupRemarks),
    ExcelColumnDef<ConsumerRecord>(header: 'Status', valueExtractor: (r) => r.status),
    ExcelColumnDef<ConsumerRecord>(header: 'Remarks', valueExtractor: (r) => r.remarks),
  ];

  /// 2. Action Center Operational Queue Columns
  static final List<ExcelColumnDef<ConsumerRecord>> actionCenterColumns = [
    ExcelColumnDef<ConsumerRecord>(header: 'Customer Name', valueExtractor: (r) => r.name),
    ExcelColumnDef<ConsumerRecord>(header: 'Consumer No', valueExtractor: (r) => r.consumerNo),
    ExcelColumnDef<ConsumerRecord>(header: 'Mobile', valueExtractor: (r) => r.mobile),
    ExcelColumnDef<ConsumerRecord>(header: 'Village / Address', valueExtractor: (r) => r.address),
    ExcelColumnDef<ConsumerRecord>(header: 'Current Stage', valueExtractor: (r) => r.overallStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Sub-Stage', valueExtractor: (r) => r.currentSubStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Days in Stage', valueExtractor: (r) => r.daysInCurrentStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Priority', valueExtractor: (r) => r.priorityCategory),
    ExcelColumnDef<ConsumerRecord>(header: 'Action Required', valueExtractor: (r) => r.actionRequired),
    ExcelColumnDef<ConsumerRecord>(header: 'Why Action Required', valueExtractor: (r) => r.remarks ?? r.followupReason ?? '—'),
    ExcelColumnDef<ConsumerRecord>(header: 'Next Action', valueExtractor: (r) => r.nextAction),
    ExcelColumnDef<ConsumerRecord>(header: 'Assigned Staff', valueExtractor: (r) => r.assignedStaff),
    ExcelColumnDef<ConsumerRecord>(header: 'Follow-up Date', valueExtractor: (r) => r.followupDate),
    ExcelColumnDef<ConsumerRecord>(header: 'Due Date', valueExtractor: (r) => r.paymentDueDate ?? r.followupDate),
    ExcelColumnDef<ConsumerRecord>(header: 'Remarks', valueExtractor: (r) => r.remarks ?? r.followupRemarks),
  ];

  /// 3. Payment Tracking Columns (Record Level)
  static final List<ExcelColumnDef<ConsumerRecord>> paymentRecordColumns = [
    ExcelColumnDef<ConsumerRecord>(header: 'Customer Name', valueExtractor: (r) => r.name),
    ExcelColumnDef<ConsumerRecord>(header: 'Consumer No', valueExtractor: (r) => r.consumerNo),
    ExcelColumnDef<ConsumerRecord>(header: 'Mobile', valueExtractor: (r) => r.mobile),
    ExcelColumnDef<ConsumerRecord>(header: 'Total Amount', valueExtractor: (r) => r.totalAmount, isCurrency: true),
    ExcelColumnDef<ConsumerRecord>(header: 'Paid Amount', valueExtractor: (r) => r.paidAmount, isCurrency: true),
    ExcelColumnDef<ConsumerRecord>(header: 'Pending Amount', valueExtractor: (r) => r.pendingAmount, isCurrency: true),
    ExcelColumnDef<ConsumerRecord>(header: 'Payment Status', valueExtractor: (r) => r.paymentStatus),
    ExcelColumnDef<ConsumerRecord>(header: 'Due Date', valueExtractor: (r) => r.paymentDueDate),
    ExcelColumnDef<ConsumerRecord>(header: 'Current Stage', valueExtractor: (r) => r.overallStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Assigned Staff', valueExtractor: (r) => r.assignedStaff),
  ];

  /// 4. Payment Transactions Columns
  static final List<ExcelColumnDef<PaymentTransaction>> paymentTransactionColumns = [
    ExcelColumnDef<PaymentTransaction>(header: 'Receipt / Txn ID', valueExtractor: (t) => t.id?.substring(0, 8)),
    ExcelColumnDef<PaymentTransaction>(header: 'Consumer No', valueExtractor: (t) => t.consumerNo),
    ExcelColumnDef<PaymentTransaction>(header: 'Amount', valueExtractor: (t) => t.amount, isCurrency: true),
    ExcelColumnDef<PaymentTransaction>(header: 'Payment Date', valueExtractor: (t) => t.paymentDate),
    ExcelColumnDef<PaymentTransaction>(header: 'Payment Mode', valueExtractor: (t) => t.paymentMode),
    ExcelColumnDef<PaymentTransaction>(header: 'Reference No', valueExtractor: (t) => t.referenceNumber),
    ExcelColumnDef<PaymentTransaction>(header: 'Received By', valueExtractor: (t) => t.receivedBy),
    ExcelColumnDef<PaymentTransaction>(header: 'Status', valueExtractor: (t) => t.status),
    ExcelColumnDef<PaymentTransaction>(header: 'Remarks', valueExtractor: (t) => t.remarks),
  ];

  /// 5. Customer Issues / Support Tickets Columns
  static final List<ExcelColumnDef<CustomerIssue>> issueColumns = [
    ExcelColumnDef<CustomerIssue>(header: 'Ticket ID', valueExtractor: (i) => i.id?.substring(0, 8)),
    ExcelColumnDef<CustomerIssue>(header: 'Customer Name', valueExtractor: (i) => i.customerName),
    ExcelColumnDef<CustomerIssue>(header: 'Consumer No', valueExtractor: (i) => i.consumerNo),
    ExcelColumnDef<CustomerIssue>(header: 'Issue Title', valueExtractor: (i) => i.title),
    ExcelColumnDef<CustomerIssue>(header: 'Issue Type', valueExtractor: (i) => i.issueType),
    ExcelColumnDef<CustomerIssue>(header: 'Priority', valueExtractor: (i) => i.priority),
    ExcelColumnDef<CustomerIssue>(header: 'Status', valueExtractor: (i) => i.status),
    ExcelColumnDef<CustomerIssue>(header: 'Assigned Staff', valueExtractor: (i) => i.assignedStaff ?? 'Unassigned'),
    ExcelColumnDef<CustomerIssue>(header: 'Created At', valueExtractor: (i) => i.createdAt),
    ExcelColumnDef<CustomerIssue>(header: 'Resolution Remarks', valueExtractor: (i) => i.resolutionRemarks),
  ];

  /// 6. MISC Operational Actions Columns
  static final List<ExcelColumnDef<CustomerMiscAction>> miscActionColumns = [
    ExcelColumnDef<CustomerMiscAction>(header: 'Action ID', valueExtractor: (m) => m.id?.substring(0, 8)),
    ExcelColumnDef<CustomerMiscAction>(header: 'Customer Name', valueExtractor: (m) => m.customerName),
    ExcelColumnDef<CustomerMiscAction>(header: 'Consumer No', valueExtractor: (m) => m.consumerNo),
    ExcelColumnDef<CustomerMiscAction>(header: 'Reason / Title', valueExtractor: (m) => m.reason),
    ExcelColumnDef<CustomerMiscAction>(header: 'Description', valueExtractor: (m) => m.description),
    ExcelColumnDef<CustomerMiscAction>(header: 'Priority', valueExtractor: (m) => m.priority),
    ExcelColumnDef<CustomerMiscAction>(header: 'Status', valueExtractor: (m) => m.status),
    ExcelColumnDef<CustomerMiscAction>(header: 'Assigned Staff', valueExtractor: (m) => m.assignedStaffName ?? 'Unassigned'),
    ExcelColumnDef<CustomerMiscAction>(header: 'Due Date', valueExtractor: (m) => m.dueDate),
    ExcelColumnDef<CustomerMiscAction>(header: 'Remarks', valueExtractor: (m) => m.remarks),
  ];

  /// 7. Leads Management Columns
  static final List<ExcelColumnDef<LeadRecord>> leadRecordColumns = [
    ExcelColumnDef<LeadRecord>(header: 'Lead ID', valueExtractor: (l) => l.id.substring(0, 8)),
    ExcelColumnDef<LeadRecord>(header: 'Customer Name', valueExtractor: (l) => l.customerName),
    ExcelColumnDef<LeadRecord>(header: 'Mobile', valueExtractor: (l) => l.mobileNo),
    ExcelColumnDef<LeadRecord>(header: 'Village / City', valueExtractor: (l) => l.village),
    ExcelColumnDef<LeadRecord>(header: 'Interested In', valueExtractor: (l) => l.interestedIn),
    ExcelColumnDef<LeadRecord>(header: 'System Size', valueExtractor: (l) => l.approxSystemSize),
    ExcelColumnDef<LeadRecord>(header: 'Estimated Budget', valueExtractor: (l) => l.estimatedBudget, isCurrency: true),
    ExcelColumnDef<LeadRecord>(header: 'Lead Status', valueExtractor: (l) => l.leadStatus),
    ExcelColumnDef<LeadRecord>(header: 'Lead Source', valueExtractor: (l) => l.leadSource),
    ExcelColumnDef<LeadRecord>(header: 'Assigned Staff', valueExtractor: (l) => l.assignedStaffName ?? 'Unassigned'),
    ExcelColumnDef<LeadRecord>(header: 'Next Follow-up', valueExtractor: (l) => l.nextFollowupDate),
    ExcelColumnDef<LeadRecord>(header: 'Notes / Remarks', valueExtractor: (l) => l.remarks),
  ];

  /// 8. Centralized Follow-up Queue Columns (Consumer Record Follow-up View)
  static final List<ExcelColumnDef<ConsumerRecord>> followupRecordColumns = [
    ExcelColumnDef<ConsumerRecord>(header: 'Customer Name', valueExtractor: (r) => r.name),
    ExcelColumnDef<ConsumerRecord>(header: 'Consumer No', valueExtractor: (r) => r.consumerNo),
    ExcelColumnDef<ConsumerRecord>(header: 'Mobile', valueExtractor: (r) => r.mobile),
    ExcelColumnDef<ConsumerRecord>(header: 'Current Stage', valueExtractor: (r) => r.overallStage),
    ExcelColumnDef<ConsumerRecord>(header: 'Follow-up Date', valueExtractor: (r) => r.followupDate),
    ExcelColumnDef<ConsumerRecord>(header: 'Follow-up Reason', valueExtractor: (r) => r.followupReason),
    ExcelColumnDef<ConsumerRecord>(header: 'Follow-up Status', valueExtractor: (r) => r.isFollowupToday ? 'Today' : (r.isFollowupOverdue ? 'Overdue' : 'Upcoming')),
    ExcelColumnDef<ConsumerRecord>(header: 'Last Follow-up Result', valueExtractor: (r) => r.lastFollowupResult),
    ExcelColumnDef<ConsumerRecord>(header: 'Assigned Staff', valueExtractor: (r) => r.assignedStaff),
    ExcelColumnDef<ConsumerRecord>(header: 'Remarks', valueExtractor: (r) => r.followupRemarks),
  ];
}
