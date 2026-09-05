import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/lead_record.dart';

void main() {
  group('LeadRecord Model & Smart Next Actions', () {
    test('Correctly maps JSON to LeadRecord and back', () {
      final now = DateTime.now();
      final lead = LeadRecord(
        id: 'lead-123',
        customerName: 'Raj Patil',
        mobileNo: '9876543210',
        whatsappNo: '9876543210',
        village: 'Koregaon',
        taluka: 'Satara',
        district: 'Satara',
        leadSource: 'Call',
        interestedIn: 'On-Grid',
        approxSystemSize: '3 kW',
        monthlyElectricityBill: 3500.0,
        estimatedBudget: 180000.0,
        consumerNo: '028512345678',
        leadStatus: 'New',
        nextFollowupDate: now,
        assignedStaffName: 'Rihan',
        remarks: 'Customer interested in subsidy',
        createdAt: now,
        updatedAt: now,
      );

      final json = lead.toJson();
      expect(json['customer_name'], 'Raj Patil');
      expect(json['mobile_no'], '9876543210');
      expect(json['lead_source'], 'Call');
      expect(json['interested_in'], 'On-Grid');
      expect(json['lead_status'], 'New');

      final fromJson = LeadRecord.fromJson({
        'id': 'lead-123',
        ...json,
        'created_at': now.toIso8601String(),
      });

      expect(fromJson.id, 'lead-123');
      expect(fromJson.customerName, 'Raj Patil');
      expect(fromJson.fullAddress, 'Koregaon, Satara, Satara');
      expect(fromJson.isTerminalState, false);
    });

    test('Smart Next Action resolves accurately across stages', () {
      LeadRecord createWithStatus(String status) => LeadRecord(
            id: 'test',
            customerName: 'Test',
            mobileNo: '9999999999',
            leadSource: 'Call',
            interestedIn: 'On-Grid',
            leadStatus: status,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      expect(createWithStatus('New').smartNextAction, 'Contact Customer');
      expect(createWithStatus('Contacted').smartNextAction, 'Assess Requirement');
      expect(createWithStatus('Interested').smartNextAction, 'Schedule Site Survey');
      expect(createWithStatus('Site Survey').smartNextAction, 'Complete Survey & Quotation');
      expect(createWithStatus('Quotation').smartNextAction, 'Follow Up Quotation');
      expect(createWithStatus('Follow-up').smartNextAction, 'Call Customer');
      expect(createWithStatus('Converted').smartNextAction, 'None (Converted to Application)');
      expect(createWithStatus('Lost').smartNextAction, 'None (Lost Lead)');
      expect(createWithStatus('No Action Required').smartNextAction, 'None (On Hold)');
    });

    test('Follow-up urgency: Today, Overdue, and Terminal exclusions', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 3));
      final tomorrow = now.add(const Duration(days: 2));

      final overdueLead = LeadRecord(
        id: 'overdue-1',
        customerName: 'Amit',
        mobileNo: '9999999991',
        leadSource: 'Walk-in',
        interestedIn: 'Off-Grid',
        leadStatus: 'Follow-up',
        nextFollowupDate: yesterday,
        createdAt: now,
        updatedAt: now,
      );

      expect(overdueLead.isOverdue, true);
      expect(overdueLead.overdueDays >= 2, true);
      expect(overdueLead.isTodayFollowup, false);

      final todayLead = LeadRecord(
        id: 'today-1',
        customerName: 'Suresh',
        mobileNo: '9999999992',
        leadSource: 'WhatsApp',
        interestedIn: 'Hybrid',
        leadStatus: 'Interested',
        nextFollowupDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(todayLead.isTodayFollowup, true);
      expect(todayLead.isOverdue, false);

      final futureLead = LeadRecord(
        id: 'future-1',
        customerName: 'Ramesh',
        mobileNo: '9999999993',
        leadSource: 'Reference',
        interestedIn: 'Solar Pump',
        leadStatus: 'Site Survey',
        nextFollowupDate: tomorrow,
        createdAt: now,
        updatedAt: now,
      );

      expect(futureLead.isTodayFollowup, false);
      expect(futureLead.isOverdue, false);

      // Terminal state check: Converted, Lost, Hold must NEVER trigger overdue
      final lostOverdueLead = LeadRecord(
        id: 'lost-1',
        customerName: 'Ganesh',
        mobileNo: '9999999994',
        leadSource: 'Other',
        interestedIn: 'On-Grid',
        leadStatus: 'Lost',
        nextFollowupDate: yesterday,
        createdAt: now,
        updatedAt: now,
      );

      expect(lostOverdueLead.isTerminalState, true);
      expect(lostOverdueLead.isOverdue, false);
      expect(lostOverdueLead.isTodayFollowup, false);

      final holdLead = LeadRecord(
        id: 'hold-1',
        customerName: 'Sunil',
        mobileNo: '9999999995',
        leadSource: 'Other',
        interestedIn: 'On-Grid',
        leadStatus: 'No Action Required',
        nextFollowupDate: yesterday,
        createdAt: now,
        updatedAt: now,
      );

      expect(holdLead.isTerminalState, true);
      expect(holdLead.isNoActionRequired, true);
      expect(holdLead.isOverdue, false);
    });
  });
}
