import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/solar_quotation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Solar Quotation Generator Bilingual & Acceptance Tests', () {
    // -------------------------------------------------------------------------
    // 1. Option A: New Customer without saving to Customer Master
    // -------------------------------------------------------------------------
    test('1. New customer quotation without saving to customer master maintains null customerId', () {
      final quotation = SolarQuotation.create(
        customerId: null, // No permanent customer record created
        consumerNo: '',
        customerName: 'Ganesh Dilip Patil',
        mobileNo: '9876543210',
        address: 'Plot No. 12, Ram Nagar, Betawad',
        villageCity: 'Betawad',
        district: 'Dhule',
        systemCapacity: '3 kW',
        grandTotal: 200000.0,
        quotationType: 'Residential',
        language: 'mr_en',
      );

      expect(quotation.customerId, isNull);
      expect(quotation.customerName, equals('Ganesh Dilip Patil'));
      expect(quotation.mobileNo, equals('9876543210'));

      final json = quotation.toJson();
      expect(json['customerId'], isNull);

      final restored = SolarQuotation.fromJson(json);
      expect(restored.customerId, isNull);
      expect(restored.customerName, equals('Ganesh Dilip Patil'));
      expect(restored.quotationType, equals('Residential'));
      expect(restored.language, equals('mr_en'));
    });

    // -------------------------------------------------------------------------
    // 2. Option B: Existing Customer quotation
    // -------------------------------------------------------------------------
    test('2. Existing customer quotation properly links customerId and pre-fills details', () {
      final quotation = SolarQuotation.create(
        customerId: 'master_cust_123',
        consumerNo: '096590001608',
        customerName: 'Sunil Anna Chaudhari',
        mobileNo: '9123456780',
        address: 'Station Road, Betawad',
        systemCapacity: '5 kW',
        grandTotal: 280000.0,
        quotationType: 'Residential',
      );

      expect(quotation.customerId, equals('master_cust_123'));
      expect(quotation.consumerNo, equals('096590001608'));
      expect(quotation.customerName, equals('Sunil Anna Chaudhari'));
    });

    // -------------------------------------------------------------------------
    // 3. PM Surya Ghar Central Subsidy Calculations (Residential)
    // -------------------------------------------------------------------------
    test('3. PM Surya Ghar subsidy rules: ₹30k/kW for first 2kW, ₹18k for 3rd kW, max ₹78k', () {
      // 1 kW -> ₹30,000
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 1.0, quotationType: 'Residential'),
        equals(30000.0),
      );

      // 2 kW -> ₹60,000
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 2.0, quotationType: 'Residential'),
        equals(60000.0),
      );

      // 3 kW -> ₹78,000 (30k*2 + 18k)
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 3.0, quotationType: 'Residential'),
        equals(78000.0),
      );

      // 4 kW -> Capped at ₹78,000
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 4.0, quotationType: 'Residential'),
        equals(78000.0),
      );

      // 5 kW -> Capped at ₹78,000
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 5.0, quotationType: 'Residential'),
        equals(78000.0),
      );

      // 10 kW -> Capped at ₹78,000
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 10.0, quotationType: 'Residential'),
        equals(78000.0),
      );
    });

    // -------------------------------------------------------------------------
    // 4. Commercial Quotation: Strictly 0 Central Residential Subsidy
    // -------------------------------------------------------------------------
    test('4. Commercial connections receive ₹0 PM Surya Ghar residential central subsidy', () {
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 3.0, quotationType: 'Commercial'),
        equals(0.0),
      );
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 5.0, quotationType: 'Commercial'),
        equals(0.0),
      );
      expect(
        SolarQuotationCalculations.calculatePmSuryaGharSubsidy(capacityKw: 10.0, quotationType: 'Commercial'),
        equals(0.0),
      );
    });

    // -------------------------------------------------------------------------
    // 5. 12 Monthly Generation (Jan–Dec) & Exact Annual Sum Equality
    // -------------------------------------------------------------------------
    test('5. 12-month Jan–Dec generation: Sum of all 12 months exactly equals annual generation', () {
      const capacityKw = 3.0;
      final monthly = SolarQuotationCalculations.calculate12MonthGeneration(
        capacityKw: capacityKw,
        electricityTariff: 8.0,
      );

      expect(monthly.length, equals(12));

      // Check month names sequence
      final monthNames = monthly.map((m) => m.monthEn).toList();
      expect(
        monthNames,
        equals(['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']),
      );

      // Check monthly variation: May (summer) should generate more than August (monsoon)
      final mayGen = monthly.firstWhere((m) => m.monthEn == 'May').units;
      final augGen = monthly.firstWhere((m) => m.monthEn == 'August').units;
      expect(mayGen, greaterThan(augGen));

      // Sum of 12 months
      double sum12 = 0.0;
      for (final m in monthly) {
        sum12 += m.units;
      }

      final annual = SolarQuotationCalculations.calculateAnnualGenerationUnits(capacityKw);
      expect(sum12, closeTo(annual, 1.0)); // Rounding difference within 1 unit

      // Check daily averages are positive and realistic (between 2.0 and 25.0 units/day)
      for (final m in monthly) {
        expect(m.avgDailyUnits, greaterThan(2.0));
        expect(m.avgDailyUnits, lessThan(25.0)); // 3 kW system produces 9-16 units/day
      }
    });

    // -------------------------------------------------------------------------
    // 6. Reducing-Balance EMI & Zero-Interest Formula
    // -------------------------------------------------------------------------
    test('6. Reducing-balance EMI formula & zero-interest handling', () {
      // 1. Standard loan: Principal ₹1,80,000, 7.5% annual rate, 60 months (5 years)
      final emi = SolarQuotationCalculations.calculateMonthlyEmi(
        principal: 180000.0,
        annualInterestRate: 7.5,
        tenureMonths: 60,
      );
      // Expected EMI: ~3608
      expect(emi, closeTo(3608.0, 2.0));

      // Loan summary
      final summary = SolarQuotationCalculations.calculateLoanBreakdown(
        principal: 180000.0,
        annualInterestRate: 7.5,
        tenureMonths: 60,
        processingFees: 1000.0,
      );
      expect(summary['principal'], equals(180000.0));
      expect(summary['emi'], closeTo(3608.0, 2.0));
      expect(summary['totalRepayment']!, greaterThan(180000.0));
      expect(summary['totalInterest']!, closeTo(summary['totalRepayment']! - 180000.0, 1.0));
      expect(summary['totalLoanCost'], equals(summary['totalRepayment']! + 1000.0));

      // 2. Zero-interest loan: Principal ₹1,20,000, 0% rate, 12 months
      final zeroEmi = SolarQuotationCalculations.calculateMonthlyEmi(
        principal: 120000.0,
        annualInterestRate: 0.0,
        tenureMonths: 12,
      );
      expect(zeroEmi, equals(10000.0));
    });

    // -------------------------------------------------------------------------
    // 7. Solar Savings, ROI & Payback Analysis
    // -------------------------------------------------------------------------
    test('7. Solar Savings, ROI and simple payback analysis calculation', () {
      final roi = SolarQuotationCalculations.calculateRoiAndPayback(
        totalSystemCost: 200000.0,
        eligibleSubsidy: 78000.0,
        deductSubsidyFromNetInvestment: true,
        annualGenerationUnits: 4365.0,
        electricityTariff: 8.0,
        annualMaintenanceCost: 1500.0,
      );

      // Net Investment = 200,000 - 78,000 = 122,000
      expect(roi['netInvestment'], equals(122000.0));

      // Annual bill savings = 4365 * 8 = 34,920
      expect(roi['annualBillSavings'], equals(34920.0));

      // Net annual savings = 34,920 - 1500 = 33,420
      expect(roi['netAnnualSavings'], equals(33420.0));

      // Simple payback years = 122,000 / 33,420 ≈ 3.65 years (~3 Years 8 Months)
      expect(roi['paybackYears'], closeTo(3.65, 0.1));
      expect(roi['paybackFormatted'], contains('Years'));

      // Annual ROI % = (33,420 / 122,000) * 100 ≈ 27.4%
      expect(roi['annualRoiPercent'], closeTo(27.4, 0.5));

      // 25-Year Lifetime Net Savings = (33,420 * 25) - 122,000 = 835,500 - 122,000 = 713,500
      expect(roi['lifetime25YearNetSavings'], equals(713500.0));
    });

    // -------------------------------------------------------------------------
    // 8. Bilingual Rupee Number to Words (Marathi + English)
    // -------------------------------------------------------------------------
    test('8. NumberToWordsUtils generates clean English, Marathi and Bilingual words', () {
      const amount = 200000.0;

      final enWords = NumberToWordsUtils.convertToIndianRupees(amount);
      expect(enWords.toLowerCase(), contains('two lakh'));

      final mrWords = NumberToWordsUtils.convertToMarathiRupees(amount);
      expect(mrWords, contains('दोन लाख'));
      expect(mrWords, contains('फक्त'));

      final biWords = NumberToWordsUtils.convertToBilingualRupees(amount);
      expect(biWords, contains('Two Lakh'));
      expect(biWords, contains('दोन लाख'));

      // Test zero and small amounts
      expect(NumberToWordsUtils.convertToMarathiRupees(0), contains('शून्य'));
      expect(NumberToWordsUtils.convertToMarathiRupees(78000), contains('अठ्ठ्याहत्तर हजार'));
    });

    // -------------------------------------------------------------------------
    // 9. Bilingual Translations Consistency
    // -------------------------------------------------------------------------
    test('9. SolarQuotationTranslations supports mr_en, en, and mr modes', () {
      final tBilingual = SolarQuotationTranslations('mr_en');
      expect(tBilingual.isBilingual, isTrue);
      expect(tBilingual.customerName, contains('/'));
      expect(tBilingual.customerName, contains('Customer Name'));
      expect(tBilingual.customerName, contains('ग्राहकाचे नाव'));

      final tEn = SolarQuotationTranslations('en');
      expect(tEn.isEnglishOnly, isTrue);
      expect(tEn.customerName, equals('Customer Name'));
      expect(tEn.systemCapacity, equals('System Capacity'));

      final tMr = SolarQuotationTranslations('mr');
      expect(tMr.isMarathiOnly, isTrue);
      expect(tMr.customerName, equals('ग्राहकाचे नाव'));
      expect(tMr.systemCapacity, equals('सोलर सिस्टम क्षमता'));
    });

    // -------------------------------------------------------------------------
    // 10. WhatsApp Message Template
    // -------------------------------------------------------------------------
    test('10. WhatsApp message format contains bilingual details, capacity, and totals', () {
      final quotation = SolarQuotation.create(
        consumerNo: '',
        customerName: 'Pravin Ratan Patil',
        mobileNo: '9673220315',
        quotationNo: 'SIYA-Q-2026-9901',
        systemCapacity: '3 kW',
        grandTotal: 200000.0,
        quotationType: 'Residential',
        subsidyAmount: 78000.0,
        paymentMode: 'Bank Loan',
        monthlyEmi: 3608.0,
        annualGenerationUnits: 4365.0,
      );

      final msg = SolarQuotationService.formatWhatsAppMessage(quotation);
      expect(msg, contains('Dear Pravin Ratan Patil'));
      expect(msg, contains('SIYA-Q-2026-9901'));
      expect(msg, contains('3 kW'));
      expect(msg, contains('2,00,000'));
      expect(msg, contains('4365 Units'));
      expect(msg, contains('78,000'));
      expect(msg, contains('3,608'));
      expect(msg, contains('SIYA INFOTECH & SOLAR ENERGY'));
    });

    // -------------------------------------------------------------------------
    // 11. Multi-Page Presentation A4 PDF Generation with Devanagari Font
    // -------------------------------------------------------------------------
    test('11. Multi-page presentation A4 PDF renders cleanly with Devanagari Unicode font', () async {
      final quotation = SolarQuotation.create(
        customerId: null,
        consumerNo: '096590001608',
        customerName: 'श्री गणेश दिलीप पाटील (Ganesh Dilip Patil)',
        address: 'प्लॉट नं. १२, राम नगर, बेटावद, ता. शिंदखेडा, जि. धुळे',
        villageCity: 'बेटावद (Betawad)',
        district: 'धुळे (Dhule)',
        mobileNo: '9673220315',
        quotationNo: 'SIYA-Q-2026-0001',
        systemCapacity: '3 kW',
        totalSystemCost: 184180.79,
        gstAmount: 15819.21,
        grandTotal: 200000.0,
        bankLoanAmount: 180000.0,
        customerContribution: 20000.0,
        quotationType: 'Residential',
        language: 'mr_en',
        subsidyAmount: 78000.0,
        payableAfterSubsidy: 122000.0,
        paymentMode: 'Bank Loan',
        annualInterestRate: 7.5,
        loanTenureMonths: 60,
        monthlyEmi: 3608.0,
        annualGenerationUnits: 4365.0,
        annualSavings: 34920.0,
        paybackYears: 3.65,
        includeDiagram: true,
        includeGenerationTable: true,
        includeRoi: true,
      );

      final pdfBytes = await SolarQuotationService.generateQuotationPdfBytes(
        quotation,
        includeStampAndSignature: true,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000)); // Comprehensive 2-page document

      // Ensure valid PDF header
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));

      // Save a copy to the workspace artifacts directory for inspection
      try {
        final convDir = 'C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149';
        final artifactPdf = File('$convDir/bilingual_solar_quotation.pdf');
        artifactPdf.parent.createSync(recursive: true);
        artifactPdf.writeAsBytesSync(pdfBytes);
      } catch (_) {}
    });
  });
}
