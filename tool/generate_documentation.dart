import 'dart:io';

List<String> kDirs = [
  "lib/src/core/lib.dart",
  "lib/src/core",
  "lib/src/scene/lib.dart",
  "lib/src/scene",
  "lib/src/shader/lib.dart",
  "lib/src/shader",
  "lib/src/shape/lib.dart",
  "lib/src/shape",
  "lib/src/animation/lib.dart",
  "lib/src/animation",
  "lib/src/importer/lib.dart",
  "lib/src/importer",
  "lib/src/webhelper/lib.dart",
  "lib/src/webhelper",
  "lib/src/polygon/lib.dart",
  "lib/src/polygon",
  "lib/src/misc/lib.dart",
  "lib/src/misc",
];

final Set<String> gAlreadyProcessed = <String>{};

void maybeEmitDocumentation(List<String> commentBlock, String line) {
  if (commentBlock[0].startsWith("#")) {
    for (String line in commentBlock) {
      print(line);
    }
    print("");
  } else if (line.startsWith("class") || line.startsWith("abstract")) {
    print("## ${line.substring(0, line.length - 1)}");
    for (String line in commentBlock) {
      print(line);
    }
    print("");
  }
}

void extractDoc(File file) {
  List<String> commentBlock = <String>[];

  if (gAlreadyProcessed.contains(file.path)) return;
  gAlreadyProcessed.add(file.path);
  for (String line in file.readAsLinesSync()) {
    if (!line.startsWith("///")) {
      if (commentBlock.isNotEmpty) {
        maybeEmitDocumentation(commentBlock, line);
        commentBlock.clear();
      }
      continue;
    }
    if (line.length < 4) {
      commentBlock.add("");
    } else {
      commentBlock.add(line.substring(4));
    }
  }

  if (commentBlock.isNotEmpty) {
    maybeEmitDocumentation(commentBlock, "");
  }
}

void main(List<String> args) {
  if (args.isEmpty) {
    args = kDirs;
  }

  for (String d in args) {
    if (FileSystemEntity.isDirectorySync(d)) {
      var dir = Directory(d);
      List<FileSystemEntity> content = dir.listSync(
        recursive: true,
        followLinks: false,
      );
      for (FileSystemEntity f in content) {
        if (f is File) {
          extractDoc(f);
        }
      }
    } else if (FileSystemEntity.isFileSync(d)) {
      extractDoc(File(d));
    }
  }
}
