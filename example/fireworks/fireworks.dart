import 'package:chronosgl/chronosgl.dart';

import 'dart:math' as math;
import 'dart:html' as html;

import 'package:vector_math/vector_math.dart' as vm;

final ShaderObject fireworksVertexShader = ShaderObject("FireWorksV")
  ..addAttributeVars([aPosition, aNormal])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime])
  ..setBody([
    """
void main() {
    float t = mod($uTime, 5.0);
    vec3 vp = $aPosition;
    if( t < 3.0) {
     vp.y = t;
    } else {
     vp.y = 3.0;
     vp += normalize($aNormal)*(t-3.0);
    }
    gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4(vp, 1.0);
    gl_PointSize = 100.0/gl_Position.z;
}
""",
  ]);

final ShaderObject fireworksFragmentShader = ShaderObject("FireWorksF")
  ..addUniformVars([
    uTime,
    //uColor,
    uTexture,
  ])
  ..setBody([
    """
void main() {
    $oFragColor = texture($uTexture, gl_PointCoord);
    float t = mod($uTime, 5.0);
    if( t < 3.0) {
       //gl_FragColor.x = 1.0;
    } else {
       //gl_FragColor.rgb = $uColor;
       $oFragColor.a -= (t-3.0);
    }
}
""",
  ]);

MeshData getRocket(RenderProgram prog) {
  int numPoints = 200;
  math.Random rand = math.Random();

  List<vm.Vector3> vertices = [];
  List<vm.Vector3> normals = [];
  for (var i = 0; i < numPoints; i++) {
    vertices.add(vm.Vector3(0.0, 0.0, 0.0));
    normals.add(
      vm.Vector3(
        rand.nextDouble() - 0.5,
        rand.nextDouble() - 0.5,
        rand.nextDouble() - 0.5,
      ),
    );
  }

  return prog.makeMeshData("firefwork-particles", glPoints)
    ..addVertices(flattenVector3List(vertices))
    ..addAttribute(aNormal, flattenVector3List(normals), 3);
}

void main() {
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  // Make sure canvas is really full screen
  final int w = canvas.clientWidth;
  final int h = canvas.clientHeight;
  canvas.width = w;
  canvas.height = h;

  ChronosGL cgl = ChronosGL(canvas);
  OrbitCamera orbit = OrbitCamera(15.0, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);
  perspective.adjustAspect(w, h);

  final RenderProgram progSprites = RenderProgram(
    "basic",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );

  final RenderProgram progFireworks = RenderProgram(
    "fireworks",
    cgl,
    fireworksVertexShader,
    fireworksFragmentShader,
  );

  // used for both stars and fireworks
  final Material material = Utils.makeStarMaterial(cgl)
    ..setUniform(uModelMatrix, vm.Matrix4.identity())
    ..setUniform(uColor, colorRed);

  final MeshData stars = Utils.makeStarMesh(progSprites, 2000, 100.0);
  final MeshData rocket = getRocket(progFireworks);

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    material.forceUniform(uTime, timeMs / 1000.0);

    progSprites.draw(stars, [perspective, material]);
    progFireworks.draw(rocket, [perspective, material]);

    html.window.animationFrame.then(animate);
  }

  animate(0.0);
}
