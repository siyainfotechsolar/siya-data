import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:siya_shared/siya_shared.dart';

import 'company_stamp_helper.dart';
import 'customer_signature_helper.dart';
import 'settings_service.dart';
import 'solar_quotation_font_helper.dart';

/// Professional Executive Solar Customer Proposal & Quotation Service
/// 100% Clean Corporate English — Spacious, Un-cramped 7-Page Executive Proposal.
/// Features:
/// Page 1: Corporate Cover Page, Company Profile, EPC Track Record & Solar Graphics Banner
/// Page 2: Executive Proposal, Customer & Installation Site Details & Key Project Highlights
/// Page 3: Detailed Bill of Materials (BOQ), Technical Specs & Statutory 70:30 GST Breakdown
/// Page 4: 12-Month Generation Forecast Table, Visual Bar Chart & Environmental Impact
/// Page 5: Official Full-Color On-Grid System Architecture & Energy Flow Infographic
/// Page 6: Financial ROI Analysis, Payment Milestones, Bank Details & Customer Sign-off
/// Page 7: Nationalized Bank Rooftop Solar Loan — Multi-Tenure EMI Calculation & Financing Sheet
class SolarQuotationService {
  // Theme Color Palette
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor emeraldColor = PdfColor.fromInt(0xFF047857);
  static const PdfColor lightGreenColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor goldenYellowColor = PdfColor.fromInt(0xFFD97706);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor headerBgColor = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor zebraBgColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor cardBgColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor accentBannerBg = PdfColor.fromInt(0xFFEFF6FF);

