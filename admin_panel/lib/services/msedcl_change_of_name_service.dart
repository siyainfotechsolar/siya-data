import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/msedcl_change_of_name.dart';
import '../models/consumer_record.dart';
import '../utils/consumer_no_utils.dart';
import 'supabase_service.dart';
import 'team_work_service.dart';

class MsedclChangeOfNameService {
  static SupabaseClient get _client => SupabaseService.client;

  // In-memory cache for fast local access, offline fallback, and unit test execution
  static final List<MsedclChangeOfNameApplication> _applicationCache = [];

  /// Reset cache (useful for testing)
  static void resetCacheForTesting() {
    _applicationCache.clear();
  }

  /// Default seed applications for demo and immediate out-of-the-box readiness
  static List<MsedclChangeOfNameApplication> get defaultSeedApplications {
    final now = DateTime.now();
    return [
      MsedclChangeOfNameApplication(
        id: 'seed-app-001',
        applicationNo: 'MSEDCL-CN-202611-001',
        applicationDate: now.subtract(const Duration(days: 4)),
        subDivisionOffice: 'Nardana Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Nardana',
        reasonForChange: MsedclReasonForChange.purchaseOfProperty,
        assignedEmployee: 'Rahul',
        remarks: 'Registered Sale deed and electricity bill attached. Client requested urgent name change.',
        status: MsedclApplicationStatus.submitted,
        statusHistory: [
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.newEntry,
            timestamp: now.subtract(const Duration(days: 4)),
            updatedBy: 'Rahul',
            remarks: 'Application created with customer details',
          ),
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.docsCompleted,
            timestamp: now.subtract(const Duration(days: 3)),
            updatedBy: 'Rahul',
            remarks: 'All 7/12, Sale deed, and Tax receipts verified',
          ),
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.submitted,
            timestamp: now.subtract(const Duration(days: 1)),
            updatedBy: 'Rahul',
            remarks: 'Physical Form U and Affidavit submitted at Nardana Sub-Division counter',
          ),
        ],
        // Old Consumer
        oldFirstName: 'AALIEM',
        oldFatherOrHusbandName: 'BABUMIYA',
        oldSurname: 'PATEL',
        oldConsumerFullName: 'AALIEM BABUMIYA PATEL',
        consumerNo: '096570003663',
        oldMobileNo: '9822334455',
        oldMeterNo: 'MTR-782190',
        // New Consumer
        newFirstName: 'RAJU',
        newFatherOrHusbandName: 'VASANT',
        newSurname: 'CHAUDHARI',
        newConsumerFullName: 'RAJU VASANT CHAUDHARI',
        newAge: 42,
        newMobileNo: '9423187654',
        newPhoneNo: '02562-234567',
        newEmail: 'raju.chaudhari@gmail.com',
        newAadhaarNo: '4567 8901 2345',
        propertyAddress: 'Plot No. 14, Gat No. 89, Near Gram Panchayat, Nardana, Tal. Shindkheda, Dist. Dhule',
        // Stamp Paper Configuration
        stampPaperValue: 100.0,
        stampPaperState: 'Maharashtra',
        stampPaperLanguage: 'Marathi',
        isPhysicalStampPaper: false,
        stampTopMarginMm: 0.0,
        affidavitPlace: 'Nardana',
        // Form X Configuration
        formXOption: 'transfer',
        oldConsumerConsent: true,
        // Documents
        documents: [
          MsedclDocumentItem(
            docType: MsedclDocumentType.electricityBill,
            status: 'Received',
            fileName: 'electricity_bill_oct2026.pdf',
            notes: 'October 2026 paid bill, Zero arrears',
            uploadedAt: now.subtract(const Duration(days: 4)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.ownershipProof,
            status: 'Received',
            fileName: 'registered_sale_deed_plot14.pdf',
            notes: 'Registered Sale Deed No. 1245/2026',
            uploadedAt: now.subtract(const Duration(days: 4)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.extract712,
            status: 'Received',
            fileName: '7_12_extract_gat89.pdf',
            notes: 'Digital 7/12 extract with QR code',
            uploadedAt: now.subtract(const Duration(days: 4)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.propertyTaxReceipt,
            status: 'Received',
            fileName: 'grampanchayat_tax_receipt.pdf',
            notes: 'FY 2026-27 Grampanchayat Tax Receipt',
            uploadedAt: now.subtract(const Duration(days: 3)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.occupancyCertificate,
            status: 'Not Applicable',
            notes: 'Rural residential house',
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.leaseAgreement,
            status: 'Not Applicable',
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.successionOrWill,
            status: 'Not Applicable',
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.affidavitGazette,
            status: 'Received',
            fileName: 'stamp_paper_affidavit_100.pdf',
            notes: '₹100 Non-Judicial Stamp Paper Affidavit',
            uploadedAt: now.subtract(const Duration(days: 3)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.ownerNoc,
            status: 'Not Applicable',
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.other,
            status: 'Received',
            fileName: 'aadhar_card_raju_chaudhari.pdf',
            notes: 'New Consumer Aadhaar card copy',
            uploadedAt: now.subtract(const Duration(days: 4)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      MsedclChangeOfNameApplication(
        id: 'seed-app-002',
        applicationNo: 'MSEDCL-CN-202611-002',
        applicationDate: now.subtract(const Duration(days: 2)),
        subDivisionOffice: 'Shindkheda Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Shindkheda',
        reasonForChange: MsedclReasonForChange.inheritance,
        assignedEmployee: 'Rahul',
        remarks: 'Father passed away. Legal heir succession and death certificate attached.',
        status: MsedclApplicationStatus.docsPending,
        statusHistory: [
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.newEntry,
            timestamp: now.subtract(const Duration(days: 2)),
            updatedBy: 'Rahul',
            remarks: 'Application created, waiting for Form 8-A and Death certificate',
          ),
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.docsPending,
            timestamp: now.subtract(const Duration(days: 2)),
            updatedBy: 'Rahul',
            remarks: 'Death Certificate uploaded. Grampanchayat Form 8 pending.',
          ),
        ],
        // Old Consumer
        oldFirstName: 'Aanandrao',
        oldFatherOrHusbandName: 'Namdev',
        oldSurname: 'Patil',
        oldConsumerFullName: 'Aanandrao Namdev Patil',
        consumerNo: '094660000245',
        oldMobileNo: '9876543210',
        oldMeterNo: 'MTR-554421',
        // New Consumer
        newFirstName: 'SUNIL',
        newFatherOrHusbandName: 'AANANDRAO',
        newSurname: 'PATIL',
        newConsumerFullName: 'SUNIL AANANDRAO PATIL',
        newAge: 38,
        newMobileNo: '9823456789',
        newPhoneNo: '',
        newEmail: 'sunil.patil@rediffmail.com',
        newAadhaarNo: '6789 0123 4567',
        propertyAddress: 'Main Road, Near Water Tank, Ghotane, Tal. Shindkheda, Dist. Dhule',
        // Stamp Paper Configuration
        stampPaperValue: 100.0,
        stampPaperState: 'Maharashtra',
        stampPaperLanguage: 'Marathi',
        isPhysicalStampPaper: false,
        stampTopMarginMm: 0.0,
        affidavitPlace: 'Shindkheda',
        // Form X Configuration
        formXOption: 'transfer',
        oldConsumerConsent: true,
        // Documents
        documents: [
          MsedclDocumentItem(
            docType: MsedclDocumentType.electricityBill,
            status: 'Received',
            fileName: 'current_bill.pdf',
            notes: 'Latest bill with zero dues',
            uploadedAt: now.subtract(const Duration(days: 2)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.extract712,
            status: 'Received',
            fileName: '7_12_ferfar_patrak.pdf',
            notes: 'Ferfar entry showing legal heirs',
            uploadedAt: now.subtract(const Duration(days: 2)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.successionOrWill,
            status: 'Received',
            fileName: 'varas_pramanpatra.pdf',
            notes: 'Legal Heir / Varas certificate from Tahsildar',
            uploadedAt: now.subtract(const Duration(days: 2)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.form8,
            status: 'Pending',
            notes: 'Grampanchayat Namuna 8 awaited',
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.affidavitGazette,
            status: 'Pending',
            notes: '₹100 Stamp Paper Affidavit to be printed and signed',
          ),
        ],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      MsedclChangeOfNameApplication(
        id: 'seed-app-003',
        applicationNo: 'MSEDCL-CN-202611-003',
        applicationDate: now.subtract(const Duration(days: 10)),
        subDivisionOffice: 'Dhule Rural Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Dhule',
        reasonForChange: MsedclReasonForChange.purchaseOfProperty,
        assignedEmployee: 'Rahul',
        remarks: 'Name change successfully processed and updated in MSEDCL billing system.',
        status: MsedclApplicationStatus.nameChanged,
        statusHistory: [
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.newEntry,
            timestamp: now.subtract(const Duration(days: 10)),
            updatedBy: 'Rahul',
            remarks: 'Application created',
          ),
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.submitted,
            timestamp: now.subtract(const Duration(days: 8)),
            updatedBy: 'Rahul',
            remarks: 'Submitted at Dhule Rural Office',
          ),
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.approved,
            timestamp: now.subtract(const Duration(days: 3)),
            updatedBy: 'Rahul',
            remarks: 'MSEDCL approved change of name',
          ),
          MsedclStatusHistoryEntry(
            status: MsedclApplicationStatus.nameChanged,
            timestamp: now.subtract(const Duration(days: 1)),
            updatedBy: 'Rahul',
            remarks: 'Updated bill received in new consumer name',
          ),
        ],
        // Old Consumer
        oldFirstName: 'Prakash',
        oldFatherOrHusbandName: 'Kisan',
        oldSurname: 'Shinde',
        oldConsumerFullName: 'Prakash Kisan Shinde',
        consumerNo: '097030120005',
        oldMobileNo: '9890123456',
        oldMeterNo: 'MTR-998877',
        // New Consumer
        newFirstName: 'VIJAY',
        newFatherOrHusbandName: 'RAMESH',
        newSurname: 'MORE',
        newConsumerFullName: 'VIJAY RAMESH MORE',
        newAge: 45,
        newMobileNo: '9922334455',
        newPhoneNo: '',
        newEmail: 'vijay.more@gmail.com',
        newAadhaarNo: '8901 2345 6789',
        propertyAddress: 'House No. 45, Near Hanuman Temple, Songir, Tal. Dhule, Dist. Dhule',
        // Stamp Paper Configuration
        stampPaperValue: 100.0,
        stampPaperState: 'Maharashtra',
        stampPaperLanguage: 'Marathi',
        isPhysicalStampPaper: false,
        stampTopMarginMm: 0.0,
        affidavitPlace: 'Dhule',
        // Form X Configuration
        formXOption: 'transfer',
        oldConsumerConsent: true,
        // Documents
        documents: [
          MsedclDocumentItem(
            docType: MsedclDocumentType.electricityBill,
            status: 'Received',
            fileName: 'paid_bill.pdf',
            notes: 'Latest bill with zero arrears',
            uploadedAt: now.subtract(const Duration(days: 10)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.ownershipProof,
            status: 'Received',
            fileName: 'sale_deed.pdf',
            notes: 'Registered Sale deed copy',
            uploadedAt: now.subtract(const Duration(days: 10)),
          ),
          MsedclDocumentItem(
            docType: MsedclDocumentType.affidavitGazette,
            status: 'Received',
            fileName: 'affidavit.pdf',
            notes: 'Notarized affidavit on ₹100 stamp',
            uploadedAt: now.subtract(const Duration(days: 9)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Fetch all applications with optional search and filters
  static Future<List<MsedclChangeOfNameApplication>> fetchApplications({
    String? status,
    String? subDivision,
    String? employee,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = _client.from('msedcl_name_change_applications').select('*');
      final response = await query.order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final list = data.map((json) => MsedclChangeOfNameApplication.fromJson(json as Map<String, dynamic>)).toList();

      if (list.isNotEmpty) {
        _applicationCache.clear();
        _applicationCache.addAll(list);
      } else if (_applicationCache.isEmpty) {
        _applicationCache.addAll(defaultSeedApplications);
      }
    } catch (e) {
      // ignore: avoid_print
      print('MsedclChangeOfNameService.fetchApplications fallback: $e');
      if (_applicationCache.isEmpty) {
        _applicationCache.addAll(defaultSeedApplications);
      }
    }

    var result = List<MsedclChangeOfNameApplication>.from(_applicationCache);

    // Apply status filter
    if (status != null && status != 'All' && status.isNotEmpty) {
      result = result.where((a) => a.status.toLowerCase() == status.toLowerCase()).toList();
    }

    // Apply sub-division filter
    if (subDivision != null && subDivision != 'All' && subDivision.isNotEmpty) {
      result = result.where((a) => a.subDivisionOffice.toLowerCase().contains(subDivision.toLowerCase())).toList();
    }

    // Apply employee filter
    if (employee != null && employee != 'All' && employee.isNotEmpty) {
      result = result.where((a) => a.assignedEmployee.toLowerCase() == employee.toLowerCase()).toList();
    }

    // Apply date range
    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      result = result.where((a) => a.applicationDate.isAfter(start.subtract(const Duration(seconds: 1)))).toList();
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      result = result.where((a) => a.applicationDate.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    // Apply search query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((a) {
        return a.applicationNo.toLowerCase().contains(q) ||
            a.consumerNo.toLowerCase().contains(q) ||
            a.oldConsumerFullName.toLowerCase().contains(q) ||
            a.newConsumerFullName.toLowerCase().contains(q) ||
            a.village.toLowerCase().contains(q) ||
            a.newMobileNo.contains(q) ||
            a.propertyAddress.toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  /// Generate next unique application number
  static String generateNextApplicationNo() {
    final now = DateTime.now();
    final yearMonth = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final count = _applicationCache.length + 1;
    final numStr = count.toString().padLeft(3, '0');
    return 'MSEDCL-CN-$yearMonth-$numStr';
  }

  /// Save or Update application
  static Future<MsedclChangeOfNameApplication> saveApplication(
    MsedclChangeOfNameApplication application, {
    String updatedBy = 'Admin',
    String? changeRemarks,
  }) async {
    final isNew = application.id.isEmpty || application.id.startsWith('seed-') || application.id.startsWith('temp-');
    final String targetId = isNew ? DateTime.now().millisecondsSinceEpoch.toString() : application.id;

    // Check application number
    String appNo = application.applicationNo;
    if (appNo.isEmpty) {
      appNo = generateNextApplicationNo();
    }

    // Update status history
    final history = List<MsedclStatusHistoryEntry>.from(application.statusHistory);
    if (isNew && history.isEmpty) {
      history.add(MsedclStatusHistoryEntry(
        status: application.status,
        timestamp: DateTime.now(),
        updatedBy: updatedBy,
        remarks: changeRemarks ?? 'Application created',
      ));
    } else if (changeRemarks != null && changeRemarks.isNotEmpty) {
      history.add(MsedclStatusHistoryEntry(
        status: application.status,
        timestamp: DateTime.now(),
        updatedBy: updatedBy,
        remarks: changeRemarks,
      ));
    }

    final toSave = application.copyWith(
      id: targetId,
      applicationNo: appNo,
      statusHistory: history,
      updatedAt: DateTime.now(),
    );

    try {
      if (isNew) {
        final payload = toSave.toJson();
        payload.remove('id');
        final res = await _client.from('msedcl_name_change_applications').insert(payload).select().single();
        final saved = MsedclChangeOfNameApplication.fromJson(res);
        _applicationCache.removeWhere((a) => a.id == targetId || a.applicationNo == appNo);
        _applicationCache.insert(0, saved);
        return saved;
      } else {
        final res = await _client
            .from('msedcl_name_change_applications')
            .update(toSave.toJson())
            .eq('id', toSave.id)
            .select()
            .single();
        final saved = MsedclChangeOfNameApplication.fromJson(res);
        final idx = _applicationCache.indexWhere((a) => a.id == saved.id);
        if (idx >= 0) {
          _applicationCache[idx] = saved;
        } else {
          _applicationCache.insert(0, saved);
        }
        return saved;
      }
    } catch (e) {
      // ignore: avoid_print
      print('MsedclChangeOfNameService.saveApplication fallback: $e');
      final idx = _applicationCache.indexWhere((a) => a.id == toSave.id || a.applicationNo == toSave.applicationNo);
      if (idx >= 0) {
        _applicationCache[idx] = toSave;
      } else {
        _applicationCache.insert(0, toSave);
      }
      return toSave;
    }
  }

  /// Update application status with audit log
  static Future<MsedclChangeOfNameApplication?> updateStatus({
    required String id,
    required String newStatus,
    required String updatedBy,
    required String remarks,
  }) async {
    final idx = _applicationCache.indexWhere((a) => a.id == id);
    if (idx < 0) return null;

    final app = _applicationCache[idx];
    final updatedHistory = List<MsedclStatusHistoryEntry>.from(app.statusHistory)
      ..add(MsedclStatusHistoryEntry(
        status: newStatus,
        timestamp: DateTime.now(),
        updatedBy: updatedBy,
        remarks: remarks,
      ));

    final updatedApp = app.copyWith(
      status: newStatus,
      statusHistory: updatedHistory,
      updatedAt: DateTime.now(),
    );

    return await saveApplication(updatedApp, updatedBy: updatedBy);
  }

  /// Delete application
  static Future<bool> deleteApplication(String id) async {
    try {
      await _client.from('msedcl_name_change_applications').delete().eq('id', id);
      _applicationCache.removeWhere((a) => a.id == id);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('MsedclChangeOfNameService.deleteApplication fallback: $e');
      _applicationCache.removeWhere((a) => a.id == id);
      return true;
    }
  }

  /// Fetch Customer Master records from Customer Master for fast autocomplete & preselection
  static Future<List<ConsumerRecord>> fetchAvailableCustomers() async {
    return await TeamWorkService.fetchAvailableCustomers();
  }

  /// Find customer by consumer number
  static ConsumerRecord? findCustomerByConsumerNo(List<ConsumerRecord> customers, String consumerNo) {
    final norm = ConsumerNoNormalizer.normalize(consumerNo);
    return customers.cast<ConsumerRecord?>().firstWhere(
          (c) => c != null && ConsumerNoNormalizer.normalize(c.consumerNo) == norm,
          orElse: () => null,
        );
  }
}
