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

  static const List<String> _marathiUnits = [
    '', 'एक', 'दोन', 'तीन', 'चार', 'पाच', 'सहा', 'सात', 'आठ', 'नऊ', 'दहा',
    'अकरा', 'बारा', 'तेरा', 'चौदा', 'पंधरा', 'सोळा', 'सतरा', 'अठरा', 'एकोणीस', 'वीस',
    'एकवीस', 'बावीस', 'तेवीस', 'चोवीस', 'पंचवीस', 'सव्वीस', 'सत्तावीस', 'अठ्ठावीस', 'एकोणतीस', 'तीस',
    'एकतीस', 'बत्तीस', 'तेहत्तीस', 'चौतीस', 'पस्तीस', 'छत्तीस', 'सदतीस', 'अडतीस', 'एकोणचाळीस', 'चाळीस',
    'एकेचाळीस', 'बेचाळीस', 'त्रेचाळीस', 'चव्वेचाळीस', 'पंचेचाळीस', 'शेहेचाळीस', 'सत्तेचाळीस', 'अठ्ठेचाळीस', 'एकोणपन्नास', 'पन्नास',
    'एकावन्न', 'बावन्न', 'त्रेपन्न', 'चौपन्न', 'पंचावन्न', 'छप्पन्न', 'सत्तावन्न', 'अठ्ठावन्न', 'एकोणसाठ', 'साठ',
    'एकसष्ठ', 'बासष्ठ', 'त्रेसष्ठ', 'चौसष्ठ', 'पासष्ठ', 'सहासष्ठ', 'सदुसष्ठ', 'अडुसष्ठ', 'एकोणसत्तर', 'सत्तर',
    'एकाहत्तर', 'बाहत्तर', 'त्र्याहत्तर', 'चौऱ्याहत्तर', 'पंचाहत्तर', 'शहात्तर', 'सत्त्याहत्तर', 'अठ्ठ्याहत्तर', 'एकोणऐंशी', 'ऐंशी',
    'एक्याऐंशी', 'ब्याऐंशी', 'त्र्याऐंशी', 'चौऱ्याऐंशी', 'पंच्याऐंशी', 'शहाऐंशी', 'सत्त्याऐंशी', 'अठ्ठ्याऐंशी', 'एकोणनव्वद', 'नव्वद',
    'एक्याण्णव', 'ब्याण्णव', 'त्र्याण्णव', 'चौऱ्याण्णव', 'पंच्याण्णव', 'शहाण्णव', 'सत्त्याण्णव', 'अठ्ठ्याण्णव', 'नव्व्याण्णव'
  ];

  /// Convert a number to Marathi currency words
  /// Example: 160000 -> "रुपये एक लाख साठ हजार फक्त"
  static String convertToMarathiRupees(double amount) {
    if (amount.isNaN || amount.isInfinite) return 'रुपये शून्य फक्त';

    final int rupees = amount.floor();
    final int paise = ((amount - rupees) * 100).round();

    if (rupees == 0 && paise == 0) {
      return 'रुपये शून्य फक्त';
    }

    final String words = _convertMarathiNumber(rupees).trim();
    final buffer = StringBuffer('रुपये ');
    if (words.isNotEmpty) {
      buffer.write(words);
    } else {
      buffer.write('शून्य');
    }

    if (paise > 0) {
      final String paiseWords = _convertMarathiNumber(paise).trim();
      buffer.write(' आणि $paiseWords पैसे');
    }

    buffer.write(' फक्त');
    return buffer.toString();
  }

  static String _convertMarathiNumber(int n) {
    if (n < 0) {
      return 'उणे ${_convertMarathiNumber(-n)}';
    }
    if (n == 0) {
      return '';
    }

    if (n < 100) {
      return _marathiUnits[n];
    }

    if (n < 1000) {
      final int hundreds = n ~/ 100;
      final int rem = n % 100;
      final prefix = hundreds == 1 ? 'एकशे' : '${_marathiUnits[hundreds]} शे';
      return '$prefix${rem > 0 ? " ${_convertMarathiNumber(rem)}" : ""}';
    }

    // Thousands (up to 99 thousand)
    if (n < 100000) {
      final int thousands = n ~/ 1000;
      final int rem = n % 1000;
      return '${_marathiUnits[thousands]} हजार${rem > 0 ? " ${_convertMarathiNumber(rem)}" : ""}';
    }

    // Lakhs (up to 99 Lakh)
    if (n < 10000000) {
      final int lakhs = n ~/ 100000;
      final int rem = n % 100000;
      return '${_marathiUnits[lakhs]} लाख${rem > 0 ? " ${_convertMarathiNumber(rem)}" : ""}';
    }

    // Crores
    final int crores = n ~/ 10000000;
    final int rem = n % 10000000;
    return '${_convertMarathiNumber(crores)} कोटी${rem > 0 ? " ${_convertMarathiNumber(rem)}" : ""}';
  }

  /// Converts based on selected language ('mr_en', 'en', 'mr')
  static String convertToBilingualRupees(double amount, {String language = 'mr_en'}) {
    final en = convertToIndianRupees(amount);
    final mr = convertToMarathiRupees(amount);

    if (language == 'mr') {
      return mr;
    } else if (language == 'en') {
      return en;
    } else {
      // Marathi + English Mix
      return '$en / $mr';
    }
  }
}
