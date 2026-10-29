import 'dart:math' as math;

/// Represents a single month's solar radiation yield model
class SolarMonthlyYield {
  final String monthEn;
  final String monthMr;
  final int days;
  final double specificYieldKwhPerKw; // kWh per kW installed

  const SolarMonthlyYield({
    required this.monthEn,
    required this.monthMr,
    required this.days,
    required this.specificYieldKwhPerKw,
  });

  String getMonthLabel(String language) {
    if (language == 'mr') return monthMr;
    if (language == 'en') return monthEn;
    return '$monthEn / $monthMr';
  }
}

/// Represents calculated monthly generation row for tables and charts
class MonthlyGenerationRow {
  final int monthIndex; // 1 to 12
  final String monthEn;
  final String monthMr;
  final int days;
  final double units; // kWh generated in month
  final double avgDailyUnits; // units / days
  final double estimatedSavings; // units * tariff

  const MonthlyGenerationRow({
    required this.monthIndex,
    required this.monthEn,
    required this.monthMr,
    required this.days,
    required this.units,
    required this.avgDailyUnits,
    required this.estimatedSavings,
  });

  String getMonthName(String language) {
    if (language == 'mr') return monthMr;
    if (language == 'en') return monthEn;
    return '$monthEn / $monthMr';
  }
}

/// Core deterministic calculation engine for Solar Quotations
class SolarQuotationCalculations {
  /// Realistic, validated monthly solar insolation profile for Maharashtra & Western India
  /// Total specific yield: ~1,455 kWh per kW per year.
  static const List<SolarMonthlyYield> monthlyProfiles = [
    SolarMonthlyYield(monthEn: 'January', monthMr: 'जानेवारी', days: 31, specificYieldKwhPerKw: 125.0),
    SolarMonthlyYield(monthEn: 'February', monthMr: 'फेब्रुवारी', days: 28, specificYieldKwhPerKw: 130.0),
    SolarMonthlyYield(monthEn: 'March', monthMr: 'मार्च', days: 31, specificYieldKwhPerKw: 155.0),
    SolarMonthlyYield(monthEn: 'April', monthMr: 'एप्रिल', days: 30, specificYieldKwhPerKw: 160.0),
    SolarMonthlyYield(monthEn: 'May', monthMr: 'मे', days: 31, specificYieldKwhPerKw: 165.0),
    SolarMonthlyYield(monthEn: 'June', monthMr: 'जून', days: 30, specificYieldKwhPerKw: 120.0),
    SolarMonthlyYield(monthEn: 'July', monthMr: 'जुलै', days: 31, specificYieldKwhPerKw: 100.0),
    SolarMonthlyYield(monthEn: 'August', monthMr: 'ऑगस्ट', days: 31, specificYieldKwhPerKw: 95.0),
    SolarMonthlyYield(monthEn: 'September', monthMr: 'सप्टेंबर', days: 30, specificYieldKwhPerKw: 115.0),
    SolarMonthlyYield(monthEn: 'October', monthMr: 'ऑक्टोबर', days: 31, specificYieldKwhPerKw: 135.0),
    SolarMonthlyYield(monthEn: 'November', monthMr: 'नोव्हेंबर', days: 30, specificYieldKwhPerKw: 130.0),
    SolarMonthlyYield(monthEn: 'December', monthMr: 'डिसेंबर', days: 31, specificYieldKwhPerKw: 125.0),
  ];

