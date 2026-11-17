@TestOn('vm')
library;

import 'dart:io';

import 'package:chronosgl/core.dart';
import 'package:test/test.dart';

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

Iterable<Uri> _dependencies(File file) sync* {
  for (final match in _directive.allMatches(file.readAsStringSync())) {
    final uri = Uri.parse(match[1]!);
    yield uri.hasScheme ? uri : file.absolute.uri.resolveUri(uri);
  }
}

void main() {
  test(
    'Immutable colors and independent vector adapters are usable on the VM',
    () {
      final first = colorWhite.toVector3();
      final second = colorWhite.toVector3();
      first.storage.fillRange(0, 3, 0);

      expect(second.storage, [1, 1, 1]);
      expect(colorWhite, const Color(1, 1, 1));
      expect(colorWhite.copyWith(r: 0, b: 0), colorGreen);
      expect(const Color(2, -1, 0.5).toVector3().storage, [2, -1, 0.5]);
      expect(() => (colorWhite as dynamic).g = 0.0, throwsNoSuchMethodError);
    },
  );

  test('Library sources never import demo code', () {
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final dependency in _dependencies(file)) {
        expect(
          dependency.pathSegments,
          isNot(contains('example')),
          reason: '${file.path} depends on $dependency',
        );
      }
    }
  });

  test('Shadow computation has no transitive diagnostics or browser helper dependency', () {
    final pending = <Uri>[File('lib/shadows.dart').absolute.uri];
    final visited = <Uri>{};
    while (pending.isNotEmpty) {
      final uri = pending.removeLast();
      if (!visited.add(uri)) continue;
      expect(uri.pathSegments, isNot(contains('diagnostics')), reason: '$uri');
      expect(uri.pathSegments, isNot(contains('webhelper')), reason: '$uri');
      expect(uri.pathSegments, isNot(contains('misc')), reason: '$uri');
      for (final dependency in _dependencies(File.fromUri(uri))) {
        if (dependency.scheme == 'file') pending.add(dependency);
        if (dependency.scheme == 'package' &&
            dependency.pathSegments.first == 'chronosgl') {
          pending.add(
            Uri.directory('${Directory.current.path}/lib/')
                .resolve(dependency.pathSegments.skip(1).join('/')),
          );
        }
      }
    }
  });
}
