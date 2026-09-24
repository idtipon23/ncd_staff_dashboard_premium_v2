import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class WebFilePlatformUtils {
  static Future<({String name, Uint8List bytes})?> pickImageOrPdf() async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*,.pdf';
    uploadInput.click();

    final completer = Completer<({String name, Uint8List bytes})?>();
    uploadInput.onChange.listen((_) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        final bytes = result is ByteBuffer ? result.asUint8List() : Uint8List(0);
        completer.complete((name: file.name, bytes: bytes));
      });
    });

    return completer.future;
  }

  static Future<void> downloadCsv(String csvContent, String fileName) async {
    final fullCsv = csvContent.startsWith('\uFEFF') ? csvContent : '\uFEFF$csvContent';
    final bytes = utf8.encode(fullCsv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
