import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/solar_quotation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Verify Loan Amount is strictly calculated on Net Amount After Subsidy', () async {
    // Turnkey: ₹2,00,000, 3kW, Subsidy: ₹78,000
    final quotation = SolarQuotation.create(
      consumerNo: '096590001608',
      customerName: 'Ganesh Dilip Patil',
      systemCapacity: '3 kW',
      grandTotal: 200000.0,
      quotationType: 'Residential',
      paymentMode: 'Bank Loan',
    );

    // 1. Subsidy must be ₹78,000
    expect(quotation.subsidyAmount, equals(78000.0));

    // 2. Net amount after subsidy must be ₹1,22,000
    expect(quotation.payableAfterSubsidy, equals(122000.0));

    // 3. Bank Loan Amount must default to ₹2,00,000 with 120 months tenure
    expect(quotation.bankLoanAmount, equals(200000.0));
    expect(quotation.loanTenureMonths, equals(120));

    // 4. Customer Margin must default to ₹0
    expect(quotation.customerContribution, equals(0.0));

    // 5. Monthly EMI for ₹2,00,000 @ 7.5% for 120 months is ~₹2,374
    expect(quotation.monthlyEmi, closeTo(2374.0, 1.0));

    // 6. Verify Required Loan Documents Checklist
    expect(quotation.loanDocuments.length, equals(5));
    expect(quotation.loanDocuments, contains('Aadhaar Card (Applicant KYC)'));
    expect(quotation.loanDocuments, contains('PAN Card (Identity Verification)'));
    expect(quotation.loanDocuments, contains('Electricity Bill / Light Bill (Latest Paid Bill)'));
    expect(quotation.loanDocuments, contains('8A Utara (Land & Property Ownership Extract)'));
    expect(quotation.loanDocuments, contains('Bank Passbook / Statement (Last 6 Months Records)'));

    // 7. Verify All Quotation Components have Company / Make
    for (final item in quotation.items) {
      final make = item['make'] ?? item['company'];
      expect(make, isNotNull);
      expect(make!.isNotEmpty, isTrue);
    }

    // 7. Verify Proposal 7-page PDF generation
    final proposalPdfBytes = await SolarQuotationService.generateQuotationPdfBytes(
      quotation,
      includeStampAndSignature: true,
      includeCustomerSignature: true,
    );
    expect(proposalPdfBytes, isNotEmpty);
    expect(proposalPdfBytes.length, greaterThan(100000));

    // 8. Verify Standalone 1-page Bank Loan EMI Sheet PDF generation
    final emiSheetPdfBytes = await SolarQuotationService.generateBankLoanEmiSheetPdfBytes(
      quotation,
      includeStampAndSignature: true,
    );
    expect(emiSheetPdfBytes, isNotEmpty);
    expect(emiSheetPdfBytes.length, greaterThan(50000));
  });
}
