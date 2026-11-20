import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:async';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

const String modelFile = "../ct_logo.obj";

final List<Future<Object>> gLoadables = [];

final web.HTMLInputElement gSSAO =
    web.document.querySelector('#activate') as web.HTMLInputElement;

void main() {
  final FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );

  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  var width = canvas.clientWidth;
  var height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;

  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 2520.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 15.0,
      azimuth: -45.0,
      polar: 0.3,
    ),
  );
  final CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  width = viewport.drawingBufferWidthPixels;
  height = viewport.drawingBufferHeightPixels;
  final Framebuffer screen = lifetime.own(Framebuffer.screen(cgl));
  Framebuffer fb = lifetime.own(
    Framebuffer.defaultFramebuffer(cgl, width, height),
  );

  final RenderProgram progSolid = lifetime.own(
    RenderProgram.create(
      name: "solid",
      context: cgl,
      vertexShader: solidColorVertexShader,
      fragmentShader: solidColorFragmentShader,
    ),
  );

  final RenderProgram progSSAO = lifetime.own(
    RenderProgram.create(
      name: "ssao",
      context: cgl,
      vertexShader: ssaoVertexShader,
      fragmentShader: ssaoFragmentShader,
    ),
  );

  final UniformGroup uniforms = lifetime.own(UniformGroup("plain"))
    ..setUniform(uCameraNear, 0.1)
    ..setUniform(uCameraFar, 2520.0)
    ..setUniform(uCanvasSize, vm.Vector2(0.0 + width, 0.0 + height))
    ..setUniform(uDepthMap, fb.depthTexture!)
    ..setUniform(uTexture, fb.colorTexture!);

  final GpuMesh unitQuad = lifetime.own(shapeQuad(progSSAO, 1));

  late GpuMesh ctLogo;
  var future = loadRaw(modelFile)
    ..then((String content) {
      if (lifetime.isDisposed) return;
      GeometryBuilder gb = importGeometryFromWavefront(content);
      ctLogo = lifetime.own(uploadGeometry("", progSolid, gb));
    });
  gLoadables.add(future);

  Material material = lifetime.own(Material("mat"))
    ..setUniform(uColor, colorGray8.toVector3())
    ..setUniform(uModelMatrix, vm.Matrix4.identity()..rotateX(math.pi / 2));

  double lastTimeMs = 0.0;
  bool firstFrame = true;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    if (width != viewport.drawingBufferWidthPixels ||
        height != viewport.drawingBufferHeightPixels) {
      width = viewport.drawingBufferWidthPixels;
      height = viewport.drawingBufferHeightPixels;
      fb.dispose();
      fb = lifetime.own(Framebuffer.defaultFramebuffer(cgl, width, height));
      uniforms.forceUniform(
        uCanvasSize,
        vm.Vector2(width.toDouble(), height.toDouble()),
      );
      uniforms.forceUniform(uDepthMap, fb.depthTexture!);
      uniforms.forceUniform(uTexture, fb.colorTexture!);
    }
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000;
    orbit.update(elapsed / 1000);
    if (gSSAO.checked) {
      fb.activate(glClearAll, 0, 0, width, height);
      progSolid.draw(ctLogo, [perspective, material]);
      screen.activate(glClearAll, 0, 0, width, height);
      progSSAO.draw(unitQuad, [uniforms]);
    } else {
      progSolid.draw(ctLogo, [perspective, material]);
    }

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
