import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/consumer_record.dart';
import '../models/work_completion_report_data.dart';
import 'company_stamp_helper.dart';

class WorkCompletionCertificateService {
  static const PdfColor blackColor = PdfColor.fromInt(0xFF000000);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFF000000);
  static const PdfColor lightGreyBg = PdfColor.fromInt(0xFFF8FAFC);

  // =========================================================================
  // 1. WORK COMPLETION REPORT FOR SOLAR POWER PLANT (2 Pages A4 - Document 1)
  // =========================================================================
  static Future<Uint8List> generateWcrPdfBytes(
    WorkCompletionReportData data, {
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? stampAndSigImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampAndSignatureBytes,
      );
      if (stampBytes != null && stampBytes.isNotEmpty) {
        try {
          stampAndSigImage = pw.MemoryImage(stampBytes);
        } catch (e) {
          debugPrint('Stamp decode error: $e');
        }
      }
    }

    pw.TableRow tableRow(String sr, String comp, String obs, {bool isHeader = false, bool isSubHeader = false}) {
      final textStyle = pw.TextStyle(
        color: blackColor,
        fontSize: isHeader ? 8.5 : (isSubHeader ? 8.0 : 7.8),
        fontWeight: (isHeader || isSubHeader) ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

      return pw.TableRow(
        decoration: isHeader ? const pw.BoxDecoration(color: lightGreyBg) : null,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(sr, style: textStyle, textAlign: pw.TextAlign.center),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
            child: pw.Text(comp, style: textStyle),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
            child: pw.Text(obs, style: textStyle),
          ),
        ],
      );
    }

    pw.TableRow subHeaderRow(String sr, String title) {
      return pw.TableRow(
        decoration: const pw.BoxDecoration(color: lightGreyBg),
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.0, horizontal: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(sr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.0, horizontal: 6),
            child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.0, horizontal: 6),
            child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.2)),
          ),
        ],
      );
    }

    // --- PAGE 1: 9-point Table + Structural Stability & Islanding Declarations ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'Work Completion Report for Solar Power Plant',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: blackColor),
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: borderDarkColor, width: 0.7),
                columnWidths: const {
                  0: pw.FixedColumnWidth(34),
                  1: pw.FlexColumnWidth(4.5),
                  2: pw.FlexColumnWidth(5.5),
                },
                children: [
                  tableRow('Sr.No', 'Component', 'Observation', isHeader: true),
                  tableRow('1', 'Name', data.customerName),
                  tableRow('2', 'Consumer number', data.consumerNo),
                  tableRow('3', 'Site/Location With Complete Address', data.customerAddress),
                  tableRow('4', 'Category: Govt/Private Sector', data.category),
                  tableRow('5', 'Sanction number', data.sanctionNo),
                  tableRow('6', 'Sanctioned Capacity of solar PV system (KW) Installed\nCapacity of solar PV system (KW)', '${data.sanctionedCapacityKw.toStringAsFixed(1)} KW\n${data.installedCapacityKw.toStringAsFixed(1)} KW'),
                  
                  subHeaderRow('7', 'Specification of the Modules'),
                  tableRow('', 'Make of Module', data.moduleMake),
                  tableRow('', 'ALMM Model Number', data.moduleAlmmModel),
                  tableRow('', 'Wattage per module', '${data.moduleWattage} Wp'),
                  tableRow('', 'No. of Module', '${data.moduleCount} Nos'),
                  tableRow('', 'Total Capacity (KWP)', '${data.moduleTotalCapacityKwp.toStringAsFixed(2)} KWP'),
                  tableRow('', 'Warrantee Details (Product + Performance)', data.moduleWarranty),

                  subHeaderRow('8', 'PCU'),
                  tableRow('', 'Make & Model number of Inverter', '${data.inverterMake} ${data.inverterModel}'),
                  tableRow('', 'Rating', data.inverterRating),
                  tableRow('', 'Type of charge controller/ MPPT', data.inverterControllerType),
                  tableRow('', 'Capacity of Inverter', '${data.inverterCapacityKw.toStringAsFixed(1)} KW'),
                  tableRow('', 'HPD', data.inverterHpd),
                  tableRow('', 'Year of manufacturing', '${data.inverterMfgYear}'),

                  subHeaderRow('9', 'Earthing and Protections'),
                  tableRow('', 'No of Separate Earthings with earth Resistance', data.earthResistanceDetails),
                  tableRow('', 'It is certified that the Earth Resistance measure in presence of Licensed Electrical Contractor/Supervisor and found in order i.e. < 5 Ohms as per MNRE OM Dtd. 07.06.24 for CFA Component.', data.earthResistanceCertified),
                  tableRow('', 'Lightening Arrester', data.lightningArrester),
                ],
              ),
              pw.SizedBox(height: 10),

              // Structural & Islanding Declarations
              pw.Text(
                'We ${data.vendorFirmName} [Vendor] & ${data.customerName} [Consumer] bearing Consumer Number ${data.consumerNo}. Ensured structural stability of installed solar power plant and obtained requisite permissions from the concerned authority. If in future, by virtue of any means due to collapsing or damage to installed solar power plant, MSEDCL will not be held responsible for any loss to property or human life, if any.',
                style: const pw.TextStyle(fontSize: 7.2, color: blackColor, lineSpacing: 1.2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 7),

              pw.Text(
                'This is to Certified above Installed Solar PV System is working properly with electrical safety & Islanding switch in case of any presence of backup inverter an arrangement should be made in such way the backup inverter supply should never be synchronized with solar inverter to avoid any electrical accident due to back feeding. We will be held responsible for non-working of islanding mechanism and back feed to the de-energized grid.',
                style: const pw.TextStyle(fontSize: 7.2, color: blackColor, lineSpacing: 1.2),
                textAlign: pw.TextAlign.justify,
              ),
              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (stampAndSigImage != null)
                        pw.Container(
                          width: 108,
                          height: 70,
                          margin: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Image(stampAndSigImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 50),
                      pw.Container(width: 160, height: 0.8, color: blackColor),
                      pw.SizedBox(height: 4),
                      pw.Text('Signature [Vendor]', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.SizedBox(height: 50),
                      pw.Container(width: 160, height: 0.8, color: blackColor),
                      pw.SizedBox(height: 4),
                      pw.Text('Signature [Consumer]', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // --- PAGE 2: 5-Year CMC Guarantee + Aadhar Card Upload Box ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Guarantee Certificate Undertaking to be submitted by VENDOR',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: blackColor),
              ),
              pw.SizedBox(height: 14),

              pw.Text(
                'The undersigned will provide the services to the consumers for repairs/maintenance of the RTS plant free of cost for 5 years of the comprehensive Maintenance Contract (CMC) period from the date of commissioning of the plant. Non performing/under-performing system component will be replaced/repaired free of cost in the CMC period',
                style: const pw.TextStyle(fontSize: 8.5, color: blackColor, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 24),

              if (stampAndSigImage != null)
                pw.Container(
                  width: 120,
                  height: 76,
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Image(stampAndSigImage, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(height: 60),

              pw.Text('Signature [Vendor]', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Stamp & Seal', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 28),

              pw.Text('Identity Details of Consumer: -', style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(
                'Aadhar Number: ${data.consumerAadhar.isNotEmpty ? data.consumerAadhar : "..................................................."}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.SizedBox(height: 20),

              // Large Box for Aadhar Card Xerox
              pw.Container(
                width: double.infinity,
                height: 280,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: blackColor, width: 0.8),
                ),
                child: pw.Center(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Upload Xerox of AADHAR CARD HERE',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: blackColor),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'SHOULD BE SELF ATTESTED BY CONSUMER',
                        style: const pw.TextStyle(fontSize: 8.5, color: blackColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 2. ANNEXURE-I & PROFORMA-A COMMISSIONING REPORT (2 Pages A4 - Document 2)
  // =========================================================================
  static Future<Uint8List> generateAnnexure1PdfBytes(
    WorkCompletionReportData data, {
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? stampAndSigImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampAndSignatureBytes,
      );
      if (stampBytes != null && stampBytes.isNotEmpty) {
        try {
          stampAndSigImage = pw.MemoryImage(stampBytes);
        } catch (e) {
          debugPrint('Stamp decode error: $e');
        }
      }
    }

    pw.TableRow row(String sno, String part, String comm, {bool isHeader = false}) {
      final style = pw.TextStyle(
        fontSize: isHeader ? 8.2 : 7.6,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.TableRow(
        decoration: isHeader ? const pw.BoxDecoration(color: lightGreyBg) : null,
        children: [
          pw.Container(padding: const pw.EdgeInsets.all(3.5), alignment: pw.Alignment.center, child: pw.Text(sno, style: style)),
          pw.Container(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(part, style: style)),
          pw.Container(padding: const pw.EdgeInsets.all(3.5), child: pw.Text(comm, style: style)),
        ],
      );
    }

    // --- PAGE 1: 15-Point Table + Proforma-A ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 26, 36, 24),
        build: (context) {
          final compDateStr = DateFormat('dd/MM/yyyy').format(data.completionDate);
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Renewable Energy Generating System', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Annexure-I', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('(Commissioning Report for RE System)', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: borderDarkColor, width: 0.6),
                columnWidths: const {
                  0: pw.FixedColumnWidth(30),
                  1: pw.FlexColumnWidth(5),
                  2: pw.FlexColumnWidth(5),
                },
                children: [
                  row('SNo.', 'Particulars', 'As Commissioned', isHeader: true),
                  row('1', 'Name of the Consumer', data.customerName),
                  row('2', 'Consumer Number', data.consumerNo),
                  row('3', 'Mobile Number', data.customerMobile),
                  row('4', 'E-mail', data.customerEmail.isNotEmpty ? data.customerEmail : 'siyainfodigital@gmail.com'),
                  row('5', 'Address of Installation', data.customerAddress),
                  row('6', 'RE Arrangement Type', 'Net Metering Arrangement'),
                  row('7', 'RE Source', 'Solar Rooftop PV'),
                  row('8', 'Sanctioned Capacity(KW)', '${data.sanctionedCapacityKw.toStringAsFixed(1)} KW'),
                  row('9', 'Capacity Type', 'LT Residential'),
                  row('10', 'Project Model', 'CAPEX'),
                  row('11', 'RE installed Capacity(Rooftop)(KW)', '${data.installedCapacityKw.toStringAsFixed(1)} KW'),
                  row('12', 'RE installed Capacity(Rooftop + Ground)(KW)', '-'),
                  row('13', 'RE installed Capacity(Ground)(KW)', '-'),
                  row('14', 'Installation date', compDateStr),
                  row('15', 'SolarPV Details:\n  Inverter Capacity(KW)\n  Inverter Make\n  No .of PV Modules\n  Module Capacity (KW)', '\n${data.inverterCapacityKw.toStringAsFixed(1)} KW\n${data.inverterMake}\n${data.moduleCount} Nos\n${data.moduleTotalCapacityKwp.toStringAsFixed(2)} KWp'),
                ],
              ),
              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Proforma-A', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('COMMISSIONING REPORT (PROVISIONAL) FOR GRID CONNECTED SOLAR', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('PHOTOVOLTAIC POWER PLANT (with Net-metering facility)', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Text(
                'Certified that a Grid Connected SPV Power Plant of ${data.moduleTotalCapacityKwp.toStringAsFixed(2)} KWp capacity has been installed at the site ${data.customerAddress} District Dhule of MAHARASHTRA which has been installed by M/S ${data.vendorFirmName} on $compDateStr. The system is as per BIS/MNRE specifications. The system has been checked for its performance and found in order for further commissioning.',
                style: const pw.TextStyle(fontSize: 7.5, lineSpacing: 1.25),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 18),

              // Agency Signature with Stamp (Beneficiary signature removed as requested)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (stampAndSigImage != null)
                      pw.Container(
                        width: 100,
                        height: 56,
                        child: pw.Image(stampAndSigImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.SizedBox(height: 48),
                    pw.Container(width: 200, height: 0.8, color: blackColor),
                    pw.SizedBox(height: 4),
                    pw.Text('Signature of the agency with name, seal and date', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // --- PAGE 2: MSEDCL Officer Inspection Section ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'The above RTS installation has been inspected by me for Pre-Commissioning Testing of Roof Top Solar Connection on dt.................... as per guidelines issued by the office of The Chief Engineer vide letter no 21653 on dt. 18.08.2022 and found in order for commissioning.',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 40),

              pw.Text('Signature of the MSEDCL Officer', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Name,', style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 6),
              pw.Text('Designation', style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 6),
              pw.Text('Date and seal', style: const pw.TextStyle(fontSize: 8.5)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 3. DCR UNDERTAKING / SELF-DECLARATION (1 Page A4 - Document 3)
  // =========================================================================
  static Future<Uint8List> generateDcrPdfBytes(
    WorkCompletionReportData data, {
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? stampAndSigImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampAndSignatureBytes,
      );
      if (stampBytes != null && stampBytes.isNotEmpty) {
        try {
          stampAndSigImage = pw.MemoryImage(stampBytes);
        } catch (e) {
          debugPrint('Stamp decode error: $e');
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 26),
        build: (context) {
          final appDateStr = DateFormat('dd/MM/yyyy').format(data.applicationDate);
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Undertaking/Self- Declaration for Domestic Content Requirement fulfillment',
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text('(On a plain Paper)', style: const pw.TextStyle(fontSize: 8.2)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              pw.Text(
                '1. This is to certify that M/S ${data.vendorFirmName} has installed ${data.installedCapacityKw.toStringAsFixed(1)} KW Grid Connected Rooftop Solar Plant for ${data.customerName} at ${data.customerAddress} under application number ${data.applicationNo} dated $appDateStr under ${data.discomName}.',
                style: const pw.TextStyle(fontSize: 8.2, lineSpacing: 1.25),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                '2. It is hereby undertaken that the PV modules installed for the above-mentioned project are domestically manufactured using domestic manufactured solar cells. The details of installed PV Modules are follows:',
                style: const pw.TextStyle(fontSize: 8.2, lineSpacing: 1.25),
              ),
              pw.SizedBox(height: 6),

              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 18),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('1. PV Module Capacity: ${data.moduleWattage} Wp (${data.moduleTotalCapacityKwp.toStringAsFixed(2)} KWp)', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.SizedBox(height: 3.5),
                    pw.Text('2. Number of PV Modules: ${data.moduleCount} Nos', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.SizedBox(height: 3.5),
                    pw.Text('3. Sr No of PV Module: ${data.moduleSerialNos}', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.SizedBox(height: 3.5),
                    pw.Text('4. PV Module Make: ${data.moduleMake} (${data.moduleAlmmModel})', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.SizedBox(height: 3.5),
                    pw.Text('5. Cell manufacturer\'s name: ${data.cellManufacturer}', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.SizedBox(height: 3.5),
                    pw.Text('6. Cell GST invoice No: ${data.cellGstInvoiceNo}', style: const pw.TextStyle(fontSize: 8.0)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                '3. The above undertaking is based on the certificate issued by PV Module manufacturer/supplier while supplying the above mentioned order.',
                style: const pw.TextStyle(fontSize: 8.2, lineSpacing: 1.25),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                '4. I, ${data.authorizedPerson} on behalf of M/S ${data.vendorFirmName} further declare that the information given above is true and correct and nothing has been concealed therein. If anything is found incorrect at any stage, then REC/ MNRE may take any appropriate action against my company for wrong declaration. Supporting documents and proof of the above information will be provided as and when requested by MNRE.',
                style: const pw.TextStyle(fontSize: 8.2, lineSpacing: 1.25),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 16),

              // Signatures
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (stampAndSigImage != null)
                      pw.Container(
                        width: 105,
                        height: 60,
                        child: pw.Image(stampAndSigImage, fit: pw.BoxFit.contain),
                      )
                    else
                      pw.SizedBox(height: 45),
                    pw.Text('(Signature With official Seal)', style: const pw.TextStyle(fontSize: 7.8)),
                    pw.SizedBox(height: 3),
                    pw.Text('For M/S ${data.vendorFirmName}', style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Name: ${data.authorizedPerson}', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.Text('Designation: Authorized Signatory', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.Text('Phone: ${data.vendorMobile}', style: const pw.TextStyle(fontSize: 8.0)),
                    pw.Text('Email: ${data.vendorEmail}', style: const pw.TextStyle(fontSize: 8.0)),
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

  // =========================================================================
  // 4. ANNEXURE-3 NET METERING CONNECTION AGREEMENT (5 Pages A4 - Document 4)
  // =========================================================================
  static Future<Uint8List> generateAnnexure3PdfBytes(
    WorkCompletionReportData data, {
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final pdf = pw.Document();

    final compDate = data.completionDate;
    final dayStr = DateFormat('dd').format(compDate);
    final monthStr = DateFormat('MMMM').format(compDate);
    final yearStr = DateFormat('yyyy').format(compDate);

    // Page 1
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Annexure - 3', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Net Metering Connection Agreement', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 8.5, color: blackColor, lineSpacing: 1.35),
                  children: [
                    const pw.TextSpan(text: 'This Agreement is made and entered into at '),
                    pw.TextSpan(text: 'Dhule', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' on this '),
                    pw.TextSpan(text: dayStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' day of '),
                    pw.TextSpan(text: '$monthStr $yearStr', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' between the Eligible Consumer '),
                    pw.TextSpan(text: data.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' having premises at '),
                    pw.TextSpan(text: data.customerAddress, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' and Consumer No. '),
                    pw.TextSpan(text: data.consumerNo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' as the first Party,\n\nAND\n\n'),
                    const pw.TextSpan(text: 'MSEDCL (hereinafter referred to as \'the Licensee\') and having its Registered Office at Prakashgad, Plot No. G-9, Anant Kanekar Marg, Bandra (E), Mumbai - 400051 as second Party of this Agreement.\n\n'),
                    const pw.TextSpan(text: 'Whereas the Eligible Consumer has applied to MSEDCL for approval of a Net Metering Arrangement under the provisions of the Maharashtra Electricity Regulatory Commission (Grid Interactive Renewable Energy Generating Systems) Regulations, 2019 (\'the Grid Interactive Renewable Regulations\') and sought its connectivity to MSEDCL\'s distribution Network;\n\n'),
                    const pw.TextSpan(text: 'And whereas MSEDCL has agreed to provide Network connectivity to the Eligible Consumer for injection of electricity generated from its Renewable Energy Generating System of '),
                    pw.TextSpan(text: '${data.installedCapacityKw.toStringAsFixed(1)} kilowatt;\n\n', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: 'Both Parties hereby agree as follows:\n\n'),
                    pw.TextSpan(text: '1  Eligibility\n', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: 'The Renewable Energy Generating System meets the applicable norms for being integrated into the distribution network, and that the Eligible Consumer shall maintain the System accordingly for the duration of this Agreement.\n\n'),
                    pw.TextSpan(text: '2  Technical and Inter-connection Requirements\n', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: '2.1  The metering arrangement and the inter-connection of the Renewable Energy Generating System with the Network of MSEDCL shall be as per the provisions of the Grid Interactive Renewable Regulations, and the technical standards and norms specified by the Central Electricity Authority for connectivity of distributed generation resources and for the installation and operation of meters.\n\n'),
                    const pw.TextSpan(text: '2.2  The Eligible Consumer agrees, that he shall install, prior to connection of the Renewable'),
                  ],
                ),
                textAlign: pw.TextAlign.justify,
              ),
            ],
          );
        },
      ),
    );

    // Page 2
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Energy Generating System to the Network of MSEDCL, an isolation device (both automatic and in-built within inverter and external manual relays); and MSEDCL shall have access to it if required for the repair and maintenance of the distribution Network.\n\n'
                '2.3  MSEDCL shall specify the interface/inter-connection point and metering point.\n\n'
                '2.4  The Eligible Consumer shall furnish all relevant data, such as voltage, frequency, circuit breaker, isolator position in his System, as and when required by MSEDCL.\n\n'
                '3  Safety\n\n'
                '3.1  The equipment connected to MSEDCL\'s distribution System shall be compliant with relevant International (IEEE/IEC) or Indian standards (BIS), as the case may be, and the installation of electrical equipment shall comply with the requirements specified by the Central Electricity Authority regarding safety and electricity supply.\n\n'
                '3.2  The design, installation, maintenance and operation of the Renewable Energy Generating System shall be undertaken in a manner conducive to the safety of the Renewable Energy Generating System as well as MSEDCL\'s Network.\n\n'
                '3.3  If, at any time, MSEDCL determines that the Eligible Consumer\'s Renewable Energy Generating System is causing or may cause damage to and/or results in MSEDCL\'s other consumers or its assets, the Eligible Consumer shall disconnect the Renewable Energy Generating System from the distribution Network upon direction from MSEDCL, and shall undertake corrective measures at his own expense prior to re-connection.\n\n'
                '3.4  MSEDCL shall not be responsible for any accident resulting in injury to human beings or animals or damage to property that may occur due to back-feeding from the Renewable Energy Generating System when the grid supply is off. MSEDCL may disconnect the installation at any time in the event of such exigencies to prevent such accident.\n\n'
                '4  Other Clearances and Approvals\n\n'
                'The Eligible Consumer shall obtain any statutory approvals and clearances that may be required, such as from the Electrical Inspector or the municipal or other authorities, before connecting the Renewable Energy Generating System to the distribution Network.\n\n'
                '5  Period of Agreement, and Termination\n\n'
                '5.1  This Agreement shall be for a period for 20 years, but may be terminated prematurely:\n'
                'a) By mutual consent; or',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.35),
                textAlign: pw.TextAlign.justify,
              ),
            ],
          );
        },
      ),
    );

    // Page 3
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'b) By the Eligible Consumer, by giving 90 days\' notice to MSEDCL;\n\n'
                'c) By MSEDCL, by giving 30 days\' notice, if the Eligible Consumer breaches any terms of this Agreement or the provisions of the Grid Interactive Rooftop Renewable Energy Generating Systems Regulations and does not remedy such breach within 30 days, or such other reasonable period as may be provided, of receiving notice of such breach, or for any other valid reason communicated by MSEDCL in writing;\n\n'
                'd) By MSEDCL, by giving 30 days\' notice, if the Eligible Consumer fails to pay his dues in a timely manner or indulges in any malpractices.\n\n'
                '6  Access and Disconnection\n\n'
                '6.1  The Eligible Consumer shall provide access to MSEDCL to the metering equipment and disconnecting devices of Renewable Energy Generating System, both automatic and manual, by the Eligible Consumer.\n\n'
                '6.2  If, in an emergent or outage situation, MSEDCL cannot access the disconnecting devices of the Renewable Energy Generating System, both automatic and manual, it may disconnect power supply to the premises.\n\n'
                '6.3  Upon termination of this Agreement under Clause 5, the Eligible Consumer shall disconnect the Renewable Energy Generating System forthwith from the Network of MSEDCL.\n\n'
                '7  Liabilities\n\n'
                '7.1  The Parties shall indemnify each other for damages or adverse effects of either Party\'s negligence or misconduct during the installation of the Renewable Energy Generating System, connectivity with the distribution Network and operation of the System.\n\n'
                '7.2  The Parties shall not be liable to each other for any loss of profits or revenues, business interruption losses, loss of contract or goodwill, or for indirect, consequential, incidental or special damages including, but not limited to, punitive or exemplary damages, whether any of these liabilities, losses or damages arise in contract, or otherwise.\n\n'
                '8  Commercial Settlement\n\n'
                '8.1  The commercial settlements under this Agreement shall be in accordance with the Grid Interactive Renewable Regulations.\n\n'
                '8.2  MSEDCL shall not be liable to compensate the Eligible Consumer if his Renewable Energy Generating System is unable to inject surplus power generated into MSEDCL\'s Network on account of failure of power supply in the grid/Network.',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.35),
                textAlign: pw.TextAlign.justify,
              ),
            ],
          );
        },
      ),
    );

    // Page 4
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                '8.3  The existing metering System, if not in accordance with the Grid Interactive Renewable Regulations, shall be replaced by a bi-directional meter (whole current/CT operated) and a separate Renewable Energy Generation Meter shall be provided to measure Renewable Energy generation. The bi-directional meter (whole current/CT operated) shall be installed at the inter-connection point to MSEDCL\'s Network for recording export and import of energy.\n\n'
                '8.4  The uni-directional and bi-directional meters shall be fixed in separate meter boxes in the same proximity.\n\n'
                '8.5  The energy generated by the Renewable Energy Generating Station shall be offset against the energy consumption of the consumer from the MSEDCL in the following manner:\n\n'
                'a) If the quantum of electricity exported exceeds the quantum imported during the Billing Period, the excess quantum shall be carried forward to the next Billing Period as credited Units of electricity;\n\n'
                'b) If the quantum of electricity Units imported by the Eligible Consumer during any Billing Period exceeds the quantum exported, the MSEDCL shall raise its invoice for the net electricity consumption after adjusting the credited Units;\n\n'
                'c) The unadjusted net credited Units of electricity as at the end of each financial year shall be purchased by the MSEDCL at the Generic Tariff approved by the Commission for that year, within the first month of the following year:\n'
                'Provided that, at the beginning of each Settlement Period, the cumulative quantum of injected electricity carried forward will be re-set to zero;\n\n'
                'd) In case the Eligible Consumer is within the ambit of Time of Day (ToD) tariff, the electricity consumption in any time block, i.e. peak hours, off-peak hours, etc., shall be first compensated with the quantum of electricity injected in the same time block; any excess injection over and above the consumption in any other time block in a Billing Cycle shall be accounted as if the excess injection had occurred during off- peak hours;\n\n'
                'e) MSEDCL shall compute the amount payable to the Eligible Consumer for the excess Renewable Energy purchased by it as specified in Clause 8.5 (c), and shall provide credit equivalent to the amount payable in the immediately succeeding Billing Cycle.\n\n'
                '9  Connection Costs\n\n'
                'The Eligible Consumer shall bear all costs related to the setting up of the Renewable Energy Generating System, including the cost of the Renewable Energy Generation Meter.',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.35),
                textAlign: pw.TextAlign.justify,
              ),
            ],
          );
        },
      ),
    );

    // Page 5
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                '10  Dispute Resolution\n\n'
                '10.1 Any dispute arising under this Agreement shall be resolved promptly, in good faith and in an equitable manner by both the Parties.\n\n'
                '10.2 The Eligible Consumer shall have recourse to the concerned Consumer Grievance Redressal Forum constituted under the relevant Regulations in respect of any grievance regarding billing, which has not been redressed by MSEDCL.\n\n\n\n',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.35),
                textAlign: pw.TextAlign.justify,
              ),

              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 8.5, color: blackColor, lineSpacing: 1.5),
                  children: [
                    const pw.TextSpan(text: 'In the witness, where of (Name) '),
                    pw.TextSpan(text: data.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    const pw.TextSpan(text: ' for and on behalf of Eligible Consumer) and (Name) _________________________________ for and on behalf of MSEDCL (Licensee) agree to this agreement.\n\n\n\n'),
                    const pw.TextSpan(text: '______________________________                                    ______________________________\n'),
                    const pw.TextSpan(text: 'Signature of Eligible Consumer                                     Signature of MSEDCL Authority\n'),
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

  // =========================================================================
  // BACKWARD-COMPATIBLE WRAPPER
  // =========================================================================
  static Future<Uint8List> generateCertificatePdfBytes(
    ConsumerRecord customer, {
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final data = WorkCompletionReportData.fromCustomer(
      customer,
      customCustomerName: customCustomerName,
      customConsumerNo: customConsumerNo,
      customAddress: customAddress,
      customCapacity: customCapacity,
      customCompletionDate: customCompletionDate,
    );

    return generateWcrPdfBytes(
      data,
      includeStampAndSignature: includeStampAndSignature,
      customStampAndSignatureBytes: customStampAndSignatureBytes,
    );
  }

  /// Download the Certificate / WCR directly
  static Future<void> downloadCertificatePdf(
    BuildContext context,
    ConsumerRecord customer, {
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
    bool includeStampAndSignature = true,
    int documentType = 0, // 0: WCR, 1: Annexure-1, 2: DCR, 3: Annexure-3
    WorkCompletionReportData? reportData,
  }) async {
    try {
      final data = reportData ?? WorkCompletionReportData.fromCustomer(
        customer,
        customCustomerName: customCustomerName,
        customConsumerNo: customConsumerNo,
        customAddress: customAddress,
        customCapacity: customCapacity,
        customCompletionDate: customCompletionDate,
      );

      Uint8List bytes;
      String docPrefix;
      switch (documentType) {
        case 1:
          bytes = await generateAnnexure1PdfBytes(data, includeStampAndSignature: includeStampAndSignature);
          docPrefix = 'Annexure_1_Commissioning';
          break;
        case 2:
          bytes = await generateDcrPdfBytes(data, includeStampAndSignature: includeStampAndSignature);
          docPrefix = 'DCR_Undertaking';
          break;
        case 3:
          bytes = await generateAnnexure3PdfBytes(data, includeStampAndSignature: includeStampAndSignature);
          docPrefix = 'Annexure_3_Net_Metering';
          break;
        case 0:
        default:
          bytes = await generateWcrPdfBytes(data, includeStampAndSignature: includeStampAndSignature);
          docPrefix = 'Work_Completion_Report_WCR';
          break;
      }

      final safeName = data.customerName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${docPrefix}_${safeName}_${data.consumerNo}.pdf';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Download $docPrefix PDF',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document downloaded successfully ($fileName)!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send Work Completion Details & Notification via WhatsApp
  static Future<void> sendOnWhatsApp(BuildContext context, ConsumerRecord customer, {WorkCompletionReportData? reportData}) async {
    final data = reportData ?? WorkCompletionReportData.fromCustomer(customer);
    final phone = (data.customerMobile).replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number is not available for WhatsApp.')),
      );
      return;
    }

    final message = '''
*${data.vendorFirmName}*
*Work Completion & Commissioning Dossier Ready*

Dear *${data.customerName}*,
Your Rooftop Solar PV System (${data.installedCapacityKw.toStringAsFixed(1)} kW) installation has been certified!

📋 *Project Dossier Summary*:
• Consumer No: ${data.consumerNo}
• Sanction No: ${data.sanctionNo}
• Installed Capacity: ${data.installedCapacityKw.toStringAsFixed(1)} kW (${data.moduleTotalCapacityKwp.toStringAsFixed(2)} kWp)
• Solar Modules: ${data.moduleCount}x ${data.moduleMake} (${data.moduleWattage} Wp)
• Inverter: ${data.inverterMake} ${data.inverterModel}
• 5-Year Comprehensive Maintenance Contract (CMC): Active

All official documents (WCR, Annexure-1, DCR & Net-Metering Agreement) are ready for MSEDCL submission.

For assistance:
📞 ${data.vendorMobile}
✉ ${data.vendorEmail}
📍 ${data.vendorAddress}
''';

    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening WhatsApp: $e')),
        );
      }
    }
  }
}
