import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/bank_loan_quotation_service.dart';
import 'package:admin_panel/services/solar_quotation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate both Bank Loan Quotation and Solar Quotation Generator sample PDFs', () async {
    const artifactDir = 'C:/Users/Admin/.gemini/antigravity/brain/830e2504-7b0c-4ee4-8264-23b83985f796';
    Directory(artifactDir).createSync(recursive: true);

    // -------------------------------------------------------------------------
    // 1. BANK LOAN QUOTATION SAMPLE PDF (Standard Formal Bank Quotation)
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
      systemType: 'On-Grid Rooftop',
      panelWattage: '550 Wp TopCon Bifacial (6 Nos)',
      inverterCapacity: '3.3 kW Single Phase',
      inverterBrand: 'SolarEdge / Sungrow / Growatt',
      mountingStructure: 'GI High Rise Rooftop Structure',
      totalSystemCost: 184180.79,
      gstAmount: 15819.21,
      grandTotal: 200000.0,
      bankLoanAmount: 200000.0,
      customerContribution: 0.0,
      bankName: 'Bank of Maharashtra',
      branch: 'Betawad Branch (Branch Code: 0142)',
      accountNo: '60123456789',
      ifscCode: 'MAHB0000142',
      quotationType: 'Residential',
      notes: 'Quotation issued for Solar Rooftop Bank Loan finance with 100% net loan sanction and direct vendor disbursement.',
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
    // 2. SOLAR QUOTATION GENERATOR 7-PAGE BILINGUAL SAMPLE PDF (Marathi + English Mix)
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
      systemType: 'On-Grid Rooftop Solar System',
      panelWattage: '550 Wp DCR Mono Perc / Bifacial (6 Panels)',
      inverterCapacity: '3.3 kW Single Phase High Efficiency',
      inverterBrand: 'Sungrow / Growatt / Solis',
      mountingStructure: 'Galvanized Iron (GI) Elevated High-Rise Structure',
      totalSystemCost: 184180.79,
      gstAmount: 15819.21,
      grandTotal: 200000.0,
      quotationType: 'Residential',
      language: 'mr_en', // Bilingual Marathi + English Mix (लोकल भाषा)
      subsidyAmount: 78000.0, // PM Surya Ghar Subsidy
      payableAfterSubsidy: 122000.0,
      paymentMode: 'Bank Loan',
      bankLoanAmount: 200000.0, // Default Loan Amount ₹2,00,000
      customerContribution: 0.0,
      downPayment: 0.0,
      annualInterestRate: 7.5,
      loanTenureMonths: 120, // Default 120 Months (10 Years)
      monthlyEmi: 2374.0, // Calculated EMI for ₹2,00,000 @ 7.5% for 120m
      loanDocuments: const [
        'Aadhaar Card (आधार कार्ड - KYC Verification)',
        'PAN Card (पॅन कार्ड - Identity Proof)',
        'Electricity Bill / Light Bill (लाईट बिल - Latest Paid)',
        '8A Utara (८अ उतारा - Land & Property Ownership Extract)',
        'Bank Passbook (बँक पासबुक - 6 Months Records / Statement)',
      ],
      items: [
        {
          'sr': '1',
          'item': 'Solar PV Modules (सोलर पॅनेल्स)',
          'make': 'Waaree / Adani / Goldi (DCR TopCon)',
          'spec': 'Mono / TOPCon DCR - 550 Wp x 6 Nos (25 Years Performance Warranty)',
          'qty': '3 kW',
          'warranty': '25 Years Warranty',
        },
        {
          'sr': '2',
          'item': 'Grid-Tied Inverter (सोलर इन्व्हर्टर)',
          'make': 'Sungrow / Growatt / Solis / Polycab',
          'spec': '3.3 kW 1-Phase Grid-Tied Inverter with Built-in WiFi (IP65)',
          'qty': '1 No.',
          'warranty': '5-10 Years Warranty',
        },
        {
          'sr': '3',
          'item': 'Mounting Structure (सोलर स्ट्रक्चर)',
          'make': 'Hot Dip Galvanized Iron (GI)',
          'spec': 'Hot Dip GI Elevated Structure (Wind resistance up to 150 km/h)',
          'qty': '1 Set',
          'warranty': '10 Years Structure Warranty',
        },
        {
          'sr': '4',
          'item': 'DC Cable (सोलर डीसी केबल)',
          'make': 'Polycab / Havells / Siechem (Solar Grade)',
          'spec': 'Solar UV Protected 4 sq.mm Copper Cable (Fire Retardant)',
          'qty': 'As Required',
          'warranty': 'Standard Warranty',
        },
        {
          'sr': '5',
          'item': 'AC Cable (एसी केबल)',
          'make': 'Polycab / KEI / Finolex',
          'spec': '2-Core Armoured Copper / Aluminium AC Cable',
          'qty': 'As Required',
          'warranty': 'Standard Warranty',
        },
        {
          'sr': '6',
          'item': 'ACDB & DCDB (सुरक्षा बॉक्सेस)',
          'make': 'Hensel / Elmex / Schneider Protection Box',
          'spec': 'Dual SPD Class-II Surge Arrestors + DC/AC MCB & Enclosure (IP65)',
          'qty': '1 Set',
          'warranty': 'Standard Warranty',
        },
        {
          'sr': '7',
          'item': 'Earthing Kit & Lightning Arrester (अर्थिंग किट)',
          'make': 'True Power / Ashlok Chemical GI',
          'spec': 'Dual Chemical GI Electrode Earthing (AC/DC & Structure) + ESE LA',
          'qty': '3 Sets',
          'warranty': 'Standard Warranty',
        },
        {
          'sr': '8',
          'item': 'Net Metering System (नेट मीटर)',
          'make': 'MSEDCL / Discom Approved Bi-directional Meter',
          'spec': 'Bi-directional Net Generation & Import/Export Meter with Testing',
          'qty': '1 Set',
          'warranty': 'Discom Warranty',
        },
        {
          'sr': '9',
          'item': 'Installation & Commissioning (इन्स्टॉलेशन आणि कमिशनिंग)',
          'make': 'Siya Infotech Engineering Team',
          'spec': 'Complete Electrical, Civil Foundation, Rooftop Fabrication & Testing',
          'qty': 'Complete Project',
          'warranty': '5 Years Comprehensive O&M',
        },
      ],
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

    final solarFile = File('$artifactDir/bilingual_solar_quotation_7page_sample.pdf');
    solarFile.writeAsBytesSync(solarPdfBytes);
    print('Generated 7-Page Bilingual Solar Quotation Sample: ${solarFile.path} (${solarPdfBytes.length} bytes)');

    // Also write standard filename for backward compatibility
    File('$artifactDir/solar_quotation_generator_sample.pdf').writeAsBytesSync(solarPdfBytes);

    // -------------------------------------------------------------------------
    // 3. STANDALONE BANK LOAN EMI CALCULATION SHEET SAMPLE PDF (1-Page Bilingual)
    // -------------------------------------------------------------------------
    final emiSheetBytes = await SolarQuotationService.generateBankLoanEmiSheetPdfBytes(
      solarQuotation,
      includeStampAndSignature: true,
    );
    final emiFile = File('$artifactDir/bilingual_bank_loan_emi_sheet_sample.pdf');
    emiFile.writeAsBytesSync(emiSheetBytes);
    print('Generated Standalone Bilingual Bank Loan EMI Sheet Sample: ${emiFile.path} (${emiSheetBytes.length} bytes)');

    // Also write standard filename for backward compatibility
    File('$artifactDir/bank_loan_emi_sheet_sample.pdf').writeAsBytesSync(emiSheetBytes);

    expect(bankFile.existsSync(), isTrue);
    expect(solarFile.existsSync(), isTrue);
    expect(emiFile.existsSync(), isTrue);
    expect(bankPdfBytes.length, greaterThan(1000));
    expect(solarPdfBytes.length, greaterThan(1000));
    expect(emiSheetBytes.length, greaterThan(1000));
  });
}
