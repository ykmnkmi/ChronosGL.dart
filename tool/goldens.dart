import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.any(
        (arg) => !['--update', '--self-check', '--help'].contains(arg),
      ) ||
      (arguments.contains('--update') && arguments.contains('--self-check'))) {
    stderr.writeln('Use --update, --self-check, or no arguments.');
    exitCode = 64;
    return;
  }
  if (arguments.contains('--help')) {
    print(
      'dart run tool/goldens.dart              Compare with committed PNGs\n'
      'dart run tool/goldens.dart --update     Write PNGs for visual review\n'
      'dart run tool/goldens.dart --self-check Verify intentional color regression',
    );
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent;
  final selfCheck = arguments.contains('--self-check');
  final update = arguments.contains('--update');
  final artifacts = Directory('${root.path}/build/golden_failures/geometry');
  if (update && Platform.environment['CI'] == 'true') {
    stderr.writeln(
      'CI cannot update reference images. Review updates locally.',
    );
    exitCode = 64;
    return;
  }
  if (selfCheck) {
    for (final name in [
      'expected.png',
      'actual.png',
      'diff.png',
      'result.json',
    ]) {
      final file = File('${artifacts.path}/$name');
      if (file.existsSync()) await file.delete();
    }
  }
  final testArguments = [
    'test',
    '-P',
    'goldens',
    '--reporter',
    'expanded',
    if (selfCheck) ...['--name', r'^golden geometry$'],
  ];
  final process = await Process.start(
    Platform.resolvedExecutable,
    testArguments,
    workingDirectory: root.path,
    environment: {
      'CHRONOSGL_UPDATE_GOLDENS': update ? '1' : '0',
      'CHRONOSGL_GOLDEN_SELF_CHECK': selfCheck ? '1' : '0',
    },
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  final result = await process.exitCode;
  if (!selfCheck) {
    exitCode = result;
    return;
  }
  final summary = File('${artifacts.path}/result.json');
  final hasImages = [
    'expected',
    'actual',
    'diff',
  ].every((name) => File('${artifacts.path}/$name.png').existsSync());
  final mismatch = summary.existsSync()
      ? jsonDecode(await summary.readAsString()) as Map
      : <String, Object?>{};
  if (result == 1 &&
      hasImages &&
      (mismatch['differentPixels'] as int? ?? 0) > 0) {
    print(
      'Self-check passed: an intentional color change failed the golden test '
      'and produced expected.png, actual.png, diff.png.',
    );
  } else {
    stderr.writeln(
      'Self-check failed: expected a rendered color mismatch and PNG artifacts.',
    );
    exitCode = 1;
  }
}
