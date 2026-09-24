import 'dart:typed_data';

import 'web_file_utils_stub.dart'
    if (dart.library.html) 'web_file_utils_web.dart';

class WebFileUtils {
  static Future<({String name, Uint8List bytes})?> pickImageOrPdf() async =>
      WebFilePlatformUtils.pickImageOrPdf();

  static Future<void> downloadCsv(String csvContent, String fileName) async =>
      WebFilePlatformUtils.downloadCsv(csvContent, fileName);
}
