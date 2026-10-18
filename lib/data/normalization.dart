import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Shared build-time/runtime normalization for Arabic-script search.
class DictionaryNormalization {
  static const Map<String, String> letters = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ي': 'ی',
    'ى': 'ی',
    'ې': 'ی',
    'ے': 'ی',
    'ۓ': 'ی',
    'ئ': 'ی',
    'ك': 'ک',
    'ه': 'ه',
    'ہ': 'ه',
    'ھ': 'ه',
    'ة': 'ه',
    'ۃ': 'ه',
    'ؤ': 'و',
    'ں': 'ن',
  };
  static const Map<String, String> looseLetters = {
    'ٹ': 'ت',
    'ڈ': 'د',
    'ڑ': 'ر',
    'چ': 'ج',
    'ژ': 'ز',
    'ث': 'س',
    'ص': 'س',
    'ذ': 'ز',
    'ض': 'ز',
    'ظ': 'ز',
    'ط': 'ت',
  };
  static String normalize(String? input, {bool loose = false}) {
    var s = unorm.nfkc(input ?? '').toLowerCase();
    final out = StringBuffer();
    for (final r in s.runes) {
      if ((r >= 0x064b && r <= 0x065f) ||
          r == 0x0670 ||
          (r >= 0x06d6 && r <= 0x06ed) ||
          r == 0x0640 ||
          (r >= 0x200c && r <= 0x200f))
        continue;
      var c = String.fromCharCode(r);
      final digit = _digit(c);
      if (digit != null) c = digit;
      c = letters[c] ?? c;
      if (loose) c = looseLetters[c] ?? c;
      out.write(c);
    }
    return out
        .toString()
        .replaceAll(RegExp(r'[/،۔.,()\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _digit(String c) {
    const arabic = '٠١٢٣٤٥٦٧٨٩', persian = '۰۱۲۳۴۵۶۷۸۹';
    final a = arabic.indexOf(c), p = persian.indexOf(c);
    if (a >= 0) return '$a';
    if (p >= 0) return '$p';
    return null;
  }

  static List<String> glosses(String value, {bool english = false}) => value
      .split(RegExp(r'[۔،؛;,/\n]'))
      .map((g) {
        var s = normalize(g);
        if (english) s = s.replaceFirst(RegExp(r'^(to|a|an|the) '), '');
        return s;
      })
      .where((g) => g.isNotEmpty)
      .toList();
}
