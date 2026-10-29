import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/bank_loan_quotation_service.dart';
import 'package:admin_panel/services/solar_quotation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate both Bank Loan Quotation and Solar Quotation Generator sample PDFs', () async {
    const artifactDir = 'C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149';
    Directory(artifactDir).createSync(recursive: true);

    // -------------------------------------------------------------------------
    // 1. BANK LOAN QUOTATION SAMPLE PDF (Original, Untouched Bank System)
    // -------------------------------------------------------------------------
    final bankLoanQuotation = SolarQuotation.create(
      customerId: 'bank_cust_001',
      consumerNo: '096590004521',
      customerName: 'Sanjay Vitthal Patil',
      address: 'Plot No. 14, Shindkheda Road, Betawad, Tal. Shindkheda, Dist. Dhule',
      villageCity: 'Betawad',
      district: 'Dhule',
      mobileNo: '9822334455',
      quotationNo: 'SIYA/BANK/2026/0142',
      quotationDate: DateTime.now(),
      systemCapacity: '3 kW',
      systemType: 'On-Grid',
      panelWattage: '550 Wp TopCon Bifacial (6 Nos)',
      inverterCapacity: '3.3 kW Single Phase',
      inverterBrand: 'SolarEdge / Sungrow / Growatt',
      mountingStructure: 'GI High Rise Rooftop Structure',
      totalSystemCost: 184180.79,
      gstAmount: 15819.21,
      grandTotal: 200000.0,
      bankLoanAmount: 160000.0,
      customerContribution: 40000.0,
      bankName: 'Bank of Maharashtra',
      branch: 'Betawad Branch (Branch Code: 0142)',
      accountNo: '60123456789',
      ifscCode: 'MAHB0000142',
      quotationType: 'Residential',
      notes: 'Quotation issued for Solar Rooftop Bank Loan finance with 20% margin money and 80% loan disbursement directly to vendor account.',
    );

    final bankPdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(
      bankLoanQuotation,
      includeStampAndSignature: true,
      includeCustomerSignature: true,
    );

    final bankFile = File('$artifactDir/bank_loan_quotation_sample.pdf');
    bankFile.writeAsBytesSync(bankPdfBytes);
    print('Generated Bank Loan Quotation Sample: ${bankFile.path} (${bankPdfBytes.length} bytes)');

    // -------------------------------------------------------------------------
    // 2. SOLAR QUOTATION GENERATOR BILINGUAL SAMPLE PDF (New Dedicated System)
    // -------------------------------------------------------------------------
    final solarQuotation = SolarQuotation.create(
      customerId: null, // Direct Entry / Option A
      consumerNo: '096590001608',
      customerName: 'Ganesh Dilip Patil',
      address: 'Plot No. 12, Ram Nagar, Betawad, Tal. Shindkheda, Dist. Dhule',
      villageCity: 'Betawad',
      district: 'Dhule',
      mobileNo: '9673220315',
      quotationNo: 'SIYA/SOLAR/2026/0891',
      quotationDate: DateTime.now(),
      systemCapacity: '3 kW',
      systemType: 'On-Grid Rooftop',
      panelWattage: '550 Wp DCR Mono Perc / Bifacial (6 Panels)',
      inverterCapacity: '3.3 kW Single Phase High Efficiency',
      inverterBrand: 'Growatt / Solis / Polycab',
      mountingStructure: 'Galvanized Iron (GI) Elevated Structure',
      totalSystemCost: 184180.79,
      gstAmount: 15819.21,
      grandTotal: 200000.0,
      quotationType: 'Residential',
      language: 'mr_en', // Bilingual Marathi + English
      subsidyAmount: 78000.0, // PM Surya Ghar Subsidy
      payableAfterSubsidy: 122000.0,
      paymentMode: 'Bank Loan',
      bankLoanAmount: 109800.0,
      customerContribution: 12200.0,
      annualInterestRate: 7.5,
      loanTenureMonths: 60,
      monthlyEmi: 2201.0,
      annualGenerationUnits: 4365.0,
      annualSavings: 34920.0,
      paybackYears: 3.49,
      includeDiagram: true,
      includeGenerationTable: true,
      includeRoi: true,
      notes: 'PM Surya Ghar: Muft Bijli Yojana rooftop installation with 5 years complete comprehensive warranty and 25 years solar panel performance warranty.',
    );

    final solarPdfBytes = await SolarQuotationService.generateQuotationPdfBytes(
      solarQuotation,
      includeStampAndSignature: true,
      includeCustomerSignature: true,
    );

    final solarFile = File('$artifactDir/solar_quotation_generator_sample.pdf');
    solarFile.writeAsBytesSync(solarPdfBytes);
    print('Generated Solar Quotation Generator Sample: ${solarFile.path} (${solarPdfBytes.length} bytes)');

    // -------------------------------------------------------------------------
    // 3. STANDALONE BANK LOAN EMI CALCULATION SHEET SAMPLE PDF
    // -------------------------------------------------------------------------
    final emiSheetBytes = await SolarQuotationService.generateBankLoanEmiSheetPdfBytes(
      solarQuotation,
      includeStampAndSignature: true,
    );
    final emiFile = File('$artifactDir/bank_loan_emi_sheet_sample.pdf');
    emiFile.writeAsBytesSync(emiSheetBytes);
    print('Generated Standalone Bank Loan EMI Sheet Sample: ${emiFile.path} (${emiSheetBytes.length} bytes)');

    expect(bankFile.existsSync(), isTrue);
    expect(solarFile.existsSync(), isTrue);
    expect(emiFile.existsSync(), isTrue);
    expect(bankPdfBytes.length, greaterThan(1000));
    expect(solarPdfBytes.length, greaterThan(1000));
    expect(emiSheetBytes.length, greaterThan(1000));
  });
}
