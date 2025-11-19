String formatIndianCurrency(double amount, {bool withSymbol = false}) {
  final isNegative = amount < 0;
  final absAmount = amount.abs();

  // Split into integer and decimal parts
  final parts = absAmount.toStringAsFixed(2).split('.');
  String integerPart = parts[0];
  final decimalPart = parts[1];

  // Format integer part with Indian grouping
  if (integerPart.length > 3) {
    final lastThree = integerPart.substring(integerPart.length - 3);
    final remaining = integerPart.substring(0, integerPart.length - 3);

    // Add commas for every 2 digits in the remaining part
    String formatted = '';
    for (int i = remaining.length - 1; i >= 0; i--) {
      formatted = remaining[i] + formatted;
      if ((remaining.length - i) % 2 == 0 && i != 0) {
        formatted = ',' + formatted;
      }
    }
    integerPart = '$formatted,$lastThree';
  }

  final formattedAmount = '$integerPart.$decimalPart';
  final sign = isNegative ? '-' : '';
  final symbol = withSymbol ? '₹' : '';

  return '$sign$symbol$formattedAmount';
}
