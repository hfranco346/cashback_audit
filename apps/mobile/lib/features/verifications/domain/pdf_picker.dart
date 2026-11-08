class PickedPdf {
  const PickedPdf({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final int sizeBytes;
}

/// Port to the platform file picker (PDF only).
abstract class PdfPicker {
  /// Returns `null` when the user cancels.
  Future<PickedPdf?> pick();
}
