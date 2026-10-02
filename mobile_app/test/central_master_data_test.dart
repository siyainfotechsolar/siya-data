import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';

void main() {
  group('Global Master Data — Mobile Single Source of Truth Tests', () {
    late ConsumerRecord masterCustomer;

    setUp(() {
      // Initialize default Company Master
      MasterDataHub.setCompanyMaster(CompanyMaster.defaultMaster());

      // Create initial Customer Master
      masterCustomer = ConsumerRecord(
        id: 'cust_001',
        consumerNo: '012345678901',
        name: 'RAMESHWAR KISANRAO PATIL',
        mobile: '9876543210',
        address: 'Plot 12, Main Road, Betawad',
        systemCapacity: '3 kW',
        systemType: 'On-Grid Solar System',
        totalAmount: 160000.0,
        loanRequired: 'Yes',
        loanSanctionedAmount: 144000.0,
        status: 'In Progress',
      );
    });

    test('1. Customer Profile update reflects automatically across Quotation, Invoice, WCR, Agreement & Receipt', () {
      final initialQuotation = MasterDataHub.hydrateQuotation(
        quotation: SolarQuotation.create(
          id: 'quot_1',
          consumerNo: masterCustomer.consumerNo,
          customerName: masterCustomer.name,
          totalSystemCost: 160000.0,
        ),
        customer: masterCustomer,
      );
      expect(initialQuotation.customerName, 'RAMESHWAR KISANRAO PATIL');
      expect(initialQuotation.mobileNo, '9876543210');
      expect(initialQuotation.systemCapacity, '3 kW');

      // User updates Customer Master (Name, Mobile, Address, Capacity)
      final updatedCustomer = masterCustomer.copyWith(
        name: 'RAMESHWAR KISAN PATIL (UPDATED)',
        mobile: '9988776655',
        address: 'New House 45, Betawad Shindkheda',
        systemCapacity: '5 kW',
      );

      final updatedQuotation = MasterDataHub.hydrateQuotation(
        quotation: initialQuotation,
        customer: updatedCustomer,
      );
      final updatedWcr = MasterDataHub.createWorkCompletionReport(customer: updatedCustomer);
      final updatedAgreement = MasterDataHub.createAgreement(customer: updatedCustomer);
      final updatedReceipt = MasterDataHub.createMarginReceipt(customer: updatedCustomer);

      expect(updatedQuotation.customerName, 'RAMESHWAR KISAN PATIL (UPDATED)');
      expect(updatedQuotation.mobileNo, '9988776655');
      expect(updatedQuotation.address, 'New House 45, Betawad Shindkheda');
      expect(updatedQuotation.systemCapacity, '5 kW');

      expect(updatedWcr.customerName, 'RAMESHWAR KISAN PATIL (UPDATED)');
      expect(updatedWcr.customerMobile, '9988776655');
      expect(updatedWcr.customerAddress, 'New House 45, Betawad Shindkheda');
      expect(updatedWcr.installedCapacityKw, 5.0);

      expect(updatedAgreement.customerName, 'RAMESHWAR KISAN PATIL (UPDATED)');
      expect(updatedAgreement.customerMobile, '9988776655');
      expect(updatedAgreement.customerAddress, 'New House 45, Betawad Shindkheda');
      expect(updatedAgreement.systemCapacity, '5 kW');

      expect(updatedReceipt.customerName, 'RAMESHWAR KISAN PATIL (UPDATED)');
      expect(updatedReceipt.mobileNo, '9988776655');
      expect(updatedReceipt.address, 'New House 45, Betawad Shindkheda');
      expect(updatedReceipt.systemCapacity, '5 kW');
    });

    test('2. Lead and Task modules reflect updated Customer Master details', () {
      final initialLead = LeadRecord(
        id: 'lead_1',
        customerName: 'Old Lead Name',
        mobileNo: '0000000000',
        leadSource: 'Referral',
        interestedIn: 'On-Grid',
        leadStatus: 'Converted',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final initialTask = OfficeTask(
        id: 'task_1',
        title: 'Site Visit',
        taskType: 'Survey',
        customerName: 'Old Task Customer',
        consumerNo: '0000',
        assignedToName: 'Staff 1',
        assignedToId: 'user_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final hydratedLead = MasterDataHub.hydrateLead(lead: initialLead, customer: masterCustomer);
      final hydratedTask = MasterDataHub.hydrateTask(task: initialTask, customer: masterCustomer);

      expect(hydratedLead.customerName, 'RAMESHWAR KISANRAO PATIL');
      expect(hydratedLead.mobileNo, '9876543210');
      expect(hydratedLead.consumerNo, '012345678901');
      expect(hydratedLead.approxSystemSize, '3 kW');

      expect(hydratedTask.customerName, 'RAMESHWAR KISANRAO PATIL');
      expect(hydratedTask.consumerNo, '012345678901');
    });

    test('3. Company Master update automatically propagates across all documents', () {
      final customCompany = CompanyMaster.defaultMaster().copyWith(
        companyName: 'SIYA SOLAR ENERGY PRIVATE LIMITED',
        gstin: '27AABCS1429B1Z1',
        mobile: '9123456789',
        email: 'info@siyasolar.in',
        bankName: 'HDFC BANK LTD',
        accountNo: '50200012345678',
        ifscCode: 'HDFC0001234',
        signatoryName: 'Manoj P. Kshirsagar',
      );
      MasterDataHub.setCompanyMaster(customCompany);

      final quotation = MasterDataHub.hydrateQuotation(
        quotation: SolarQuotation.create(
          id: 'q_test',
          consumerNo: masterCustomer.consumerNo,
          customerName: masterCustomer.name,
          totalSystemCost: 160000.0,
        ),
        customer: masterCustomer,
      );
      final wcr = MasterDataHub.createWorkCompletionReport(customer: masterCustomer);
      final agreement = MasterDataHub.createAgreement(customer: masterCustomer);
      final receipt = MasterDataHub.createMarginReceipt(customer: masterCustomer);

      expect(quotation.bankName, 'HDFC BANK LTD');
      expect(quotation.accountNo, '50200012345678');
      expect(quotation.ifscCode, 'HDFC0001234');
      expect(quotation.signatoryName, 'Manoj P. Kshirsagar');

      expect(wcr.vendorFirmName, 'SIYA SOLAR ENERGY PRIVATE LIMITED');
      expect(wcr.vendorGstin, '27AABCS1429B1Z1');
      expect(wcr.vendorMobile, '9123456789');
      expect(wcr.vendorEmail, 'info@siyasolar.in');
      expect(wcr.authorizedPerson, 'Manoj P. Kshirsagar');

      expect(agreement.vendorName, 'SIYA SOLAR ENERGY PRIVATE LIMITED');
      expect(agreement.vendorGstin, '27AABCS1429B1Z1');
      expect(agreement.vendorPhone, '9123456789');
      expect(agreement.vendorEmail, 'info@siyasolar.in');

      expect(receipt.bankName, 'HDFC BANK LTD');
      expect(receipt.accountNo, '50200012345678');
      expect(receipt.ifscCode, 'HDFC0001234');
      expect(receipt.signatoryName, 'Manoj P. Kshirsagar');
    });
  });
}
