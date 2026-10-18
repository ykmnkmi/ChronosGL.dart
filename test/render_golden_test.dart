@TestOn('golden_chrome')
library;

import 'package:test/test.dart';

import 'support/golden_matcher.dart';
import 'support/golden_scenes.dart';

void main() {
  for (final name in goldenSceneNames) {
    test('golden $name', () async {
      final session = await GoldenSession.open(name);
      final scene = GoldenScene(name, mutate: session.mutate);
      addTearDown(scene.dispose);
      final environment = scene.environment;
      expect(
        environment['renderer'].toString(),
        contains('SwiftShader'),
        reason: 'Run dart run tool/goldens.dart to use the software renderer',
      );
      final image = scene.render();
      var foregroundPixels = 0;
      for (var offset = 0; offset < image.rgba.length; offset += 4) {
        if (image.rgba[offset] != 0 ||
            image.rgba[offset + 1] != 0 ||
            image.rgba[offset + 2] != 0)
          foregroundPixels++;
      }
      expect(
        foregroundPixels,
        greaterThan(500),
        reason: 'Scene must not be blank',
      );
      expect(
        foregroundPixels,
        lessThan(GoldenScene.size * GoldenScene.size - 500),
        reason: 'Scene must retain a background border',
      );
      for (var frame = 0; frame < 3; frame++) {
        expect(
          scene.render().rgba,
          orderedEquals(image.rgba),
          reason: 'Scene $name changes between identical frames',
        );
      }
      final independent = GoldenScene(name, mutate: session.mutate);
      try {
        expect(
          independent.render().rgba,
          orderedEquals(image.rgba),
          reason: 'Scene $name changes between fresh WebGL contexts',
        );
      } finally {
        independent.dispose();
      }
      await session.expectImage(image, environment);
    });
  }
}
