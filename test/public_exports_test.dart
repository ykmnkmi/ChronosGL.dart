@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'aggregate exports supported modules and excludes implementation details',
    () async {
      // Place the fixture inside the package so the analyzer resolves the same
      // package configuration and browser SDK libraries as a consuming project.
      final temporary = await Directory('.dart_tool')
          .createTemp('public_exports_');
      addTearDown(() => temporary.delete(recursive: true));
      final fixture = File('${temporary.path}/imports.dart');
      const hidden = [
        'MidiInput',
        'findBridge',
        'UnknownEntity',
        'kUnknownEntity',
        'Face1',
        'Face2',
        'Edge3',
        'hashVector3',
        'drawRecursively',
        'extractWireframe',
        'StatsPanel',
        'ShadowMapVisualizer',
        'getOrthogonalVector3',
        'icosahedronFaceList',
        'rightX',
        'prefixUniform',
      ];
      const supported = [
        'Transform',
        'PerspectiveCamera',
        'GeometryBuilder',
        'Bone',
        'importGeometryFromWavefront',
        'ShaderStage',
        'UniformKey',
        'UniformKeys',
        'ChronosGL',
        'glTriangles',
        'RenderProgram',
        'MeshNode',
        'RenderPass',
        'ShadowMap',
        'CanvasViewport',
        'coneGeometryWireframeFriendly',
      ];
      final lines = [
        "import 'package:chronosgl/chronosgl.dart' as api;",
        'void main() {',
        for (final name in supported) '  api.$name;',
        for (final name in hidden) '  api.$name;',
        '}',
      ];
      await fixture.writeAsString(lines.join('\n'));
      final analysis = await Process.run(Platform.resolvedExecutable, [
        'analyze',
        '--format=machine',
        fixture.path,
      ]);
      final output = '${analysis.stdout}\n${analysis.stderr}';
      expect(analysis.exitCode, 3, reason: output);
      final errors = output
          .split('\n')
          .where((line) => line.startsWith('ERROR|'))
          .toList();
      expect(errors, hasLength(hidden.length), reason: output);
      for (var index = 0; index < hidden.length; index++) {
        final lineNumber = 3 + supported.length + index;
        expect(
          errors.where((line) => line.split('|')[4] == '$lineNumber'),
          hasLength(1),
          reason: '${hidden[index]} unexpectedly exported:\n$output',
        );
      }
    },
  );
}
