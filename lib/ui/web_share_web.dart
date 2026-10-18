import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> shareText(String text) async {
  try {
    await web.window.navigator.share(web.ShareData(text: text)).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
