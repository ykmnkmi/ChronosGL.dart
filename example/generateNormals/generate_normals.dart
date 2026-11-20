import 'dart:js_interop';
import 'dart:async';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final ShaderObject normal2ColorVertexShader =
    ShaderObject.vertex("Normal2Color")
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

final ShaderObject normal2ColorFragmentShader =
    ShaderObject.fragment("Normal2ColorF")
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
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 2520.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: -45.0,
      polar: 0.3,
    ),
  );
  final perspective = CameraUniforms(camera);

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );
  final RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "objects",
      lifetime.own(
        RenderProgram(
          "test",
          cgl,
          normal2ColorVertexShader,
          normal2ColorFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  phase.add(scene);
  final Material mat = lifetime.own(Material("mat"));

  var future = loadRaw(modelFile)
    ..then((String content) {
      if (lifetime.isDisposed) return;
      List<GeometryBuilder> geos = [
        importGeometryFromWavefront(content),
        cylinderGeometry(1.0, 1.0, 2.0, 16, false),
        cubeGeometry(computeNormals: false),
      ];

      for (var i = 0; i < geos.length; i++) {
        geos[i].generateNormalsAssumingTriangleMode();
        GpuMesh md = lifetime.own(uploadGeometry("", scene.program, geos[i]));
        Node mesh = MeshNode(md.name, md, mat)..setPos(-5.0 + i * 7, 4.0, 0.0);
        if (i == 0 /* ctLogo*/ ) {
          mesh
            ..rotX(3.14 / 2)
            ..rotZ(3.14);
        }
        scene.add(mesh);
      }
    });
  gLoadables.add(future);

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
    phase.draw();
    lifetime.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
