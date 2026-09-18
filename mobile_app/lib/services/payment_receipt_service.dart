import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';

class PaymentReceiptService {
  /// Generate a professional PDF payment receipt
  static Future<File> generateReceiptPdf({
    required PaymentTransaction tx,
    required ConsumerRecord customer,
  }) async {
    // 1. Create a PDF document
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 30;

    final PdfPage page = document.pages.add();
    final PdfGraphics graphics = page.graphics;
    final Size pageSize = page.getClientSize();

    // Fonts
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final PdfFont boldFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    // Colors
    final PdfBrush primaryBrush = PdfSolidBrush(PdfColor(15, 118, 110)); // Teal primary
    final PdfBrush darkBrush = PdfSolidBrush(PdfColor(15, 23, 42)); // Slate dark
    final PdfPen borderPen = PdfPen(PdfColor(226, 232, 240), width: 1);
    final PdfBrush lightBgBrush = PdfSolidBrush(PdfColor(248, 250, 252));

    double y = 0;

    // --- WATERMARK (Draft / Confirmed) ---
    final isDraft = tx.isPendingSync;
    final watermarkText = isDraft ? 'DRAFT — PENDING SYNC' : 'CONFIRMED RECEIPT';
    final watermarkColor = isDraft ? PdfColor(234, 88, 12, 40) : PdfColor(5, 150, 105, 30);
    final PdfFont watermarkFont = PdfStandardFont(PdfFontFamily.helvetica, 36, style: PdfFontStyle.bold);

    graphics.save();
    graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
    graphics.rotateTransform(-35);
    final watermarkSize = watermarkFont.measureString(watermarkText);
    graphics.drawString(
      watermarkText,
      watermarkFont,
      brush: PdfSolidBrush(watermarkColor),
      bounds: Rect.fromLTWH(-watermarkSize.width / 2, -watermarkSize.height / 2, watermarkSize.width, watermarkSize.height),
    );
    graphics.restore();

    // --- 1. HEADER SECTION ---
    graphics.drawRectangle(
      brush: lightBgBrush,
      pen: borderPen,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 65),
    );

    graphics.drawString(
      'SIYA INFOTECH SOLAR CONNECT',
      titleFont,
      brush: primaryBrush,
      bounds: Rect.fromLTWH(15, y + 10, pageSize.width - 30, 25),
    );

    graphics.drawString(
      'Payment Receipt & Financial Voucher  |  Solar EPC & Rooftop Management',
      smallFont,
      brush: darkBrush,
      bounds: Rect.fromLTWH(15, y + 36, pageSize.width - 30, 15),
    );

    final dateStr = DateFormat('dd-MM-yyyy').format(tx.paymentDate);
    final receiptId = (tx.clientTxId ?? tx.id ?? 'TXN').replaceAll('ptx_', 'REC-');
    graphics.drawString(
      'Receipt No: $receiptId\nDate: $dateStr',
      smallFont,
      brush: darkBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(pageSize.width - 180, y + 15, 165, 35),
    );

    y += 80;

    // --- 2. CUSTOMER PROFILE & PAYMENT SUMMARY ---
    graphics.drawString('CUSTOMER & INSTALLATION DETAILS', headerFont, brush: primaryBrush, bounds: Rect.fromLTWH(0, y, pageSize.width, 20));
    y += 22;

    graphics.drawRectangle(
      pen: borderPen,
      brush: lightBgBrush,
      bounds: Rect.fromLTWH(0, y, pageSize.width, 70),
    );