  /// Parses capacity string (e.g., '3 kW', '3.5 kW', '5kW') to double
  static double parseCapacity(String capacityStr) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(capacityStr);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 3.0;
    }
    return 3.0;
  }

  /// Calculates complete 12-month generation table
  static List<MonthlyGenerationRow> calculate12MonthGeneration({
    required double capacityKw,
    double electricityTariff = 8.0,
    double? targetAnnualUnits,
  }) {
    final validCap = capacityKw > 0 ? capacityKw : 3.0;
    final validTariff = electricityTariff > 0 ? electricityTariff : 8.0;

    // Baseline total
    double baselineTotal = 0.0;
    for (final p in monthlyProfiles) {
      baselineTotal += (validCap * p.specificYieldKwhPerKw);
    }

    final double scale = (targetAnnualUnits != null && targetAnnualUnits > 0 && baselineTotal > 0)
        ? (targetAnnualUnits / baselineTotal)
        : 1.0;

    return List.generate(monthlyProfiles.length, (index) {
      final p = monthlyProfiles[index];
      final units = (validCap * p.specificYieldKwhPerKw * scale).roundToDouble();
      final avgDaily = double.parse((units / p.days).toStringAsFixed(1));
      final savings = (units * validTariff).roundToDouble();

      return MonthlyGenerationRow(
        monthIndex: index + 1,
        monthEn: p.monthEn,
        monthMr: p.monthMr,
        days: p.days,
        units: units,
        avgDailyUnits: avgDaily,
        estimatedSavings: savings,
      );
    });
  }

  /// Sum of all 12 monthly generation values (guaranteed exact match)
  static double calculateAnnualGenerationUnits(double capacityKw) {
    final rows = calculate12MonthGeneration(capacityKw: capacityKw);
    double total = 0.0;
    for (final r in rows) {
      total += r.units;
    }
    return total;
  }

  /// Official PM Surya Ghar: Muft Bijli Yojana Central Subsidy Calculation
  /// Scheme Guidelines:
  /// - First 2 kW: Rs. 30,000 per kW (up to Rs. 60,000)
  /// - Additional capacity up to 3 kW: Rs. 18,000 per kW
  /// - Maximum central subsidy: Rs. 78,000 (for 3 kW and higher residential systems)
  /// - Commercial: 0 (Scheme applies strictly to residential connections)
  static double calculatePmSuryaGharSubsidy({
    required double capacityKw,
    required String quotationType,
  }) {
    if (quotationType.trim().toLowerCase() == 'commercial') {
      return 0.0;
    }

    if (capacityKw <= 0) return 0.0;

    if (capacityKw <= 2.0) {
      return (capacityKw * 30000.0).roundToDouble();
    } else if (capacityKw <= 3.0) {
      final additional = (capacityKw - 2.0) * 18000.0;
      return (60000.0 + additional).roundToDouble();
    } else {
      // 3 kW or higher capped at maximum subsidy of Rs. 78,000
      return 78000.0;
    }
  }

  /// Standard Reducing-Balance Monthly EMI Calculation
  /// Formula: EMI = P * r * (1 + r)^n / ((1 + r)^n - 1)
  /// where r = (annualRate / 100) / 12, n = tenure in months
  static double calculateMonthlyEmi({
    required double principal,
    required double annualInterestRate,
    required int tenureMonths,
  }) {
    if (principal <= 0 || tenureMonths <= 0) return 0.0;
    if (annualInterestRate <= 0.001) {
      return (principal / tenureMonths).roundToDouble();
    }

    final double r = (annualInterestRate / 100.0) / 12.0;
    final double factor = math.pow(1.0 + r, tenureMonths).toDouble();
    if (factor <= 1.0) return (principal / tenureMonths).roundToDouble();

    final double emi = (principal * r * factor) / (factor - 1.0);
    return emi.roundToDouble();
  }

  /// Complete Financial Loan Summary
  static Map<String, double> calculateLoanBreakdown({
    required double principal,
    required double annualInterestRate,
    required int tenureMonths,
    double processingFees = 0.0,
  }) {
    final emi = calculateMonthlyEmi(
      principal: principal,
      annualInterestRate: annualInterestRate,
      tenureMonths: tenureMonths,
    );
    final totalRepayment = emi * tenureMonths;
    final totalInterest = totalRepayment > principal ? (totalRepayment - principal) : 0.0;
    final totalLoanCost = totalRepayment + processingFees;

    return {
      'principal': principal,
      'emi': emi,
      'totalRepayment': totalRepayment,
      'totalInterest': totalInterest,
      'processingFees': processingFees,
      'totalLoanCost': totalLoanCost,
    };
  }

  /// Solar Savings, ROI and Payback Analysis
  static Map<String, dynamic> calculateRoiAndPayback({
    required double totalSystemCost,
    required double eligibleSubsidy,
    required bool deductSubsidyFromNetInvestment,
    required double annualGenerationUnits,
    required double electricityTariff,
    double annualMaintenanceCost = 1500.0,
    double selfConsumptionRatio = 1.0,
  }) {
    final netInvestment = deductSubsidyFromNetInvestment
        ? (totalSystemCost - eligibleSubsidy).clamp(0.0, double.infinity)
        : totalSystemCost;

    final estimatedAnnualBillSavings = (annualGenerationUnits * electricityTariff * selfConsumptionRatio).roundToDouble();
    final estimatedNetAnnualSavings = (estimatedAnnualBillSavings - annualMaintenanceCost).clamp(0.0, double.infinity);

    double paybackYears = 0.0;
    String paybackFormatted = 'N/A';
    if (estimatedNetAnnualSavings > 0 && netInvestment > 0) {
      paybackYears = netInvestment / estimatedNetAnnualSavings;
      final int yrs = paybackYears.floor();
      final int months = ((paybackYears - yrs) * 12).round();
      if (yrs == 0) {
        paybackFormatted = '$months Months';
      } else if (months == 0) {
        paybackFormatted = '$yrs Years';
      } else {
        paybackFormatted = '$yrs Years $months Months';
      }
    }

    double annualRoiPercent = 0.0;
    if (netInvestment > 0 && estimatedNetAnnualSavings > 0) {
      annualRoiPercent = double.parse(((estimatedNetAnnualSavings / netInvestment) * 100.0).toStringAsFixed(1));
    }

    // 25-Year Lifetime Cumulative Net Savings (25-year panel performance standard)
    final double lifetime25YearGrossSavings = estimatedNetAnnualSavings * 25.0;
    final double lifetime25YearNetSavings = (lifetime25YearGrossSavings - netInvestment).clamp(0.0, double.infinity);

    return {
      'netInvestment': netInvestment,
      'annualBillSavings': estimatedAnnualBillSavings,
      'netAnnualSavings': estimatedNetAnnualSavings,
      'paybackYears': paybackYears,
      'paybackFormatted': paybackFormatted,
      'annualRoiPercent': annualRoiPercent,
      'lifetime25YearNetSavings': lifetime25YearNetSavings,
    };
  }
}

