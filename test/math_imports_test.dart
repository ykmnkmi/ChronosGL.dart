@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test('public math imports compile and run as a standalone VM program', () async {
    final coreUri = await Isolate.resolvePackageUri(
      Uri.parse('package:chronosgl/core.dart'),
    );
    expect(coreUri, isNotNull);
    final packageRoot = coreUri!.resolve('../');
    final fixture = packageRoot.resolve('test/support/math_imports.dart');
    final packages = packageRoot.resolve('.dart_tool/package_config.json');
    final temporary = await Directory.systemTemp.createTemp('chronosgl_math_');
    addTearDown(() => temporary.delete(recursive: true));
    final kernel = File.fromUri(temporary.uri.resolve('math_imports.dill'));

    // The VM compiler must accept the complete import/export graph, even for
    // unused declarations. Transitive browser dependencies fail compilation.
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      '--packages=${packages.toFilePath()}',
      '--output=${kernel.path}',
      fixture.toFilePath(),
    ], workingDirectory: packageRoot.toFilePath());
    expect(
      compilation.exitCode,
      0,
      reason:
          'VM compilation failed:\n${compilation.stdout}\n${compilation.stderr}',
    );

    final execution = await Process.run(Platform.resolvedExecutable, [
      kernel.path,
    ], workingDirectory: packageRoot.toFilePath());
    expect(
      execution.exitCode,
      0,
      reason: 'VM execution failed:\n${execution.stdout}\n${execution.stderr}',
    );
    expect((execution.stdout as String).trim(), 'VM math imports OK');
  });
}
