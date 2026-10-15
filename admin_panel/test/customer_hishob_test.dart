import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/customer_hishob.dart';
import 'package:admin_panel/models/customer_payment.dart';
import 'package:admin_panel/models/invoice.dart';

void main() {
  group('Customer Hishob Management Module Tests', () {
    // Sample Invoice factory helper
    Invoice createSampleInvoice({
      required String id,
      required String invoiceNumber,
      required String consumerNo,
      required String customerName,
      required double grandTotal,
      DateTime? invoiceDate,
    }) {
      return Invoice(
        id: id,
        invoiceNumber: invoiceNumber,
        refInvoiceNo: 'QUOT-$invoiceNumber',
        consumerNo: consumerNo,
        customerName: customerName,
        address: 'Pune, Maharashtra',
        villageCity: 'Pune',
        district: 'Pune',
        mobileNo: '9876543210',
        invoiceDate: invoiceDate ?? DateTime(2026, 10, 1),
        items: [
          {'description': 'Solar Grid Inverter & Panels', 'amount': grandTotal.toString()}
        ],
        taxableAmount: grandTotal / 1.12,
        gst5: (grandTotal / 1.12) * 0.05,
        gst18: (grandTotal / 1.12) * 0.07,
        totalGst: (grandTotal / 1.12) * 0.12,
        grandTotal: grandTotal,
        amountInWords: 'Rupees',
        totalPaid: 0.0,
        totalPending: grandTotal,
        paymentStatus: 'Pending',
      );
    }

    // Sample Payment factory helper
    PaymentTransaction createSamplePayment({
      required String id,
      required String customerId,
      required String consumerNo,
      required double amount,
      String? invoiceNumber,
      String status = TransactionStatus.valid,
      DateTime? paymentDate,
    }) {
      return PaymentTransaction(
        id: id,
        customerId: customerId,
        consumerNo: consumerNo,
        amount: amount,
        paymentDate: paymentDate ?? DateTime(2026, 10, 5),
        paymentMode: PaymentMode.bankTransfer,
        referenceNumber: 'REF-$id',
        invoiceNumber: invoiceNumber,
        status: status,
      );
    }

    test('1. Core Calculation Rule: Invoice ₹2,00,000 and Actual Paid ₹80,000 results in Pending ₹1,20,000', () {
      final invoice = createSampleInvoice(
        id: 'inv-1',
        invoiceNumber: 'SID000101',
        consumerNo: '09701001',
        customerName: 'Anand Kulkarni',
        grandTotal: 200000.0,
      );

      final payment = createSamplePayment(
        id: 'pay-1',
        customerId: 'cust-1',
        consumerNo: '09701001',
        amount: 80000.0,
        invoiceNumber: 'SID000101',
      );

      final hishob = CustomerHishobEntry.build(
        customerId: 'cust-1',
        consumerNo: '09701001',
        customerName: 'Anand Kulkarni',
        invoices: [invoice],
        payments: [payment],
      );

      // Verify customer-level calculations
      expect(hishob.totalAmount, equals(200000.0));
      expect(hishob.totalPaid, equals(80000.0));
      expect(hishob.totalPending, equals(120000.0));
      expect(hishob.paymentStatus, equals('Partially Paid'));
      expect(hishob.isOverpaid, isFalse);

      // Verify invoice-level balance
      final invBal = hishob.invoiceBalances.first;
      expect(invBal.grandTotal, equals(200000.0));
      expect(invBal.totalPaid, equals(80000.0));
      expect(invBal.pendingAmount, equals(120000.0));
      expect(invBal.paymentStatus, equals('Partially Paid'));
    });

    test('2. Margin Receipt Exclusion: Margin receipts are strictly excluded from payments', () {
      final invoice = createSampleInvoice(
        id: 'inv-2',
        invoiceNumber: 'SID000102',
        consumerNo: '09701002',
        customerName: 'Suresh Patil',
        grandTotal: 200000.0,
      );

      final actualPayment = createSamplePayment(
        id: 'pay-2',
        customerId: 'cust-2',
        consumerNo: '09701002',
        amount: 80000.0,
      );

      // Even if a Margin Receipt was generated for loan purposes (e.g., ₹50,000),
      // it is NEVER added to payments list in CustomerHishobEntry.
      // CustomerHishobEntry only receives actual PaymentTransactions.
      final hishob = CustomerHishobEntry.build(
        customerId: 'cust-2',
        consumerNo: '09701002',
        customerName: 'Suresh Patil',
        invoices: [invoice],
        payments: [actualPayment], // Only actual payments passed
      );

      expect(hishob.totalPaid, equals(80000.0));
      expect(hishob.totalPending, equals(120000.0));
    });

    test('3. Quotation Exclusion: Saved quotations without invoices do not count as receivables', () {
      // Customer has a saved quotation but NO invoice has been generated yet.
      final hishob = CustomerHishobEntry.build(
        customerId: 'cust-3',
        consumerNo: '09701003',
        customerName: 'Ramesh Pawar',
        invoices: [], // No invoices generated
        payments: [],
      );

      expect(hishob.totalAmount, equals(0.0));
      expect(hishob.totalPaid, equals(0.0));
      expect(hishob.totalPending, equals(0.0));
      expect(hishob.paymentStatus, equals('No Invoices'));
    });

    test('4. Full Payment: Clearing pending balance updates status to Paid', () {
      final invoice = createSampleInvoice(
        id: 'inv-4',
        invoiceNumber: 'SID000104',
        consumerNo: '09701004',
        customerName: 'Pooja Deshmukh',
        grandTotal: 150000.0,
      );

      final pay1 = createSamplePayment(
        id: 'pay-4a',
        customerId: 'cust-4',
        consumerNo: '09701004',
        amount: 50000.0,
        invoiceNumber: 'SID000104',
      );

      final pay2 = createSamplePayment(
        id: 'pay-4b',
        customerId: 'cust-4',
        consumerNo: '09701004',
        amount: 100000.0,
        invoiceNumber: 'SID000104',
      );

      final hishob = CustomerHishobEntry.build(
        customerId: 'cust-4',
        consumerNo: '09701004',
        customerName: 'Pooja Deshmukh',
        invoices: [invoice],
        payments: [pay1, pay2],
      );

      expect(hishob.totalAmount, equals(150000.0));
      expect(hishob.totalPaid, equals(150000.0));
      expect(hishob.totalPending, equals(0.0));
      expect(hishob.paymentStatus, equals('Paid'));
    });

    test('5. Payment Editing & Deletion Recalculation', () {
      final invoice = createSampleInvoice(
        id: 'inv-5',
        invoiceNumber: 'SID000105',
        consumerNo: '09701005',
        customerName: 'Vikas Shinde',
        grandTotal: 100000.0,
      );

      final originalPayment = createSamplePayment(
        id: 'pay-5',
        customerId: 'cust-5',
        consumerNo: '09701005',
        amount: 40000.0,
      );

      // Initial state
      var hishob = CustomerHishobEntry.build(
        customerId: 'cust-5',
        consumerNo: '09701005',
        customerName: 'Vikas Shinde',
        invoices: [invoice],
        payments: [originalPayment],
      );
      expect(hishob.totalPending, equals(60000.0));

      // After Editing payment from 40k to 70k
      final editedPayment = originalPayment.copyWith(amount: 70000.0);
      hishob = CustomerHishobEntry.build(
        customerId: 'cust-5',
        consumerNo: '09701005',
        customerName: 'Vikas Shinde',
        invoices: [invoice],
        payments: [editedPayment],
      );
      expect(hishob.totalPaid, equals(70000.0));
      expect(hishob.totalPending, equals(30000.0));
      expect(hishob.paymentStatus, equals('Partially Paid'));

      // After Deleting / Cancelling payment (status != 'Valid')
      final deletedPayment = originalPayment.copyWith(status: 'Cancelled');
      hishob = CustomerHishobEntry.build(
        customerId: 'cust-5',
        consumerNo: '09701005',
        customerName: 'Vikas Shinde',
        invoices: [invoice],
        payments: [deletedPayment],
      );
      expect(hishob.totalPaid, equals(0.0));
      expect(hishob.totalPending, equals(100000.0));
      expect(hishob.paymentStatus, equals('Unpaid'));
    });

    test('6. Overpayment Rule: No negative pending balances, flags overpayment for review', () {
      final invoice = createSampleInvoice(
        id: 'inv-6',
        invoiceNumber: 'SID000106',
        consumerNo: '09701006',
        customerName: 'Sunita Joshi',
        grandTotal: 100000.0,
      );

      final overPayment = createSamplePayment(
        id: 'pay-6',
        customerId: 'cust-6',
        consumerNo: '09701006',
        amount: 120000.0,
      );

      final hishob = CustomerHishobEntry.build(
        customerId: 'cust-6',
        consumerNo: '09701006',
        customerName: 'Sunita Joshi',
        invoices: [invoice],
        payments: [overPayment],
      );

      // Must be clamped to 0.0, never -20,000
      expect(hishob.totalPending, equals(0.0));
      expect(hishob.isOverpaid, isTrue);
      expect(hishob.overpaidAmount, equals(20000.0));
      expect(hishob.paymentStatus, equals('Paid'));
    });

    test('7. Multiple Invoices FIFO Allocation for unlinked payments', () {
      final inv1 = createSampleInvoice(
        id: 'inv-7a',
        invoiceNumber: 'SID000107A',
        consumerNo: '09701007',
        customerName: 'Ganesh More',
        grandTotal: 100000.0,
        invoiceDate: DateTime(2026, 9, 1),
      );

      final inv2 = createSampleInvoice(
        id: 'inv-7b',
        invoiceNumber: 'SID000107B',
        consumerNo: '09701007',
        customerName: 'Ganesh More',
        grandTotal: 100000.0,
        invoiceDate: DateTime(2026, 10, 1),
      );

      // Customer makes an unlinked payment of ₹1,40,000
      final generalPayment = createSamplePayment(
        id: 'pay-7',
        customerId: 'cust-7',
        consumerNo: '09701007',
        amount: 140000.0,
        invoiceNumber: null, // General payment
      );

      final hishob = CustomerHishobEntry.build(
        customerId: 'cust-7',
        consumerNo: '09701007',
        customerName: 'Ganesh More',
        invoices: [inv1, inv2],
        payments: [generalPayment],
      );

      expect(hishob.totalAmount, equals(200000.0));
      expect(hishob.totalPaid, equals(140000.0));
      expect(hishob.totalPending, equals(60000.0));

      // Earliest invoice (inv1) is completely paid (₹1,00,000)
      final bal1 = hishob.invoiceBalances.firstWhere((b) => b.invoiceNumber == 'SID000107A');
      expect(bal1.totalPaid, equals(100000.0));
      expect(bal1.pendingAmount, equals(0.0));
      expect(bal1.paymentStatus, equals('Paid'));

      // Later invoice (inv2) receives remaining ₹40,000
      final bal2 = hishob.invoiceBalances.firstWhere((b) => b.invoiceNumber == 'SID000107B');
      expect(bal2.totalPaid, equals(40000.0));
      expect(bal2.pendingAmount, equals(60000.0));
      expect(bal2.paymentStatus, equals('Partially Paid'));
    });

    test('8. Dashboard Metrics: Correctly aggregates total amount, paid, pending, and customer counts', () {
      final cust1 = CustomerHishobEntry.build(
        customerId: 'c-1',
        consumerNo: 'CN-1',
        customerName: 'Customer One',
        invoices: [
          createSampleInvoice(id: 'i-1', invoiceNumber: 'SID-01', consumerNo: 'CN-1', customerName: 'Customer One', grandTotal: 200000.0),
        ],
        payments: [
          createSamplePayment(id: 'p-1', customerId: 'c-1', consumerNo: 'CN-1', amount: 80000.0),
        ],
      );

      final cust2 = CustomerHishobEntry.build(
        customerId: 'c-2',
        consumerNo: 'CN-2',
        customerName: 'Customer Two',
        invoices: [
          createSampleInvoice(id: 'i-2', invoiceNumber: 'SID-02', consumerNo: 'CN-2', customerName: 'Customer Two', grandTotal: 100000.0),
        ],
        payments: [
          createSamplePayment(id: 'p-2', customerId: 'c-2', consumerNo: 'CN-2', amount: 100000.0),
        ],
      );

      final cust3 = CustomerHishobEntry.build(
        customerId: 'c-3',
        consumerNo: 'CN-3',
        customerName: 'Customer Three',
        invoices: [
          createSampleInvoice(id: 'i-3', invoiceNumber: 'SID-03', consumerNo: 'CN-3', customerName: 'Customer Three', grandTotal: 150000.0),
        ],
        payments: [], // Unpaid
      );

      final metrics = CustomerHishobMetrics.fromEntries([cust1, cust2, cust3]);

      // Total Customer Amount = 200,000 + 100,000 + 150,000 = 450,000
      expect(metrics.totalCustomerAmount, equals(450000.0));

      // Total Paid Amount = 80,000 + 100,000 = 180,000
      expect(metrics.totalPaidAmount, equals(180000.0));

      // Total Pending Amount = 450,000 - 180,000 = 270,000
      expect(metrics.totalPendingAmount, equals(270000.0));

      // Customers with pending balance = cust1 (120k) + cust3 (150k) = 2
      expect(metrics.pendingCustomersCount, equals(2));

      // Fully paid customers = cust2 = 1
      expect(metrics.fullyPaidCustomersCount, equals(1));

      // Unpaid customers = cust3 = 1
      expect(metrics.unpaidCustomersCount, equals(1));
    });
  });
}
