import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'file_selection_helper.dart';

class FileSelectionHelper {
  const FileSelectionHelper();

  static Future<PickedFile?> pickImageOrPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result.isEmpty) {
      return null;
    }
    final file = result.first;
    final bytes = await file.readAsBytes();
    return (name: file.name, bytes: bytes);
  }

  static Future<void> saveCsv(String csvContent, String fileName) async {
    final file = File(fileName);
    await file.writeAsString(csvContent, encoding: utf8);
  }
}
