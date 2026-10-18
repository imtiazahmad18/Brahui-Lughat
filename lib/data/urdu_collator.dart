class UrduCollator {
  static const alphabet =
      'ا آ ب پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل م ن و ہ ھ ی ے';
  static final _order = <int, int>{
    for (var i = 0; i < alphabet.split(' ').length; i++)
      alphabet.split(' ')[i].runes.first: i,
  };
  static int compare(String a, String b) {
    final x = a.runes.toList(), y = b.runes.toList();
    for (var i = 0; i < x.length && i < y.length; i++) {
      final xi = _order[x[i]] ?? (1000 + x[i]);
      final yi = _order[y[i]] ?? (1000 + y[i]);
      if (xi != yi) return xi.compareTo(yi);
    }
    return x.length.compareTo(y.length);
  }
}
