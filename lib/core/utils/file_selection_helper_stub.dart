import 'file_selection_helper.dart';

class FileSelectionHelper {
  const FileSelectionHelper();

  static Future<PickedFile?> pickImageOrPdf() async => null;

  static Future<void> saveCsv(String csvContent, String fileName) async {
    // Non-web and non-IO targets do not support direct browser download or file export.
    // The app can ignore these actions during VM/test execution.
    return;
  }
}
