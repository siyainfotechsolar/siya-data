import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/models/lead_record.dart';
import 'package:mobile_app/services/workflow_engine.dart';

void main() {
  group('Non-Subsidy Site Support - ConsumerRecord Model Tests', () {
    test('Default siteType is Subsidy', () {
      final record = ConsumerRecord(
        consumerNo: '096590001601',
        name: 'Ramesh Patil',
      );

      expect(record.siteType, equals('Subsidy'));
      expect(record.isSubsidy, isTrue);
      expect(record.isNonSubsidy, isFalse);
    });

    test('Non-Subsidy record sets flags and properties correctly', () {
      final record = ConsumerRecord(
        consumerNo: '096590001602',
        name: 'Suresh Shinde',
        siteType: 'Non-Subsidy',
        systemCapacity: '5 kW',
        systemType: 'On-Grid',
      );

      expect(record.siteType, equals('Non-Subsidy'));
      expect(record.isNonSubsidy, isTrue);
      expect(record.isSubsidy, isFalse);
      expect(record.systemCapacity, equals('5 kW'));
      expect(record.systemType, equals('On-Grid'));
    });

    test('toJson and fromJson roundtrip preserves site_type, capacity, and system_type', () {
      final original = ConsumerRecord(
        id: 'cust_ns_01',
        consumerNo: '096590001603',
        name: 'Anita Deshmukh',
        mobile: '9876543210',
        address: 'Barsi, Solapur',
        siteType: 'Non-Subsidy',
        systemCapacity: '10 kW',
        systemType: 'Hybrid',
        totalAmount: 450000.0,
        paidAmount: 200000.0,
        pendingAmount: 250000.0,
      );

      final json = original.toJson(includeId: true);
      expect(json['site_type'], equals('Non-Subsidy'));
      expect(json['system_capacity'], equals('10 kW'));
      expect(json['system_type'], equals('Hybrid'));

      final parsed = ConsumerRecord.fromJson(json);
      expect(parsed.id, equals('cust_ns_01'));
      expect(parsed.name, equals('Anita Deshmukh'));
      expect(parsed.siteType, equals('Non-Subsidy'));
      expect(parsed.isNonSubsidy, isTrue);
      expect(parsed.systemCapacity, equals('10 kW'));
      expect(parsed.systemType, equals('Hybrid'));
    });

    test('copyWith updates siteType and system specifications', () {
      final original = ConsumerRecord(
        consumerNo: '096590001604',
        name: 'Vijay Kadam',
      );
      expect(original.isSubsidy, isTrue);

      final updated = original.copyWith(
        siteType: 'Non-Subsidy',
        systemCapacity: '3 kW',
        systemType: 'Off-Grid',
      );

      expect(updated.isNonSubsidy, isTrue);
      expect(updated.siteType, equals('Non-Subsidy'));
      expect(updated.systemCapacity, equals('3 kW'));
      expect(updated.systemType, equals('Off-Grid'));
      expect(updated.consumerNo, equals('096590001604'));
    });
  });

  group('Non-Subsidy Site Support - LeadRecord Model Tests', () {
    test('Default Lead siteType is Subsidy', () {
      final lead = LeadRecord(
        id: 'lead_01',
        customerName: 'Kishor Kale',
        mobileNo: '9822001122',
        leadSource: 'Call',
        interestedIn: 'On-Grid',
        leadStatus: 'New',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(lead.siteType, equals('Subsidy'));
      expect(lead.isSubsidy, isTrue);
      expect(lead.isNonSubsidy, isFalse);
    });

    test('Lead with Non-Subsidy siteType serializes and deserializes', () {
      final lead = LeadRecord(
        id: 'lead_02',
        customerName: 'Pooja Jadhav',
        mobileNo: '9822334455',
        leadSource: 'Reference',
        interestedIn: 'Hybrid',
        leadStatus: 'Site Survey',
        siteType: 'Non-Subsidy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(lead.siteType, equals('Non-Subsidy'));
      expect(lead.isNonSubsidy, isTrue);

      final json = lead.toJson();
      expect(json['site_type'], equals('Non-Subsidy'));

      final parsed = LeadRecord.fromJson(json);
      expect(parsed.siteType, equals('Non-Subsidy'));
      expect(parsed.isNonSubsidy, isTrue);
    });
  });

  group('Non-Subsidy Site Support - Workflow Engine Progression', () {
    test('Non-subsidy customer is considered completed once installation is completed', () {
      final nonSubsidyRecord = ConsumerRecord(
        consumerNo: '096590001605',
        name: 'Manoj Chavan',
        siteType: 'Non-Subsidy',
        applicationStatus: 'Approved',
        agreementStatus: 'Completed',
        loanRequired: 'No',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Pending',
        subsidyStatus: 'Not Applied',
      );

      // In WorkflowEngine, Non-Subsidy skips subsidy requirement
      final isDone = WorkflowEngine.isWorkCompleted(nonSubsidyRecord);
      expect(isDone, isTrue);

      final currentStage = WorkflowEngine.getCurrentWorkStage(nonSubsidyRecord);
      expect(currentStage, equals('Completed'));
    });

    test('Subsidy customer requires subsidy completion to be considered completed', () {
      final subsidyRecord = ConsumerRecord(
        consumerNo: '096590001606',
        name: 'Sunil Pawar',
        siteType: 'Subsidy',
        applicationStatus: 'Approved',
        agreementStatus: 'Completed',
        loanRequired: 'No',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Pending',
      );

      final isDone = WorkflowEngine.isWorkCompleted(subsidyRecord);
      expect(isDone, isFalse);

      final currentStage = WorkflowEngine.getCurrentWorkStage(subsidyRecord);
      expect(currentStage, equals('Subsidy'));
    });

    test('getStageStates marks Subsidy stage as skipped for Non-Subsidy records', () {
      final nonSubsidyRecord = ConsumerRecord(
        consumerNo: '096590001607',
        name: 'Sunita More',
        siteType: 'Non-Subsidy',
        applicationStatus: 'Approved',
        agreementStatus: 'Completed',
        installationStatus: 'Installation Completed',
      );

      final states = WorkflowEngine.getStageStates(nonSubsidyRecord);
      expect(states[WorkflowStage.subsidy]?.state, equals(StageState.skipped));
      expect(states[WorkflowStage.subsidy]?.isUnlocked, isFalse);
    });
  });

  group('Above 6 kW is 3-Phase & Non-Subsidy DCR Not Required Rules', () {
    test('Capacity > 6 kW is 3-Phase (415V, 50Hz)', () {
      final record8Kw = ConsumerRecord(
        consumerNo: '096590001608',
        name: 'Ganesh Shinde',
        systemCapacity: '8 kW',
        siteType: 'Non-Subsidy',
      );

      expect(record8Kw.capacityKw, equals(8.0));
      expect(record8Kw.isThreePhase, isTrue);
      expect(record8Kw.electricalPhase, equals('3-Phase'));
      expect(record8Kw.phaseVoltage, equals('3-Phase 415V, 50Hz'));
      expect(record8Kw.isNonSubsidy, isTrue);
      expect(record8Kw.isDcrRequired, isFalse);
    });

    test('Capacity <= 6 kW is 1-Phase (230V, 50Hz)', () {
      final record3Kw = ConsumerRecord(
        consumerNo: '096590001609',
        name: 'Sachin Patil',
        systemCapacity: '3 kW',
        siteType: 'Subsidy',
      );

      expect(record3Kw.capacityKw, equals(3.0));
      expect(record3Kw.isThreePhase, isFalse);
      expect(record3Kw.electricalPhase, equals('1-Phase'));
      expect(record3Kw.phaseVoltage, equals('1-Phase 230V, 50Hz'));
      expect(record3Kw.isSubsidy, isTrue);
      expect(record3Kw.isDcrRequired, isTrue);

      final record6Kw = ConsumerRecord(
        consumerNo: '096590001610',
        name: 'Nitin Deshmukh',
        systemCapacity: '6 kW',
        siteType: 'Subsidy',
      );

      expect(record6Kw.capacityKw, equals(6.0));
      expect(record6Kw.isThreePhase, isFalse);
      expect(record6Kw.electricalPhase, equals('1-Phase'));
    });

    test('LeadRecord capacity, 3-phase and DCR flags work properly', () {
      final leadLarge = LeadRecord(
        id: 'lead_large',
        customerName: 'Kailas Sugar Factory',
        mobileNo: '9822114477',
        leadSource: 'Field',
        interestedIn: 'On-Grid',
        approxSystemSize: '10 kW',
        siteType: 'Non-Subsidy',
        leadStatus: 'Quotation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(leadLarge.capacityKw, equals(10.0));
      expect(leadLarge.isThreePhase, isTrue);
      expect(leadLarge.electricalPhase, equals('3-Phase'));
      expect(leadLarge.phaseVoltage, equals('3-Phase 415V, 50Hz'));
      expect(leadLarge.isNonSubsidy, isTrue);
      expect(leadLarge.isDcrRequired, isFalse);
    });
  });
}
