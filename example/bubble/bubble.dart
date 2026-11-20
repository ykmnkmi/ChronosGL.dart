import 'dart:math' as math;

import 'dart:js_interop';
import "dart:async";

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

String textureFile = "sphere.png";
// https://cycling74.com/forums/topic/shader-help-recreating-gl_sphere_map/
// https://www.opengl.org/wiki/Mathematics_of_glTexGen

ShaderObject sphereVertexShader = ShaderObject.vertex("sphereV")
  ..addAttributeVars([aPosition, aNormal])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
  ..addVaryingVars([vTexUV])
  ..setBody([
    """
void main() {
    $stdVertexBody
    vec3 u = normalize(vec3($uModelMatrix * vec4($aPosition, 1.0)));
    vec3 n = normalize($uNormalMatrix * $aNormal );
    vec3 r = reflect( u, n );
    r.z += 1.0;
    float m = 2.0 * length(r);
    $vTexUV = vec2(r.x/m + 0.5, r.y/m + 0.5);
}
  """,
  ]);

ShaderObject sphereFragmentShader = ShaderObject.fragment("sphereF")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uTexture])
  ..setBody([
    """
void main() {
    $oFragColor = texture($uTexture, $vTexUV);
}
      """,
  ]);

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
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas, faceCulling: true);

  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 5.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram progSphere = lifetime.own(
    RenderProgram("spheres", cgl, sphereVertexShader, sphereFragmentShader),
  );
  final GpuMesh mdSphere = lifetime.own(
    shapeIcosahedron(progSphere, subdivisions: 3),
  );
  final vm.Matrix4 modelMat = vm.Matrix4.identity();
  final vm.Matrix3 normalMat = vm.Matrix3.identity();

  final Material matSphere =
      lifetime.own(Material.transparent("sphere", blendEquationMix))
        ..setUniform(uNormalMatrix, normalMat)
        ..setUniform(uModelMatrix, modelMat);
  var future = loadImage(textureFile)
    ..then((img) {
      if (lifetime.isDisposed) return;
      Texture bubble = lifetime.own(
        ImageTexture.fromImage(context: cgl, name: textureFile, image: img),
      );
      matSphere.setUniform(uTexture, bubble);
    });
  gLoadables.add(future);

  final RenderProgram progStars = lifetime.own(
    RenderProgram(
      "stars",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    ),
  );
  final Material matStars = lifetime.own(makeStarMaterial(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh mdStars = lifetime.own(
    makeStarMesh(progStars, 2000, 100.0, random: math.Random()),
  );

  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      lastTimeMs = timeMs;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = lastTimeMs == null ? 0.0 : timeMs - lastTimeMs!;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000.0;
    orbit.update(elapsed / 1000.0);
    modelMat.setIdentity();
    progSphere.draw(mdSphere, [matSphere, perspective]);
    modelMat.setTranslationRaw(1.5, 0.0, 0.0);
    progSphere.draw(mdSphere, [matSphere, perspective]);
    progStars.draw(mdStars, [matStars, perspective]);

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
