import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/customer_payment.dart';
import 'package:admin_panel/services/excel_export_service.dart';

void main() {
  group('Simple Payment Module Tests (Admin Panel)', () {
    test('1. Deterministic calculation: Total ₹1,90,000 with ₹50,000 and ₹40,000 payments', () {
      final now = DateTime.now();

      final payment1 = PaymentTransaction(
        id: 'tx-1',
        customerId: 'cust-101',
        consumerNo: '123456789012',
        amount: 50000.0,
        paymentDate: DateTime(2026, 9, 15),
        paymentMode: 'Cash',
        remarks: 'First installment',
        status: 'Valid',
        createdAt: now,
      );

      final summary1 = CustomerPaymentSummary.calculate(
        totalAmount: 190000.0,
        transactions: [payment1],
      );

      expect(summary1.totalAmount, 190000.0);
      expect(summary1.paidAmount, 50000.0);
      expect(summary1.pendingAmount, 140000.0);
      expect(summary1.paymentStatus, 'Partially Paid');

      final payment2 = PaymentTransaction(
        id: 'tx-2',
        customerId: 'cust-101',
        consumerNo: '123456789012',
        amount: 40000.0,
        paymentDate: DateTime(2026, 9, 18),
        paymentMode: 'UPI',
        remarks: 'Second installment',
        status: 'Valid',
        createdAt: now,
      );

      final summary2 = CustomerPaymentSummary.calculate(
        totalAmount: 190000.0,
        transactions: [payment1, payment2],
      );

      expect(summary2.totalAmount, 190000.0);
      expect(summary2.paidAmount, 90000.0);
      expect(summary2.pendingAmount, 100000.0);
      expect(summary2.paymentStatus, 'Partially Paid');
    });

    test('2. Full payment transition: Total ₹1,90,000, Paid ₹1,90,000 -> Pending ₹0 and Paid status', () {
      final now = DateTime.now();

      final paymentFull = PaymentTransaction(
        id: 'tx-full',
        customerId: 'cust-102',
        consumerNo: '987654321012',
        amount: 190000.0,
        paymentDate: DateTime(2026, 9, 19),
        paymentMode: 'Bank Transfer',
        status: 'Valid',
        createdAt: now,
      );

      final summary = CustomerPaymentSummary.calculate(
        totalAmount: 190000.0,
        transactions: [paymentFull],
      );

      expect(summary.totalAmount, 190000.0);
      expect(summary.paidAmount, 190000.0);
      expect(summary.pendingAmount, 0.0);
      expect(summary.paymentStatus, 'Paid');
      expect(summary.isPaid, isTrue);
    });

    test('3. CustomerPaymentRow correctly models table columns', () {
      final row = CustomerPaymentRow(
        customerId: 'cust-101',
        customerName: 'Ramesh Patel',
        consumerNo: '123456789012',
        village: 'Navsari',
        mobileNumber: '9876543210',
        totalAmount: 190000.0,
        paidAmount: 90000.0,
        pendingAmount: 100000.0,
        paymentStatus: 'Partially Paid',
        lastPaymentAmount: 40000.0,
        lastPaymentDate: DateTime(2026, 9, 18),
        lastPaymentMode: 'UPI',
      );

      expect(row.customerName, 'Ramesh Patel');
      expect(row.consumerNo, '123456789012');
      expect(row.totalAmount, 190000.0);
      expect(row.paidAmount, 90000.0);
      expect(row.pendingAmount, 100000.0);
      expect(row.lastPaymentMode, 'UPI');
    });

    test('4. Excel export definitions format currencies and headers properly', () {
      final columns = [
        ExcelColumnDef<CustomerPaymentRow>(
          header: 'Customer',
          valueExtractor: (r) => r.customerName,
        ),
        ExcelColumnDef<CustomerPaymentRow>(
          header: 'Consumer No',
          valueExtractor: (r) => r.consumerNo,
        ),
        ExcelColumnDef<CustomerPaymentRow>(
          header: 'Total Amount',
          valueExtractor: (r) => r.totalAmount,
          isCurrency: true,
        ),
        ExcelColumnDef<CustomerPaymentRow>(
          header: 'Paid',
          valueExtractor: (r) => r.paidAmount,
          isCurrency: true,
        ),
        ExcelColumnDef<CustomerPaymentRow>(
          header: 'Pending',
          valueExtractor: (r) => r.pendingAmount,
          isCurrency: true,
        ),
      ];

      final row = CustomerPaymentRow(
        customerId: 'cust-101',
        customerName: 'Suresh Kumar',
        consumerNo: '112233445566',
        totalAmount: 200000.0,
        paidAmount: 50000.0,
        pendingAmount: 150000.0,
        paymentStatus: 'Partially Paid',
      );

      expect(columns[0].valueExtractor(row), 'Suresh Kumar');
      expect(columns[1].valueExtractor(row), '112233445566');
      expect(columns[2].valueExtractor(row), 200000.0);
      expect(columns[3].valueExtractor(row), 50000.0);
      expect(columns[4].valueExtractor(row), 150000.0);
    });

    test('5. Additional Payment: Separated and does NOT reduce Contract Pending', () {
      const total = 190000.0;
      final p1 = PaymentTransaction(
        id: 'tx-1',
        customerId: 'cust-101',
        consumerNo: '123456789012',
        amount: 50000.0,
        paymentDate: DateTime(2026, 9, 15),
        paymentMode: 'Cash',
        paymentType: PaymentType.contract,
        status: 'Valid',
      );

      final p2 = PaymentTransaction(
        id: 'tx-2',
        customerId: 'cust-101',
        consumerNo: '123456789012',
        amount: 40000.0,
        paymentDate: DateTime(2026, 9, 18),
        paymentMode: 'UPI',
        paymentType: PaymentType.contract,
        status: 'Valid',
      );

      final pAdditional = PaymentTransaction(
        id: 'tx-add-1',
        customerId: 'cust-101',
        consumerNo: '123456789012',
        amount: 10000.0,
        paymentDate: DateTime(2026, 9, 19),
        paymentMode: 'UPI',
        paymentType: PaymentType.additional,
        status: 'Valid',
        remarks: 'Extra material',
      );

      final summary = CustomerPaymentSummary.calculate(
        totalAmount: total,
        transactions: [p1, p2, pAdditional],
      );

      expect(summary.contractAmount, 190000.0);
      expect(summary.contractPaid, 90000.0);
      expect(summary.contractPending, 100000.0);
      expect(summary.additionalPaid, 10000.0);
      expect(summary.totalReceived, 100000.0);
    });
  });
}
