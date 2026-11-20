import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';

import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final ShaderObject fireworksVertexShader = ShaderObject.vertex("FireWorksV")
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

final ShaderObject fireworksFragmentShader = ShaderObject.fragment("FireWorksF")
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

GpuMesh getRocket(RenderProgram prog) {
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

  return lifetime.own(prog.makeGpuMesh("firefwork-particles", glPoints))
    ..addVertices(flattenVector3List(vertices))
    ..addAttribute(aNormal, flattenVector3List(normals), 3);
}

void main() {
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  // Make sure canvas is really full screen
  final int w = canvas.clientWidth;
  final int h = canvas.clientHeight;
  canvas.width = w;
  canvas.height = h;

  ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 15.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram progSprites = lifetime.own(
    RenderProgram(
      "basic",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    ),
  );

  final RenderProgram progFireworks = lifetime.own(
    RenderProgram(
      "fireworks",
      cgl,
      fireworksVertexShader,
      fireworksFragmentShader,
    ),
  );

  // used for both stars and fireworks
  final Material material = lifetime.own(makeStarMaterial(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity())
    ..setUniform(uColor, colorRed.toVector3());

  final GpuMesh stars = lifetime.own(
    makeStarMesh(progSprites, 2000, 100.0, random: math.Random()),
  );
  final GpuMesh rocket = getRocket(progFireworks);

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
    material.forceUniform(uTime, timeMs / 1000.0);

    progSprites.draw(stars, [perspective, material]);
    progFireworks.draw(rocket, [perspective, material]);

    lifetime.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
