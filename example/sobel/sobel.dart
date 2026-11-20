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

final web.HTMLInputElement gSobel =
    web.document.querySelector('#activate') as web.HTMLInputElement;

final List<Future<Object>> gLoadables = [];

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

  final List<ShaderObject> greyShader = createPlane2GreyShader();
  final RenderProgram progGrey = lifetime.own(
    RenderProgram.create(
      name: "grey",
      context: cgl,
      vertexShader: greyShader[0],
      fragmentShader: greyShader[1],
    ),
  );

  final RenderProgram progSobel = lifetime.own(
    RenderProgram.create(
      name: "ssao",
      context: cgl,
      vertexShader: sobelVertexShader,
      fragmentShader: sobelFragmentShader,
    ),
  );

  final UniformGroup uniforms = lifetime.own(UniformGroup("plain"))
    ..setUniform(uCanvasSize, vm.Vector2(0.0 + width, 0.0 + height))
    ..setUniform(uDepthMap, fb.depthTexture!)
    ..setUniform(uTexture, fb.colorTexture!);

  final GpuMesh unitQuad = lifetime.own(shapeQuad(progSobel, 1));
  late GpuMesh ctLogo;

  var future = loadRaw(modelFile)
    ..then((String content) {
      if (lifetime.isDisposed) return;
      GeometryBuilder gb = importGeometryFromWavefront(content);
      ctLogo = lifetime.own(uploadGeometry("", progGrey, gb));
    });
  gLoadables.add(future);

  Material material = lifetime.own(Material("mat"))
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
    if (gSobel.checked) {
      // Draw objects into fb
      fb.activate(glClearAll, 0, 0, width, height);
      progGrey.draw(ctLogo, [perspective, material]);
      // Apply sobel to fb and show result on screen
      screen.activate(glClearAll, 0, 0, width, height);
      progSobel.draw(unitQuad, [uniforms]);
    } else {
      progGrey.draw(ctLogo, [perspective, material]);
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
