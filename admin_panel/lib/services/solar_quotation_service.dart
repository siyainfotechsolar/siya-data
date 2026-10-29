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
          pw.Text(
            title,
            style: pw.TextStyle(
              color: darkTextColor,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subTitle != null) ...[
            pw.Spacer(),
            pw.Text(
              subTitle,
              style: const pw.TextStyle(
                color: slateMutedColor,
                fontSize: 8.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Common Header for Pages 2, 3, 4 ────────────────────────────────────────
  static pw.Widget _buildPageTopHeader(String pageTitle, int pageNumber, int totalPages) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: borderDarkColor, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'SIYA INFOTECH & SOLAR ENERGY',
                style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold, color: navyColor),
              ),
              pw.Text(
                '  |  $pageTitle',
                style: const pw.TextStyle(fontSize: 8.5, color: slateMutedColor),
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
  static pw.Widget _buildPageFooter(int pageNumber, int totalPages, String proposalNo) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8)),
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
    final pdf = pw.Document();

    // Load Customer Signature Font if needed
    pw.Font? customerSignatureFont;
    if (includeCustomerSignature) {
      try {
        customerSignatureFont = await CustomerSignatureHelper.loadSignatureFont();
      } catch (_) {}
    }

    final comp = MasterDataHub.company;

    // Load Company Logo
    pw.MemoryImage? logoImage;
    if (comp.logoImagePath != null && comp.logoImagePath!.isNotEmpty) {
      final customLogoBytes = SettingsService.decodeImageFromDataUri(comp.logoImagePath);
      if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
        try {
          logoImage = pw.MemoryImage(customLogoBytes);
        } catch (_) {}
      }
    }
    if (logoImage == null) {
      try {
        final ByteData logoData = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    // Load Company Stamp
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      if (customStampAndSignatureBytes != null && customStampAndSignatureBytes.isNotEmpty) {
        stampImage = pw.MemoryImage(customStampAndSignatureBytes);
      } else {
        final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes();
        if (stampBytes != null) {
          stampImage = pw.MemoryImage(stampBytes);
        }
      }
    }

    // Load On-Grid System Architecture Diagram Image
    pw.MemoryImage? diagramImage;
    try {
      final ByteData diagramData = await rootBundle.load('assets/images/on_grid_solar_diagram.jpg');
      diagramImage = pw.MemoryImage(diagramData.buffer.asUint8List());
    } catch (_) {
      try {
        final fallbackFile = File('admin_panel/assets/images/on_grid_solar_diagram.jpg');
        if (fallbackFile.existsSync()) {
          diagramImage = pw.MemoryImage(fallbackFile.readAsBytesSync());
        } else {
          final brainFile = File('C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149/on_grid_solar_diagram.jpg');
          if (brainFile.existsSync()) {
            diagramImage = pw.MemoryImage(brainFile.readAsBytesSync());
          }
        }
      } catch (_) {}
    }

    // Load Company Profile Solar Hero Graphic Banner Image
    pw.MemoryImage? bannerImage;
    try {
      final ByteData bannerData = await rootBundle.load('assets/images/company_profile_banner.jpg');
      bannerImage = pw.MemoryImage(bannerData.buffer.asUint8List());
    } catch (_) {
      try {
        final fallbackFile = File('admin_panel/assets/images/company_profile_banner.jpg');
        if (fallbackFile.existsSync()) {
          bannerImage = pw.MemoryImage(fallbackFile.readAsBytesSync());
        } else {
          final brainFile = File('C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149/company_profile_banner.jpg');
          if (brainFile.existsSync()) {
            bannerImage = pw.MemoryImage(brainFile.readAsBytesSync());
          }
        }
      } catch (_) {}
    }

    // Load Seasonal Solar Generation Infographic Banner Image
    pw.MemoryImage? seasonalBannerImage;
    try {
      final ByteData seasonalData = await rootBundle.load('assets/images/solar_seasonal_generation_banner.jpg');
      seasonalBannerImage = pw.MemoryImage(seasonalData.buffer.asUint8List());
    } catch (_) {
      try {
        final fallbackFile = File('admin_panel/assets/images/solar_seasonal_generation_banner.jpg');
        if (fallbackFile.existsSync()) {
          seasonalBannerImage = pw.MemoryImage(fallbackFile.readAsBytesSync());
        } else {
          final brainFile = File('C:/Users/Admin/.gemini/antigravity-ide/brain/3f02c7c4-7581-4140-9b4d-4531f2d04149/solar_seasonal_generation_banner_1793261670113.jpg');
          if (brainFile.existsSync()) {
            seasonalBannerImage = pw.MemoryImage(brainFile.readAsBytesSync());
          }
        }
      } catch (_) {}
    }

    // Formatters
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final inrIntFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final numberFormat = NumberFormat('#,##,###');

    // Standard GST Calculation (70:30 Split)
    final gst = quotation.gstBreakdown;

    // 12-Month Generation Schedule
    final capacityKw = SolarQuotationCalculations.parseCapacity(quotation.systemCapacity);
    final monthlyYields = SolarQuotationCalculations.calculate12MonthGeneration(
      capacityKw: capacityKw,
      electricityTariff: quotation.electricityTariff > 0 ? quotation.electricityTariff : 8.0,
      targetAnnualUnits: quotation.annualGenerationUnits > 0 ? quotation.annualGenerationUnits : null,
    );

    const int totalPages = 7;

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
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                            comp.companyName.isNotEmpty ? comp.companyName : 'SIYA INFOTECH & SOLAR ENERGY',
                            style: pw.TextStyle(
                              color: navyColor,
                              fontSize: 14.0,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Authorized Solar EPC & Channel Partner | PM Surya Ghar: Muft Bijli Yojana',
                            style: pw.TextStyle(
                              color: emeraldColor,
                              fontSize: 8.2,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            comp.address.isNotEmpty ? comp.address : 'Betawad, Tal. Shindkheda, Dist. Dhule, Maharashtra - 425403',
                            style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.2),
                          ),
                          pw.Text(
                            'Mobile: ${comp.mobile.isNotEmpty ? comp.mobile : "+91 9673220315 / +91 8888001122"} | Email: ${comp.email.isNotEmpty ? comp.email : "siyainfotech.solar@gmail.com"} | GSTIN: ${comp.gstin.isNotEmpty ? comp.gstin : "27AABCS1234F1Z5"}',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8),
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
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ),

              pw.SizedBox(height: 10),

              // About Siya Infotech & Solar Energy Section
              _buildSectionHeader('ABOUT SIYA INFOTECH & SOLAR ENERGY', subTitle: 'Pioneering Sustainable Rooftop Solar Infrastructure'),
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Text(
                  'Siya Infotech & Solar Energy is a premier, full-service Solar EPC (Engineering, Procurement, and Construction) enterprise based in Dhule, Maharashtra. We deliver high-efficiency, turnkey grid-connected rooftop solar solutions for residential, commercial, industrial, and agricultural consumers.\n\n'
                  'As an authorized channel partner under the Ministry of New & Renewable Energy (MNRE) and the national PM Surya Ghar: Muft Bijli Yojana, we offer comprehensive project execution -- from rooftop structural engineering and shadow analysis to supply of Tier-1 ALMM-listed bifacial/mono modules, smart grid inverters, seamless MSEDCL net metering liaisoning, and direct subsidy facilitation. Our mission is to empower homes and businesses to achieve up to 90% power bill reduction through clean, dependable solar electricity.',
                  style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.5, lineSpacing: 2.0),
                ),
              ),

              pw.SizedBox(height: 10),

              // Proven Track Record & EPC Credentials (6 Badges)
              _buildSectionHeader('PROVEN TRACK RECORD & EPC CREDENTIALS', subTitle: 'Commitment to Quality, Speed & Customer Delight'),
              pw.Row(
                children: [
                  _buildProfileBadge('500+ INSTALLATIONS', '2.5+ MWp', 'Solar capacity commissioned across North Maharashtra', navyColor),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge('100% SUBSIDY CLAIMS', 'Direct DBT', 'Seamless government subsidy crediting assistance', emeraldColor),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge('TIER-1 COMPONENTS', 'ALMM List-I', 'TopCon Bifacial & Mono PERC solar modules', goldenYellowColor),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  _buildProfileBadge('TURNKEY LIAISONING', 'MSEDCL / Discom', 'Complete sanction, inspection & net meter setup', navyColor),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge('25-YR PERFORMANCE', 'Linear Guarantee', 'Manufacturer power warranty & local service', emeraldColor),
                  pw.SizedBox(width: 8),
                  _buildProfileBadge('CONCESSIONAL LOAN', 'National Banks', 'Low-interest solar loans up to 90% project cost', darkTextColor),
                ],
              ),

              pw.SizedBox(height: 10),

              // Project Proposal Recipient & Submission Block
              pw.Container(
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                            'PROPOSAL PREPARED EXCLUSIVELY FOR:',
                            style: pw.TextStyle(color: navyColor, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            quotation.customerName,
                            style: pw.TextStyle(color: darkTextColor, fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            'Site Location: ${quotation.address.isNotEmpty ? quotation.address : "Rooftop Site Location"}, ${quotation.villageCity.isNotEmpty ? quotation.villageCity : ""}, ${quotation.district.isNotEmpty ? quotation.district : "Dhule"}',
                            style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.2),
                          ),
                          pw.Text(
                            'Consumer / CA No.: ${quotation.consumerNo.isNotEmpty ? quotation.consumerNo : "To be assigned"} | Mobile: ${quotation.mobileNo.isNotEmpty ? quotation.mobileNo : "N/A"}',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.8, height: 48, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PROJECT REFERENCE DETAILS:',
                            style: pw.TextStyle(color: navyColor, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Proposal No.: ${quotation.quotationNo}',
                            style: pw.TextStyle(color: darkTextColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            'Proposed System: ${quotation.systemCapacity} Grid-Connected Rooftop PV',
                            style: pw.TextStyle(color: emeraldColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Date: ${quotation.formattedDate} | Validity: 30 Days from issuance',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8),
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
              _buildPageTopHeader('EXECUTIVE PROPOSAL & PROJECT OVERVIEW', 2, totalPages),

              // Proposal Title Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                          'PROJECT PROPOSAL & COMMERCIAL QUOTATION',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 11.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.4),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Grid-Connected Rooftop Solar Photovoltaic (PV) System',
                          style: const pw.TextStyle(color: PdfColor.fromInt(0xFFBAE6FD), fontSize: 8.2),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Proposal No.: ${quotation.quotationNo}',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Date: ${quotation.formattedDate}',
                          style: const pw.TextStyle(color: PdfColor.fromInt(0xFFE2E8F0), fontSize: 7.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Customer Profile Card
              _buildSectionHeader('CUSTOMER & INSTALLATION SITE DETAILS'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                          _buildProfileRow('Customer Name', quotation.customerName, isBold: true),
                          _buildProfileRow('Consumer / CA No.', quotation.consumerNo.isNotEmpty ? quotation.consumerNo : 'To be provided for Net Metering'),
                          _buildProfileRow('Contact Mobile', quotation.mobileNo.isNotEmpty ? quotation.mobileNo : 'N/A'),
                          _buildProfileRow('Email Address', (quotation.email != null && quotation.email!.isNotEmpty) ? quotation.email! : 'N/A'),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.8, height: 60, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 10)),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Installation Address', quotation.address.isNotEmpty ? quotation.address : 'Rooftop Site Location'),
                          _buildProfileRow('Village / City', quotation.villageCity.isNotEmpty ? quotation.villageCity : 'N/A'),
                          _buildProfileRow('District & State', '${quotation.district.isNotEmpty ? quotation.district : "Dhule"}, Maharashtra'),
                          _buildProfileRow('Tariff Category', '${quotation.quotationType} Connection'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Executive Introduction
              _buildSectionHeader('EXECUTIVE SUMMARY'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Text(
                  'We thank you for considering SIYA INFOTECH & SOLAR ENERGY as your solar energy partner. We are pleased to submit this comprehensive proposal for the design, engineering, procurement, supply, installation, testing, and commissioning of a high-efficiency ${quotation.systemCapacity} Grid-Tied Solar Rooftop System.\n\n'
                  'This customized proposal integrates premium Tier-1 solar modules with 25-year performance warranties, high-efficiency grid-tied inverters with digital monitoring, and wind-resilient galvanized structures. It is specifically designed to eliminate up to 90% of your monthly electricity expenditure while securing central government subsidies under the PM Surya Ghar: Muft Bijli Yojana.',
                  style: const pw.TextStyle(color: slateBodyColor, fontSize: 8.0, lineSpacing: 2.2),
                ),
              ),

              pw.SizedBox(height: 14),

              // Key System Highlights Grid (6 spacious cards)
              _buildSectionHeader('KEY PROJECT HIGHLIGHTS'),
              pw.Row(
                children: [
                  _buildHighlightBox('SYSTEM CAPACITY', quotation.systemCapacity, 'DC Solar Capacity', emeraldColor),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox('ANNUAL GENERATION', '${numberFormat.format(quotation.annualGenerationUnits.round())} Units', 'Est. kWh / Year', navyColor),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox('TOTAL PROJECT COST', inrIntFormatter.format(quotation.grandTotal), 'Incl. 70:30 GST', darkTextColor),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  _buildHighlightBox(
                    'CENTRAL SUBSIDY',
                    quotation.subsidyAmount > 0 ? inrIntFormatter.format(quotation.subsidyAmount) : 'N/A (Commercial)',
                    'PM Surya Ghar Scheme',
                    emeraldColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox(
                    'NET EFFECTIVE COST',
                    inrIntFormatter.format(quotation.payableAfterSubsidy > 0 ? quotation.payableAfterSubsidy : quotation.grandTotal),
                    'After Direct Subsidy',
                    navyColor,
                  ),
                  pw.SizedBox(width: 8),
                  _buildHighlightBox(
                    'SIMPLE PAYBACK',
                    quotation.paybackYears > 0 ? '${quotation.paybackYears.toStringAsFixed(1)} Years' : '3.5 Years',
                    'High Lifetime ROI',
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
              _buildPageTopHeader('TECHNICAL SPECIFICATIONS & FINANCIAL BREAKDOWN', 3, totalPages),

              // Section 1: Detailed BOQ
              _buildSectionHeader('BILL OF MATERIALS (BOQ) & TECHNICAL SPECIFICATIONS', subTitle: 'Tier-1 MNRE / ALMM Approved Components'),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    _buildBoqHeaderRow(),
                    if (quotation.items.isNotEmpty)
                      ...quotation.items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final it = entry.value;
                        final String make = (it['make'] != null && it['make']!.isNotEmpty)
                            ? it['make']!
                            : (it['company'] != null && it['company']!.isNotEmpty)
                                ? it['company']!
                                : (idx == 0
                                    ? quotation.panelBrand
                                    : (idx == 1
                                        ? quotation.inverterBrand
                                        : (idx == 2 ? quotation.mountingStructure : 'Standard Grade')));
                        final String warranty = it['warranty']?.isNotEmpty == true
                            ? it['warranty']!
                            : (idx == 0
                                ? '25 Years Linear Performance Warranty'
                                : (idx == 1
                                    ? '5 Years Standard Replacement Warranty'
                                    : (idx == 2 ? '10 Years Structural Integrity Warranty' : 'Standard Component Warranty')));
                        return _buildBoqItemRow(
                          '${idx + 1}',
                          it['item'] ?? '',
                          make,
                          it['spec'] ?? '',
                          it['qty'] ?? '1 Set',
                          warranty,
                          isZebra: idx % 2 == 1,
                        );
                      })
                    else ...[
                      _buildBoqItemRow(
                        '1',
                        'Solar PV Modules',
                        quotation.panelBrand.isNotEmpty ? quotation.panelBrand : 'Waaree / Adani / Goldi (DCR TopCon)',
                        quotation.panelWattage.isNotEmpty ? quotation.panelWattage : '550 Wp TopCon Bifacial / Mono PERC DCR Grade Modules',
                        quotation.systemCapacity,
                        '25 Years Linear Performance Warranty',
                        isZebra: false,
                      ),
                      _buildBoqItemRow(
                        '2',
                        'Grid-Tied Inverter',
                        quotation.inverterBrand.isNotEmpty ? quotation.inverterBrand : 'Growatt / Solis / Polycab',
                        '(${quotation.inverterCapacity.isNotEmpty ? quotation.inverterCapacity : "3.3 kW"}) High Efficiency MPPT Inverter with WiFi',
                        '1 Set',
                        '5 Years Standard Replacement Warranty',
                        isZebra: true,
                      ),
                      _buildBoqItemRow(
                        '3',
                        'Mounting Structure',
                        'Hot Dip Galvanized Iron (GI)',
                        quotation.mountingStructure.isNotEmpty ? quotation.mountingStructure : 'Elevated Structure engineered for 150 km/h wind resilience',
                        'Complete Roof Set',
                        '10 Years Structural Integrity Warranty',
                        isZebra: false,
                      ),
                      _buildBoqItemRow(
                        '4',
                        'DC Distribution Box',
                        'Hensel / Elmex / Schneider',
                        'IP65 Weatherproof Enclosure with 1000V DC Fuses and Type-II Surge Protection Devices (SPD)',
                        '1 Set',
                        '2 Years Equipment Warranty',
                        isZebra: true,
                      ),
                      _buildBoqItemRow(
                        '5',
                        'AC Distribution Box',
                        'Hensel / Elmex / Schneider',
                        'IP65 Weatherproof Enclosure with Heavy-Duty MCB / Isolator and AC Surge Protection Devices',
                        '1 Set',
                        '2 Years Equipment Warranty',
                        isZebra: false,
                      ),
                      _buildBoqItemRow(
                        '6',
                        'Solar DC & AC Cables',
                        'Polycab / Havells / KEI',
                        '4 sq.mm / 6 sq.mm UV-resistant, Flame Retardant (FRLS) Cu/Al Cables enclosed in UV conduit pipes',
                        'As per site layout',
                        '5 Years Manufacturer Warranty',
                        isZebra: true,
                      ),
                      _buildBoqItemRow(
                        '7',
                        'Earthing & Lightning Kit',
                        'True Power / Ashlok',
                        'Chemical Gel Earthing Electrodes (Inverter, Structure & LA) + Early Streamer Lightning Arrester',
                        '3 Pits + 1 Arrester',
                        '5 Years Functional Warranty',
                        isZebra: false,
                      ),
                      _buildBoqItemRow(
                        '8',
                        'Bi-Directional Net Meter',
                        'MSEDCL / Discom Approved',
                        'MSEDCL Approved Dual-Register Import/Export Smart Energy Meter',
                        '1 Unit',
                        'Standard Utility Warranty',
                        isZebra: true,
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Section 2: Statutory 70:30 GST Breakdown
              _buildSectionHeader('STATUTORY 70:30 GST FINANCIAL BREAKDOWN', subTitle: 'Ministry of Finance Mandated Ratio'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Note: As per Ministry of Finance GST Circular & Solar EPC Guidelines, rooftop solar contracts are taxed under a statutory 70:30 split -- 70% of total project cost treated as Goods (@ 5% GST) and 30% treated as Services/Civil Works (@ 18% GST), yielding an effective blended GST rate of approx. 8.9%.',
                      style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.2, lineSpacing: 1.8),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        children: [
                          _buildFinRow('70% Goods Portion Value (Solar Modules, Inverter, Hardware)', currencyFormatter.format(gst.portion70), isZebra: false),
                          _buildFinRow('GST on Goods Portion @ 5%', currencyFormatter.format(gst.gst5), isZebra: true),
                          _buildFinRow('30% Services Portion Value (Installation, Commissioning, Civil)', currencyFormatter.format(gst.portion30), isZebra: false),
                          _buildFinRow('GST on Services Portion @ 18%', currencyFormatter.format(gst.gst18), isZebra: true),
                          _buildFinRow('Total Base Taxable Value', currencyFormatter.format(gst.totalTaxableValue), isBold: true, isZebra: false),
                          _buildFinRow('Total GST Amount Included', currencyFormatter.format(gst.totalGstIncluded), isBold: true, isZebra: true),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: const pw.BoxDecoration(
                              color: accentBannerBg,
                              border: pw.Border(top: pw.BorderSide(color: navyColor, width: 1.2)),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('TOTAL COMMERCIAL PROPOSAL AMOUNT (INCL. GST):', style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                                pw.Text(currencyFormatter.format(quotation.grandTotal), style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
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
              _buildSectionHeader('SCOPE OF SUPPLY & INSTALLATION SERVICES'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint('Detailed rooftop shadow profiling & engineering structural design.'),
                          _buildBulletPoint('Supply of all Tier-1 modules, inverters, cables & accessories.'),
                          _buildBulletPoint('Complete mechanical mounting with wind-tested GI structures.'),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint('Complete electrical AC/DC cabling, earthing & surge arresters.'),
                          _buildBulletPoint('Online MSEDCL portal application & net metering liaisoning.'),
                          _buildBulletPoint('System testing, pre-commissioning verification & handover.'),
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
              _buildPageTopHeader('GENERATION FORECAST & ENVIRONMENTAL IMPACT', 4, totalPages),

              // Section 1: Seasonal Performance Infographic Banner
              _buildSectionHeader(
                'ROOFTOP SOLAR SEASONAL GENERATION DYNAMICS',
                subTitle: 'Summer Peak Irradiation vs. Monsoon Diffused Light vs. Winter Efficiency',
              ),
              if (seasonalBannerImage != null) ...[
                pw.Container(
                  width: double.infinity,
                  height: 125,
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(seasonalBannerImage, fit: pw.BoxFit.contain),
                  ),
                ),
                pw.SizedBox(height: 7),
              ],

              // Section 2: 12-Month Generation Visual Analytics Chart
              _buildSectionHeader('12-MONTH SOLAR GENERATION VISUAL TREND & ANALYTICS', subTitle: 'Engineered for Maharashtra Solar Irradiance Profile'),
              _buildGenerationVisualChart(monthlyYields),

              pw.SizedBox(height: 7),

              // Section 3: 2-Column Monthly Yield & Financial Savings Table
              _buildSectionHeader('12-MONTH (JANUARY - DECEMBER) DETAILED GENERATION SCHEDULE'),
              _buildMonthlyGenerationTable(monthlyYields, quotation.annualGenerationUnits, currencyFormatter),

              pw.SizedBox(height: 7),

              // Section 4: Environmental & Green Energy Impact
              _buildSectionHeader('ENVIRONMENTAL & GREEN ENERGY IMPACT'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF0FDF4),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: emeraldColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildEcoMetric('CO2 Offset / Year', '${(quotation.annualGenerationUnits * 0.82 / 1000).toStringAsFixed(1)} Metric Tons', 'Carbon emissions avoided annually'),
                    _buildEcoMetric('Lifetime Trees Equivalent', '${(quotation.annualGenerationUnits * 0.04 * 25).round()} Trees', 'Equivalent mature trees planted over 25 yrs'),
                    _buildEcoMetric('Lifetime Clean Energy', '${numberFormat.format((quotation.annualGenerationUnits * 25).round())} kWh', 'Total green electricity generated'),
                  ],
                ),
              ),

              pw.SizedBox(height: 7),

              // Section 5: Performance Assurance Card
              _buildSectionHeader('SYSTEM PERFORMANCE & GENERATION ASSURANCES'),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildTermBullet('1. Tier-1 Solar PV Modules: Linear power output guarantee with <= 2% degradation in Year 1 and <= 0.55%/year thereafter up to 25 Years.'),
                    _buildTermBullet('2. High-Yield Inverter: Advanced dual MPPT technology with > 98.4% peak efficiency ensuring maximum harvest during low-light and winter conditions.'),
                    _buildTermBullet('3. Net Metering Banking: Unconsumed solar electricity credited directly to MSEDCL billing cycle, offsetting peak commercial and residential tariffs.'),
                    _buildTermBullet('4. Weather Resilience: Elevated GI mounting engineered to withstand extreme wind velocities up to 150 km/h and severe climatic variations.'),
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
              _buildPageTopHeader('SYSTEM ARCHITECTURE & WORKING FLOW', 5, totalPages),

              _buildSectionHeader(
                'ON-GRID ROOFTOP SOLAR SYSTEM WORKING ARCHITECTURE',
                subTitle: 'Generate Solar Power | Use Clean Electricity | Export Excess to Discom Grid',
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
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
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
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: navyColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildArchSummaryItem('1. Solar Panels', 'Generates DC Electricity'),
                    _buildArchSummaryItem('2. Grid Inverter', 'Converts DC to 230V AC'),
                    _buildArchSummaryItem('3. Home Loads', 'Direct Self-Consumption'),
                    _buildArchSummaryItem('4. Net Meter', 'Bi-Directional Recording'),
                    _buildArchSummaryItem('5. MSEDCL Grid', 'Zero Battery Maintenance'),
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
              _buildPageTopHeader('FINANCIAL ROI, PAYMENT TERMS & ACCEPTANCE', 6, totalPages),

              // Financial Analysis & Subsidy Card
              _buildSectionHeader('FINANCIAL & RETURN ON INVESTMENT (ROI) ANALYSIS'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          _buildRoiRow('Total Turnkey Project Cost', inrIntFormatter.format(quotation.grandTotal)),
                          _buildRoiRow(
                            'PM Surya Ghar Central Subsidy',
                            quotation.subsidyAmount > 0 ? inrIntFormatter.format(quotation.subsidyAmount) : 'Rs. 0 (Commercial)',
                            highlightColor: emeraldColor,
                            isBold: true,
                          ),
                          _buildRoiRow(
                            'Net Effective Customer Investment',
                            inrIntFormatter.format(quotation.payableAfterSubsidy > 0 ? quotation.payableAfterSubsidy : quotation.grandTotal),
                            highlightColor: navyColor,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.8, height: 60, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 10)),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          _buildRoiRow('Projected 1st Year Bill Savings', inrIntFormatter.format(quotation.annualSavings > 0 ? quotation.annualSavings : quotation.annualGenerationUnits * 8.0)),
                          _buildRoiRow('Estimated Simple Payback Period', '${quotation.paybackYears.toStringAsFixed(1)} Years', isBold: true),
                          _buildRoiRow('25-Year Cumulative Savings', inrIntFormatter.format((quotation.annualSavings > 0 ? quotation.annualSavings : quotation.annualGenerationUnits * 8.0) * 25), highlightColor: emeraldColor, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Payment Terms & Bank Loan Options
              _buildSectionHeader('PAYMENT TERMS & LOW-INTEREST LOAN OPTIONS'),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Option A: Self-Financed Milestones', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                          pw.SizedBox(height: 4),
                          _buildBulletPoint('20% Advance along with work order confirmation.'),
                          _buildBulletPoint('70% against delivery of solar modules & inverter at site.'),
                          _buildBulletPoint('10% upon complete installation & net meter inspection.'),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.8, height: 65, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 10)),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Option B: Concessional Solar Bank Loan', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                          pw.SizedBox(height: 4),
                          _buildBulletPoint('Nationalized bank solar rooftop loan up to 90% of net project cost after subsidy.'),
                          _buildBulletPoint('Concessional interest rate: ${quotation.annualInterestRate.toStringAsFixed(1)}% p.a. (Tenure: ${quotation.loanTenureMonths} Months).'),
                          _buildBulletPoint('Estimated Monthly EMI: ${inrIntFormatter.format(quotation.monthlyEmi)} / month (Offset by solar savings).'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Bank Details Card
              _buildSectionHeader('COMPANY BANK ACCOUNT (FOR DISBURSEMENT / RTGS / NEFT)'),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBankItem('Account Name', comp.companyName.isNotEmpty ? comp.companyName : 'SIYA INFOTECH & SOLAR ENERGY', isBold: true),
                    _buildBankItem('Bank Name', quotation.bankName.isNotEmpty ? quotation.bankName : comp.bankName),
                    _buildBankItem('Account Number', quotation.accountNo.isNotEmpty ? quotation.accountNo : comp.accountNo, isBold: true),
                    _buildBankItem('IFSC Code', quotation.ifscCode.isNotEmpty ? quotation.ifscCode : comp.ifscCode, isBold: true),
                    _buildBankItem('Branch', quotation.branch.isNotEmpty ? quotation.branch : comp.branch),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Terms & Conditions
              _buildSectionHeader('COMMERCIAL TERMS & WARRANTY COMMITMENTS'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (quotation.termsAndConditions != null && quotation.termsAndConditions!.isNotEmpty)
                      ...quotation.termsAndConditions!.asMap().entries.map((e) {
                        final text = e.value.trim();
                        final hasNumber = RegExp(r'^\d+[\.\)]').hasMatch(text);
                        return _buildTermBullet(hasNumber ? text : '${e.key + 1}. $text');
                      })
                    else ...[
                      _buildTermBullet('1. Warranties: 25 Years linear power warranty on PV modules; 5 Years on grid inverter; 5 Years comprehensive system service warranty.'),
                      _buildTermBullet('2. Subsidy Disbursement: PM Surya Ghar central subsidy is credited directly to customer\'s Aadhaar-linked bank account post MSEDCL net meter installation.'),
                      _buildTermBullet('3. Grid Approval & Net Metering: All liaisoning with MSEDCL / Discom handled turnkey by Siya Infotech & Solar Energy.'),
                      _buildTermBullet('4. Roof Availability: Customer to provide shadow-free roof space, single-phase/three-phase electrical point, and water for module cleaning.'),
                      _buildTermBullet('5. Proposal Validity: This quotation is valid for 30 days from date of issuance. Material pricing subject to prevailing MNRE/ALMM policies.'),
                    ],
                    if (quotation.notes != null && quotation.notes!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: const pw.BoxDecoration(color: accentBannerBg, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
                        child: pw.Text('Special Remarks / Site Notes: ${quotation.notes!.trim()}', style: pw.TextStyle(fontSize: 6.2, fontStyle: pw.FontStyle.italic, color: navyColor)),
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
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('CUSTOMER ACCEPTANCE & SIGN-OFF:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                        if (includeCustomerSignature && customerSignatureFont != null)
                          pw.Text(
                            quotation.customerName,
                            style: pw.TextStyle(font: customerSignatureFont, fontSize: 13, color: navyColor),
                          )
                        else
                          pw.SizedBox(height: 25),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Authorized Signature: ____________', style: const pw.TextStyle(fontSize: 7.0, color: slateMutedColor)),
                            pw.Text('Date: ________', style: const pw.TextStyle(fontSize: 7.0, color: slateMutedColor)),
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
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('FOR SIYA INFOTECH & SOLAR ENERGY:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
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
                            pw.Text('Place: ${quotation.villageCity.isNotEmpty ? quotation.villageCity : "Betawad, Dhule"}', style: const pw.TextStyle(fontSize: 7.0, color: slateMutedColor)),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(quotation.signatoryName.isNotEmpty ? quotation.signatoryName : 'Authorized Signatory', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                                pw.Text(quotation.signatoryDesignation.isNotEmpty ? quotation.signatoryDesignation : 'Authorized Signatory / Seal', style: const pw.TextStyle(fontSize: 5.8, color: slateMutedColor)),
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
    final double netAmountAfterSubsidy = (quotation.quotationType != 'Commercial' && quotation.subsidyAmount > 0)
        ? (quotation.payableAfterSubsidy > 0
            ? quotation.payableAfterSubsidy
            : (quotation.grandTotal - quotation.subsidyAmount).clamp(0.0, double.infinity))
        : quotation.grandTotal;

    // Bank loan is calculated on Net Amount After Subsidy
    final double loanPrincipal = (quotation.bankLoanAmount > 0 && quotation.bankLoanAmount <= (netAmountAfterSubsidy * 1.05))
        ? quotation.bankLoanAmount
        : (netAmountAfterSubsidy * 0.90).roundToDouble();

    final double customerMargin = (quotation.customerContribution > 0 && quotation.customerContribution <= netAmountAfterSubsidy)
        ? quotation.customerContribution
        : (netAmountAfterSubsidy - loanPrincipal).clamp(0.0, double.infinity);

    final double effLoanRate = quotation.annualInterestRate > 0 ? quotation.annualInterestRate : 7.5;
    final double monthlySolarSavings = (quotation.annualSavings > 0 ? quotation.annualSavings : quotation.annualGenerationUnits * 8.0) / 12.0;

    final loan36 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 36);
    final loan60 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 60);
    final loan84 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 84);
    final loan120 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 120);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPageTopHeader('BANK ROOFTOP SOLAR LOAN — EMI CALCULATION & FINANCING', 7, totalPages),

              // Section 1: Loan Capital Structure (Calculated on Net Amount After Subsidy)
              _buildSectionHeader(
                'LOAN FINANCING PARAMETERS & CAPITAL STRUCTURE (CALCULATED ON NET AFTER SUBSIDY)',
                subTitle: 'PM Surya Ghar Nationalized Bank Concessional Financing @ ${effLoanRate.toStringAsFixed(2)}% p.a.',
              ),
              pw.Row(
                children: [
                  _buildHighlightBox('TOTAL PROJECT COST', inrIntFormatter.format(quotation.grandTotal), 'Turnkey Incl. GST', darkTextColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('CENTRAL SUBSIDY', inrIntFormatter.format(quotation.subsidyAmount), 'PM Surya Ghar DBT', goldenYellowColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('NET COST (FINANCED)', inrIntFormatter.format(netAmountAfterSubsidy), 'Payable Post-Subsidy', navyColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('CUSTOMER MARGIN (10%)', inrIntFormatter.format(customerMargin), 'Down Payment on Net', darkTextColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('PROPOSED LOAN (90%)', inrIntFormatter.format(loanPrincipal), 'Eligible Loan on Net', emeraldColor),
                ],
              ),

              pw.SizedBox(height: 9),

              // Section 2: Multi-Tenure Comparison Matrix
              _buildSectionHeader('MULTI-TENURE EMI & NET CASHFLOW COMPARISON MATRIX', subTitle: 'Showing How Solar Electricity Bill Savings Comfortably Offset Monthly EMIs'),
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
              _buildSectionHeader('FINANCIAL BENEFIT: LOAN SANCTIONED ON NET COST AFTER SUBSIDY'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                          pw.Text('Substantially Lower Monthly EMI on Net Cost (${inrIntFormatter.format(netAmountAfterSubsidy)})', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
                          pw.SizedBox(height: 2),
                          pw.Text('Direct Benefit: Central Subsidy Pre-Deducted from Financing Base', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.Text('Because the bank loan is availed strictly on the net cost after deducting the ${inrIntFormatter.format(quotation.subsidyAmount)} central subsidy, your loan principal is only ${inrIntFormatter.format(loanPrincipal)}. This drops your monthly EMI to just ${inrIntFormatter.format(loan60['emi'] ?? 0)}/mo (5-Year tenure), keeping financing exceptionally light and stress-free.', style: const pw.TextStyle(fontSize: 6.5, color: slateBodyColor, lineSpacing: 1.3)),
                        ],
                      ),
                    ),
                    pw.Container(width: 0.8, height: 55, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('100% Self-Financing: Positive Cash Flow from Month 1', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.SizedBox(height: 2),
                          pw.Text('Electricity Bill Savings Exceed the Monthly EMI', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.Text('Your solar power plant generates an estimated ${inrIntFormatter.format(monthlySolarSavings)} in electricity bill savings every month. Since your monthly solar savings (${inrIntFormatter.format(monthlySolarSavings)}/mo) exceed your EMI (${inrIntFormatter.format(loan60['emi'] ?? 0)}/mo), the system completely pays for itself from Month 1 with an instant net surplus in your pocket!', style: const pw.TextStyle(fontSize: 6.5, color: slateBodyColor, lineSpacing: 1.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 9),

              // Section 4: Empanelled Nationalized Banks
              _buildSectionHeader('EMPANELLED NATIONALIZED BANKS & CONCESSIONAL SCHEME FEATURES'),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBankBadge('SBI Surya Ghar', '7.00% p.a.*', 'Zero Collateral up to 3L'),
                    _buildBankBadge('Bank of Maharashtra', '7.15% p.a.*', 'Direct JanSamarth Portal'),
                    _buildBankBadge('Punjab National Bank', '7.00% p.a.*', 'Tenure up to 120 Months'),
                    _buildBankBadge('Canara / Union Bank', '7.25% p.a.*', 'Fast Track Sanction'),
                  ],
                ),
              ),

              pw.SizedBox(height: 9),

              // Section 5: Required Document Checklist
              _buildSectionHeader('LOAN SANCTION DOCUMENTATION CHECKLIST', subTitle: 'Submit to Siya Infotech & Solar Energy for End-to-End Bank Liaisoning'),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint('1. KYC: Applicant Aadhaar Card & PAN Card (Self-Attested).'),
                          _buildBulletPoint('2. Electricity Bill: Latest 3 months paid bills with Consumer CA No.'),
                          _buildBulletPoint('3. Income / Banking: Last 6 months bank statement showing regular transactions.'),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildBulletPoint('4. Property Proof: Latest House Tax Receipt / Index-II / 7/12 Extract.'),
                          _buildBulletPoint('5. Formal Quotation & Rooftop Feasibility Report (Provided by Siya Infotech).'),
                          _buildBulletPoint('6. 2 Passport Size Photographs & JanSamarth Portal Registration.'),
                        ],
                      ),
                    ),
                  ],
                ),
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

  // ════════════════════════════════════════════════════════════════════════════
  // UI WIDGET BUILDER HELPERS FOR PDF
  // ════════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildProfileRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.0,
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
              style: pw.TextStyle(fontSize: labelFontSize, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 2.5),
            pw.Text(
              value,
              maxLines: 1,
              style: pw.TextStyle(fontSize: valueFontSize, fontWeight: pw.FontWeight.bold, color: darkTextColor),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              subText,
              maxLines: 1,
              style: pw.TextStyle(fontSize: subFontSize, color: slateMutedColor),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildProfileBadge(String title, String mainStat, String desc, PdfColor accentColor) {
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
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
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
              style: const pw.TextStyle(fontSize: 6.0, color: slateMutedColor, lineSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildBoqHeaderRow() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: const pw.BoxDecoration(
        color: headerBgColor,
        border: pw.Border(bottom: pw.BorderSide(color: borderDarkColor, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 20, child: pw.Text('#', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.SizedBox(width: 95, child: pw.Text('Item Component', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.SizedBox(width: 105, child: pw.Text('Company / Make (Brand)', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.Expanded(child: pw.Text('Technical Specification & Standard', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.SizedBox(width: 65, child: pw.Text('Quantity', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.SizedBox(width: 95, child: pw.Text('Warranty Term', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
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
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(bottom: pw.BorderSide(color: borderDarkColor, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 20, child: pw.Text(no, style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor))),
          pw.SizedBox(width: 95, child: pw.Text(item, style: pw.TextStyle(fontSize: 7.4, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.SizedBox(width: 105, child: pw.Text(make, style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor))),
          pw.Expanded(child: pw.Text(spec, style: const pw.TextStyle(fontSize: 7.1, color: slateBodyColor))),
          pw.SizedBox(width: 65, child: pw.Text(qty, style: const pw.TextStyle(fontSize: 7.2, color: darkTextColor))),
          pw.SizedBox(width: 95, child: pw.Text(warranty, style: pw.TextStyle(fontSize: 7.1, fontWeight: pw.FontWeight.bold, color: emeraldColor))),
        ],
      ),
    );
  }

  static pw.Widget _buildFinRow(String label, String value, {bool isBold = false, bool isZebra = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(bottom: pw.BorderSide(color: borderDarkColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: isBold ? darkTextColor : slateBodyColor, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor)),
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
            decoration: const pw.BoxDecoration(color: navyColor, shape: pw.BoxShape.circle),
          ),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.4, color: slateBodyColor, lineSpacing: 1.4)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermBullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 6.8, color: slateBodyColor, lineSpacing: 1.3)),
    );
  }

  static pw.Widget _buildArchSummaryItem(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor)),
        pw.SizedBox(height: 1.5),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor)),
      ],
    );
  }

  static pw.Widget _buildRoiRow(String label, String value, {PdfColor? highlightColor, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.8, color: slateBodyColor)),
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

  static pw.Widget _buildBankItem(String label, String value, {bool isBold = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
        pw.SizedBox(height: 1.5),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 7.6, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor),
        ),
      ],
    );
  }

  static pw.Widget _buildEcoMetric(String title, String value, String subtitle) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 7.0, color: slateMutedColor)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
        pw.SizedBox(height: 1),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor)),
      ],
    );
  }

  // ── Monthly Generation Table (2-Column Balanced Design) ────────────────────
  static pw.Widget _buildMonthlyGenerationTable(
    List<MonthlyGenerationRow> monthlyYields,
    double annualUnits,
    NumberFormat currencyFormatter,
  ) {
    final h1 = monthlyYields.length >= 6 ? monthlyYields.sublist(0, 6) : monthlyYields;
    final h2 = monthlyYields.length >= 12 ? monthlyYields.sublist(6, 12) : <MonthlyGenerationRow>[];

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
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.0),
                color: headerBgColor,
                child: pw.Row(
                  children: [
                    pw.SizedBox(width: 48, child: pw.Text('Month', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                    pw.SizedBox(width: 25, child: pw.Text('Days', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                    pw.SizedBox(width: 48, child: pw.Text('Daily Avg', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                    pw.Expanded(child: pw.Text('Generation', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                    pw.SizedBox(width: 58, child: pw.Text('Savings (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                  ],
                ),
              ),
              ...rows.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.0),
                  color: idx % 2 == 1 ? zebraBgColor : PdfColors.white,
                  child: pw.Row(
                    children: [
                      pw.SizedBox(width: 48, child: pw.Text(m.monthEn, style: const pw.TextStyle(fontSize: 6.5, color: darkTextColor))),
                      pw.SizedBox(width: 25, child: pw.Text('${m.days}', style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor))),
                      pw.SizedBox(width: 48, child: pw.Text('${m.avgDailyUnits.toStringAsFixed(1)} u/d', style: const pw.TextStyle(fontSize: 6.5, color: slateBodyColor))),
                      pw.Expanded(child: pw.Text('${m.units.round()} kWh', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyColor))),
                      pw.SizedBox(width: 58, child: pw.Text(currencyFormatter.format(m.estimatedSavings), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 6.5, color: darkTextColor))),
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
                  pw.Text('ANNUAL AGGREGATE SUMMARY: ', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                  pw.Text('365 Days Operation | Avg: ${(annualUnits / 365).toStringAsFixed(1)} kWh/Day', style: const pw.TextStyle(fontSize: 6.5, color: slateBodyColor)),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text('Total Generation: ', style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor)),
                  pw.Text('${annualUnits.round()} kWh / Year', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
                  pw.SizedBox(width: 10),
                  pw.Text('Est. Savings: ', style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor)),
                  pw.Text(currencyFormatter.format(annualUnits * 8.0), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── High-End Professional Monthly Generation Analytics Bar Chart ───────────
  static pw.Widget _buildGenerationVisualChart(List<MonthlyGenerationRow> yields) {
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
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(1.5)),
                    ),
                    margin: const pw.EdgeInsets.only(right: 6),
                  ),
                  pw.Text(
                    'MONTHLY SOLAR GENERATION CURVE & IRRADIANCE (kWh)',
                    style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  _buildLegendIndicator('Summer Peak (Mar-May)', goldenYellowColor),
                  pw.SizedBox(width: 8),
                  _buildLegendIndicator('Monsoon (Jun-Sep)', emeraldColor),
                  pw.SizedBox(width: 8),
                  _buildLegendIndicator('Winter (Oct-Feb)', const PdfColor.fromInt(0xFF1D4ED8)),
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
                          padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.8),
                          margin: const pw.EdgeInsets.only(bottom: 1.5),
                          decoration: const pw.BoxDecoration(
                            color: goldenYellowColor,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                          child: pw.Text(
                            'PEAK',
                            style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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
                          borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2.5)),
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
                      style: const pw.TextStyle(fontSize: 5.0, color: slateMutedColor),
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
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
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
              _buildDiagramNode('1. Solar Panels', quotation.systemCapacity, 'Generates DC Electricity', const PdfColor.fromInt(0xFF0284C7)),
              _buildFlowArrow('DC Power'),
              _buildDiagramNode('2. DCDB Box', 'Protection Box', 'DC Fuses & SPD', const PdfColor.fromInt(0xFFD97706)),
              _buildFlowArrow('DC Power'),
              _buildDiagramNode('3. Grid Inverter', quotation.inverterCapacity, 'Converts DC to 230V AC', emeraldColor),
              _buildFlowArrow('AC Power'),
              _buildDiagramNode('4. ACDB Box', 'AC Protection', 'MCB & Surge Arrest', const PdfColor.fromInt(0xFF7C3AED)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 120, height: 1, color: borderDarkColor),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                child: pw.Text('Bi-Directional Net Metering Power Flow', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
              ),
              pw.Container(width: 120, height: 1, color: borderDarkColor),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildDiagramNode('5. Building Loads', 'Self-Consumption', 'Powers Lights, AC, Fans', navyColor),
              _buildFlowArrow('Net Export / Import', isBiDirectional: true),
              _buildDiagramNode('6. Bi-Directional Net Meter', 'MSEDCL Dual Register', 'Imports & Exports Energy', goldenYellowColor),
              _buildFlowArrow('Grid Banking', isBiDirectional: true),
              _buildDiagramNode('7. MSEDCL Utility Grid', 'Power Distribution', 'Credits Solar Power to Bill', darkTextColor),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDiagramNode(String title, String spec, String desc, PdfColor color) {
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
          pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 1.5),
          pw.Text(spec, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
          pw.SizedBox(height: 1),
          pw.Text(desc, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 5.5, color: slateMutedColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildFlowArrow(String label, {bool isBiDirectional = false}) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 5.5, color: slateMutedColor)),
        pw.SizedBox(height: 1),
        pw.Text(isBiDirectional ? '<--->' : '---->', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
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
    final inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

    final emiText = (quotation.paymentMode.toLowerCase().contains('loan') && quotation.monthlyEmi > 0)
        ? '\nEstimated Monthly EMI: ${inrFormat.format(quotation.monthlyEmi)} / month (${quotation.loanTenureMonths} months @ ${quotation.annualInterestRate.toStringAsFixed(1)}% p.a.)'
        : '';

    final subsidyText = (quotation.quotationType != 'Commercial' && quotation.subsidyAmount > 0)
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

    final url = Uri.parse(cleanPhone.isNotEmpty ? 'https://wa.me/$cleanPhone?text=$encodedMsg' : 'https://wa.me/?text=$encodedMsg');

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
      {'tenure': '5 Years (60 Months)', 'data': loan60, 'highlight': true}, // Most popular
      {'tenure': '7 Years (84 Months)', 'data': loan84, 'highlight': false},
      {'tenure': '10 Years (120 Months)', 'data': loan120, 'highlight': false},
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
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            color: headerBgColor,
            child: pw.Row(
              children: [
                pw.SizedBox(width: 105, child: pw.Text('Loan Tenure', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                pw.SizedBox(width: 75, child: pw.Text('Monthly EMI', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                pw.SizedBox(width: 80, child: pw.Text('Total Interest', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                pw.SizedBox(width: 90, child: pw.Text('Total Repayment', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                pw.SizedBox(width: 85, child: pw.Text('Solar Savings/Mo', style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                pw.Expanded(child: pw.Text('Net Out-of-Pocket / Gain', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.0),
              color: isPopular ? accentBannerBg : (idx % 2 == 1 ? zebraBgColor : PdfColors.white),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 105,
                    child: pw.Row(
                      children: [
                        pw.Text(item['tenure'] as String, style: pw.TextStyle(fontSize: 6.8, fontWeight: isPopular ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor)),
                        if (isPopular)
                          pw.Container(
                            margin: const pw.EdgeInsets.only(left: 4),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                            decoration: const pw.BoxDecoration(color: goldenYellowColor, borderRadius: pw.BorderRadius.all(pw.Radius.circular(2))),
                            child: pw.Text('POPULAR', style: pw.TextStyle(fontSize: 4.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 75, child: pw.Text(inrIntFormatter.format(emi), style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor))),
                  pw.SizedBox(width: 80, child: pw.Text(inrIntFormatter.format(interest), style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor))),
                  pw.SizedBox(width: 90, child: pw.Text(inrIntFormatter.format(repayment), style: const pw.TextStyle(fontSize: 6.8, color: slateBodyColor))),
                  pw.SizedBox(width: 85, child: pw.Text(inrIntFormatter.format(monthlySolarSavings), style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: emeraldColor))),
                  pw.Expanded(
                    child: pw.Text(
                      netCashflow >= 0
                          ? '+${inrIntFormatter.format(netCashflow)}/mo (Zero Cost!)'
                          : '-${inrIntFormatter.format(netCashflow.abs())}/mo only',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 7.0,
                        fontWeight: pw.FontWeight.bold,
                        color: netCashflow >= 0 ? emeraldColor : const PdfColor.fromInt(0xFFDC2626),
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
          pw.Text(bankName, style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: navyColor)),
          pw.SizedBox(height: 1),
          pw.Text('Interest: $rate', style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
          pw.Text(note, style: const pw.TextStyle(fontSize: 5.2, color: slateMutedColor)),
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
    final pdf = pw.Document();
    final comp = MasterDataHub.company;

    // Load Company Logo
    pw.MemoryImage? logoImage;
    if (comp.logoImagePath != null && comp.logoImagePath!.isNotEmpty) {
      final customLogoBytes = SettingsService.decodeImageFromDataUri(comp.logoImagePath);
      if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
        try {
          logoImage = pw.MemoryImage(customLogoBytes);
        } catch (_) {}
      }
    }
    if (logoImage == null) {
      try {
        final ByteData logoData = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    // Load Company Stamp
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes();
      if (stampBytes != null) {
        stampImage = pw.MemoryImage(stampBytes);
      }
    }

    final inrIntFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

    final double netAmountAfterSubsidy = (quotation.quotationType != 'Commercial' && quotation.subsidyAmount > 0)
        ? (quotation.payableAfterSubsidy > 0
            ? quotation.payableAfterSubsidy
            : (quotation.grandTotal - quotation.subsidyAmount).clamp(0.0, double.infinity))
        : quotation.grandTotal;

    // Bank loan is calculated on Net Amount After Subsidy
    final double loanPrincipal = (quotation.bankLoanAmount > 0 && quotation.bankLoanAmount <= (netAmountAfterSubsidy * 1.05))
        ? quotation.bankLoanAmount
        : (netAmountAfterSubsidy * 0.90).roundToDouble();

    final double customerMargin = (quotation.customerContribution > 0 && quotation.customerContribution <= netAmountAfterSubsidy)
        ? quotation.customerContribution
        : (netAmountAfterSubsidy - loanPrincipal).clamp(0.0, double.infinity);

    final double effLoanRate = quotation.annualInterestRate > 0 ? quotation.annualInterestRate : 7.5;
    final double monthlySolarSavings = (quotation.annualSavings > 0 ? quotation.annualSavings : quotation.annualGenerationUnits * 8.0) / 12.0;

    final loan36 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 36);
    final loan60 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 60);
    final loan84 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 84);
    final loan120 = SolarQuotationCalculations.calculateLoanBreakdown(principal: loanPrincipal, annualInterestRate: effLoanRate, tenureMonths: 120);

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
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                            comp.companyName.isNotEmpty ? comp.companyName : 'SIYA INFOTECH & SOLAR ENERGY',
                            style: pw.TextStyle(color: navyColor, fontSize: 13.0, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Authorized Solar Channel Partner | PM Surya Ghar: Muft Bijli Yojana',
                            style: pw.TextStyle(color: emeraldColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Betawad, Tal. Shindkheda, Dist. Dhule, Maharashtra | Helpline: +91 9673220315',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8),
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
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                        pw.Text('NATIONALIZED BANK ROOFTOP SOLAR LOAN — EMI CALCULATION SHEET', style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('PM Surya Ghar Concessional Solar Financing Scheme (Loan on Net Cost Post-Subsidy)', style: const pw.TextStyle(color: PdfColor.fromInt(0xFFBAE6FD), fontSize: 7.2)),
                      ],
                    ),
                    pw.Text('Proposal No.: ${quotation.quotationNo}', style: pw.TextStyle(color: PdfColors.white, fontSize: 8.0, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Customer & Site Profile Card
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Applicant Name', quotation.customerName, isBold: true),
                          _buildProfileRow('Consumer / CA No.', quotation.consumerNo.isNotEmpty ? quotation.consumerNo : 'To be provided'),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Proposed System', '${quotation.systemCapacity} Grid-Connected Rooftop PV', isBold: true),
                          _buildProfileRow('Installation Site', '${quotation.address}, ${quotation.villageCity}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Loan Capital Structure (Calculated on Net Cost After Subsidy)
              _buildSectionHeader(
                'LOAN CAPITAL STRUCTURE (CALCULATED ON NET AFTER SUBSIDY)',
                subTitle: 'Concessional Financing Scheme @ ${effLoanRate.toStringAsFixed(2)}% p.a.',
              ),
              pw.Row(
                children: [
                  _buildHighlightBox('TOTAL PROJECT COST', inrIntFormatter.format(quotation.grandTotal), 'Turnkey Incl. GST', darkTextColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('CENTRAL SUBSIDY', inrIntFormatter.format(quotation.subsidyAmount), 'PM Surya Ghar DBT', goldenYellowColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('NET COST (FINANCED)', inrIntFormatter.format(netAmountAfterSubsidy), 'Payable Post-Subsidy', navyColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('CUSTOMER MARGIN (10%)', inrIntFormatter.format(customerMargin), 'Down Payment on Net', darkTextColor),
                  pw.SizedBox(width: 6),
                  _buildHighlightBox('PROPOSED LOAN (90%)', inrIntFormatter.format(loanPrincipal), 'Eligible Loan on Net', emeraldColor),
                ],
              ),

              pw.SizedBox(height: 8),

              // Multi-Tenure Comparison Matrix
              _buildSectionHeader('MULTI-TENURE EMI & NET CASHFLOW COMPARISON MATRIX'),
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
              _buildSectionHeader('FINANCIAL BENEFIT: LOAN SANCTIONED ON NET COST AFTER SUBSIDY'),
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text('• Substantially Lower Monthly EMI: Availing the bank loan on Net Cost (${inrIntFormatter.format(netAmountAfterSubsidy)}) after deducting ${inrIntFormatter.format(quotation.subsidyAmount)} central subsidy drops your EMI to just ${inrIntFormatter.format(loan60['emi'] ?? 0)}/mo (5-Year tenure), keeping financing light.', style: const pw.TextStyle(fontSize: 6.5, color: slateBodyColor, lineSpacing: 1.2)),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text('• 100% Self-Financing: Monthly electricity bill savings (${inrIntFormatter.format(monthlySolarSavings)}/mo) comfortably exceed the EMI (${inrIntFormatter.format(loan60['emi'] ?? 0)}/mo), creating immediate net monthly savings of +${inrIntFormatter.format(monthlySolarSavings - (loan60['emi'] ?? 0))}/mo from Month 1.', style: const pw.TextStyle(fontSize: 6.5, color: slateBodyColor, lineSpacing: 1.2)),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Empanelled Banks
              _buildSectionHeader('EMPANELLED NATIONALIZED BANKS'),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildBankBadge('SBI Surya Ghar', '7.00% p.a.*', 'Zero Collateral up to 3L'),
                  _buildBankBadge('Bank of Maharashtra', '7.15% p.a.*', 'Direct JanSamarth Portal'),
                  _buildBankBadge('Punjab National Bank', '7.00% p.a.*', 'Tenure up to 120 Months'),
                  _buildBankBadge('Canara / Union Bank', '7.25% p.a.*', 'Fast Track Sanction'),
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
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DOCUMENT CHECKLIST: (Submit to Siya Infotech)', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          _buildBulletPoint('1. KYC: Aadhaar Card & PAN Card.'),
                          _buildBulletPoint('2. Electricity Bill: Latest 3 months paid bills.'),
                          _buildBulletPoint('3. Income Proof: Last 6 months bank statement.'),
                          _buildBulletPoint('4. Property Proof: House Tax Receipt / Index-II.'),
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
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('FOR SIYA INFOTECH & SOLAR ENERGY', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          if (stampImage != null)
                            pw.Container(height: 28, child: pw.Image(stampImage, fit: pw.BoxFit.contain))
                          else
                            pw.SizedBox(height: 18),
                          pw.Text('Authorized Signatory / Seal', style: const pw.TextStyle(fontSize: 6.2, color: slateMutedColor)),
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
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Siya Infotech & Solar Energy | PM Surya Ghar Authorized Partner | Helpline: +91 9673220315', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
                    pw.Text('Proposal No.: ${quotation.quotationNo} | Standalone Bank EMI Sheet', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
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
      final filename = 'Bank_Loan_EMI_Sheet_${quotation.customerName.replaceAll(RegExp(r'\s+'), '_')}_${quotation.quotationNo}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading Bank Loan EMI Sheet: $e'), backgroundColor: Colors.red),
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
    final filename = 'Bank_Loan_EMI_Sheet_${quotation.customerName.replaceAll(RegExp(r'\s+'), '_')}_${quotation.quotationNo}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: filename,
    );
  }
}