/// Comprehensive bilingual dictionary for Solar Quotation
class SolarQuotationTranslations {
  final String language; // 'mr_en' (default), 'en', 'mr'

  const SolarQuotationTranslations(this.language);

  bool get isMarathiOnly => language == 'mr';
  bool get isEnglishOnly => language == 'en';
  bool get isBilingual => language != 'mr' && language != 'en';

  String text(String en, String mr) {
    if (isMarathiOnly) return mr;
    if (isEnglishOnly) return en;
    return '$en / $mr';
  }

  // Titles
  String get quotationTitle => text('SOLAR SYSTEM QUOTATION', 'सोलर सिस्टम कोटेशन');
  String get bankLoanPurpose => text('For Bank Loan / Finance Purpose', 'बँक कर्ज व वित्तपुरवठा प्रक्रियेसाठी');
  String get residentialRooftop => text('Residential Rooftop Solar System', 'घरगुती छतावरील सोलर सिस्टम');
  String get commercialSolar => text('Commercial & Industrial Solar System', 'व्यावसायिक व औद्योगिक सोलर सिस्टम');

  // Customer Section
  String get customerDetailsTitle => text('CUSTOMER DETAILS', 'ग्राहकाचा तपशील');
  String get customerName => text('Customer Name', 'ग्राहकाचे नाव');
  String get consumerNo => text('Consumer No.', 'ग्राहक क्रमांक');
  String get mobileNo => text('Mobile No.', 'मोबाईल क्र.');
  String get address => text('Address', 'पत्ता');
  String get villageCity => text('Village / City', 'गाव / शहर');
  String get district => text('District', 'जिल्हा');
  String get quotationType => text('Quotation Type', 'कोटेशन प्रकार');
  String get residential => text('Residential', 'घरगुती');
  String get commercial => text('Commercial', 'व्यावसायिक');

