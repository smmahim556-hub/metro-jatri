const _digits = '০১২৩৪৫৬৭৮৯';

/// Converts Latin digits in [value] to Bangla digits.
String bn(Object value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\d'), (m) => _digits[int.parse(m[0]!)]);
