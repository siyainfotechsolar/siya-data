import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/shared_document.dart';
import 'package:mobile_app/models/customer_task.dart';
import 'package:mobile_app/services/pdf_processing_service.dart';

void main() {
  group('WhatsApp Direct Share & Smart Extraction Tests', () {
    test('SharedDocument model parses and serializes correctly', () {
      final doc = SharedDocument(
        filePath: '/data/user/0/com.siyainfotech.mobile_app/files/whatsapp_shared_docs/bill.pdf',
        fileName: 'MSEDCL_Bill_096590001608.pdf',
        mimeType: 'application/pdf',
        fileSize: 1048576,
        fileHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        source: 'WhatsApp Share',
        receivedAt: DateTime(2026, 9, 18, 10, 30),
        extraText: 'Please update my solar file with this bill',
      );

      expect(doc.isPdf, isTrue);
      expect(doc.isImage, isFalse);
      expect(doc.formattedSize, '1.0 MB');
      expect(doc.fileNameWithoutExtension, 'MSEDCL_Bill_096590001608');
      expect(doc.source, 'WhatsApp Share');

      final map = doc.toMap();
      final fromMapDoc = SharedDocument.fromMap(map);
      expect(fromMapDoc.fileName, doc.fileName);
      expect(fromMapDoc.fileHash, doc.fileHash);
      expect(fromMapDoc.extraText, doc.extraText);
    });

    test('PdfProcessingService extracts electricity bill patterns accurately', () async {
      // Simulate raw extracted text from a typical Maharashtra MSEDCL Electricity Bill
      const sampleMsedclText = '''
MAHARASHTRA STATE ELECTRICITY DISTRIBUTION CO. LTD.
LT BILL FOR THE MONTH OF AUG-2026
CONSUMER NO: 096590001608
CONSUMER NAME: SHRI NAMDEO DAGA MALI
MOBILE: 9822012345
APPLICATION ID: APP-MH-2026-8941
VILLAGE: SHIRPUR
BILL DATE: 15/08/2026
DUE DATE: 28/08/2026
BILL AMOUNT: 4250.00
NET PAYABLE: 4250.00
      ''';

      final dummyDoc = SharedDocument(
        filePath: 'mock_bill.pdf',
        fileName: 'MSEDCL_Bill_096590001608.pdf',
        mimeType: 'application/pdf',
        fileSize: 2048,
        fileHash: 'mock_hash_12345',
        receivedAt: DateTime.now(),
        extraText: sampleMsedclText,
      );

      final extracted = await PdfProcessingService.processDocument(dummyDoc);

      expect(extracted.consumerNo, '096590001608');
      expect(extracted.customerName?.toUpperCase(), contains('NAMDEO DAGA MALI'));
      expect(extracted.mobileNumber, '9822012345');
      expect(extracted.applicationId, 'APP-MH-2026-8941');
      expect(extracted.village?.toUpperCase(), contains('SHIRPUR'));
      expect(extracted.billDate, '15/08/2026');
      expect(extracted.dueDate, '28/08/2026');
      expect(extracted.billAmount, 4250.00);
      expect(extracted.detectedDocType, TaskDocumentType.electricityBill);
      expect(extracted.confidenceMap['consumerNo'], 'High');
    });

    test('PdfProcessingService extracts payment receipt and candidate', () async {
      const sampleReceiptText = '''
TRANSACTION SUCCESSFUL
Paid to: SIYA SOLAR INFOTECH
Amount: 15000.00
Payment Date: 12-09-2026
Payment Mode: UPI
UPI Ref No: 625619284712
Customer: SUNIL BHASKAR PATIL
Consumer No: 096580005613
      ''';

      final dummyDoc = SharedDocument(
        filePath: 'payment_receipt.jpg',
        fileName: 'payment_receipt.jpg',
        mimeType: 'image/jpeg',
        fileSize: 50000,
        fileHash: 'mock_receipt_hash',
        receivedAt: DateTime.now(),
        extraText: sampleReceiptText,
      );

      final extracted = await PdfProcessingService.processDocument(dummyDoc);

      expect(extracted.detectedDocType, TaskDocumentType.paymentProof);
      expect(extracted.isPaymentProof, isTrue);
      expect(extracted.consumerNo, '096580005613');
      expect(extracted.billAmount, 15000.00);
      expect(extracted.paymentCandidate, isNotNull);
      expect(extracted.paymentCandidate!['referenceNumber'], '625619284712');
      expect(extracted.paymentCandidate!['paymentMode'], 'UPI');
    });

    test('CustomerTask lifecycle statuses and workflow order', () {
      expect(TaskStatus.standardWorkflow, [
        TaskStatus.newTask,
        TaskStatus.documentReview,
        TaskStatus.customerDataUpdate,
        TaskStatus.verification,
        TaskStatus.complete,
      ]);

      final task = CustomerTask(
        id: 'test_task_1',
        customerId: 'cust_uuid_1',
        customerName: 'SHRI NAMDEO DAGA MALI',
        consumerNo: '096590001608',
        title: 'MSEDCL Bill Review',
        documentName: 'Bill.pdf',
        documentType: TaskDocumentType.electricityBill,
        source: 'WhatsApp Share',
        status: TaskStatus.newTask,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.isWhatsAppShare, isTrue);
      expect(task.isComplete, isFalse);
      expect(task.statusColor, isNotNull);

      // Workflow transition: New -> Review
      final reviewTask = task.copyWith(status: TaskStatus.documentReview);
      expect(reviewTask.status, TaskStatus.documentReview);

      // Transition: Review -> Customer Data Update
      final updateTask = reviewTask.copyWith(status: TaskStatus.customerDataUpdate);
      expect(updateTask.status, TaskStatus.customerDataUpdate);

      // Transition: Complete
      final completedTask = updateTask.copyWith(status: TaskStatus.complete);
      expect(completedTask.isComplete, isTrue);
    });
  });
}
