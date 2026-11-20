import 'dart:async';
import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:web/web.dart' as web;

/// A complete scene that can be copied without the examples' shared helpers.
void main() {
  final canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  canvas.tabIndex = 0;
  canvas.focus();
  final cgl = ChronosGL.fromCanvas(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 100);
  final controls = OrbitControls.forCamera(
    camera: camera,
    eventTarget: canvas,
    radius: 6,
    azimuth: 0.5,
    polar: 0.3,
  );
  final program = RenderProgram.create(
    name: 'cube',
    context: cgl,
    vertexShader: solidColorVertexShader,
    fragmentShader: solidColorFragmentShader,
  );
  final mesh = shapeCube(program);
  final material = Material('blue')
    ..set(UniformKeys.color, colorLiteBlue.toVector3());
  final batch = RenderBatch('objects', program, [CameraUniforms(camera)])
    ..add(MeshNode('cube', mesh, material));
  final pass = RenderPass('screen', cgl)..add(batch);
  final viewport = CanvasViewport.forCanvas(
    cgl: cgl,
    canvas: canvas,
    camera: camera,
    renderPass: pass,
  );

  var disposed = false;
  int? frameId;
  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (disposed) return;
    final deltaSeconds = lastTimeMs == null
        ? 0.0
        : (timeMs - lastTimeMs!) / 1000;
    lastTimeMs = timeMs;
    controls.update(deltaSeconds);
    if (viewport.update()) pass.draw();
    frameId = web.window.requestAnimationFrame(onFrame);
  }

  late final JSFunction onPageHide;
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    web.window.removeEventListener('pagehide', onPageHide);
    if (frameId != null) web.window.cancelAnimationFrame(frameId!);
    final inputDisposal = controls.dispose();
    viewport.dispose();
    mesh.dispose();
    program.dispose();
    await inputDisposal;
  }

  onPageHide = ((web.PageTransitionEvent event) {
    if (!event.persisted) unawaited(dispose());
  }).toJS;
  web.window.addEventListener('pagehide', onPageHide);
  onFrame = animate.toJS;
  frameId = web.window.requestAnimationFrame(onFrame);
}
