import 'dart:typed_data';

import 'package:archive/archive.dart';

class FileToolsService {
  Uint8List createZip(List<({String name, Uint8List bytes})> files) {
    if (files.isEmpty) throw ArgumentError('Choose at least one file to zip.');
    final archive = Archive();
    final usedNames = <String>{};
    for (final file in files) {
      final safeName = _uniqueName(_safeName(file.name), usedNames);
      archive.addFile(ArchiveFile(safeName, file.bytes.length, file.bytes));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty) {
      throw StateError('Could not create the ZIP archive.');
    }
    return Uint8List.fromList(encoded);
  }

  String _safeName(String name) {
    final leaf = name.replaceAll('\\', '/').split('/').last.trim();
    if (leaf.isEmpty || leaf == '.' || leaf == '..') return 'file';
    return leaf.replaceAll(RegExp(r'[\x00-\x1f]'), '_');
  }

  String _uniqueName(String name, Set<String> used) {
    if (used.add(name)) return name;
    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    final extension = dot <= 0 ? '' : name.substring(dot);
    var index = 2;
    while (!used.add('$stem-$index$extension')) {
      index++;
    }
    return '$stem-$index$extension';
  }
}

