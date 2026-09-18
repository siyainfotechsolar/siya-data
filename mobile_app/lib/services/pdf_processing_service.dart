import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/extracted_document_data.dart';
import '../models/shared_document.dart';
import '../models/customer_task.dart';

class PdfProcessingService {
  /// Extract text and detect fields from a shared document
  static Future<ExtractedDocumentData> processDocument(
      SharedDocument doc) async {
    String extractedText = '';

    if (doc.isPdf) {
      try {
        final file = File(doc.filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final pdfDoc = PdfDocument(inputBytes: bytes);
          final textExtractor = PdfTextExtractor(pdfDoc);
          extractedText = textExtractor.extractText();
          pdfDoc.dispose();
        }
      } catch (e) {
        debugPrint('PdfTextExtractor error: $e');
      }
    }

    // Also include extraText / captions passed from WhatsApp
    if (doc.extraText != null && doc.extraText!.trim().isNotEmpty) {
      extractedText = '$extractedText\n${doc.extraText!}';
    }

    // If text is still empty or minimal (e.g. image document or scanned PDF),
    // extract information from the file name itself (e.g. MSEDCL_Bill_096590001608.pdf)
    final combinedSource = '$extractedText\n${doc.fileName}';

    return _analyzeExtractedText(combinedSource, doc.fileName);
  }

