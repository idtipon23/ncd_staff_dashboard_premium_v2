import 'dart:typed_data';

class WebFilePlatformUtils {
  static Future<({String name, Uint8List bytes})?> pickImageOrPdf() async => null;

  static Future<void> downloadCsv(String csvContent, String fileName) async {
    // no-op for non-web targets
  }
}