  // System Configuration Section
  String get systemDetailsTitle => text('SYSTEM DETAILS & SPECIFICATIONS', 'सोलर सिस्टम तांत्रिक तपशील');
  String get systemCapacity => text('System Capacity', 'सोलर सिस्टम क्षमता');
  String get systemType => text('System Type', 'सिस्टम प्रकार');
  String get onGrid => text('On-Grid Solar System', 'ऑन-ग्रिड सोलर सिस्टम');
  String get offGrid => text('Off-Grid Solar System', 'ऑफ-ग्रिड सोलर सिस्टम');
  String get hybrid => text('Hybrid Solar System', 'हायब्रिड सोलर सिस्टम');
  String get solarPackage => text('Solar Package', 'सोलर पॅकेज');
  String get panelBrand => text('Solar PV Modules', 'सोलर पीव्ही पॅनेल्स');
  String get inverterBrand => text('Grid-Tied Inverter', 'ग्रिड-टाय इन्व्हर्टर');
  String get mountingStructure => text('Mounting Structure', 'माउंटिंग स्ट्रक्चर');

  // Pricing & GST Section
  String get pricingTitle => text('MATERIAL-WISE ITEM PRICING', 'साहित्यांचे दरपत्रक व बिलिंग तपशील');
  String get sr => text('Sr.', 'अ.क्र.');
  String get component => text('Component / Description', 'साहित्य / तपशील');
  String get specification => text('Technical Specification', 'तांत्रिक तपशील');
  String get quantity => text('Qty', 'नग');
  String get rate => text('Rate (₹)', 'दर (₹)');
  String get amount => text('Amount (₹)', 'रक्कम (₹)');
  String get subtotal => text('Subtotal', 'उपएकूण');
  String get discount => text('Discount', 'सवलत');
  String get taxableAmount => text('Taxable Amount', 'करपात्र रक्कम');
  String get gst => text('GST Amount', 'जीएसटी रक्कम');
  String get grandTotal => text('Grand Total (Incl. GST)', 'एकूण कोटेशन रक्कम (जीएसटीसह)');
  String get amountInWords => text('Amount in Words', 'अक्षरी रक्कम');

  // Subsidy Section
  String get subsidyTitle => text('PM SURYA GHAR YOJANA SUBSIDY', 'पीएम सूर्य घर मोफत वीज योजना सबसिडी');
  String get eligibleSubsidy => text('Estimated Eligible Subsidy', 'अंदाजित पात्र सरकारी सबसिडी');
  String get customerContribution => text('Customer Contribution', 'ग्राहकाचे प्रत्यक्ष योगदान');
  String get netPayableAfterSubsidy => text('Net Payable After Subsidy', 'सबसिडी वजा जाता देय रक्कम');
  String get subsidyDisclaimer => text(
    'Subsidy is subject to applicable scheme guidelines, customer eligibility, DISCOM/portal approval and official disbursement. The displayed subsidy is an estimate and is not a guarantee of approval or payment.',
    'सबसिडी ही संबंधित योजना मार्गदर्शक तत्त्वे, ग्राहक पात्रता, महावितरण/पोर्टल मंजुरी आणि प्रत्यक्ष वितरणावर अवलंबून असते. दर्शविलेली सबसिडी ही अंदाजित असून मंजुरी किंवा रकमेची कोणतीही हमी नाही.'
  );

  // EMI & Bank Loan Section
  String get paymentModeTitle => text('PAYMENT MODE & BANK FINANCING', 'देयक पद्धत व बँक कर्ज तपशील');
  String get paymentMode => text('Payment Mode', 'देयक पद्धत');
  String get cashPayment => text('Cash / Self-Funded', 'रोख (स्वतःची गुंतवणूक)');
  String get bankLoanPayment => text('Bank Loan', 'बँक कर्ज');
  String get partPaymentLoan => text('Part Payment + Bank Loan', 'आगाऊ रक्कम + बँक कर्ज');
  String get downPayment => text('Customer Down Payment', 'ग्राहकाची आगाऊ रक्कम');
  String get loanAmount => text('Proposed Loan Amount', 'प्रस्तावित बँक कर्ज');
  String get annualInterestRate => text('Annual Interest Rate', 'वार्षिक व्याज दर');
  String get loanTenure => text('Loan Tenure', 'कर्ज कालावधी');
  String get monthlyEmi => text('Estimated Monthly EMI', 'अंदाजित मासिक हप्ता (EMI)');
  String get totalInterest => text('Total Interest', 'एकूण व्याज');
  String get totalRepayment => text('Total Loan Repayment', 'एकूण परतफेड रक्कम');