    // Left Column: Customer info
    graphics.drawString('Customer Name:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(10, y + 10, 100, 15));
    graphics.drawString(customer.name, bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(110, y + 10, 180, 15));

    graphics.drawString('Consumer No:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(10, y + 28, 100, 15));
    graphics.drawString(customer.consumerNo, bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(110, y + 28, 180, 15));

    graphics.drawString('Village / Town:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(10, y + 46, 100, 15));
    graphics.drawString(customer.address ?? customer.village ?? '-', bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(110, y + 46, 180, 15));

    // Right Column: Installation info
    final col2X = pageSize.width / 2 + 10;
    graphics.drawString('Mobile:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(col2X, y + 10, 90, 15));
    graphics.drawString(customer.mobile ?? '-', bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(col2X + 90, y + 10, 150, 15));

    graphics.drawString('Install Stage:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(col2X, y + 28, 90, 15));
    graphics.drawString(customer.installationStatus, bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(col2X + 90, y + 28, 150, 15));

    graphics.drawString('App ID:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(col2X, y + 46, 90, 15));
    graphics.drawString(customer.applicationId ?? '-', bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(col2X + 90, y + 46, 150, 15));

    y += 85;

    // --- 3. PAYMENT TRANSACTION BREAKDOWN ---
    graphics.drawString('TRANSACTION DETAILS', headerFont, brush: primaryBrush, bounds: Rect.fromLTWH(0, y, pageSize.width, 20));
    y += 22;

    // Table Header
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(15, 118, 110)),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 25),
    );

    final PdfBrush whiteBrush = PdfSolidBrush(PdfColor(255, 255, 255));
    graphics.drawString('Description', boldFont, brush: whiteBrush, bounds: Rect.fromLTWH(10, y + 6, 200, 20));
    graphics.drawString('Mode & Reference', boldFont, brush: whiteBrush, bounds: Rect.fromLTWH(210, y + 6, 180, 20));
    graphics.drawString('Amount (INR)', boldFont, brush: whiteBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(pageSize.width - 130, y + 6, 120, 20));

    y += 25;

    // Table Row
    graphics.drawRectangle(pen: borderPen, bounds: Rect.fromLTWH(0, y, pageSize.width, 45));
    graphics.drawString('Solar Rooftop Milestone Payment', bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(10, y + 8, 195, 15));
    if (tx.remarks != null && tx.remarks!.isNotEmpty) {
      graphics.drawString('Remarks: ${tx.remarks}', smallFont, brush: PdfSolidBrush(PdfColor(100, 116, 139)), bounds: Rect.fromLTWH(10, y + 24, 195, 15));
    }

    final modeDetail = '${tx.paymentMode}${tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty ? "\nRef: ${tx.referenceNumber}" : ""}';
    graphics.drawString(modeDetail, bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(210, y + 8, 180, 30));

    final amountFormatted = '₹${NumberFormat('#,##,###.00').format(tx.amount)}';
    graphics.drawString(
      amountFormatted,
      boldFont,
      brush: primaryBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(pageSize.width - 130, y + 8, 120, 20),
    );

    y += 55;

    // --- 4. BALANCE POSITION SUMMARY ---
    final contractTotal = customer.totalAmount;
    final currentPaid = customer.paidAmount;
    final balanceRemaining = customer.pendingAmount;

    graphics.drawString('FINANCIAL POSITION SUMMARY', headerFont, brush: primaryBrush, bounds: Rect.fromLTWH(0, y, pageSize.width, 20));
    y += 22;

    graphics.drawRectangle(pen: borderPen, brush: lightBgBrush, bounds: Rect.fromLTWH(0, y, pageSize.width, 70));

    graphics.drawString('Total Contract Value:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(15, y + 10, 160, 15));
    graphics.drawString('₹${NumberFormat('#,##,###.00').format(contractTotal)}', bodyFont, brush: darkBrush, bounds: Rect.fromLTWH(180, y + 10, 150, 15));

    graphics.drawString('Total Amount Paid (Cumulative):', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(15, y + 28, 160, 15));
    graphics.drawString('₹${NumberFormat('#,##,###.00').format(currentPaid)}', boldFont, brush: PdfSolidBrush(PdfColor(5, 150, 105)), bounds: Rect.fromLTWH(180, y + 28, 150, 15));

    graphics.drawString('Outstanding Balance:', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(15, y + 46, 160, 15));
    graphics.drawString('₹${NumberFormat('#,##,###.00').format(balanceRemaining)}', boldFont, brush: PdfSolidBrush(PdfColor(220, 38, 38)), bounds: Rect.fromLTWH(180, y + 46, 150, 15));

    y += 85;

    // --- 5. SIGNATURE & VERIFICATION NOTICE ---
    graphics.drawString('Received By: ${tx.receivedBy ?? "Authorized Staff"}', boldFont, brush: darkBrush, bounds: Rect.fromLTWH(10, y + 10, 200, 15));
    graphics.drawString('Status: ${tx.syncStatus}  |  Verification: ${tx.verificationStatus}', smallFont, brush: darkBrush, bounds: Rect.fromLTWH(10, y + 28, 250, 15));

    graphics.drawString('Authorized Signatory', boldFont, brush: darkBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(pageSize.width - 200, y + 10, 190, 15));
    graphics.drawString('Siya Infotech Solutions', smallFont, brush: darkBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(pageSize.width - 200, y + 28, 190, 15));

    // Bottom disclaimer
    graphics.drawString(
      'This is a computer-generated receipt. Offline-issued receipts are verified against company bank logs upon cloud synchronization.',
      smallFont,
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(0, pageSize.height - 25, pageSize.width, 20),
    );

    // 2. Save document to file
    final bytes = await document.save();
    document.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'Receipt_${customer.consumerNo}_${tx.paymentDate.toIso8601String().split('T')[0]}_${tx.id ?? "tx"}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  /// Open receipt with system PDF viewer
  static Future<void> openReceipt(File file) async {
    await OpenFilex.open(file.path);
  }

  /// Share payment receipt summary via WhatsApp
  static Future<void> shareViaWhatsApp({
    required PaymentTransaction tx,
    required ConsumerRecord customer,
  }) async {
    final dateStr = DateFormat('dd-MM-yyyy').format(tx.paymentDate);
    final amountFormatted = NumberFormat('#,##,###').format(tx.amount);
    final balanceFormatted = NumberFormat('#,##,###').format(customer.pendingAmount);

    final message = '''
⚡ *SIYA SOLAR CONNECT — PAYMENT RECEIPT* ⚡

Dear *${customer.name}*,
Thank you for your payment!

📄 *Receipt Details:*
• *Receipt No:* ${tx.id ?? tx.clientTxId ?? 'REC'}
• *Consumer No:* ${customer.consumerNo}
• *Amount Received:* ₹$amountFormatted
• *Payment Date:* $dateStr
• *Payment Mode:* ${tx.paymentMode} ${tx.referenceNumber != null ? "(${tx.referenceNumber})" : ""}
• *Installation Stage:* ${customer.installationStatus}

💰 *Current Balance:*
• *Remaining Balance:* ₹$balanceFormatted
• *Receipt Status:* ${tx.isPendingSync ? "Draft (Local Confirmation)" : "Verified & Confirmed"}

For any queries, please reach out to Siya Infotech.
''';

    final cleanMobile = (customer.mobile ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final phoneTarget = cleanMobile.length == 10 ? '91$cleanMobile' : cleanMobile;

    final url = Uri.parse(
      'https://wa.me/$phoneTarget?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
