/// Commission Payment Transaction Record
/// 
/// Strictly tracks commission payouts made to agents.
/// Margin receipts and loan documents are NOT treated as commission payments.
class CommissionPayment {
  final String id;
  final String commissionId;
  final DateTime paymentDate;
  final double amount;
  final String paymentMode; // 'Bank Transfer', 'UPI', 'Cash', 'Cheque'
  final String? referenceNumber;
  final String? bankName;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  const CommissionPayment({
    required this.id,
    required this.commissionId,
    required this.paymentDate,
    required this.amount,
    this.paymentMode = 'Bank Transfer',
    this.referenceNumber,
    this.bankName,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commission_id': commissionId,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      'amount': amount,
      'payment_mode': paymentMode,
      'reference_number': referenceNumber,
      'bank_name': bankName,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory CommissionPayment.fromJson(Map<String, dynamic> json) {
    return CommissionPayment(
      id: json['id']?.toString() ?? '',
      commissionId: json['commission_id']?.toString() ?? '',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : (double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0),
      paymentMode: json['payment_mode']?.toString() ?? 'Bank Transfer',
      referenceNumber: json['reference_number']?.toString(),
      bankName: json['bank_name']?.toString(),
      notes: json['notes']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