  // Generation & Savings Section
  String get generationTitle => text('MONTHLY SOLAR GENERATION (JAN–DEC)', 'महिन्यानुसार वीज निर्मिती (जानेवारी-डिसेंबर)');
  String get month => text('Month', 'महिना');
  String get unitsGenerated => text('Generation (Units/kWh)', 'निर्मिती (युनिट्स)');
  String get dailyAverage => text('Daily Avg (Units)', 'दैनिक सरासरी (युनिट्स)');
  String get monthlySavings => text('Est. Savings (₹)', 'अंदाजित बचत (₹)');
  String get annualGeneration => text('Estimated Annual Generation', 'अंदाजित वार्षिक वीज निर्मिती');
  String get averageMonthlyUnits => text('Average Monthly Generation', 'मासिक सरासरी निर्मिती');
  String get annualSavings => text('Estimated Annual Bill Savings', 'अंदाजित वार्षिक वीज बिल बचत');

  // ROI & Payback Section
  String get roiTitle => text('SOLAR SAVINGS, ROI & PAYBACK ANALYSIS', 'सोलर बचत, परतावा व पे-बॅक विश्लेषण');
  String get netInvestment => text('Customer Net Investment', 'ग्राहकाची प्रत्यक्ष गुंतवणूक');
  String get netAnnualSavings => text('Estimated Net Annual Savings', 'अंदाजित वार्षिक निव्वळ बचत');
  String get paybackPeriod => text('Payback Period', 'गुंतवणूक परत मिळण्याचा कालावधी');
  String get annualRoi => text('Simple Annual ROI', 'वार्षिक परतावा दर');
  String get lifetime25Years => text('25-Year Estimated Net Savings', '२५ वर्षांची अंदाजित एकूण निव्वळ बचत');
  String get roiDisclaimer => text(
    'Generation, savings and payback calculations are estimates based on standard test conditions and current DISCOM tariffs. Actual production may vary with site orientation, shading and weather.',
    'वीज निर्मिती, बचत आणि परतावा कालावधी हे प्रमाणित हवामान आणि महावितरणच्या सध्याच्या वीज दरावर आधारित अंदाज आहेत. प्रत्यक्ष उत्पादन साइट दिशा, सावली व हवामानानुसार बदलू शकते.'
  );

  // Diagram Section
  String get diagramTitle => text('ON-GRID SOLAR SYSTEM WORKING SCHEMATIC', 'ऑन-ग्रिड सोलर कार्यप्रणाली रेखाचित्र');
  String get rooftopPanels => text('Rooftop Solar PV Modules', 'छतावरील सोलर पॅनेल्स');
  String get dcCable => text('Solar DC Cables (UV Protected)', 'सोलर डीसी केबल');
  String get dcdb => text('DCDB (DC Protection & Surge)', 'डीसीडीबी प्रोटेक्शन बॉक्स');
  String get inverter => text('Grid-Tied Solar Inverter', 'ग्रिड-टाय इन्व्हर्टर (DC to AC)');
  String get acdb => text('ACDB (AC Protection & MCB)', 'एसीडीबी प्रोटेक्शन बॉक्स');
  String get buildingLoad => text('Building Electrical Loads', 'इमारतीतील वीज वापर (घरातील उपकरणे)');
  String get bidirectionalMeter => text('Bi-Directional Net Meter', 'बाय-डायरेक्शनल नेट मीटर (MSEDCL)');
  String get electricityGrid => text('Electricity Distribution Grid', 'महावितरण वीज वितरण जाळे (Grid)');

  // Terms & Conditions
  String get termsTitle => text('TERMS AND CONDITIONS', 'नियम व अटी');
  String get customerSignature => text('Customer Acceptance Signature', 'ग्राहकाची संमती व स्वाक्षरी');
  String get authorizedSignature => text('Authorized Signatory & Stamp', 'अधिकृत स्वाक्षरी व कंपनी शिक्का');
  String get forCompany => text('For SIYA INFOTECH & SOLAR ENERGY', 'मे. सिया इन्फोटेक अँड सोलर एनर्जी करिता');
}
