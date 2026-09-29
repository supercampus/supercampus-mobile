import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// Web picker options that never drop a chosen file.
///
/// By default file_picker_web treats the window regaining focus as a cancel
/// and resolves `null` if the input's `change` event has not arrived within
/// 500 ms. The browser fires focus first, and a PDF opened from a cloud drive
/// or a slow disk routinely takes longer than that, so the pick came back
/// empty and the attachment silently never uploaded. Browsers that fire the
/// input's own `cancel` event (all current ones) still report a real cancel.
const WebOptions reliableWebPickerOptions = FilePickerWebOptions(
  cancelUploadOnWindowBlur: false,
);
