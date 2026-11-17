@TestOn('chrome')
library;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'Legacy resize adapters own subscriptions and preserve borrowed resources',
    () {
      final canvas = web.HTMLCanvasElement()
        ..style.width = '80px'
        ..style.height = '40px';
      web.document.body!.appendChild(canvas);
      addTearDown(() => canvas.remove());
      final cgl = ChronosGL(canvas, antialiasing: false);
      addTearDown(() {
        (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
            ?.loseContext();
      });
      final camera = Spatial('borrowed camera');
      final perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.1, 100);
      final phase = RenderPhaseResizeAware(
        'borrowed pass',
        cgl,
        canvas,
        perspective,
      );
      addTearDown(perspective.dispose);
      addTearDown(phase.dispose);
      expect([canvas.width, canvas.height], [80, 40]);

      phase.dispose();
      phase.dispose();
      perspective.dispose();
      perspective.dispose();
      canvas.style
        ..width = '60px'
        ..height = '80px';
      web.window.dispatchEvent(web.Event('resize'));

      expect(phase.isDisposed, isTrue);
      expect(perspective.isDisposed, isTrue);
      expect([canvas.width, canvas.height], [80, 40]);
      expect([phase.viewPortW, phase.viewPortH], [80, 40]);
      expect(cgl.getParameter(glViewport), [0, 0, 80, 40]);
      expect(() => phase.resolutionChange(null), throwsStateError);
      expect(() => perspective.resolutionChange(null), throwsStateError);
      expect(perspective.getUniforms(), contains(uPerspectiveViewMatrix));
      camera.setPos(1, 2, 3);
      expect(camera.getPos().storage, [1, 2, 3]);
      expect(cgl.getError(), glNoError);
    },
  );
}
