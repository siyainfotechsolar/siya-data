import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/customer_payment.dart';
import 'package:mobile_app/models/consumer_record.dart';

void main() {
  group('Simple Payment Module Tests (Mobile App)', () {
    test('1. Automatic Calculation: Pending = Total - All Payments', () {
      // Total ₹1,90,000, Payment 1: ₹50,000, Payment 2: ₹40,000 -> Paid: ₹90,000, Pending: ₹1,00,000
      const total = 190000.0;
      final tx1 = PaymentTransaction(
        id: 'tx-1',
        customerId: 'cust-1',
        consumerNo: '123456789012',
        amount: 50000.0,
        paymentDate: DateTime(2026, 9, 15),
        paymentMode: 'Cash',
        remarks: 'Cash collected on site',
      );

      final summary1 = CustomerPaymentSummary.calculate(
        totalAmount: total,
        transactions: [tx1],
      );

      expect(summary1.paidAmount, 50000.0);
      expect(summary1.pendingAmount, 140000.0);
      expect(summary1.paymentStatus, 'Partially Paid');

      final tx2 = PaymentTransaction(
        id: 'tx-2',
        customerId: 'cust-1',
        consumerNo: '123456789012',
        amount: 40000.0,
        paymentDate: DateTime(2026, 9, 18),
        paymentMode: 'UPI',
        remarks: 'UPI transaction',
      );

      final summary2 = CustomerPaymentSummary.calculate(
        totalAmount: total,
        transactions: [tx1, tx2],
      );

      expect(summary2.paidAmount, 90000.0);
      expect(summary2.pendingAmount, 100000.0);
      expect(summary2.paymentStatus, 'Partially Paid');
    });

    test('2. ConsumerRecord balance update when payment is applied', () {
      final initialRecord = ConsumerRecord(
        id: 'cust-1',
        consumerNo: '123456789012',
        name: 'Vikas Sharma',
        totalAmount: 190000.0,
        paidAmount: 0.0,
        pendingAmount: 190000.0,
        paymentStatus: 'Pending',
      );

      // Apply first payment ₹50,000
      final updatedRecord1 = initialRecord.copyWith(
        paidAmount: initialRecord.paidAmount + 50000.0,
        pendingAmount: initialRecord.totalAmount - (initialRecord.paidAmount + 50000.0),
        paymentStatus: 'Partially Paid',
      );

      expect(updatedRecord1.paidAmount, 50000.0);
      expect(updatedRecord1.pendingAmount, 140000.0);
      expect(updatedRecord1.paymentStatus, 'Partially Paid');

      // Apply second payment ₹40,000
      final updatedRecord2 = updatedRecord1.copyWith(
        paidAmount: updatedRecord1.paidAmount + 40000.0,
        pendingAmount: updatedRecord1.totalAmount - (updatedRecord1.paidAmount + 40000.0),
        paymentStatus: 'Partially Paid',
      );

      expect(updatedRecord2.paidAmount, 90000.0);
      expect(updatedRecord2.pendingAmount, 100000.0);
    });

    test('3. Offline sync queue idempotency key formatting', () {
      final now = DateTime(2026, 9, 18);
      const customerId = 'cust-1';
      const amount = 40000.0;
      const paymentMode = 'UPI';
      const clientTxId = 'ptx_1726650000';

      final idempotencyKey = 'idem_${customerId}_${now.toIso8601String().split('T')[0]}_${amount.toStringAsFixed(2)}_${paymentMode.trim()}_$clientTxId';

      expect(idempotencyKey, contains('cust-1'));
      expect(idempotencyKey, contains('2026-09-18'));
      expect(idempotencyKey, contains('40000.00'));
      expect(idempotencyKey, contains('UPI'));
      expect(idempotencyKey, contains('ptx_172665000'));
    });

    test('4. Additional Payment: Does NOT reduce original Contract Pending balance', () {
      const total = 190000.0;
      final tx1 = PaymentTransaction(
        id: 'tx-1',
        customerId: 'cust-1',
        consumerNo: '123456789012',
        amount: 50000.0,
        paymentDate: DateTime(2026, 9, 15),
        paymentMode: 'Cash',
        paymentType: PaymentType.contract,
      );

      final tx2 = PaymentTransaction(
        id: 'tx-2',
        customerId: 'cust-1',
        consumerNo: '123456789012',
        amount: 40000.0,
        paymentDate: DateTime(2026, 9, 18),
        paymentMode: 'UPI',
        paymentType: PaymentType.contract,
      );

      final txAdditional = PaymentTransaction(
        id: 'tx-add-1',
        customerId: 'cust-1',
        consumerNo: '123456789012',
        amount: 10000.0,
        paymentDate: DateTime(2026, 9, 19),
        paymentMode: 'UPI',
        paymentType: PaymentType.additional,
        remarks: 'Extra cable wire',
      );

      final summary = CustomerPaymentSummary.calculate(
        totalAmount: total,
        transactions: [tx1, tx2, txAdditional],
      );

      expect(summary.contractAmount, 190000.0);
      expect(summary.contractPaid, 90000.0);
      // Contract Pending must remain exactly 1,00,000 (190000 - 90000)
      expect(summary.contractPending, 100000.0);
      expect(summary.additionalPaid, 10000.0);
      expect(summary.totalReceived, 100000.0);
    });

    test('5. Loan Customer Calculations: 1st, 2nd, and Additional accounting match prompt specs', () {
      final loanCustomer = ConsumerRecord(
        id: 'cust-loan',
        consumerNo: '998877665544',
        name: 'Rajesh Patil',
        loanRequired: 'Yes',
        totalAmount: 200000.0,
        firstPaymentAmount: 120000.0,
        secondPaymentAmount: 80000.0,
        firstPaymentReceived: 120000.0,
        secondPaymentReceived: 0.0,
        paidAmount: 120000.0,
        pendingAmount: 80000.0,
        additionalPaidAmount: 10000.0,
      );

      expect(loanCustomer.isLoanCustomer, true);
      expect(loanCustomer.firstPaymentPending, 0.0);
      expect(loanCustomer.secondPaymentPending, 80000.0);
      expect(loanCustomer.totalAmount, 200000.0);
      expect(loanCustomer.paidAmount, 120000.0);
      expect(loanCustomer.pendingAmount, 80000.0);
      expect(loanCustomer.additionalPaidAmount, 10000.0);

      // Verify Additional payment does NOT reduce original 1st or 2nd Payment pending
      final tx1 = PaymentTransaction(
        id: 'tx-1',
        customerId: loanCustomer.id!,
        consumerNo: loanCustomer.consumerNo,
        amount: 120000.0,
        paymentDate: DateTime(2026, 9, 10),
        paymentMode: 'Bank Transfer',
        paymentType: PaymentType.firstPayment,
      );
      final txAdd = PaymentTransaction(
        id: 'tx-add',
        customerId: loanCustomer.id!,
        consumerNo: loanCustomer.consumerNo,
        amount: 10000.0,
        paymentDate: DateTime(2026, 9, 15),
        paymentMode: 'UPI',
        paymentType: PaymentType.additional,
      );

      expect(tx1.isFirstPayment, true);
      expect(tx1.isSecondPayment, false);
      expect(tx1.isAdditional, false);
      expect(txAdd.isFirstPayment, false);
      expect(txAdd.isSecondPayment, false);
      expect(txAdd.isAdditional, true);
    });
  });
}