  // ── Section Header Helper ──────────────────────────────────────────────────
  static pw.Widget _buildSectionHeader(String title, {String? subTitle}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: pw.BoxDecoration(
        color: headerBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 14,
            decoration: const pw.BoxDecoration(
              color: navyColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            margin: const pw.EdgeInsets.only(right: 8),
          ),
          pw.Expanded(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Flexible(
                  child: pw.Text(
                    title,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      color: darkTextColor,
                      fontSize: 9.0,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (subTitle != null && subTitle.trim().isNotEmpty) ...[
                  pw.SizedBox(width: 8),
                  pw.Text(
                    subTitle.trim(),
                    style: const pw.TextStyle(
                      color: slateMutedColor,
                      fontSize: 7.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Common Header for Pages 2, 3, 4 ────────────────────────────────────────
  static pw.Widget _buildPageTopHeader(
    String pageTitle,
    int pageNumber,
    int totalPages,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: borderDarkColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'SIYA INFOTECH & SOLAR ENERGY',
                style: pw.TextStyle(
                  fontSize: 9.0,
                  fontWeight: pw.FontWeight.bold,
                  color: navyColor,
                ),
              ),
              pw.Text(
                '  |  $pageTitle',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: slateMutedColor,
                ),
              ),
            ],
          ),
          pw.Text(
            'Page $pageNumber of $totalPages',
            style: const pw.TextStyle(fontSize: 8.0, color: slateMutedColor),
          ),
        ],
      ),
    );
  }

  // ── Common Footer for All Pages ────────────────────────────────────────────
  static pw.Widget _buildPageFooter(
    int pageNumber,
    int totalPages,
    String proposalNo,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderDarkColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Siya Infotech & Solar Energy | Betawad, Tal. Shindkheda, Dist. Dhule | Helpline: +91 9673220315',
            style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
          ),
          pw.Text(
            '$proposalNo | Page $pageNumber of $totalPages',
            style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MAIN PDF GENERATION METHOD (4-Page Spacious Proposal)
  // ════════════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generateQuotationPdfBytes(
    SolarQuotation quotation, {
    bool includeStampAndSignature = false,
    Uint8List? customStampAndSignatureBytes,
    bool includeCustomerSignature = false,
    Uint8List? customCustomerSignatureBytes,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    // Load Customer Signature Font if needed
    pw.Font? customerSignatureFont;
    if (includeCustomerSignature) {
      try {
        customerSignatureFont =
            await CustomerSignatureHelper.loadSignatureFont();
      } catch (_) {}
    }

    final comp = MasterDataHub.company;

    // Load Company Logo
    pw.MemoryImage? logoImage;
    if (comp.logoImagePath != null && comp.logoImagePath!.isNotEmpty) {
      final customLogoBytes = SettingsService.decodeImageFromDataUri(
        comp.logoImagePath,
      );
      if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
        try {
          logoImage = pw.MemoryImage(customLogoBytes);
        } catch (_) {}
      }
    }
    if (logoImage == null) {
      try {
        final ByteData logoData = await rootBundle.load(
          'assets/images/logo.png',
        );
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    // Load Company Stamp
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      if (customStampAndSignatureBytes != null &&
          customStampAndSignatureBytes.isNotEmpty) {
        stampImage = pw.MemoryImage(customStampAndSignatureBytes);
      } else {
        final stampBytes =
            await AdminCompanyStampHelper.loadStampAndSignatureBytes();
        if (stampBytes != null) {
          stampImage = pw.MemoryImage(stampBytes);
        }
      }
    }

    // Load On-Grid System Architecture Diagram Image
    pw.MemoryImage? diagramImage;
    try {
      final ByteData diagramData = await rootBundle.load(
        'assets/images/on_grid_solar_diagram.jpg',
      );
      diagramImage = pw.MemoryImage(diagramData.buffer.asUint8List());
    } catch (_) {
      try {
        final fallbackFile = File(
          'admin_panel/assets/images/on_grid_solar_diagram.jpg',
        );
        if (fallbackFile.existsSync()) {
          diagramImage = pw.MemoryImage(fallbackFile.readAsBytesSync());
        } else {
          final brainFile = File(
            'C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149/on_grid_solar_diagram.jpg',
          );
          if (brainFile.existsSync()) {
            diagramImage = pw.MemoryImage(brainFile.readAsBytesSync());
          }
        }
      } catch (_) {}
    }

    // Load Company Profile Solar Hero Graphic Banner Image
    pw.MemoryImage? bannerImage;
    try {
      final ByteData bannerData = await rootBundle.load(
        'assets/images/company_profile_banner.jpg',
      );
      bannerImage = pw.MemoryImage(bannerData.buffer.asUint8List());
    } catch (_) {
      try {
        final fallbackFile = File(
          'admin_panel/assets/images/company_profile_banner.jpg',
        );
        if (fallbackFile.existsSync()) {
          bannerImage = pw.MemoryImage(fallbackFile.readAsBytesSync());
        } else {
          final brainFile = File(
            'C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149/company_profile_banner.jpg',
          );
          if (brainFile.existsSync()) {
            bannerImage = pw.MemoryImage(brainFile.readAsBytesSync());
          }
        }
      } catch (_) {}
    }

    // Load Seasonal Solar Generation Infographic Banner Image
    pw.MemoryImage? seasonalBannerImage;
    try {
      final ByteData seasonalData = await rootBundle.load(
        'assets/images/solar_seasonal_generation_banner.jpg',
      );
      seasonalBannerImage = pw.MemoryImage(seasonalData.buffer.asUint8List());
    } catch (_) {
      try {
        final fallbackFile = File(
          'admin_panel/assets/images/solar_seasonal_generation_banner.jpg',
        );
        if (fallbackFile.existsSync()) {
          seasonalBannerImage = pw.MemoryImage(fallbackFile.readAsBytesSync());
        } else {
          final brainFile = File(
            'C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149/solar_seasonal_generation_banner_1793261670113.jpg',
          );
          if (brainFile.existsSync()) {
            seasonalBannerImage = pw.MemoryImage(brainFile.readAsBytesSync());
          }
        }
      } catch (_) {}
    }

    // Formatters
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
    final inrIntFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat('#,##,###');

    // Standard GST Calculation (70:30 Split)
    final gst = quotation.gstBreakdown;

    // 12-Month Generation Schedule
    final capacityKw = SolarQuotationCalculations.parseCapacity(
      quotation.systemCapacity,
    );
    final monthlyYields = SolarQuotationCalculations.calculate12MonthGeneration(
      capacityKw: capacityKw,
      electricityTariff: quotation.electricityTariff > 0
          ? quotation.electricityTariff
          : 8.0,
      targetAnnualUnits: quotation.annualGenerationUnits > 0
          ? quotation.annualGenerationUnits
          : null,
    );

    const int totalPages = 7;

    final String lang =
        quotation.language.isNotEmpty ? quotation.language : 'mr_en';
    final bool isMarathi = lang == 'mr';
    final bool isEnglishOnly = lang == 'en';
    String tr(String en, String mr) =>
        isMarathi ? mr : (isEnglishOnly ? en : '$en / $mr');

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 1: CORPORATE COVER & COMPANY PROFILE (WITH GRAPHICS)
    // ──────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Corporate Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 52,
                        height: 52,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            comp.companyName.isNotEmpty
                                ? comp.companyName
                                : 'SIYA INFOTECH & SOLAR ENERGY',
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 14.0,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            tr(
                              'Authorized Solar EPC & Channel Partner | PM Surya Ghar: Muft Bijli Yojana',
                              'अधिकृत सोलर ईपीसी पार्टनर | पीएम सूर्य घर: मोफत वीज योजना',
                            ),
                            style: pw.TextStyle(
                              color: emeraldColor,
                              fontSize: 8.0,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            comp.address.isNotEmpty
                                ? comp.address
                                : 'Betawad, Tal. Shindkheda, Dist. Dhule, Maharashtra - 425403',
                            style: const pw.TextStyle(
                              color: slateBodyColor,
                              fontSize: 7.2,
                            ),
                          ),
                          pw.Text(
                            'Mobile: ${comp.mobile.isNotEmpty ? comp.mobile : "+91 9673220315 / +91 8888001122"} | Email: ${comp.email.isNotEmpty ? comp.email : "siyainfotech.solar@gmail.com"} | GSTIN: ${comp.gstin.isNotEmpty ? comp.gstin : "27AABCS1234F1Z5"}',
                            style: const pw.TextStyle(
                              color: slateMutedColor,
                              fontSize: 6.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Visual Graphic Hero Banner
              if (bannerImage != null)
                pw.Container(
                  width: double.infinity,
                  height: 160,
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                    border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(bannerImage, fit: pw.BoxFit.cover),
                  ),
                )
              else
                pw.Container(
                  width: double.infinity,
                  height: 120,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: navyColor,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'PIONEERING CLEAN & GREEN SOLAR ENERGY SOLUTIONS',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              pw.SizedBox(height: 10),

              // About Siya Infotech & Solar Energy Section
              _buildSectionHeader(
                'ABOUT SIYA INFOTECH & SOLAR ENERGY',
                subTitle: 'Pioneering Sustainable Rooftop Solar Infrastructure',
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Text(
                  'Siya Infotech & Solar Energy is a premier, full-service Solar EPC (Engineering, Procurement, and Construction) enterprise based in Dhule, Maharashtra. We deliver high-efficiency, turnkey grid-connected rooftop solar solutions for residential, commercial, industrial, and agricultural consumers.\n\n'
                  'As an authorized channel partner under the Ministry of New & Renewable Energy (MNRE) and the national PM Surya Ghar: Muft Bijli Yojana, we offer comprehensive project execution -- from rooftop structural engineering and shadow analysis to supply of Tier-1 ALMM-listed bifacial/mono modules, smart grid inverters, seamless MSEDCL net metering liaisoning, and direct subsidy facilitation. Our mission is to empower homes and businesses to achieve up to 90% power bill reduction through clean, dependable solar electricity.',
                  style: const pw.TextStyle(
                    color: slateBodyColor,
                    fontSize: 7.5,
                    lineSpacing: 2.0,
                  ),
                ),
              ),

              pw.SizedBox(height: 10),

              // Proven Track Record & EPC Credentials (6 Badges)
              _buildSectionHeader(
                'PROVEN TRACK RECORD & EPC CREDENTIALS',
                subTitle: 'Commitment to Quality, Speed & Customer Delight',
              ),
              pw.Row(
                children: [
                  _buildProfileBadge(
                    '500+ INSTALLATIONS',
                    '2.5+ MWp',
                    'Solar capacity commissioned across North Maharashtra',
                    navyColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge(
                    '100% SUBSIDY CLAIMS',
                    'Direct DBT',
                    'Seamless government subsidy crediting assistance',
                    emeraldColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge(
                    'TIER-1 COMPONENTS',
                    'ALMM List-I',
                    'TopCon Bifacial & Mono PERC solar modules',
                    goldenYellowColor,
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  _buildProfileBadge(
                    'TURNKEY LIAISONING',
                    'MSEDCL / Discom',
                    'Complete sanction, inspection & net meter setup',
                    navyColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge(
                    '25-YR PERFORMANCE',
                    'Linear Guarantee',
                    'Manufacturer power warranty & local service',
                    emeraldColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge(
                    'CONCESSIONAL LOAN',
                    'National Banks',
                    'Low-interest solar loans up to 90% project cost',
                    darkTextColor,
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Project Proposal Recipient & Submission Block
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: navyColor, width: 0.9),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr(
                              'PROPOSAL PREPARED EXCLUSIVELY FOR:',
                              'ग्राहकाचा संपूर्ण तपशील (CUSTOMER DETAILS):',
                            ),
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 7.2,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            quotation.customerName,
                            style: pw.TextStyle(
                              color: darkTextColor,
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            '${tr("Site Location", "जागेचा पत्ता")}: ${quotation.address.isNotEmpty ? quotation.address : "Rooftop Site Location"}, ${quotation.villageCity.isNotEmpty ? quotation.villageCity : ""}, ${quotation.district.isNotEmpty ? quotation.district : "Dhule"}',
                            style: const pw.TextStyle(
                              color: slateBodyColor,
                              fontSize: 7.2,
                            ),
                          ),
                          pw.Text(
                            '${tr("Consumer / CA No.", "ग्राहक क्र.")}: ${quotation.consumerNo.isNotEmpty ? quotation.consumerNo : "To be assigned"} | ${tr("Mobile", "मोबाईल")}: ${quotation.mobileNo.isNotEmpty ? quotation.mobileNo : "N/A"}',
                            style: const pw.TextStyle(
                              color: slateMutedColor,
                              fontSize: 6.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 0.8,
                      height: 48,
                      color: borderDarkColor,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr(
                              'PROJECT REFERENCE DETAILS:',
                              'प्रकल्प संदर्भ तपशील (PROJECT REFERENCE):',
                            ),
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 7.2,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '${tr("Proposal No.", "कोटेशन क्र.")}: ${quotation.quotationNo}',
                            style: pw.TextStyle(
                              color: darkTextColor,
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            '${tr("Proposed System", "प्रस्तावित सोलर")}: ${quotation.systemCapacity} Grid-Connected Rooftop PV',
                            style: pw.TextStyle(
                              color: emeraldColor,
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${tr("Date", "दिनांक")}: ${quotation.formattedDate} | ${tr("Validity: 30 Days", "वैधता: ३० दिवस")}',
                            style: const pw.TextStyle(
                              color: slateMutedColor,
                              fontSize: 6.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildPageFooter(1, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 2: EXECUTIVE PROPOSAL & PROJECT HIGHLIGHTS
    // ──────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader(
                'EXECUTIVE PROPOSAL & PROJECT OVERVIEW',
                2,
                totalPages,
              ),

              // Proposal Title Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: const pw.BoxDecoration(
                  color: navyColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr(
                              'PROJECT PROPOSAL & COMMERCIAL QUOTATION',
                              'प्रकल्प प्रस्ताव व सोलर रूफटॉप कोटेशन',
                            ),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10.8,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            tr(
                              'Grid-Connected Rooftop Solar Photovoltaic (PV) System',
                              'ऑन-ग्रिड रूफटॉप सोलर सिस्टीम (PM Surya Ghar)',
                            ),
                            style: const pw.TextStyle(
                              color: PdfColor.fromInt(0xFFBAE6FD),
                              fontSize: 8.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Proposal No.: ${quotation.quotationNo}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Date: ${quotation.formattedDate}',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFE2E8F0),
                            fontSize: 7.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Customer Profile Card
              _buildSectionHeader(
                tr(
                  'CUSTOMER & INSTALLATION SITE DETAILS',
                  'ग्राहकाचा संपूर्ण तपशील व जागेचा पत्ता',
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow(
                            tr('Customer Name', 'ग्राहकाचे नाव'),
                            quotation.customerName,
                            isBold: true,
                          ),
                          _buildProfileRow(
                            tr('Consumer No. (CA)', 'ग्राहक क्र.'),
                            quotation.consumerNo.isNotEmpty
                                ? quotation.consumerNo
                                : 'To be provided for Net Metering',
                          ),
                          _buildProfileRow(
                            tr('Contact Mobile', 'मोबाईल क्र.'),
                            quotation.mobileNo.isNotEmpty
                                ? quotation.mobileNo
                                : 'N/A',
                          ),
                          _buildProfileRow(
                            tr('Email Address', 'ईमेल पत्ता'),
                            (quotation.email != null &&
                                    quotation.email!.isNotEmpty)
                                ? quotation.email!
                                : 'N/A',
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 0.8,
                      height: 60,
                      color: borderDarkColor,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow(
                            tr('Site Address', 'जागेचा पत्ता'),
                            quotation.address.isNotEmpty
                                ? quotation.address
                                : 'Rooftop Site Location',
                          ),
                          _buildProfileRow(
                            tr('Village / City', 'गाव/शहर'),
                            quotation.villageCity.isNotEmpty
                                ? quotation.villageCity
                                : 'N/A',
                          ),
                          _buildProfileRow(
                            tr('District', 'जिल्हा व राज्य'),
                            '${quotation.district.isNotEmpty ? quotation.district : "Dhule"}, Maharashtra',
                          ),
                          _buildProfileRow(
                            tr('Category', 'जोडणी प्रकार'),
                            '${quotation.quotationType} Connection',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Executive Introduction
              _buildSectionHeader(
                tr('EXECUTIVE SUMMARY', 'प्रकल्प कार्यकारी सारांश'),
                subTitle: tr('Pioneering Solar Energy', 'शाश्वत ऊर्जा आणि आर्थिक बचत'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Text(
                  quotation.language == 'en'
                      ? 'We thank you for considering SIYA INFOTECH & SOLAR ENERGY as your solar energy partner. We are pleased to submit this comprehensive proposal for the design, engineering, procurement, supply, installation, testing, and commissioning of a high-efficiency ${quotation.systemCapacity} Grid-Tied Solar Rooftop System.\n\n'
                        'This customized proposal integrates premium Tier-1 solar modules with 25-year performance warranties, high-efficiency grid-tied inverters with digital monitoring, and wind-resilient galvanized structures. It is specifically designed to eliminate up to 90% of your monthly electricity expenditure while securing central government subsidies under the PM Surya Ghar: Muft Bijli Yojana.'
                      : 'सिया इन्फोटेक & सोलर एनर्जी (SIYA INFOTECH & SOLAR ENERGY) सोबत संपर्क केल्याबद्दल मनःपूर्वक धन्यवाद. आपल्या निवासस्थानासाठी उच्च कार्यक्षमतेची ${quotation.systemCapacity} ऑन-ग्रिड सोलर रूफटॉप सिस्टीम (PM Surya Ghar) बसविण्याचा हा संपूर्ण प्रकल्प प्रस्ताव सादर करत आहोत.\n\n'
                        'या प्रस्तावात २५ वर्षांची वॉरंटी असलेले Tier-1 DCR सोलर पॅनेल्स, अत्याधुनिक इन्व्हर्टर आणि वादळ-प्रतिरोधक GI स्ट्रक्चरचा समावेश आहे. यामुळे तुमचे मासिक वीज बिल ९०% पर्यंत कमी होईल आणि पीएम सूर्य घर योजनेअंतर्गत ₹७८,००० थेट शासकीय सबसिडी (DBT Subsidy) तसेच राष्ट्रीयकृत बँकेचे सुलभ कर्ज उपलब्ध होईल.',
                  style: const pw.TextStyle(
                    color: slateBodyColor,
                    fontSize: 7.8,
                    lineSpacing: 1.8,
                  ),
                ),
              ),

              pw.SizedBox(height: 14),

              // Key System Highlights Grid (6 spacious cards)
              _buildSectionHeader(
                tr('KEY PROJECT HIGHLIGHTS', 'मुख्य प्रकल्प वैशिष्ट्ये व सारांश'),
              ),
              pw.Row(
                children: [
                  _buildHighlightBox(
                    tr('SYSTEM CAPACITY', 'सोलर क्षमता'),
                    quotation.systemCapacity,
                    tr('DC Solar Capacity', 'सोलर क्षमता'),
                    emeraldColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox(
                    tr('ANNUAL GENERATION', 'वार्षिक वीज निर्मिती'),
                    '${numberFormat.format(quotation.annualGenerationUnits.round())} Units',
                    tr('Est. kWh / Year', 'अंदाजित युनिट्स'),
                    navyColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox(
                    tr('TOTAL PROJECT COST', 'एकूण प्रकल्प किंमत'),
                    inrIntFormatter.format(quotation.grandTotal),
                    tr('Turnkey Cost', 'जीएसटीसह'),
                    darkTextColor,
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _buildHighlightBox(
                    tr('CENTRAL SUBSIDY', 'शासकीय सबसिडी'),
                    quotation.subsidyAmount > 0
                        ? inrIntFormatter.format(quotation.subsidyAmount)
                        : 'N/A (Commercial)',
                    tr('PM Surya Ghar DBT', 'थेट बँक खात्यात'),
                    emeraldColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox(
                    tr('NET EFFECTIVE COST', 'प्रत्यक्ष देय रक्कम'),
                    inrIntFormatter.format(
                      quotation.payableAfterSubsidy > 0
                          ? quotation.payableAfterSubsidy
                          : quotation.grandTotal,
                    ),
                    tr('After Direct Subsidy', 'सबसिडी वजा जाता'),
                    navyColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox(
                    tr('SIMPLE PAYBACK', 'परतावा कालावधी'),
                    quotation.paybackYears > 0
                        ? '${quotation.paybackYears.toStringAsFixed(1)} Years'
                        : '3.5 Years',
                    tr('High Lifetime ROI', '२५ वर्षे मोफत वीज'),
                    goldenYellowColor,
                  ),
                ],
              ),

              pw.Spacer(),
              _buildPageFooter(2, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 3: BILL OF MATERIALS, TECHNICAL SPECS & 70:30 GST
    // ──────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader(
                'TECHNICAL SPECIFICATIONS & FINANCIAL BREAKDOWN',
                3,
                totalPages,
              ),

              // Section 1: Detailed BOQ
              _buildSectionHeader(
                tr('BILL OF MATERIALS (BOQ) & TECHNICAL SPECIFICATIONS', 'साहित्य यादी (BOQ) व तांत्रिक तपशील'),
                subTitle: tr('Tier-1 MNRE / ALMM Approved Components', 'Tier-1 MNRE/ALMM मान्यताप्राप्त साहित्य'),
              ),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  children: [
                    _buildBoqHeaderRow(quotation.language),
                    if (quotation.items.isNotEmpty)
                      ...quotation.items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final it = entry.value;
                        String make =
                            (it['make'] != null && it['make']!.trim().isNotEmpty && !it['make']!.toLowerCase().contains('standard'))
                            ? it['make']!.trim()
                            : (it['company'] != null && it['company']!.trim().isNotEmpty && !it['company']!.toLowerCase().contains('standard'))
                            ? it['company']!.trim()
                            : '';
                        if (make.isEmpty) {
                          if (idx == 0) {
                            make = quotation.panelBrand.isNotEmpty ? quotation.panelBrand : 'Waaree / Adani / Goldi (DCR TopCon)';
                          } else if (idx == 1) {
                            make = quotation.inverterBrand.isNotEmpty ? quotation.inverterBrand : 'Sungrow / Growatt / Solis / Polycab';
                          } else if (idx == 2) {
                            make = quotation.mountingStructure.isNotEmpty ? quotation.mountingStructure : 'Hot Dip Galvanized Iron (GI)';
                          } else if (idx == 3) {
                            make = quotation.dcCableBrand;
                          } else if (idx == 4) {
                            make = quotation.acCableBrand;
                          } else if (idx == 5) {
                            make = quotation.switchgearBrand;
                          } else if (idx == 6) {
                            make = quotation.earthingBrand;
                          } else if (idx == 7) {
                            make = 'Siya Infotech Engineering Team';
                          } else if (idx == 8) {
                            make = quotation.netMeterBrand;
                          } else {
                            make = 'Tier-1 Approved Standard';
                          }
                        }
                        final String warranty =
                            it['warranty']?.isNotEmpty == true
                            ? it['warranty']!
                            : (idx == 0
                                  ? '25 Years Linear Performance Warranty'
                                  : (idx == 1
                                        ? '5 Years Standard Replacement Warranty'
                                        : (idx == 2
                                              ? '10 Years Structural Integrity Warranty'
                                              : 'Standard Component Warranty')));
                        return _buildBoqItemRow(
                          '${idx + 1}',
                          _translateBoqItem(it['item'] ?? '', quotation.language),
                          make,
                          it['spec'] ?? '',
                          it['qty'] ?? '1 Set',
                          warranty,
                          isZebra: idx % 2 == 1,
                          language: quotation.language,
                        );
                      })
                    else ...[
                      _buildBoqItemRow(
                        '1',
                        _translateBoqItem('Solar PV Modules', quotation.language),
                        quotation.panelBrand.isNotEmpty
                            ? quotation.panelBrand
                            : 'Waaree / Adani / Goldi (DCR TopCon)',
                        quotation.panelWattage.isNotEmpty
                            ? quotation.panelWattage
                            : '550 Wp TopCon Bifacial / Mono PERC DCR Grade Modules',
                        quotation.systemCapacity,
                        '25 Years Linear Performance Warranty',
                        isZebra: false,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '2',
                        _translateBoqItem('Grid-Tied Inverter', quotation.language),
                        quotation.inverterBrand.isNotEmpty
                            ? quotation.inverterBrand
                            : 'Growatt / Solis / Polycab',
                        '(${quotation.inverterCapacity.isNotEmpty ? quotation.inverterCapacity : "3.3 kW"}) High Efficiency MPPT Inverter with WiFi',
                        '1 Set',
                        '5 Years Standard Replacement Warranty',
                        isZebra: true,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '3',
                        _translateBoqItem('Mounting Structure', quotation.language),
                        'Hot Dip Galvanized Iron (GI)',
                        quotation.mountingStructure.isNotEmpty
                            ? quotation.mountingStructure
                            : 'Elevated Structure engineered for 150 km/h wind resilience',
                        'Complete Roof Set',
                        '10 Years Structural Integrity Warranty',
                        isZebra: false,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '4',
                        _translateBoqItem('DC Distribution Box', quotation.language),
                        'Hensel / Elmex / Schneider',
                        'IP65 Weatherproof Enclosure with 1000V DC Fuses and Type-II Surge Protection Devices (SPD)',
                        '1 Set',
                        '2 Years Equipment Warranty',
                        isZebra: true,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '5',
                        _translateBoqItem('AC Distribution Box', quotation.language),
                        'Hensel / Elmex / Schneider',
                        'IP65 Weatherproof Enclosure with Heavy-Duty MCB / Isolator and AC Surge Protection Devices',
                        '1 Set',
                        '2 Years Equipment Warranty',
                        isZebra: false,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '6',
                        _translateBoqItem('Solar DC & AC Cables', quotation.language),
                        'Polycab / Havells / KEI',
                        '4 sq.mm / 6 sq.mm UV-resistant, Flame Retardant (FRLS) Cu/Al Cables enclosed in UV conduit pipes',
                        'As per site layout',
                        '5 Years Manufacturer Warranty',
                        isZebra: true,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '7',
                        _translateBoqItem('Earthing & Lightning Kit', quotation.language),
                        'True Power / Ashlok',
                        'Chemical Gel Earthing Electrodes (Inverter, Structure & LA) + Early Streamer Lightning Arrester',
                        '3 Pits + 1 Arrester',
                        '5 Years Functional Warranty',
                        isZebra: false,
                        language: quotation.language,
                      ),
                      _buildBoqItemRow(
                        '8',
                        _translateBoqItem('Bi-Directional Net Meter', quotation.language),
                        'MSEDCL / Discom Approved',
                        'MSEDCL Approved Dual-Register Import/Export Smart Energy Meter',
                        '1 Unit',
                        'Standard Utility Warranty',
                        isZebra: true,
                        language: quotation.language,
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Section 2: Statutory 70:30 GST Breakdown
              _buildSectionHeader(
                tr('STATUTORY 70:30 GST FINANCIAL BREAKDOWN', 'सरकारी ७०:३० GST आर्थिक विभाजन'),
                subTitle: tr('Ministry of Finance Mandated Ratio', 'वित्त मंत्रालय निर्धारित गुणोत्तर'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Note: As per Ministry of Finance GST Circular & Solar EPC Guidelines, rooftop solar contracts are taxed under a statutory 70:30 split -- 70% of total project cost treated as Goods (@ 5% GST) and 30% treated as Services/Civil Works (@ 18% GST), yielding an effective blended GST rate of approx. 8.9%.',
                      style: const pw.TextStyle(
                        color: slateMutedColor,
                        fontSize: 7.2,
                        lineSpacing: 1.8,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: borderDarkColor,
                          width: 0.8,
                        ),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          _buildFinRow(
                            '70% Goods Portion Value (Solar Modules, Inverter, Hardware)',
                            currencyFormatter.format(gst.portion70),
                            isZebra: false,
                          ),
                          _buildFinRow(
                            'GST on Goods Portion @ 5%',
                            currencyFormatter.format(gst.gst5),
                            isZebra: true,
                          ),
                          _buildFinRow(
                            '30% Services Portion Value (Installation, Commissioning, Civil)',
                            currencyFormatter.format(gst.portion30),
                            isZebra: false,
                          ),
                          _buildFinRow(
                            'GST on Services Portion @ 18%',
                            currencyFormatter.format(gst.gst18),
                            isZebra: true,
                          ),
                          _buildFinRow(
                            'Total Base Taxable Value',
                            currencyFormatter.format(gst.totalTaxableValue),
                            isBold: true,
                            isZebra: false,
                          ),
                          _buildFinRow(
                            'Total GST Amount Included',
                            currencyFormatter.format(gst.totalGstIncluded),
                            isBold: true,
                            isZebra: true,
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: const pw.BoxDecoration(
                              color: accentBannerBg,
                              border: pw.Border(
                                top: pw.BorderSide(
                                  color: navyColor,
                                  width: 1.2,
                                ),
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'TOTAL COMMERCIAL PROPOSAL AMOUNT (INCL. GST):',
                                  style: pw.TextStyle(
                                    fontSize: 8.8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: navyColor,
                                  ),
                                ),
                                pw.Text(
                                  currencyFormatter.format(
                                    quotation.grandTotal,
                                  ),
                                  style: pw.TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: emeraldColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Section 3: Scope of Work
              _buildSectionHeader(
                tr('SCOPE OF SUPPLY & INSTALLATION SERVICES', 'कामाचे स्वरूप व पुरवठा सेवा'),
                subTitle: tr('Turnkey EPC Execution', 'संपूर्ण प्रकल्प उभारणी'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint(
                            tr(
                              'Detailed rooftop shadow profiling & engineering structural design.',
                              'छत पाहणी, सावली विश्लेषण व अचूक इंजिनिअरिंग डिझाईन.',
                            ),
                          ),
                          _buildBulletPoint(
                            tr(
                              'Supply of all Tier-1 modules, inverters, cables & accessories.',
                              'सर्व Tier-1 प्रमाणित सोलर साहित्य, इन्व्हर्टर व केबल्सचा पुरवठा.',
                            ),
                          ),
                          _buildBulletPoint(
                            tr(
                              'Complete mechanical mounting with wind-tested GI structures.',
                              'वादळ-प्रतिरोधक हॉट डिप GI स्ट्रक्चरचे मजबूत फॅब्रिकेशन.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint(
                            tr(
                              'Complete electrical AC/DC cabling, earthing & surge arresters.',
                              'अचूक AC/DC वायरिंग, केमिकल अर्थिंग व लाइटनिंग अरेस्टेर.',
                            ),
                          ),
                          _buildBulletPoint(
                            tr(
                              'Online MSEDCL portal application & net metering liaisoning.',
                              'महावितरण (MSEDCL) नेट मीटर परवानग्या व शासकीय सबसिडी प्रक्रिया.',
                            ),
                          ),
                          _buildBulletPoint(
                            tr(
                              'System testing, pre-commissioning verification & handover.',
                              'संपूर्ण टेस्टिंग, कमिशनिंग आणि सिस्टम यशस्वी हस्तांतरण.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildPageFooter(3, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 4: 12-MONTH GENERATION FORECAST & ENVIRONMENTAL IMPACT
    // ──────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader(
                'GENERATION FORECAST & ENVIRONMENTAL IMPACT',
                4,
                totalPages,
              ),

              // Section 1: Seasonal Performance Infographic Banner
              _buildSectionHeader(
                tr('ROOFTOP SOLAR SEASONAL GENERATION', 'ऋतूनुसार सोलर वीज निर्मिती'),
                subTitle: tr('Summer, Monsoon & Winter Trends', 'उन्हाळा, पावसाळा व हिवाळा कल'),
              ),
              if (seasonalBannerImage != null) ...[
                pw.Container(
                  width: double.infinity,
                  height: 125,
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                    border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(
                      seasonalBannerImage,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
                pw.SizedBox(height: 7),
              ],

              // Section 2: 12-Month Generation Visual Analytics Chart
              _buildSectionHeader(
                tr('12-MONTH SOLAR GENERATION VISUAL TREND', '१२ महिन्यांचे वीज उत्पादन व विश्लेषण'),
                subTitle: tr('Maharashtra Irradiance Profile', 'महाराष्ट्र सौर ऊर्जा प्रमाण'),
              ),
              _buildGenerationVisualChart(monthlyYields),

              pw.SizedBox(height: 7),

              // Section 3: 2-Column Monthly Yield & Financial Savings Table
              _buildSectionHeader(
                tr('12-MONTH DETAILED GENERATION SCHEDULE', '१२ महिन्यांचे सविस्तर वीज निर्मिती कोष्टक'),
                subTitle: tr('Generation (kWh) & Monthly Savings', 'वीज निर्मिती व मासिक बचत'),
              ),
              _buildMonthlyGenerationTable(
                monthlyYields,
                quotation.annualGenerationUnits,
                currencyFormatter,
              ),

              pw.SizedBox(height: 7),

              // Section 4: Environmental & Green Energy Impact
              _buildSectionHeader(
                tr('ENVIRONMENTAL & GREEN ENERGY IMPACT', 'पर्यावरण व हरित ऊर्जा योगदान'),
                subTitle: tr('Clean Energy Offset', 'स्वच्छ व प्रदूषणमुक्त ऊर्जा'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF0FDF4),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: emeraldColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildEcoMetric(
                      'CO2 Offset / Year',
                      '${(quotation.annualGenerationUnits * 0.82 / 1000).toStringAsFixed(1)} Metric Tons',
                      'Carbon emissions avoided annually',
                    ),
                    _buildEcoMetric(
                      'Lifetime Trees Equivalent',
                      '${(quotation.annualGenerationUnits * 0.04 * 25).round()} Trees',
                      'Equivalent mature trees planted over 25 yrs',
                    ),
                    _buildEcoMetric(
                      'Lifetime Clean Energy',
                      '${numberFormat.format((quotation.annualGenerationUnits * 25).round())} kWh',
                      'Total green electricity generated',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 7),

              // Section 5: Performance Assurance Card
              _buildSectionHeader(
                tr('SYSTEM PERFORMANCE & GENERATION ASSURANCES', 'सोलर कार्यक्षमता व निर्मिती हमी'),
                subTitle: tr('25 Years Assurance', '२५ वर्षे शाश्वत कामगिरी'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildTermBullet(
                      '1. Tier-1 Solar PV Modules: Linear power output guarantee with <= 2% degradation in Year 1 and <= 0.55%/year thereafter up to 25 Years.',
                    ),
                    _buildTermBullet(
                      '2. High-Yield Inverter: Advanced dual MPPT technology with > 98.4% peak efficiency ensuring maximum harvest during low-light and winter conditions.',
                    ),
                    _buildTermBullet(
                      '3. Net Metering Banking: Unconsumed solar electricity credited directly to MSEDCL billing cycle, offsetting peak commercial and residential tariffs.',
                    ),
                    _buildTermBullet(
                      '4. Weather Resilience: Elevated GI mounting engineered to withstand extreme wind velocities up to 150 km/h and severe climatic variations.',
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildPageFooter(4, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 5: ON-GRID SYSTEM ARCHITECTURE & WORKING FLOW INFOGRAPHIC
    // ──────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader(
                'SYSTEM ARCHITECTURE & WORKING FLOW',
                5,
                totalPages,
              ),

              _buildSectionHeader(
                tr('ON-GRID ROOFTOP SOLAR SYSTEM ARCHITECTURE', 'ऑन-ग्रिड सोलर रूफटॉप कार्यप्रणाली'),
                subTitle: tr('Generation, Consumption & Net Metering', 'वीज निर्मिती, वापर व नेट मीटरिंग'),
              ),

              pw.SizedBox(height: 4),

              // Full High-Resolution Infographic Image / Schematic
              if (diagramImage != null)
                pw.Container(
                  width: double.infinity,
                  height: 520,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                    border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(diagramImage, fit: pw.BoxFit.contain),
                  ),
                )
              else
                _buildOnGridArchitectureDiagram(quotation),

              pw.SizedBox(height: 8),

              // Architecture Flow Summary Card
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: navyColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildArchSummaryItem(
                      '1. Solar Panels',
                      'Generates DC Electricity',
                    ),
                    _buildArchSummaryItem(
                      '2. Grid Inverter',
                      'Converts DC to 230V AC',
                    ),
                    _buildArchSummaryItem(
                      '3. Home Loads',
                      'Direct Self-Consumption',
                    ),
                    _buildArchSummaryItem(
                      '4. Net Meter',
                      'Bi-Directional Recording',
                    ),
                    _buildArchSummaryItem(
                      '5. MSEDCL Grid',
                      'Zero Battery Maintenance',
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildPageFooter(5, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 6: FINANCIAL ROI, PAYMENT TERMS, BANK DETAILS & ACCEPTANCE
    // ──────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader(
                'FINANCIAL ROI, PAYMENT TERMS & ACCEPTANCE',
                6,
                totalPages,
              ),

              // Financial Analysis & Subsidy Card
              _buildSectionHeader(
                'FINANCIAL & RETURN ON INVESTMENT (ROI) ANALYSIS',
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          _buildRoiRow(
                            'Total Turnkey Project Cost',
                            inrIntFormatter.format(quotation.grandTotal),
                          ),
                          _buildRoiRow(
                            'PM Surya Ghar Central Subsidy',
                            quotation.subsidyAmount > 0
                                ? inrIntFormatter.format(
                                    quotation.subsidyAmount,
                                  )
                                : 'Rs. 0 (Commercial)',
                            highlightColor: emeraldColor,
                            isBold: true,
                          ),
                          _buildRoiRow(
                            'Net Effective Customer Investment',
                            inrIntFormatter.format(
                              quotation.payableAfterSubsidy > 0
                                  ? quotation.payableAfterSubsidy
                                  : quotation.grandTotal,
                            ),
                            highlightColor: navyColor,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 0.8,
                      height: 60,
                      color: borderDarkColor,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          _buildRoiRow(
                            'Projected 1st Year Bill Savings',
                            inrIntFormatter.format(
                              quotation.annualSavings > 0
                                  ? quotation.annualSavings
                                  : quotation.annualGenerationUnits * 8.0,
                            ),
                          ),
                          _buildRoiRow(
                            'Estimated Simple Payback Period',
                            '${quotation.paybackYears.toStringAsFixed(1)} Years',
                            isBold: true,
                          ),
                          _buildRoiRow(
                            '25-Year Cumulative Savings',
                            inrIntFormatter.format(
                              (quotation.annualSavings > 0
                                      ? quotation.annualSavings
                                      : quotation.annualGenerationUnits * 8.0) *
                                  25,
                            ),
                            highlightColor: emeraldColor,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Payment Terms & Bank Loan Options
              _buildSectionHeader(
                tr('PAYMENT TERMS & LOW-INTEREST LOAN OPTIONS', 'पेमेंट अटी व कमी व्याजाचे बँक कर्ज पर्याय'),
                subTitle: tr('Self-Financed & Bank Loan Options', 'स्वतःचा भरणा व बँक कर्ज पर्याय'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr('Option A: Self-Financed Milestones', 'पर्याय अ: स्वतःचा भरणा (टप्पे)'),
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: darkTextColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildBulletPoint(
                            tr('20% Advance along with work order confirmation.', '२०% ॲडव्हान्स: कार्यारंभ नोंदणी (Work Order) वेळी.'),
                          ),
                          _buildBulletPoint(
                            tr('70% against delivery of solar modules & inverter at site.', '७०% रक्कम: सोलर पॅनेल्स व इन्व्हर्टर जागेवर आल्यावर.'),
                          ),
                          _buildBulletPoint(
                            tr('10% upon complete installation & net meter inspection.', '१०% रक्कम: इन्स्टॉलेशन व नेट मीटर तपासणी पूर्ण झाल्यावर.'),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 0.8,
                      height: 65,
                      color: borderDarkColor,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 10),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr('Option B: Concessional Solar Bank Loan', 'पर्याय ब: राष्ट्रीयकृत बँक सोलर कर्ज'),
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: darkTextColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildBulletPoint(
                            tr('Nationalized bank solar rooftop loan up to 90% of project cost.', 'राष्ट्रीयकृत बँकेकडून सोलर रूफटॉपसाठी सुलभ कर्ज मंजुरी.'),
                          ),
                          _buildBulletPoint(
                            tr('Concessional interest rate: ${quotation.annualInterestRate.toStringAsFixed(1)}% p.a. (Tenure: ${quotation.loanTenureMonths} Months).', 'सवलतीचा व्याजदर: ${quotation.annualInterestRate.toStringAsFixed(1)}% प्रतिवर्ष (कालावधी: ${quotation.loanTenureMonths} महिने).'),
                          ),
                          _buildBulletPoint(
                            tr('Estimated Monthly EMI: ${inrIntFormatter.format(quotation.monthlyEmi)} / month (Offset by solar savings).', 'अंदाजित मासिक हप्ता (EMI): ${inrIntFormatter.format(quotation.monthlyEmi)}/महिना (वीज बचतीतून भरता येतो).'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Bank Details Card
              _buildSectionHeader(
                tr('COMPANY BANK ACCOUNT (FOR DISBURSEMENT / RTGS / NEFT)', 'कंपनीचे अधिकृत बँक खाते (कर्ज वितरण / RTGS / NEFT साठी)'),
                subTitle: tr('Official EPC Account', 'अधिकृत बँक खाते'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBankItem(
                      'Account Name',
                      comp.companyName.isNotEmpty
                          ? comp.companyName
                          : 'SIYA INFOTECH & SOLAR ENERGY',
                      isBold: true,
                    ),
                    _buildBankItem(
                      'Bank Name',
                      quotation.bankName.isNotEmpty
                          ? quotation.bankName
                          : comp.bankName,
                    ),
                    _buildBankItem(
                      'Account Number',
                      quotation.accountNo.isNotEmpty
                          ? quotation.accountNo
                          : comp.accountNo,
                      isBold: true,
                    ),
                    _buildBankItem(
                      'IFSC Code',
                      quotation.ifscCode.isNotEmpty
                          ? quotation.ifscCode
                          : comp.ifscCode,
                      isBold: true,
                    ),
                    _buildBankItem(
                      'Branch',
                      quotation.branch.isNotEmpty
                          ? quotation.branch
                          : comp.branch,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Terms & Conditions
              _buildSectionHeader(
                tr('COMMERCIAL TERMS & WARRANTY COMMITMENTS', 'व्यावसायिक नियम, अटी व वॉरंटी हमी'),
                subTitle: tr('Standard Solar EPC Terms', 'प्रमाणित सोलर अटी व शर्ती'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (quotation.termsAndConditions != null &&
                        quotation.termsAndConditions!.isNotEmpty)
                      ...quotation.termsAndConditions!.asMap().entries.map((e) {
                        final text = e.value.trim();
                        final hasNumber = RegExp(r'^\d+[\.\)]').hasMatch(text);
                        return _buildTermBullet(
                          hasNumber ? text : '${e.key + 1}. $text',
                        );
                      })
                    else ...[
                      _buildTermBullet(
                        tr(
                          '1. Warranties: 25 Years linear power warranty on PV modules; 5 Years on grid inverter; 5 Years comprehensive system service warranty.',
                          '१. वॉरंटी: सोलर पॅनेल्सना २५ वर्षे परफॉर्मन्स वॉरंटी; इन्व्हर्टरला ५ वर्षे; सिस्टीमला ५ वर्षे सर्वसमावेशक देखभाल हमी.',
                        ),
                      ),
                      _buildTermBullet(
                        tr(
                          '2. Subsidy Disbursement: PM Surya Ghar central subsidy is credited directly to customer\'s Aadhaar-linked bank account post MSEDCL net meter installation.',
                          '२. शासकीय अनुदान (सबसिडी): पीएम सूर्य घर अनुदान थेट ग्राहकाच्या आधार-संलग्न बँक खात्यात DBT द्वारे जमा होते.',
                        ),
                      ),
                      _buildTermBullet(
                        tr(
                          '3. Grid Approval & Net Metering: All liaisoning with MSEDCL / Discom handled turnkey by Siya Infotech & Solar Energy.',
                          '३. नेट मीटर व परवानग्या: महावितरण (MSEDCL) कडील सर्व अर्ज व अधिकृत परवानग्या सिया इन्फोटेक पूर्ण करून देईल.',
                        ),
                      ),
                      _buildTermBullet(
                        tr(
                          '4. Roof Availability: Customer to provide shadow-free roof space, single-phase/three-phase electrical point, and water for module cleaning.',
                          '४. जागेची उपलब्धता: ग्राहकाने सावलीमुक्त छताची जागा, वीज जोडणी आणि पॅनेल स्वच्छतेसाठी पाण्याची व्यवस्था उपलब्ध करून द्यावी.',
                        ),
                      ),
                      _buildTermBullet(
                        tr(
                          '5. Proposal Validity: This quotation is valid for 30 days from date of issuance. Material pricing subject to prevailing MNRE/ALMM policies.',
                          '५. कोटेशन वैधता: हे कोटेशन जारी केल्याच्या दिनांकापासून ३० दिवसांसाठी वैध आहे.',
                        ),
                      ),
                    ],
                    if (quotation.notes != null &&
                        quotation.notes!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: const pw.BoxDecoration(
                          color: accentBannerBg,
                          borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(3),
                          ),
                        ),
                        child: pw.Text(
                          'Special Remarks / Site Notes: ${quotation.notes!.trim()}',
                          style: pw.TextStyle(
                            fontSize: 6.2,
                            fontStyle: pw.FontStyle.italic,
                            color: navyColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Signatures & Acceptance Block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Customer Acceptance
                  pw.Container(
                    width: 240,
                    height: 85,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          tr('CUSTOMER ACCEPTANCE & SIGN-OFF:', 'ग्राहक स्वीकृती व स्वाक्षरी:'),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: darkTextColor,
                          ),
                        ),
                        if (includeCustomerSignature &&
                            customerSignatureFont != null)
                          pw.Text(
                            quotation.customerName,
                            style: pw.TextStyle(
                              font: customerSignatureFont,
                              fontSize: 13,
                              color: navyColor,
                            ),
                          )
                        else
                          pw.SizedBox(height: 25),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              tr('Authorized Signature: ____________', 'अधिकृत सही: ____________'),
                              style: const pw.TextStyle(
                                fontSize: 6.8,
                                color: slateMutedColor,
                              ),
                            ),
                            pw.Text(
                              tr('Date: ________', 'दिनांक: ________'),
                              style: const pw.TextStyle(
                                fontSize: 6.8,
                                color: slateMutedColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Company Seal & Signature
                  pw.Container(
                    width: 250,
                    height: 85,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          tr('FOR SIYA INFOTECH & SOLAR ENERGY:', 'सिया इन्फोटेक & सोलर एनर्जी:'),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: darkTextColor,
                          ),
                        ),
                        if (stampImage != null)
                          pw.Container(
                            height: 38,
                            child: pw.Image(stampImage, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 25),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Flexible(
                              child: pw.Text(
                                'Place / ठिकाण: ${quotation.villageCity.isNotEmpty ? (quotation.villageCity.length > 18 ? quotation.villageCity.substring(0, 16) + '...' : quotation.villageCity) : (quotation.district.isNotEmpty ? quotation.district : "Betawad, Dhule")}',
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: const pw.TextStyle(
                                  fontSize: 6.6,
                                  color: slateMutedColor,
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  quotation.signatoryName.isNotEmpty
                                      ? quotation.signatoryName
                                      : 'Authorized Signatory',
                                  style: pw.TextStyle(
                                    fontSize: 6.8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: navyColor,
                                  ),
                                ),
                                pw.Text(
                                  quotation.signatoryDesignation.isNotEmpty
                                      ? quotation.signatoryDesignation
                                      : 'Authorized Signatory / Seal',
                                  style: const pw.TextStyle(
                                    fontSize: 5.8,
                                    color: slateMutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              _buildPageFooter(6, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    // ──────────────────────────────────────────────────────────────────────────
    // PAGE 7: BANK ROOFTOP SOLAR LOAN — EMI CALCULATION & TENURE ANALYSIS
    // ──────────────────────────────────────────────────────────────────────────
    final double netAmountAfterSubsidy =
        (quotation.quotationType != 'Commercial' && quotation.subsidyAmount > 0)
        ? (quotation.payableAfterSubsidy > 0
              ? quotation.payableAfterSubsidy
              : (quotation.grandTotal - quotation.subsidyAmount).clamp(
                  0.0,
                  double.infinity,
                ))
        : quotation.grandTotal;

    // Bank loan is standardly ₹2,00,000 or customer specific
    final double loanPrincipal = quotation.bankLoanAmount > 0
        ? quotation.bankLoanAmount
        : 200000.0;

    final bool isLoanOnProjectCost = loanPrincipal > netAmountAfterSubsidy;
    final int loanPct = isLoanOnProjectCost
        ? (quotation.grandTotal > 0 ? ((loanPrincipal / quotation.grandTotal) * 100).round() : 100)
        : (netAmountAfterSubsidy > 0 ? ((loanPrincipal / netAmountAfterSubsidy) * 100).round() : 100);
    final int marginPct = (100 - loanPct).clamp(0, 100);

    final double customerMargin = quotation.customerContribution > 0
        ? quotation.customerContribution
        : (isLoanOnProjectCost
            ? (quotation.grandTotal - loanPrincipal).clamp(0.0, double.infinity)
            : (netAmountAfterSubsidy - loanPrincipal).clamp(0.0, double.infinity));

    final double effLoanRate = quotation.annualInterestRate > 0
        ? quotation.annualInterestRate
        : 7.5;
    final double monthlySolarSavings =
        (quotation.annualSavings > 0
            ? quotation.annualSavings
            : quotation.annualGenerationUnits * 8.0) /
        12.0;

    final loan36 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 36,
    );
    final loan60 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 60,
    );
    final loan84 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 84,
    );
    final loan120 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 120,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader(
                'BANK ROOFTOP SOLAR LOAN — EMI CALCULATION & FINANCING',
                7,
                totalPages,
              ),

              // Section 1: Loan Capital Structure
              _buildSectionHeader(
                isLoanOnProjectCost
                    ? tr('LOAN FINANCING & CAPITAL STRUCTURE', 'बँक कर्ज व भांडवली रचना')
                    : tr('LOAN FINANCING ON NET AFTER SUBSIDY', 'सबसिडी वजा जाता बँक कर्ज रचना'),
                subTitle: 'Concessional Financing @ ${effLoanRate.toStringAsFixed(2)}% p.a.',
              ),
              pw.Row(
                children: [
                  _buildHighlightBox(
                    tr('TOTAL PROJECT COST', 'एकूण किंमत'),
                    inrIntFormatter.format(quotation.grandTotal),
                    tr('Turnkey Incl. GST', 'जीएसटीसह किंमत'),
                    darkTextColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    tr('CENTRAL SUBSIDY', 'शासकीय सबसिडी'),
                    inrIntFormatter.format(quotation.subsidyAmount),
                    tr('PM Surya Ghar DBT', 'थेट बँक खात्यात'),
                    goldenYellowColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    tr('NET COST', 'निव्वळ रक्कम'),
                    inrIntFormatter.format(netAmountAfterSubsidy),
                    tr('Payable Post-Subsidy', 'सबसिडी वजा जाता'),
                    navyColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    'CUSTOMER MARGIN ($marginPct%)',
                    inrIntFormatter.format(customerMargin),
                    customerMargin <= 0 ? 'Zero Down Payment' : 'Customer Margin',
                    darkTextColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    'BANK LOAN ($loanPct%)',
                    inrIntFormatter.format(loanPrincipal),
                    isLoanOnProjectCost ? 'Sanctioned on Total Cost' : 'Eligible Loan on Net',
                    emeraldColor,
                  ),
                ],
              ),

              pw.SizedBox(height: 9),

              // Section 2: Multi-Tenure Comparison Matrix
              _buildSectionHeader(
                tr('MULTI-TENURE EMI COMPARISON MATRIX', 'मासिक हप्ता (EMI) तुलना कोष्टक'),
                subTitle: tr('Solar Savings Comfortably Offsetting EMI', 'वीज बिलातील बचतीतून हप्ता फेड'),
              ),
              _buildEmiComparisonMatrixTable(
                loan36: loan36,
                loan60: loan60,
                loan84: loan84,
                loan120: loan120,
                monthlySolarSavings: monthlySolarSavings,
                inrIntFormatter: inrIntFormatter,
              ),

              pw.SizedBox(height: 9),

              // Section 3: Central Subsidy & Self-Financing Advantage
              _buildSectionHeader(
                tr('FINANCIAL BENEFIT & 100% SELF-FINANCING ADVANTAGE', 'आर्थिक फायदा व १००% मासिक वीज बचत'),
                subTitle: tr('Positive Cash Flow from Month 1', 'पहिल्या महिन्यापासून फायदा'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isLoanOnProjectCost
                                ? tr(
                                    'Direct Subsidy Credit to Account (${inrIntFormatter.format(quotation.subsidyAmount)})',
                                    'खात्यात थेट सबसिडी जमा (${inrIntFormatter.format(quotation.subsidyAmount)})',
                                  )
                                : tr(
                                    'Substantially Lower EMI on Net Cost (${inrIntFormatter.format(netAmountAfterSubsidy)})',
                                    'निव्वळ रकमेवर कमी मासिक हप्ता (${inrIntFormatter.format(netAmountAfterSubsidy)})',
                                  ),
                            style: pw.TextStyle(
                              fontSize: 7.2,
                              fontWeight: pw.FontWeight.bold,
                              color: emeraldColor,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            tr('PM Surya Ghar Central Subsidy Direct Credit', 'पीएम सूर्य घर थेट शासकीय अनुदान'),
                            style: pw.TextStyle(
                              fontSize: 7.0,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          pw.Text(
                            tr(
                              'Under PM Surya Ghar, the central subsidy of ${inrIntFormatter.format(quotation.subsidyAmount)} is directly credited to your Aadhaar-linked bank account via DBT post net metering, substantially easing your finances.',
                              'पीएम सूर्य घर योजनेअंतर्गत ${inrIntFormatter.format(quotation.subsidyAmount)} शासकीय सबसिडी थेट तुमच्या आधार-संलग्न बँक खात्यात DBT द्वारे जमा होते, ज्यामुळे कर्जाचा भार अत्यंत हलका होतो.',
                            ),
                            style: const pw.TextStyle(
                              fontSize: 6.5,
                              color: slateBodyColor,
                              lineSpacing: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 0.8,
                      height: 55,
                      color: borderDarkColor,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr('Solar Electricity Bill Savings Exceed EMI', 'मासिक वीज बिलातील बचत हप्त्यापेक्षा जास्त'),
                            style: pw.TextStyle(
                              fontSize: 7.0,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            tr('100% Self-Financing: Positive Cash Flow from Month 1', '१००% स्वतःचे बिल स्वतः फेडणारा प्रकल्प'),
                            style: pw.TextStyle(
                              fontSize: 7.0,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          pw.Text(
                            tr(
                              'Your solar power plant generates an estimated ${inrIntFormatter.format(monthlySolarSavings)} in electricity bill savings every month. Since your monthly savings (${inrIntFormatter.format(monthlySolarSavings)}/mo) exceed your EMI (${inrIntFormatter.format(loan120['emi'] ?? 0)}/mo for 120 Months), the system completely pays for itself from Month 1!',
                              'तुमच्या सोलर सिस्टीममुळे दरमहा सुमारे ${inrIntFormatter.format(monthlySolarSavings)} रुपयांची वीज बचत होते. ही बचत मासिक हप्त्यापेक्षा (${inrIntFormatter.format(loan120['emi'] ?? 0)}/महिना) जास्त असल्यामुळे प्रकल्प पहिल्याच महिन्यापासून नफ्यात राहतो!',
                            ),
                            style: const pw.TextStyle(
                              fontSize: 6.5,
                              color: slateBodyColor,
                              lineSpacing: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 9),

              // Section 4: Empanelled Nationalized Banks
              _buildSectionHeader(
                tr('EMPANELLED NATIONALIZED BANKS & SCHEME FEATURES', 'अधिकृत राष्ट्रीयकृत बँका व सोलर कर्ज योजना'),
                subTitle: tr('Concessional Solar Loans', 'कमी व्याजदराची बँक कर्जे'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBankBadge(
                      'SBI Surya Ghar',
                      '7.00% p.a.*',
                      'Zero Collateral up to 3L',
                    ),
                    _buildBankBadge(
                      'Bank of Maharashtra',
                      '7.15% p.a.*',
                      'Direct JanSamarth Portal',
                    ),
                    _buildBankBadge(
                      'Punjab National Bank',
                      '7.00% p.a.*',
                      'Tenure up to 120 Months',
                    ),
                    _buildBankBadge(
                      'Canara / Union Bank',
                      '7.25% p.a.*',
                      'Fast Track Sanction',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 9),

              // Section 5: Required Document Checklist
              _buildSectionHeader(
                tr(
                  'LOAN SANCTION DOCUMENTATION CHECKLIST',
                  'बँक कर्जासाठी आवश्यक कागदपत्रे (चेकलिस्ट)',
                ),
                subTitle: tr(
                  'Submit for Bank Sanction',
                  'बँक कर्ज मंजुरीसाठी कागदपत्रे जमा करा',
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: () {
                  final docs = quotation.loanDocuments.isNotEmpty
                      ? quotation.loanDocuments
                      : SolarQuotation.defaultLoanDocuments;
                  final int half = (docs.length / 2).ceil();
                  final col1 = docs.take(half).toList();
                  final col2 = docs.skip(half).toList();
                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < col1.length; i++)
                              _buildBulletPoint('${i + 1}. ${_translateLoanDoc(col1[i], quotation.language)}'),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < col2.length; i++)
                              _buildBulletPoint('${col1.length + i + 1}. ${_translateLoanDoc(col2[i], quotation.language)}'),
                          ],
                        ),
                      ),
                    ],
                  );
                }(),
              ),

              pw.Spacer(),
              _buildPageFooter(7, totalPages, quotation.quotationNo),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _translateLoanDoc(String doc, String language) {
    if (language == 'en') return doc;
    final lower = doc.toLowerCase();
    if (lower.contains('aadhaar') || lower.contains('आधार')) {
      return 'Aadhaar Card (आधार कार्ड - KYC Verification)';
    } else if (lower.contains('pan') || lower.contains('पॅन')) {
      return 'PAN Card (पॅन कार्ड - Identity Proof)';
    } else if (lower.contains('light') || lower.contains('electricity') || lower.contains('लाईट')) {
      return 'Electricity Bill / Light Bill (लाईट बिल - Latest Paid)';
    } else if (lower.contains('8a') || lower.contains('८अ')) {
      return '8A Utara (८अ उतारा - Land / Property Extract)';
    } else if (lower.contains('passbook') || lower.contains('statement') || lower.contains('पासबुक')) {
      return 'Bank Passbook / Statement (बँक पासबुक - 6 Months Records)';
    } else if (lower.contains('7/12') || lower.contains('७/१२')) {
      return '7/12 Extract (७/१२ उतारा - Land Record)';
    } else if (lower.contains('tax') || lower.contains('घरपट्टी')) {
      return 'House Tax Receipt (घरपट्टी पावती)';
    }
    return doc;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // UI WIDGET BUILDER HELPERS FOR PDF
  // ════════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildProfileRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 122,
            child: pw.Text(
              label.endsWith(':') ? label : '$label:',
              style: const pw.TextStyle(fontSize: 7.4, color: slateMutedColor),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 7.8,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: darkTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHighlightBox(
    String label,
    String value,
    String subText,
    PdfColor color, {
    double valueFontSize = 10.5,
    double labelFontSize = 6.2,
    double subFontSize = 5.8,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: pw.BoxDecoration(
          color: cardBgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          border: pw.Border.all(color: color, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: labelFontSize,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2.5),
            pw.Text(
              value,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: valueFontSize,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              subText,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: subFontSize,
                color: slateMutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildProfileBadge(
    String title,
    String mainStat,
    String desc,
    PdfColor accentColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
        decoration: pw.BoxDecoration(
          color: cardBgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: borderDarkColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  width: 3.5,
                  height: 11,
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(1.5),
                    ),
                  ),
                  margin: const pw.EdgeInsets.only(right: 5),
                ),
                pw.Expanded(
                  child: pw.Text(
                    title,
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 2.5),
            pw.Text(
              mainStat,
              style: pw.TextStyle(
                fontSize: 9.0,
                fontWeight: pw.FontWeight.bold,
                color: accentColor,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              desc,
              maxLines: 2,
              style: const pw.TextStyle(
                fontSize: 6.0,
                color: slateMutedColor,
                lineSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Translates BOQ item name to bilingual (English / मराठी) for mr_en language mode.
  static String _translateBoqItem(String englishName, String language) {
    if (language != 'mr_en' && language != 'mr') return englishName;
    const Map<String, String> _boqMr = {
      'Solar PV Modules': 'सोलर पॅनेल्स',
      'Grid-Tied Inverter': 'ग्रिड इन्व्हर्टर',
      'Mounting Structure': 'माउंटिंग स्ट्रक्चर',
      'DC Cable': 'DC केबल',
      'AC Cable': 'AC केबल',
      'ACDB & DCDB': 'ACDB व DCDB',
      'DC Distribution Box': 'DC वितरण बॉक्स',
      'AC Distribution Box': 'AC वितरण बॉक्स',
      'Solar DC & AC Cables': 'DC व AC केबल्स',
      'Earthing Electrodes': 'अर्थिंग इलेक्ट्रोड',
      'Earthing & Lightning Kit': 'अर्थिंग व लाइटनिंग',
      'Installation & Commissioning': 'बसवणे व चालू करणे',
      'Net Metering Assistance': 'नेट मीटर सहाय्य',
      'Bi-Directional Net Meter': 'द्विदिशा नेट मीटर',
    };
    final mr = _boqMr[englishName];
    if (mr == null || mr.isEmpty) return englishName;
    return language == 'mr' ? mr : '$englishName\n$mr';
  }

  static pw.Widget _buildBoqHeaderRow([String language = 'en']) {
    final bool isBi = language == 'mr_en';
    final bool isMr = language == 'mr';
    String h(String en, String mr) => isMr ? mr : (isBi ? '$en / $mr' : en);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: const pw.BoxDecoration(
        color: headerBgColor,
        border: pw.Border(
          bottom: pw.BorderSide(color: borderDarkColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 24,
            child: pw.Text(
              h('#', 'क्र.'),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              h('Item', 'साहित्य'),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              h('Make / Brand', 'कंपनी (ब्रँड)'),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              h('Technical Specification', 'तांत्रिक तपशील'),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              h('Qty', 'नग'),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              h('Warranty', 'वॉरंटी'),
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBoqItemRow(
    String no,
    String item,
    String make,
    String spec,
    String qty,
    String warranty, {
    bool isZebra = false,
    String language = 'en',
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(
          bottom: pw.BorderSide(color: borderDarkColor, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 24,
            child: pw.Text(
              no,
              style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
            ),
          ),
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              item,
              style: pw.TextStyle(
                fontSize: 7.4,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              make,
              style: pw.TextStyle(
                fontSize: 7.2,
                fontWeight: pw.FontWeight.bold,
                color: navyColor,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              spec,
              style: const pw.TextStyle(fontSize: 7.1, color: slateBodyColor),
            ),
          ),
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              qty,
              style: const pw.TextStyle(fontSize: 7.2, color: darkTextColor),
            ),
          ),
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              warranty,
              style: pw.TextStyle(
                fontSize: 7.1,
                fontWeight: pw.FontWeight.bold,
                color: emeraldColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFinRow(
    String label,
    String value, {
    bool isBold = false,
    bool isZebra = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(
          bottom: pw.BorderSide(color: borderDarkColor, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: isBold ? darkTextColor : slateBodyColor,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: darkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 3.5,
            height: 3.5,
            margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
            decoration: const pw.BoxDecoration(
              color: navyColor,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 7.4,
                color: slateBodyColor,
                lineSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermBullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 6.8,
          color: slateBodyColor,
          lineSpacing: 1.3,
        ),
      ),
    );
  }

  static pw.Widget _buildArchSummaryItem(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 7.2,
            fontWeight: pw.FontWeight.bold,
            color: navyColor,
          ),
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor),
        ),
      ],
    );
  }

  static pw.Widget _buildRoiRow(
    String label,
    String value, {
    PdfColor? highlightColor,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.8, color: slateBodyColor),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.2,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: highlightColor ?? darkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBankItem(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor),
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 7.6,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: darkTextColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildEcoMetric(
    String title,
    String value,
    String subtitle,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 7.0, color: slateMutedColor),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: emeraldColor,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor),
        ),
      ],
    );
  }

  // ── Monthly Generation Table (2-Column Balanced Design) ────────────────────
  static pw.Widget _buildMonthlyGenerationTable(
    List<MonthlyGenerationRow> monthlyYields,
    double annualUnits,
    NumberFormat currencyFormatter,
  ) {
    final h1 = monthlyYields.length >= 6
        ? monthlyYields.sublist(0, 6)
        : monthlyYields;
    final h2 = monthlyYields.length >= 12
        ? monthlyYields.sublist(6, 12)
        : <MonthlyGenerationRow>[];

    pw.Widget buildSubTable(String halfTitle, List<MonthlyGenerationRow> rows) {
      return pw.Expanded(
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderDarkColor, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3.0,
                ),
                color: headerBgColor,
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 48,
                      child: pw.Text(
                        'Month',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 25,
                      child: pw.Text(
                        'Days',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 48,
                      child: pw.Text(
                        'Daily Avg',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Generation',
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: 58,
                      child: pw.Text(
                        'Savings (Rs.)',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 6.8,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2.0,
                  ),
                  color: idx % 2 == 1 ? zebraBgColor : PdfColors.white,
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 48,
                        child: pw.Text(
                          m.monthEn,
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: darkTextColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        width: 25,
                        child: pw.Text(
                          '${m.days}',
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: slateMutedColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        width: 48,
                        child: pw.Text(
                          '${m.avgDailyUnits.toStringAsFixed(1)} u/d',
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: slateBodyColor,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '${m.units.round()} kWh',
                          style: pw.TextStyle(
                            fontSize: 6.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navyColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        width: 58,
                        child: pw.Text(
                          currencyFormatter.format(m.estimatedSavings),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: darkTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            buildSubTable('H1 (Jan - Jun)', h1),
            pw.SizedBox(width: 6),
            buildSubTable('H2 (Jul - Dec)', h2),
          ],
        ),
        pw.SizedBox(height: 3),
        // Annual Aggregate Strip
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: pw.BoxDecoration(
            color: accentBannerBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: navyColor, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'ANNUAL AGGREGATE SUMMARY: ',
                    style: pw.TextStyle(
                      fontSize: 6.8,
                      fontWeight: pw.FontWeight.bold,
                      color: navyColor,
                    ),
                  ),
                  pw.Text(
                    '365 Days Operation | Avg: ${(annualUnits / 365).toStringAsFixed(1)} kWh/Day',
                    style: const pw.TextStyle(
                      fontSize: 6.5,
                      color: slateBodyColor,
                    ),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Total Generation: ',
                    style: const pw.TextStyle(
                      fontSize: 6.5,
                      color: slateMutedColor,
                    ),
                  ),
                  pw.Text(
                    '${annualUnits.round()} kWh / Year',
                    style: pw.TextStyle(
                      fontSize: 7.2,
                      fontWeight: pw.FontWeight.bold,
                      color: emeraldColor,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'Est. Savings: ',
                    style: const pw.TextStyle(
                      fontSize: 6.5,
                      color: slateMutedColor,
                    ),
                  ),
                  pw.Text(
                    currencyFormatter.format(annualUnits * 8.0),
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: emeraldColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── High-End Professional Monthly Generation Analytics Bar Chart ───────────
  static pw.Widget _buildGenerationVisualChart(
    List<MonthlyGenerationRow> yields,
  ) {
    double maxUnits = 1.0;
    int peakIndex = 0;
    for (int i = 0; i < yields.length; i++) {
      if (yields[i].units > maxUnits) {
        maxUnits = yields[i].units;
        peakIndex = i;
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header Bar & Seasonal Color Legend
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 3.5,
                    height: 11,
                    decoration: const pw.BoxDecoration(
                      color: navyColor,
                      borderRadius: pw.BorderRadius.all(
                        pw.Radius.circular(1.5),
                      ),
                    ),
                    margin: const pw.EdgeInsets.only(right: 6),
                  ),
                  pw.Text(
                    'MONTHLY SOLAR GENERATION CURVE & IRRADIANCE (kWh)',
                    style: pw.TextStyle(
                      fontSize: 7.2,
                      fontWeight: pw.FontWeight.bold,
                      color: navyColor,
                    ),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  _buildLegendIndicator(
                    'Summer Peak (Mar-May)',
                    goldenYellowColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildLegendIndicator('Monsoon (Jun-Sep)', emeraldColor),
                  pw.SizedBox(width: 8),
                  _buildLegendIndicator(
                    'Winter (Oct-Feb)',
                    const PdfColor.fromInt(0xFF1D4ED8),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 6),

          // Chart Canvas with Benchmark Grid & Vertical Pillars
          pw.Container(
            height: 85,
            padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: borderDarkColor, width: 0.8),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: yields.asMap().entries.map((entry) {
                final idx = entry.key;
                final y = entry.value;
                final isPeak = idx == peakIndex;
                final ratio = (y.units / maxUnits).clamp(0.20, 1.0);
                final barHeight = 52.0 * ratio;

                // Seasonal Color Scheme
                PdfColor barColor;
                if (idx >= 2 && idx <= 4) {
                  // Summer: March, April, May
                  barColor = goldenYellowColor;
                } else if (idx >= 5 && idx <= 8) {
                  // Monsoon: June, July, August, September
                  barColor = emeraldColor;
                } else {
                  // Winter/Spring: Oct, Nov, Dec, Jan, Feb
                  barColor = const PdfColor.fromInt(0xFF1D4ED8);
                }

                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      // Peak Month Star Badge or Exact Value
                      if (isPeak)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 2.5,
                            vertical: 0.8,
                          ),
                          margin: const pw.EdgeInsets.only(bottom: 1.5),
                          decoration: const pw.BoxDecoration(
                            color: goldenYellowColor,
                            borderRadius: pw.BorderRadius.all(
                              pw.Radius.circular(2),
                            ),
                          ),
                          child: pw.Text(
                            'PEAK',
                            style: pw.TextStyle(
                              fontSize: 4.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        )
                      else
                        pw.Text(
                          '${y.units.round()}',
                          style: pw.TextStyle(
                            fontSize: 5.5,
                            fontWeight: pw.FontWeight.bold,
                            color: barColor,
                          ),
                        ),

                      pw.SizedBox(height: 1.5),

                      // Styled Pillar with Rounded Top Cap
                      pw.Container(
                        height: barHeight,
                        width: 17,
                        decoration: pw.BoxDecoration(
                          color: barColor,
                          borderRadius: const pw.BorderRadius.vertical(
                            top: pw.Radius.circular(2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          pw.SizedBox(height: 3),

          // X-Axis Month Labels and Daily Yield
          pw.Row(
            children: yields.asMap().entries.map((entry) {
              final idx = entry.key;
              final y = entry.value;
              final isSummer = idx >= 2 && idx <= 4;

              return pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      y.monthEn.substring(0, 3).toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 6.0,
                        fontWeight: pw.FontWeight.bold,
                        color: isSummer ? goldenYellowColor : darkTextColor,
                      ),
                    ),
                    pw.SizedBox(height: 0.8),
                    pw.Text(
                      '${y.avgDailyUnits.toStringAsFixed(1)} u/d',
                      style: const pw.TextStyle(
                        fontSize: 5.0,
                        color: slateMutedColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLegendIndicator(String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 5.5,
          height: 5.5,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
          margin: const pw.EdgeInsets.only(right: 3),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 5.8, color: slateBodyColor),
        ),
      ],
    );
  }

  // ── On-Grid System Architecture Diagram ────────────────────────────────────
  static pw.Widget _buildOnGridArchitectureDiagram(SolarQuotation quotation) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: cardBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildDiagramNode(
                '1. Solar Panels',
                quotation.systemCapacity,
                'Generates DC Electricity',
                const PdfColor.fromInt(0xFF0284C7),
              ),
              _buildFlowArrow('DC Power'),
              _buildDiagramNode(
                '2. DCDB Box',
                'Protection Box',
                'DC Fuses & SPD',
                const PdfColor.fromInt(0xFFD97706),
              ),
              _buildFlowArrow('DC Power'),
              _buildDiagramNode(
                '3. Grid Inverter',
                quotation.inverterCapacity,
                'Converts DC to 230V AC',
                emeraldColor,
              ),
              _buildFlowArrow('AC Power'),
              _buildDiagramNode(
                '4. ACDB Box',
                'AC Protection',
                'MCB & Surge Arrest',
                const PdfColor.fromInt(0xFF7C3AED),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 120, height: 1, color: borderDarkColor),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                child: pw.Text(
                  'Bi-Directional Net Metering Power Flow',
                  style: const pw.TextStyle(
                    fontSize: 6.8,
                    color: slateMutedColor,
                  ),
                ),
              ),
              pw.Container(width: 120, height: 1, color: borderDarkColor),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildDiagramNode(
                '5. Building Loads',
                'Self-Consumption',
                'Powers Lights, AC, Fans',
                navyColor,
              ),
              _buildFlowArrow('Net Export / Import', isBiDirectional: true),
              _buildDiagramNode(
                '6. Bi-Directional Net Meter',
                'MSEDCL Dual Register',
                'Imports & Exports Energy',
                goldenYellowColor,
              ),
              _buildFlowArrow('Grid Banking', isBiDirectional: true),
              _buildDiagramNode(
                '7. MSEDCL Utility Grid',
                'Power Distribution',
                'Credits Solar Power to Bill',
                darkTextColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDiagramNode(
    String title,
    String spec,
    String desc,
    PdfColor color,
  ) {
    return pw.Container(
      width: 95,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 6.8,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 1.5),
          pw.Text(
            spec,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: darkTextColor,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            desc,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 5.5, color: slateMutedColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFlowArrow(
    String label, {
    bool isBiDirectional = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 5.5, color: slateMutedColor),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          isBiDirectional ? '<--->' : '---->',
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: emeraldColor,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PUBLIC ACTIONS (DOWNLOAD, PRINT, WHATSAPP)
  // ════════════════════════════════════════════════════════════════════════════

  /// Download quotation PDF
  static Future<void> downloadQuotationPdf(
    BuildContext context,
    SolarQuotation quotation, {
    bool includeStampAndSignature = false,
    bool includeCustomerSignature = false,
    Uint8List? customCustomerSignatureBytes,
  }) async {
    final pdfBytes = await generateQuotationPdfBytes(
      quotation,
      includeStampAndSignature: includeStampAndSignature,
      includeCustomerSignature: includeCustomerSignature,
      customCustomerSignatureBytes: customCustomerSignatureBytes,
    );
    final String defaultFileName = quotation.pdfFileName;

    await Printing.sharePdf(bytes: pdfBytes, filename: defaultFileName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading: $defaultFileName'),
          backgroundColor: const Color(0xFF0D2B6F),
        ),
      );
    }
  }

  /// Direct Print Quotation
  static Future<void> printQuotationPdf(
    SolarQuotation quotation, {
    bool includeStampAndSignature = false,
    bool includeCustomerSignature = false,
    Uint8List? customCustomerSignatureBytes,
  }) async {
    final pdfBytes = await generateQuotationPdfBytes(
      quotation,
      includeStampAndSignature: includeStampAndSignature,
      includeCustomerSignature: includeCustomerSignature,
      customCustomerSignatureBytes: customCustomerSignatureBytes,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: quotation.pdfFileName,
    );
  }

  /// Prepares 100% Professional English WhatsApp message text
  static String formatWhatsAppMessage(SolarQuotation quotation) {
    final inrFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );

    final emiText =
        (quotation.paymentMode.toLowerCase().contains('loan') &&
            quotation.monthlyEmi > 0)
        ? '\nEstimated Monthly EMI: ${inrFormat.format(quotation.monthlyEmi)} / month (${quotation.loanTenureMonths} months @ ${quotation.annualInterestRate.toStringAsFixed(1)}% p.a.)'
        : '';

    final subsidyText =
        (quotation.quotationType != 'Commercial' && quotation.subsidyAmount > 0)
        ? '\nCentral Govt. Subsidy (PM Surya Ghar): ${inrFormat.format(quotation.subsidyAmount)}\nNet Investment after Subsidy: ${inrFormat.format(quotation.payableAfterSubsidy)}'
        : '';

    return 'Dear ${quotation.customerName},\n\n'
        'Thank you for choosing Siya Infotech & Solar Energy for your rooftop solar installation.\n'
        'We are pleased to share your customized Solar Project Proposal & Quotation:\n\n'
        'Proposal No.: ${quotation.quotationNo}\n'
        'System Capacity: ${quotation.systemCapacity} (${quotation.systemType})\n'
        'Category: ${quotation.quotationType}\n'
        'Total Project Cost: ${inrFormat.format(quotation.grandTotal)}$subsidyText\n'
        'Estimated Annual Generation: ${quotation.annualGenerationUnits.toStringAsFixed(0)} Units (kWh/year)$emiText\n\n'
        'Please review the attached project proposal PDF for detailed technical specifications, 12-month generation forecast, On-Grid schematic, and ROI analysis.\n\n'
        'Feel free to contact us if you have any questions.\n\n'
        'Best regards,\n'
        'SIYA INFOTECH & SOLAR ENERGY\n'
        'Betawad, Tal. Shindkheda, Dist. Dhule\n'
        'Contact: +91 9673220315 / +91 8888001122';
  }

  /// Share quotation via WhatsApp with automatic PDF generation
  static Future<void> shareViaWhatsApp(SolarQuotation quotation) async {
    final phone = quotation.mobileNo.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = phone.length == 10 ? '91$phone' : phone;

    final rawMessage = formatWhatsAppMessage(quotation);
    final encodedMsg = Uri.encodeComponent(rawMessage);

    final url = Uri.parse(
      cleanPhone.isNotEmpty
          ? 'https://wa.me/$cleanPhone?text=$encodedMsg'
          : 'https://wa.me/?text=$encodedMsg',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── Multi-Tenure EMI Comparison Matrix Table ─────────────────────────────
  static pw.Widget _buildEmiComparisonMatrixTable({
    required Map<String, double> loan36,
    required Map<String, double> loan60,
    required Map<String, double> loan84,
    required Map<String, double> loan120,
    required double monthlySolarSavings,
    required NumberFormat inrIntFormatter,
  }) {
    final rows = [
      {'tenure': '3 Years (36 Months)', 'data': loan36, 'highlight': false},
      {'tenure': '5 Years (60 Months)', 'data': loan60, 'highlight': false},
      {'tenure': '7 Years (84 Months)', 'data': loan84, 'highlight': false},
      {
        'tenure': '10 Years (120 Months)',
        'data': loan120,
        'highlight': true,
      }, // Standard 10-Year Scheme
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          // Header Row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3.5,
            ),
            color: headerBgColor,
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 105,
                  child: pw.Text(
                    'Loan Tenure',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 75,
                  child: pw.Text(
                    'Monthly EMI',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(
                    'Total Interest',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    'Total Repayment',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 85,
                  child: pw.Text(
                    'Solar Savings/Mo',
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'Net Out-of-Pocket / Gain',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 7.0,
                      fontWeight: pw.FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final data = item['data'] as Map<String, double>;
            final emi = data['emi'] ?? 0.0;
            final interest = data['totalInterest'] ?? 0.0;
            final repayment = data['totalRepayment'] ?? 0.0;
            final isPopular = item['highlight'] == true;
            final netCashflow = monthlySolarSavings - emi;

            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3.0,
              ),
              color: isPopular
                  ? accentBannerBg
                  : (idx % 2 == 1 ? zebraBgColor : PdfColors.white),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 105,
                    child: pw.Row(
                      children: [
                        pw.Text(
                          item['tenure'] as String,
                          style: pw.TextStyle(
                            fontSize: 6.8,
                            fontWeight: isPopular
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal,
                            color: darkTextColor,
                          ),
                        ),
                        if (isPopular)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(left: 4),
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 2.5,
                              vertical: 0.5,
                            ),
                            decoration: const pw.BoxDecoration(
                              color: goldenYellowColor,
                              borderRadius: pw.BorderRadius.all(
                                pw.Radius.circular(2),
                              ),
                            ),
                            child: pw.Text(
                              'POPULAR',
                              style: pw.TextStyle(
                                fontSize: 4.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(
                    width: 75,
                    child: pw.Text(
                      inrIntFormatter.format(emi),
                      style: pw.TextStyle(
                        fontSize: 7.2,
                        fontWeight: pw.FontWeight.bold,
                        color: navyColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(
                      inrIntFormatter.format(interest),
                      style: const pw.TextStyle(
                        fontSize: 6.8,
                        color: slateMutedColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                      inrIntFormatter.format(repayment),
                      style: const pw.TextStyle(
                        fontSize: 6.8,
                        color: slateBodyColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 85,
                    child: pw.Text(
                      inrIntFormatter.format(monthlySolarSavings),
                      style: pw.TextStyle(
                        fontSize: 6.8,
                        fontWeight: pw.FontWeight.bold,
                        color: emeraldColor,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      netCashflow >= 0
                          ? '+${inrIntFormatter.format(netCashflow)}/mo (Zero Cost!)'
                          : '-${inrIntFormatter.format(netCashflow.abs())}/mo only',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7.0,
                        fontWeight: pw.FontWeight.bold,
                        color: netCashflow >= 0
                            ? emeraldColor
                            : const PdfColor.fromInt(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildBankBadge(String bankName, String rate, String note) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: pw.BoxDecoration(
        color: cardBgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            bankName,
            style: pw.TextStyle(
              fontSize: 6.8,
              fontWeight: pw.FontWeight.bold,
              color: navyColor,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            'Interest: $rate',
            style: pw.TextStyle(
              fontSize: 6.2,
              fontWeight: pw.FontWeight.bold,
              color: emeraldColor,
            ),
          ),
          pw.Text(
            note,
            style: const pw.TextStyle(fontSize: 5.2, color: slateMutedColor),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STANDALONE 1-PAGE BANK LOAN EMI CALCULATION SHEET GENERATOR
  // ════════════════════════════════════════════════════════════════════════════

  /// Generate Standalone 1-Page Bank Loan EMI Calculation Sheet PDF bytes
  static Future<Uint8List> generateBankLoanEmiSheetPdfBytes(
    SolarQuotation quotation, {
    bool includeStampAndSignature = true,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);
    final comp = MasterDataHub.company;

    // Load Company Logo
    pw.MemoryImage? logoImage;
    if (comp.logoImagePath != null && comp.logoImagePath!.isNotEmpty) {
      final customLogoBytes = SettingsService.decodeImageFromDataUri(
        comp.logoImagePath,
      );
      if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
        try {
          logoImage = pw.MemoryImage(customLogoBytes);
        } catch (_) {}
      }
    }
    if (logoImage == null) {
      try {
        final ByteData logoData = await rootBundle.load(
          'assets/images/logo.png',
        );
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    // Load Company Stamp
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      final stampBytes =
          await AdminCompanyStampHelper.loadStampAndSignatureBytes();
      if (stampBytes != null) {
        stampImage = pw.MemoryImage(stampBytes);
      }
    }

    final inrIntFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );

    final String lang =
        quotation.language.isNotEmpty ? quotation.language : 'mr_en';
    final bool isMarathi = lang == 'mr';
    final bool isEnglishOnly = lang == 'en';
    String tr(String en, String mr) =>
        isMarathi ? mr : (isEnglishOnly ? en : '$en / $mr');

    final double netAmountAfterSubsidy =
        (quotation.quotationType != 'Commercial' && quotation.subsidyAmount > 0)
        ? (quotation.payableAfterSubsidy > 0
              ? quotation.payableAfterSubsidy
              : (quotation.grandTotal - quotation.subsidyAmount).clamp(
                  0.0,
                  double.infinity,
                ))
        : quotation.grandTotal;

    // Bank loan is standardly ₹2,00,000 or customer specific
    final double loanPrincipal = quotation.bankLoanAmount > 0
        ? quotation.bankLoanAmount
        : 200000.0;

    final bool isLoanOnProjectCost = loanPrincipal > netAmountAfterSubsidy;
    final int loanPct = isLoanOnProjectCost
        ? (quotation.grandTotal > 0 ? ((loanPrincipal / quotation.grandTotal) * 100).round() : 100)
        : (netAmountAfterSubsidy > 0 ? ((loanPrincipal / netAmountAfterSubsidy) * 100).round() : 100);
    final int marginPct = (100 - loanPct).clamp(0, 100);

    final double customerMargin = quotation.customerContribution > 0
        ? quotation.customerContribution
        : (isLoanOnProjectCost
            ? (quotation.grandTotal - loanPrincipal).clamp(0.0, double.infinity)
            : (netAmountAfterSubsidy - loanPrincipal).clamp(0.0, double.infinity));

    final double effLoanRate = quotation.annualInterestRate > 0
        ? quotation.annualInterestRate
        : 7.5;
    final double monthlySolarSavings =
        (quotation.annualSavings > 0
            ? quotation.annualSavings
            : quotation.annualGenerationUnits * 8.0) /
        12.0;

    final loan36 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 36,
    );
    final loan60 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 60,
    );
    final loan84 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 84,
    );
    final loan120 = SolarQuotationCalculations.calculateLoanBreakdown(
      principal: loanPrincipal,
      annualInterestRate: effLoanRate,
      tenureMonths: 120,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Corporate Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 48,
                        height: 48,
                        margin: const pw.EdgeInsets.only(right: 10),
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            comp.companyName.isNotEmpty
                                ? comp.companyName
                                : 'SIYA INFOTECH & SOLAR ENERGY',
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 13.0,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Authorized Solar Channel Partner | PM Surya Ghar: Muft Bijli Yojana',
                            style: pw.TextStyle(
                              color: emeraldColor,
                              fontSize: 7.8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Betawad, Tal. Shindkheda, Dist. Dhule, Maharashtra | Helpline: +91 9673220315',
                            style: const pw.TextStyle(
                              color: slateMutedColor,
                              fontSize: 6.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Title Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: const pw.BoxDecoration(
                  color: navyColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          tr(
                            'NATIONALIZED BANK ROOFTOP SOLAR LOAN — EMI CALCULATION SHEET',
                            'पीएम सूर्य घर बँक सोलर कर्ज हप्ता (EMI) पत्रक',
                          ),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          tr(
                            'PM Surya Ghar Concessional Solar Financing Scheme',
                            'सुलभ राष्ट्रीयकृत बँक सोलर कर्ज योजना (SBI / Bank of Maharashtra / PNB)',
                          ),
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFFBAE6FD),
                            fontSize: 7.2,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      '${tr("Proposal No.", "कोटेशन क्र.")}: ${quotation.quotationNo}',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8.0,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Customer & Site Profile Card
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow(
                            tr('Applicant Name', 'ग्राहकाचे नाव'),
                            quotation.customerName,
                            isBold: true,
                          ),
                          _buildProfileRow(
                            tr('Applicant Name', 'ग्राहकाचे नाव'),
                            quotation.customerName,
                            isBold: true,
                          ),
                          _buildProfileRow(
                            tr('Consumer No. (CA)', 'ग्राहक क्र.'),
                            quotation.consumerNo.isNotEmpty
                                ? quotation.consumerNo
                                : 'To be provided',
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow(
                            tr('Proposed System', 'प्रस्तावित सोलर क्षमता'),
                            '${quotation.systemCapacity} Grid-Connected Rooftop PV',
                            isBold: true,
                          ),
                          _buildProfileRow(
                            tr('Site Address', 'जागेचा पत्ता'),
                            '${quotation.address}, ${quotation.villageCity}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Loan Capital Structure
              _buildSectionHeader(
                isLoanOnProjectCost
                    ? tr('LOAN FINANCING & CAPITAL STRUCTURE', 'बँक कर्ज व भांडवली रचना')
                    : tr('LOAN FINANCING ON NET AFTER SUBSIDY', 'सबसिडी वजा जाता बँक कर्ज रचना'),
                subTitle: 'Concessional Scheme @ ${effLoanRate.toStringAsFixed(2)}% p.a.',
              ),
              pw.Row(
                children: [
                  _buildHighlightBox(
                    tr('TOTAL PROJECT COST', 'एकूण किंमत'),
                    inrIntFormatter.format(quotation.grandTotal),
                    tr('Turnkey Incl. GST', 'जीएसटीसह किंमत'),
                    darkTextColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    tr('CENTRAL SUBSIDY', 'शासकीय सबसिडी'),
                    inrIntFormatter.format(quotation.subsidyAmount),
                    tr('PM Surya Ghar DBT', 'थेट बँक खात्यात'),
                    goldenYellowColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    tr('NET COST', 'निव्वळ रक्कम'),
                    inrIntFormatter.format(netAmountAfterSubsidy),
                    tr('Payable Post-Subsidy', 'सबसिडी वजा जाता'),
                    navyColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    'CUSTOMER MARGIN ($marginPct%)',
                    inrIntFormatter.format(customerMargin),
                    customerMargin <= 0 ? 'Zero Down Payment' : 'Customer Margin',
                    darkTextColor,
                  ),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox(
                    'BANK LOAN ($loanPct%)',
                    inrIntFormatter.format(loanPrincipal),
                    isLoanOnProjectCost ? 'Sanctioned on Total Cost' : 'Eligible Loan on Net',
                    emeraldColor,
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Multi-Tenure Comparison Matrix
              _buildSectionHeader(
                tr('MULTI-TENURE EMI COMPARISON MATRIX', 'मासिक हप्ता (EMI) तुलना कोष्टक'),
                subTitle: tr('Solar Savings Comfortably Offsetting EMI', 'वीज बिलातील बचतीतून हप्ता फेड'),
              ),
              _buildEmiComparisonMatrixTable(
                loan36: loan36,
                loan60: loan60,
                loan84: loan84,
                loan120: loan120,
                monthlySolarSavings: monthlySolarSavings,
                inrIntFormatter: inrIntFormatter,
              ),

              pw.SizedBox(height: 8),

              // Subsidy DBT & Benefit Strategy
              _buildSectionHeader(
                tr('FINANCIAL BENEFIT & 100% SELF-FINANCING ADVANTAGE', 'आर्थिक फायदा व १००% मासिक वीज बचत'),
                subTitle: tr('Positive Cash Flow from Month 1', 'पहिल्या महिन्यापासून बचत'),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        isLoanOnProjectCost
                            ? tr(
                                '• Direct Subsidy Credit: Under PM Surya Ghar, central subsidy of ${inrIntFormatter.format(quotation.subsidyAmount)} is deposited directly to your bank account via DBT post net metering, substantially easing your finances.',
                                '• थेट सबसिडी जमा: पीएम सूर्य घर योजनेअंतर्गत ${inrIntFormatter.format(quotation.subsidyAmount)} शासकीय सबसिडी थेट बँक खात्यात DBT द्वारे जमा होते, ज्यामुळे कर्जाचा भार अत्यंत हलका होतो.',
                              )
                            : tr(
                                '• Lower Monthly EMI: Availing loan on net cost (${inrIntFormatter.format(netAmountAfterSubsidy)}) drops EMI to just ${inrIntFormatter.format(loan120['emi'] ?? 0)}/mo (10-Year tenure, 120 Months), keeping financing light.',
                                '• कमी मासिक हप्ता: निव्वळ रकमेवर कर्ज घेतल्यास हप्ता फक्त ${inrIntFormatter.format(loan120['emi'] ?? 0)}/महिना (१२० महिने) येतो.',
                              ),
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          color: slateBodyColor,
                          lineSpacing: 1.2,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        tr(
                          '• 100% Self-Financing: Monthly electricity bill savings (${inrIntFormatter.format(monthlySolarSavings)}/mo) comfortably exceed EMI (${inrIntFormatter.format(loan120['emi'] ?? 0)}/mo), giving instant net surplus in your pocket from Month 1!',
                          '• १००% स्व-फेडणारा प्रकल्प: दरमहा वीज बिल बचत (${inrIntFormatter.format(monthlySolarSavings)}/महिना) हप्त्यापेक्षा (${inrIntFormatter.format(loan120['emi'] ?? 0)}/महिना) जास्त असल्याने पहिल्याच महिन्यापासून निव्वळ नफा मिळतो!',
                        ),
                        style: const pw.TextStyle(
                          fontSize: 6.5,
                          color: slateBodyColor,
                          lineSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Empanelled Banks
              _buildSectionHeader(
                tr('EMPANELLED NATIONALIZED BANKS', 'अधिकृत राष्ट्रीयकृत बँका व सोलर योजना'),
                subTitle: tr('Concessional Solar Loans', 'कमी व्याजदराची बँक कर्जे'),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildBankBadge(
                    'SBI Surya Ghar',
                    '7.00% p.a.*',
                    'Zero Collateral up to 3L',
                  ),
                  _buildBankBadge(
                    'Bank of Maharashtra',
                    '7.15% p.a.*',
                    'Direct JanSamarth Portal',
                  ),
                  _buildBankBadge(
                    'Punjab National Bank',
                    '7.00% p.a.*',
                    'Tenure up to 120 Months',
                  ),
                  _buildBankBadge(
                    'Canara / Union Bank',
                    '7.25% p.a.*',
                    'Fast Track Sanction',
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Checklist & Signatures Block
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Checklist
                  pw.Expanded(
                    flex: 6,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                        border: pw.Border.all(
                          color: borderDarkColor,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            tr(
                              'DOCUMENT CHECKLIST: (Submit to Siya Infotech)',
                              'आवश्यक कागदपत्रे चेकलिस्ट: (सिया इन्फोटेककडे जमा करा)',
                            ),
                            style: pw.TextStyle(
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          ...(() {
                            final docs = quotation.loanDocuments.isNotEmpty
                                ? quotation.loanDocuments
                                : SolarQuotation.defaultLoanDocuments;
                            return List.generate(
                              docs.length,
                              (i) => _buildBulletPoint('${i + 1}. ${_translateLoanDoc(docs[i], quotation.language)}'),
                            );
                          })(),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Signature Block
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      height: 65,
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                        border: pw.Border.all(
                          color: borderDarkColor,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'FOR SIYA INFOTECH & SOLAR ENERGY',
                            style: pw.TextStyle(
                              fontSize: 6.8,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          if (stampImage != null)
                            pw.Container(
                              height: 28,
                              child: pw.Image(
                                stampImage,
                                fit: pw.BoxFit.contain,
                              ),
                            )
                          else
                            pw.SizedBox(height: 18),
                          pw.Text(
                            'Authorized Signatory / Seal',
                            style: const pw.TextStyle(
                              fontSize: 6.2,
                              color: slateMutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 6),
                padding: const pw.EdgeInsets.only(top: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: borderDarkColor, width: 0.8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Siya Infotech & Solar Energy | PM Surya Ghar Authorized Partner | Helpline: +91 9673220315',
                      style: const pw.TextStyle(
                        fontSize: 6.8,
                        color: slateMutedColor,
                      ),
                    ),
                    pw.Text(
                      'Proposal No.: ${quotation.quotationNo} | Standalone Bank EMI Sheet',
                      style: const pw.TextStyle(
                        fontSize: 6.8,
                        color: slateMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Download Standalone Bank Loan EMI Calculation Sheet PDF
  static Future<void> downloadBankLoanEmiSheetPdf(
    BuildContext context,
    SolarQuotation quotation, {
    bool includeStampAndSignature = true,
  }) async {
    try {
      final pdfBytes = await generateBankLoanEmiSheetPdfBytes(
        quotation,
        includeStampAndSignature: includeStampAndSignature,
      );
      final filename =
          'Bank_Loan_EMI_Sheet_${quotation.customerName.replaceAll(RegExp(r'\s+'), '_')}_${quotation.quotationNo}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading Bank Loan EMI Sheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Direct Print Standalone Bank Loan EMI Calculation Sheet PDF
  static Future<void> printBankLoanEmiSheetPdf(
    SolarQuotation quotation, {
    bool includeStampAndSignature = true,
  }) async {
    final pdfBytes = await generateBankLoanEmiSheetPdfBytes(
      quotation,
      includeStampAndSignature: includeStampAndSignature,
    );
    final filename =
        'Bank_Loan_EMI_Sheet_${quotation.customerName.replaceAll(RegExp(r'\s+'), '_')}_${quotation.quotationNo}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: filename,
    );
  }
}
