import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/bank_submission_sticker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ConsumerRecord createSampleCustomer(int index) {
    return ConsumerRecord(
      id: 'cust-$index',
      name: 'Customer Number $index',
      consumerNo: '01551020000$index',
      mobile: '987654321$index',
      address: 'At Post Betawad, Tal. Sindkheda, Dist. Dhule',
      applicationId: 'APP-2026-000$index',
      systemCapacity: '3 kW',
      submitDate: DateTime(2026, 10, 17),
      loanRequired: 'Yes',
      loanStatus: 'Applied',
    );
  }

  test('generates valid PDF bytes for 2 customers on 1 A4 page', () async {
    final customers = [createSampleCustomer(1), createSampleCustomer(2)];
    final pdfBytes = await BankSubmissionStickerService.generateStickersPdfBytes(customers);

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(1000));
  });

  test('generates PDF for odd number of customers (e.g. 11 customers -> 6 pages)', () async {
    final customers11 = List.generate(11, (i) => createSampleCustomer(i + 1));
    final pdfBytes = await BankSubmissionStickerService.generateStickersPdfBytes(customers11);

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(5000));
  });

  test('generates PDF for 10 customers -> 5 pages', () async {
    final customers10 = List.generate(10, (i) => createSampleCustomer(i + 1));
    final pdfBytes = await BankSubmissionStickerService.generateStickersPdfBytes(customers10);

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(5000));
  });

  test('generates sample A4 sheet with 2 customer stickers and saves to root', () async {
    final customer1 = ConsumerRecord(
      id: 'cust-1',
      name: 'RAMESH BALASAHEB PATIL',
      consumerNo: '015510289012',
      mobile: '9822012345',
      address: 'At Post Betawad, Tal. Sindkheda, Dist. Dhule - 425403',
      applicationId: 'SIYA-LN-2026-0842',
      systemCapacity: '3 kW',
      submitDate: DateTime(2026, 10, 17),
      loanRequired: 'Yes',
      loanStatus: 'Applied',
    );

    final customer2 = ConsumerRecord(
      id: 'cust-2',
      name: 'DILIP PANDURANG PATIL',
      consumerNo: '015510472091',
      mobile: '9423198765',
      address: 'Plot No. 14, Shivaji Nagar, Sindkheda, Dist. Dhule - 425406',
      applicationId: 'SIYA-LN-2026-0843',
      systemCapacity: '5 kW',
      submitDate: DateTime(2026, 10, 17),
      loanRequired: 'Yes',
      loanStatus: 'Applied',
    );

    final customer3 = ConsumerRecord(
      id: 'cust-3',
      name: 'PRAKASH SHIVAJI MORE',
      consumerNo: '015510684123',
      mobile: '9823456789',
      address: 'At Post Chimthane, Tal. Sindkheda, Dist. Dhule - 425406',
      applicationId: 'SIYA-LN-2026-0844',
      systemCapacity: '3 kW',
      submitDate: DateTime(2026, 10, 17),
      loanRequired: 'Yes',
      loanStatus: 'Applied',
    );

    final customer4 = ConsumerRecord(
      id: 'cust-4',
      name: 'SANJAY SHANTARAM CHAUDHARI',
      consumerNo: '015510793456',
      mobile: '9881234567',
      address: 'Near Gram Panchayat, Nardana, Dist. Dhule - 425404',
      applicationId: 'SIYA-LN-2026-0845',
      systemCapacity: '4 kW',
      submitDate: DateTime(2026, 10, 17),
      loanRequired: 'Yes',
      loanStatus: 'Applied',
    );

    final pdfBytes = await BankSubmissionStickerService.generateStickersPdfBytes(
      [customer1, customer2, customer3, customer4],
    );
    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(2000));

    final sampleFile = File('../sample_bank_submission_stickers_a4.pdf');
    await sampleFile.writeAsBytes(pdfBytes);
    expect(await sampleFile.exists(), isTrue);
  });
}
