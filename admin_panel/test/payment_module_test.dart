import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/customer_payment.dart';

void main() {
  group('Payment Module Tests', () {
    test('1. CustomerPaymentTransaction JSON serialization & deserialization contract', () {
      final now = DateTime.now();
      final tx = CustomerPaymentTransaction(
        id: 'pay-tx-101',
        customerId: 'cust-uuid-1',
        consumerNo: '123456789012',
        amount: 50000.0,
        paymentDate: DateTime(2026, 9, 6),
        paymentMode: 'UPI',
        referenceNumber: 'UTR123456789',
        receivedBy: 'Vishal',
        remarks: 'First installment paid online',
        status: 'Valid',
        createdAt: now,
        updatedAt: now,
      );

      final json = tx.toJson();
      expect(json['customer_id'], 'cust-uuid-1');
      expect(json['amount'], 50000.0);
      expect(json['payment_date'], '2026-09-06');
      expect(json['payment_mode'], 'UPI');
      expect(json['reference_number'], 'UTR123456789');
      expect(json['received_by'], 'Vishal');
      expect(json['status'], 'Valid');

      final deserialized = CustomerPaymentTransaction.fromJson(json);
      expect(deserialized.id, 'pay-tx-101');
      expect(deserialized.customerId, 'cust-uuid-1');
      expect(deserialized.amount, 50000.0);
      expect(deserialized.paymentMode, 'UPI');
      expect(deserialized.referenceNumber, 'UTR123456789');
      expect(deserialized.status, 'Valid');
    });

    test('2. Deterministic Balance Calculation: Pending = Total - Paid', () {
      // Test case 1 from prompt: Total ₹2,00,000, Payment ₹50,000 -> Paid ₹50,000, Pending ₹1,50,000, Partially Paid
      final tx1 = CustomerPaymentTransaction(
        id: 'tx-1', customerId: 'c1', consumerNo: '123456789012', amount: 50000.0,
        paymentDate: DateTime(2026, 9, 1), paymentMode: 'Bank Transfer',
        referenceNumber: 'UTR56789', status: 'Valid', createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary1 = CustomerPaymentCalculation.calculate(
        totalAmount: 200000.0,
        transactions: [tx1],
      );

      expect(summary1.totalAmount, 200000.0);
      expect(summary1.paidAmount, 50000.0);
      expect(summary1.pendingAmount, 150000.0);
      expect(summary1.status, 'Partially Paid');

      // Test case 2 from prompt: Add another ₹1,50,000 -> Paid ₹2,00,000, Pending ₹0, Paid
      final tx2 = CustomerPaymentTransaction(
        id: 'tx-2', customerId: 'c1', consumerNo: '123456789012', amount: 150000.0,
        paymentDate: DateTime(2026, 9, 6), paymentMode: 'UPI',
        referenceNumber: 'UTR12345', status: 'Valid', createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary2 = CustomerPaymentCalculation.calculate(
        totalAmount: 200000.0,
        transactions: [tx1, tx2],
      );

      expect(summary2.paidAmount, 200000.0);
      expect(summary2.pendingAmount, 0.0);
      expect(summary2.status, 'Paid');

      // Zero payments -> Pending
      final summaryZero = CustomerPaymentCalculation.calculate(
        totalAmount: 200000.0,
        transactions: [],
      );
      expect(summaryZero.paidAmount, 0.0);
      expect(summaryZero.pendingAmount, 200000.0);
      expect(summaryZero.status, 'Pending');
    });

    test('3. Reversed transactions do not count towards paid balance', () {
      final validTx = CustomerPaymentTransaction(
        id: 'tx-1', customerId: 'c1', consumerNo: '123456789012', amount: 50000.0,
        paymentDate: DateTime(2026, 9, 1), paymentMode: 'UPI',
        status: 'Valid', createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final reversedTx = CustomerPaymentTransaction(
        id: 'tx-2', customerId: 'c1', consumerNo: '123456789012', amount: 30000.0,
        paymentDate: DateTime(2026, 9, 2), paymentMode: 'Cash',
        status: 'Reversed', createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final summary = CustomerPaymentCalculation.calculate(
        totalAmount: 100000.0,
        transactions: [validTx, reversedTx],
      );

      // Only validTx counts
      expect(summary.paidAmount, 50000.0);
      expect(summary.pendingAmount, 50000.0);
      expect(summary.status, 'Partially Paid');
    });

    test('4. Overdue Payment evaluation rule: only if due date exists', () {
      final today = DateTime.now();
      final pastDate = today.subtract(const Duration(days: 5));
      final futureDate = today.add(const Duration(days: 5));

      // Test Case 3: Payment pending and due date passed -> Overdue
      final overdueCustomer = ConsumerRecord(
        consumerNo: '111', name: 'Overdue Cust',
        totalAmount: 200000.0, paidAmount: 50000.0, pendingAmount: 150000.0,
        paymentStatus: 'Partially Paid', paymentDueDate: pastDate,
      );
      expect(overdueCustomer.isPaymentOverdue, isTrue);

      // Test Case 4: Payment pending but no due date -> Pending only, do NOT invent overdue
      final pendingNoDueDateCustomer = ConsumerRecord(
        consumerNo: '222', name: 'No Due Date Cust',
        totalAmount: 200000.0, paidAmount: 50000.0, pendingAmount: 150000.0,
        paymentStatus: 'Partially Paid', paymentDueDate: null,
      );
      expect(pendingNoDueDateCustomer.isPaymentOverdue, isFalse);

      // Future due date -> not overdue
      final futureCustomer = ConsumerRecord(
        consumerNo: '333', name: 'Future Due Cust',
        totalAmount: 200000.0, paidAmount: 50000.0, pendingAmount: 150000.0,
        paymentStatus: 'Partially Paid', paymentDueDate: futureDate,
      );
      expect(futureCustomer.isPaymentOverdue, isFalse);

      // Fully paid with past due date -> not overdue
      final fullyPaidCustomer = ConsumerRecord(
        consumerNo: '444', name: 'Paid Cust',
        totalAmount: 200000.0, paidAmount: 200000.0, pendingAmount: 0.0,
        paymentStatus: 'Paid', paymentDueDate: pastDate,
      );
      expect(fullyPaidCustomer.isPaymentOverdue, isFalse);
    });

    test('5. Supported payment modes list', () {
      expect(CustomerPaymentTransaction.standardModes, contains('Cash'));
      expect(CustomerPaymentTransaction.standardModes, contains('UPI'));
      expect(CustomerPaymentTransaction.standardModes, contains('Bank Transfer'));
      expect(CustomerPaymentTransaction.standardModes, contains('Cheque'));
      expect(CustomerPaymentTransaction.standardModes, contains('Other'));
      expect(CustomerPaymentTransaction.standardModes.length, 5);
    });

    test('6. Overpayment detection logic', () {
      bool isOverpayment({required double currentPaid, required double newPayment, required double totalAmount}) {
        if (totalAmount <= 0) return false;
        return (currentPaid + newPayment) > (totalAmount + 0.01);
      }

      expect(isOverpayment(currentPaid: 120000, newPayment: 80000, totalAmount: 200000), isFalse);
      expect(isOverpayment(currentPaid: 120000, newPayment: 85000, totalAmount: 200000), isTrue);
      expect(isOverpayment(currentPaid: 0, newPayment: 50000, totalAmount: 50000), isFalse);
    });

    test('7. Duplicate transaction detection contract', () {
      final date = DateTime(2026, 9, 6);
      final existingTx = CustomerPaymentTransaction(
        id: 'tx-1', customerId: 'cust-1', consumerNo: '123456789012', amount: 50000.0,
        paymentDate: date, paymentMode: 'UPI', status: 'Valid', createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool isDuplicate(String customerId, double amount, DateTime paymentDate, List<CustomerPaymentTransaction> list) {
        return list.any((t) =>
          t.customerId == customerId &&
          (t.amount - amount).abs() < 0.01 &&
          t.paymentDate.year == paymentDate.year &&
          t.paymentDate.month == paymentDate.month &&
          t.paymentDate.day == paymentDate.day &&
          t.status == 'Valid',
        );
      }

      expect(isDuplicate('cust-1', 50000.0, date, [existingTx]), isTrue);
      expect(isDuplicate('cust-1', 40000.0, date, [existingTx]), isFalse);
      expect(isDuplicate('cust-2', 50000.0, date, [existingTx]), isFalse);
    });
  });
}
