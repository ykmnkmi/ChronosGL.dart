import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Runs in a VM isolate: browser tests never need direct filesystem access.
Future<void> hybridMain(StreamChannel<Object?> channel, Object? message) async {
  final name = message as String;
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name) ||
      !File('pubspec.yaml').existsSync()) {
    throw ArgumentError('Run golden tests from the package root');
  }
  final update = Platform.environment['CHRONOSGL_UPDATE_GOLDENS'] == '1';
  if (update && Platform.environment['CI'] == 'true') {
    throw StateError(
      'CI checks goldens; update them locally and review the PNGs',
    );
  }
  final baseline = File('test/goldens/$name.png');
  final artifacts = Directory('build/golden_failures/$name');
  final manifest = File('test/goldens/environment.json');
  channel.sink.add({
    'update': update,
    'mutate': Platform.environment['CHRONOSGL_GOLDEN_SELF_CHECK'] == '1',
    'expected': baseline.existsSync()
        ? base64Encode(await baseline.readAsBytes())
        : null,
    'environment': manifest.existsSync()
        ? jsonDecode(await manifest.readAsString())
        : null,
    'operatingSystem': Platform.operatingSystem,
  });

  try {
    final result = Map<String, dynamic>.from(await channel.stream.first as Map);
    final status = result['status'] as String;
    if (status == 'updated') {
      if (!update) throw StateError('Updating goldens requires --update');
      await baseline.parent.create(recursive: true);
      await baseline.writeAsBytes(base64Decode(result['actual'] as String));
      final environment =
          Map<String, dynamic>.from(result['environment'] as Map)
            ..['operatingSystem'] = Platform.operatingSystem
            ..['dartVersion'] = Platform.version.split(' ').first;
      await manifest.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(environment)}\n',
      );
      await _clearArtifacts(artifacts);
    } else if (status == 'matched') {
      await _clearArtifacts(artifacts);
    } else if (status == 'mismatch' || status == 'missing') {
      await artifacts.create(recursive: true);
      // Remove only the known files from this test's previous failure.
      await _clearArtifacts(artifacts);
      for (final kind in ['actual', 'expected', 'diff']) {
        final png = result[kind] as String?;
        if (png != null) {
          await File('${artifacts.path}/$kind.png')
              .writeAsBytes(base64Decode(png));
        }
      }
      await File('${artifacts.path}/result.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(result['summary'])}\n',
      );
    } else {
      throw ArgumentError.value(status, 'status');
    }
    channel.sink.add({'saved': true});
  } finally {
    await channel.sink.close();
  }
}

Future<void> _clearArtifacts(Directory artifacts) async {
  for (final name in [
    'actual.png',
    'expected.png',
    'diff.png',
    'result.json',
  ]) {
    final file = File('${artifacts.path}/$name');
    if (file.existsSync()) await file.delete();
  }
}
