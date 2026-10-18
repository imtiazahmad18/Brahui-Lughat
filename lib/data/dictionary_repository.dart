import 'dart:convert';

/// Converts the bundled, migrated JSON into maps ready for the domain model.
/// The Flutter layer is responsible for opening the asset so this remains pure Dart.
class DictionaryRepository {
  static List<Map<String, dynamic>> decodeRows(String encodedJson) =>
      (jsonDecode(encodedJson) as List).cast<Map<String, dynamic>>();
}
