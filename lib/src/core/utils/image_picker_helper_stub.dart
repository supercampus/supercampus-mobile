import 'package:file_picker/file_picker.dart';

import 'image_picker_helper.dart';

Future<PickedImage?> pickImageFile({String? dialogTitle}) async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      dialogTitle: dialogTitle,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedImage(bytes: bytes, name: file.name);
  } catch (_) {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
        dialogTitle: dialogTitle,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return PickedImage(bytes: bytes, name: file.name);
    } catch (_) {
      return null;
    }
  }
}
