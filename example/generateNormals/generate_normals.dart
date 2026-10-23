import 'dart:js_interop';
import 'dart:async';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';

final ShaderObject normal2ColorVertexShader = ShaderObject("Normal2Color")
  ..addAttributeVars([aPosition, aNormal])
  ..addVaryingVars([vColor])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBody([
    """
void main() {
    $stdVertexBody
    $vColor = normalize($aNormal / 2.0 + vec3(0.5) );
}
      """,
  ]);

final ShaderObject normal2ColorFragmentShader = ShaderObject("Normal2ColorF")
  ..addVaryingVars([vColor])
  ..setBody([
    """
void main() {
    $oFragColor = vec4( $vColor, 1.0 );
}
    """,
  ]);

const String modelFile = "../ct_logo.obj";

final List<Future<Object>> gLoadables = [];

void main() {
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL(canvas);
  final OrbitCamera orbit = OrbitCamera(25.0, -45.0, 0.3, canvas);
  final Perspective perspective = Perspective(orbit, 0.1, 2520.0);

  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );
  final Scene scene = Scene(
    "objects",
    RenderProgram(
      "test",
      cgl,
      normal2ColorVertexShader,
      normal2ColorFragmentShader,
    ),
    [perspective],
  );
  phase.add(scene);
  final Material mat = Material("mat");

  var future = loadRaw(modelFile)
    ..then((String content) {
      List<GeometryBuilder> geos = [
        importGeometryFromWavefront(content),
        cylinderGeometry(1.0, 1.0, 2.0, 16, false),
        cubeGeometry(computeNormals: false),
      ];

      for (var i = 0; i < geos.length; i++) {
        geos[i].generateNormalsAssumingTriangleMode();
        MeshData md = geometryBuilderToMeshData("", scene.program, geos[i]);
        Node mesh = Node(md.name, md, mat)..setPos(-5.0 + i * 7, 4.0, 0.0);
        if (i == 0 /* ctLogo*/ ) {
          mesh
            ..rotX(3.14 / 2)
            ..rotZ(3.14);
        }
        scene.add(mesh);
      }
    });
  gLoadables.add(future);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    phase.draw();
    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