  static ExtractedDocumentData _analyzeExtractedText(
      String text, String fileName) {
    String? consumerNo;
    String? customerName;
    String? mobileNumber;
    String? applicationId;
    String? village;
    String? billDate;
    String? dueDate;
    double? billAmount;
    String? documentNumber;
    Map<String, dynamic>? paymentCandidate;
    final Map<String, String> confidence = {};

    final cleanText = text.replaceAll('\r\n', '\n');

    // 1. Consumer Number (12-digit MSEDCL standard or explicit prefix)
    final consPrefixRegex = RegExp(
      r'(?:Consumer\s*(?:No|Number|#)|Cons\s*No|ग्राहक\s*क्र(?:मांक|\.)?|Account\s*No|CA\s*No)[\s:=]*([0-9]{9,12})',
      caseSensitive: false,
    );
    final consMatch = consPrefixRegex.firstMatch(cleanText);
    if (consMatch != null) {
      consumerNo = consMatch.group(1);
      confidence['consumerNo'] = 'High';
    } else {
      // Look for standalone 12-digit numbers common in Maharashtra electricity bills
      final twelveDigitRegex = RegExp(r'\b(0\d{11}|\d{12})\b');
      final match12 = twelveDigitRegex.firstMatch(cleanText);
      if (match12 != null) {
        consumerNo = match12.group(1);
        confidence['consumerNo'] = 'Medium';
      }
    }

    // 2. Customer Name
    final namePrefixRegex = RegExp(
      r'(?:Consumer\s*Name|Customer\s*Name|ग्राहकाचे\s*नाव|नाव\s*:|Name\s*:)[\s:=]*([A-Za-z\s]{3,40})',
      caseSensitive: false,
    );
    final nameMatch = namePrefixRegex.firstMatch(cleanText);
    if (nameMatch != null) {
      final candidate = nameMatch.group(1)?.trim();
      if (candidate != null &&
          candidate.length >= 3 &&
          !candidate.toLowerCase().contains('address') &&
          !candidate.toLowerCase().contains('bill')) {
        customerName = candidate;
        confidence['customerName'] = 'High';
      }
    }

    // Fallback name search: lines starting with SHRI / SMT / MR / MRS
    if (customerName == null) {
      final salutationRegex = RegExp(
        r'\b((?:SHRI|SMT|MR|MRS|KUM)\.?\s+[A-Z\s]{4,35})\b',
      );
      final salMatch = salutationRegex.firstMatch(cleanText);
      if (salMatch != null) {
        customerName = salMatch.group(1)?.trim();
        confidence['customerName'] = 'Medium';
      }
    }

    // 3. Mobile Number (10 digits starting with 6, 7, 8, 9)
    final mobilePrefixRegex = RegExp(
      r'(?:Mobile|Mob|मोबाईल|Phone|Cell)[\s:=]*(?:\+?91[\s-]?)?([6-9]\d{9})\b',
      caseSensitive: false,
    );
    final mobileMatch = mobilePrefixRegex.firstMatch(cleanText);
    if (mobileMatch != null) {
      mobileNumber = mobileMatch.group(1);
      confidence['mobileNumber'] = 'High';
    } else {
      final standaloneMobileRegex = RegExp(r'\b([6-9]\d{9})\b');
      final matchMob = standaloneMobileRegex.firstMatch(cleanText);
      if (matchMob != null) {
        mobileNumber = matchMob.group(1);
        confidence['mobileNumber'] = 'Medium';
      }
    }

    // 4. Application ID / RTS Number
    final appRegex = RegExp(
      r'(?:Application\s*(?:No|Id|#)|App\s*Id|अर्ज\s*क्र(?:मांक|\.)?|RTS\s*(?:No|Id))[\s:=]*([A-Za-z0-9-]{6,20})',
      caseSensitive: false,
    );
    final appMatch = appRegex.firstMatch(cleanText);
    if (appMatch != null) {
      applicationId = appMatch.group(1);
      confidence['applicationId'] = 'High';
    }

    // 5. Village / Location
    final villageRegex = RegExp(
      r'(?:\bVillage\b|\bगाव\b|\bTown\b|\bCity\b|\bमु\.\s*पो\.)[\s:=]*([A-Za-z\s]{3,25})',
      caseSensitive: false,
    );
    final villageMatch = villageRegex.firstMatch(cleanText);
    if (villageMatch != null) {
      village = villageMatch.group(1)?.trim();
      confidence['village'] = 'Medium';
    }

    // 6. Dates (Bill Date / Due Date)
    final billDateRegex = RegExp(
      r'(?:Bill\s*Date|Date\s*of\s*Bill|बिल\s*दिनांक|दिनांक)[\s:=]*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})',
      caseSensitive: false,
    );
    final billDateMatch = billDateRegex.firstMatch(cleanText);
    if (billDateMatch != null) {
      billDate = billDateMatch.group(1);
      confidence['billDate'] = 'High';
    }

    final dueDateRegex = RegExp(
      r'(?:Due\s*Date|देय\s*दिनांक)[\s:=]*(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})',
      caseSensitive: false,
    );
    final dueDateMatch = dueDateRegex.firstMatch(cleanText);
    if (dueDateMatch != null) {
      dueDate = dueDateMatch.group(1);
      confidence['dueDate'] = 'High';
    }

    // 7. Bill Amount / Transaction Amount
    final amountRegex = RegExp(
      r'(?:Bill\s*Amount|Net\s*(?:Payable|Amount)|Total\s*Due|Amount\s*Payable|Paid\s*Amount|\bAmount\b|रक्कम|देय\s*रक्कम)[\s:=]*(?:Rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{2})?)',
      caseSensitive: false,
    );
    final amountMatch = amountRegex.firstMatch(cleanText);
    if (amountMatch != null) {
      final rawAmountStr = amountMatch.group(1)?.replaceAll(',', '');
      if (rawAmountStr != null) {
        billAmount = double.tryParse(rawAmountStr);
        if (billAmount != null) {
          confidence['billAmount'] = 'High';
        }
      }
    }

    // 8. Document Type Detection
    final lowerText = cleanText.toLowerCase();
    final lowerFileName = fileName.toLowerCase();
    String detectedType = TaskDocumentType.other;

    if (lowerText.contains('payment receipt') ||
        lowerText.contains('transaction successful') ||
        lowerText.contains('upi ref') ||
        lowerText.contains('utr') ||
        lowerText.contains('paid to') ||
        lowerText.contains('phonepe') ||
        lowerText.contains('google pay') ||
        lowerFileName.contains('receipt') ||
        lowerFileName.contains('payment')) {
      detectedType = TaskDocumentType.paymentProof;
    } else if (lowerText.contains('mahadiscom') ||
        lowerText.contains('msedcl') ||
        lowerText.contains('electricity bill') ||
        lowerText.contains('विद्युत') ||
        (lowerText.contains('bill') && lowerText.contains('consumer')) ||
        lowerFileName.contains('bill') ||
        lowerFileName.contains('msedcl')) {
      detectedType = TaskDocumentType.electricityBill;
    } else if (lowerText.contains('sanction letter') ||
        lowerText.contains('loan account') ||
        lowerText.contains('disbursement') ||
        lowerFileName.contains('loan')) {
      detectedType = TaskDocumentType.loanDocument;
    } else if (lowerText.contains('agreement') ||
        lowerText.contains('contract') ||
        lowerText.contains('stamp paper') ||
        lowerFileName.contains('agreement')) {
      detectedType = TaskDocumentType.agreement;
    } else if (lowerText.contains('net meter') ||
        lowerText.contains('feasibility') ||
        lowerText.contains('commissioning') ||
        lowerFileName.contains('rts')) {
      detectedType = TaskDocumentType.rts;
    } else if (lowerText.contains('subsidy') ||
        lowerText.contains('pm surya') ||
        lowerText.contains('national portal') ||
        lowerFileName.contains('subsidy')) {
      detectedType = TaskDocumentType.subsidy;
    } else if (lowerText.contains('installation') ||
        lowerText.contains('work completion') ||
        lowerText.contains('structure') ||
        lowerFileName.contains('install')) {
      detectedType = TaskDocumentType.installation;
    }

    // 9. Payment Candidate (if payment proof detected)
    if (detectedType == TaskDocumentType.paymentProof) {
      final utrRegex = RegExp(
        r'(?:UPI\s*Ref(?:\s*No)?|UTR(?:\s*No)?|Txn\s*ID|Transaction\s*ID)[\s:=]*([A-Za-z0-9]{10,22})',
        caseSensitive: false,
      );
      final utrMatch = utrRegex.firstMatch(cleanText);
      final refNumber = utrMatch?.group(1);

      String mode = 'UPI';
      if (lowerText.contains('neft') || lowerText.contains('rtgs')) {
        mode = 'Bank Transfer';
      } else if (lowerText.contains('cheque')) {
        mode = 'Cheque';
      } else if (lowerText.contains('cash')) {
        mode = 'Cash';
      }

      paymentCandidate = {
        'amount': billAmount ?? 0.0,
        'paymentDate': billDate ?? DateTime.now().toIso8601String().split('T').first,
        'paymentMode': mode,
        'referenceNumber': refNumber ?? '',
      };
    }

    return ExtractedDocumentData(
      rawText: cleanText,
      customerName: customerName,
      consumerNo: consumerNo,
      mobileNumber: mobileNumber,
      applicationId: applicationId,
      village: village,
      billDate: billDate,
      dueDate: dueDate,
      billAmount: billAmount,
      documentNumber: documentNumber,
      detectedDocType: detectedType,
      paymentCandidate: paymentCandidate,
      confidenceMap: confidence,
    );
  }
}
