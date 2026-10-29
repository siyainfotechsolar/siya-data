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

    // 3. Bank Loan Amount must default to 90% of Net Amount (₹1,09,800)
    expect(quotation.bankLoanAmount, equals(109800.0));

    // 4. Customer Margin must default to 10% of Net Amount (₹12,200)
    expect(quotation.customerContribution, equals(12200.0));

    // 5. Total financing base: Loan (109,800) + Margin (12,200) = Net Amount (122,000)
    expect(quotation.bankLoanAmount + quotation.customerContribution, equals(122000.0));

    // 6. Monthly EMI for ₹1,09,800 @ 7.5% for 60 months
    expect(quotation.monthlyEmi, closeTo(2201.0, 1.0));

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
