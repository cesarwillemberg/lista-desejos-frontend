String formatMoney(double value, String? currency) {
  final code = (currency ?? '').toUpperCase();
  switch (code) {
    case 'BRL':
      return 'R\$ ${_group(value, thousands: '.', decimal: ',')}';
    case 'EUR':
      return '€ ${_group(value, thousands: '.', decimal: ',')}';
    case 'USD':
      return 'US\$ ${_group(value, thousands: ',', decimal: '.')}';
    case 'GBP':
      return '£ ${_group(value, thousands: ',', decimal: '.')}';
    case '':
      return _group(value, thousands: '.', decimal: ',');
    default:
      return '$code ${_group(value, thousands: ',', decimal: '.')}';
  }
}

double? parseUserPrice(String input) {
  final match = RegExp(r'\d[\d\.,]*').firstMatch(input.trim());
  if (match == null) return null;
  var token = match.group(0)!;
  if (token.endsWith('.') || token.endsWith(',')) {
    token = token.substring(0, token.length - 1);
  }
  if (token.contains(',') && token.contains('.')) {
    if (token.lastIndexOf(',') > token.lastIndexOf('.')) {
      token = token.replaceAll('.', '').replaceAll(',', '.');
    } else {
      token = token.replaceAll(',', '');
    }
  } else if (token.contains(',')) {
    final bits = token.split(',');
    if (bits.last.length <= 2) {
      token = '${bits.sublist(0, bits.length - 1).join().replaceAll('.', '')}.${bits.last}';
    } else {
      token = token.replaceAll(',', '');
    }
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(token)) {
    token = token.replaceAll('.', '');
  }
  final value = double.tryParse(token);
  if (value == null || value < 0) return null;
  return value;
}

String _group(double value, {required String thousands, required String decimal}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(thousands);
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer$decimal${parts[1]}';
}
