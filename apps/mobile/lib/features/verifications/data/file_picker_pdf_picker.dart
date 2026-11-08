import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/pdf_picker.dart';

class FilePickerPdfPicker implements PdfPicker {
  @override
  Future<PickedPdf?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;
    var path = file.path;
    var size = await file.length();
    if (path == null) {
      // Non-file URIs (e.g. content providers): copy to a temp file so Dio
      // can stream it.
      final bytes = await file.readAsBytes();
      final dir = await getTemporaryDirectory();
      final copy = File(p.join(dir.path, 'statement_upload.pdf'));
      await copy.writeAsBytes(bytes, flush: true);
      path = copy.path;
      size = bytes.length;
    }
    return PickedPdf(name: file.name, path: path, sizeBytes: size ?? 0);
  }
}
