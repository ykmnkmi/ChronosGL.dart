import 'dart:js_interop';
import "dart:async";

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

String textureFile = "sphere.png";
// https://cycling74.com/forums/topic/shader-help-recreating-gl_sphere_map/
// https://www.opengl.org/wiki/Mathematics_of_glTexGen

ShaderObject sphereVertexShader = ShaderObject("sphereV")
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

ShaderObject sphereFragmentShader = ShaderObject("sphereF")
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
  final StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);

  final OrbitCamera orbit = OrbitCamera(5.0, 10.0, 0.0, canvas);
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram progSphere = RenderProgram(
    "spheres",
    cgl,
    sphereVertexShader,
    sphereFragmentShader,
  );
  final MeshData mdSphere = shapeIcosahedron(progSphere, subdivisions: 3);
  final vm.Matrix4 modelMat = vm.Matrix4.identity();
  final vm.Matrix3 normalMat = vm.Matrix3.identity();

  final Material matSphere = Material.transparent("sphere", blendEquationMix)
    ..setUniform(uNormalMatrix, normalMat)
    ..setUniform(uModelMatrix, modelMat);
  var future = loadImage(textureFile)
    ..then((img) {
      Texture bubble = ImageTexture(cgl, textureFile, img);
      matSphere.setUniform(uTexture, bubble);
    });
  gLoadables.add(future);

  final RenderProgram progStars = RenderProgram(
    "stars",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );
  final Material matStars = Utils.makeStarMaterial(cgl)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData mdStars = Utils.makeStarMesh(progStars, 2000, 100.0);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    modelMat.setIdentity();
    progSphere.draw(mdSphere, [matSphere, perspective]);
    modelMat.setTranslationRaw(1.5, 0.0, 0.0);
    progSphere.draw(mdSphere, [matSphere, perspective]);
    progStars.draw(mdStars, [matStars, perspective]);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
