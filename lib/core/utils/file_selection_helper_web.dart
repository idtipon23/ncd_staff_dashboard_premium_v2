import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'file_selection_helper.dart';

class FileSelectionHelper {
  const FileSelectionHelper();

  static Future<PickedFile?> pickImageOrPdf() async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*,.pdf';
    uploadInput.click();

    final completer = Completer<PickedFile?>();
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
        final data = reader.result;
        final bytes = data is ByteBuffer
            ? data.asUint8List()
            : Uint8List(0);
        completer.complete((name: file.name, bytes: bytes));
      });
    });

    return completer.future;
  }

  static Future<void> saveCsv(String csvContent, String fileName) async {
    final bom = '\uFEFF';
    final fullCsv = csvContent.startsWith(bom) ? csvContent : bom + csvContent;
    final bytes = utf8.encode(fullCsv);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
