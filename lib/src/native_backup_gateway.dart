import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'backup.dart';

/// The platform side of export and restore: native save/pick dialogs and local
/// file I/O only. The picker is where the user chooses the location; the app
/// neither uploads nor shares the file, and this adapter never makes a network
/// call.
class NativeBackupGateway implements BackupGateway {
  const NativeBackupGateway();

  @override
  Future<String?> save(String suggestedName, String contents) async {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save your Moonpetal backup',
        fileName: suggestedName,
        mimeType: 'application/json',
        bytes: utf8.encode(contents),
      );
      if (uri == null) return null;
      return uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last;
    } catch (error) {
      throw BackupException('The backup could not be saved: $error');
    }
  }

  @override
  Future<PickedBackup?> load() async {
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return null;
      final file = files.first;
      return PickedBackup(
        name: file.name,
        contents: utf8.decode(await file.readAsBytes()),
      );
    } catch (error) {
      throw BackupException('The file could not be read: $error');
    }
  }
}
