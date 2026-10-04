import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

// Ohne diese Option bricht file_picker_web die Auswahl ab, wenn das Fenster
// vor dem change-Event den Fokus zurueckerhaelt (Edge/Chrome).
WebOptions dateiAuswahlWebOptionen() =>
    const FilePickerWebOptions(cancelUploadOnWindowBlur: false);
