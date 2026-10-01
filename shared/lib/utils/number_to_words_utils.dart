class NumberToWordsUtils {
  static const List<String> _units = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  /// Convert a number to Indian currency words
  /// Example: 160000 -> "Rupees One Lakh Sixty Thousand Only"
  static String convertToIndianRupees(double amount) {
    if (amount.isNaN || amount.isInfinite) return 'Rupees Zero Only';

    final int rupees = amount.floor();
    final int paise = ((amount - rupees) * 100).round();

    if (rupees == 0 && paise == 0) {
      return 'Rupees Zero Only';
    }

    final String words = _convertNumber(rupees).trim();
    final buffer = StringBuffer('Rupees ');
    if (words.isNotEmpty) {
      buffer.write(words);
    } else {
      buffer.write('Zero');
    }

    if (paise > 0) {
      final String paiseWords = _convertNumber(paise).trim();
      buffer.write(' and $paiseWords Paise');
    }

    buffer.write(' Only');
    return buffer.toString();
  }

  static String _convertNumber(int n) {
    if (n < 0) {
      return 'Minus ${_convertNumber(-n)}';
    }
    if (n == 0) {
      return '';
    }

    if (n < 20) {
      return _units[n];
    }

    if (n < 100) {
      final int rem = n % 10;
      return '${_tens[n ~/ 10]}${rem > 0 ? " ${_units[rem]}" : ""}';
    }

    if (n < 1000) {
      final int rem = n % 100;
      return '${_units[n ~/ 100]} Hundred${rem > 0 ? " ${_convertNumber(rem)}" : ""}';
    }

    // Thousands (up to 99 thousand)
    if (n < 100000) {
      final int rem = n % 1000;
      return '${_convertNumber(n ~/ 1000)} Thousand${rem > 0 ? " ${_convertNumber(rem)}" : ""}';
    }

    // Lakhs (up to 99 Lakh)
    if (n < 10000000) {
      final int rem = n % 100000;
      return '${_convertNumber(n ~/ 100000)} Lakh${rem > 0 ? " ${_convertNumber(rem)}" : ""}';
    }

    // Crores
    final int rem = n % 10000000;
    return '${_convertNumber(n ~/ 10000000)} Crore${rem > 0 ? " ${_convertNumber(rem)}" : ""}';
  }
}
