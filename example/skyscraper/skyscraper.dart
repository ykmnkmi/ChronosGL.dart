import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/shaders.dart';

import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final ShaderObject skyScraperVertexShader = ShaderObject.vertex("SkyScraperV")
  ..addAttributeVars([aPosition, aTexUV])
  ..addVaryingVars([vPosition, vTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBody([
    """
void main() {     
    $stdVertexBody
    $vPosition = $aPosition;
    $vTexUV = $aTexUV;
}
""",
  ]);

final ShaderObject skyScraperFragmentShader =
    ShaderObject.fragment("SkyScraperF")
      ..addVaryingVars([vPosition, vTexUV])
      ..setBody([
        """
void main() {      
      // the step finds the windows
      // multiplying the tex coord with 11 gives it a black column on the right side but with artifacts
      // multiplying the tex coord with 10.9 gives it a black column on the right side WITHOUT the
      // artifacts on the right side
      float s1 = step(mod($vTexUV.x*11.+1., 2.), 1.);
      float s2 = step(mod($vTexUV.y*21.+1., 2.), 1.);
      float s3 = step( s1+s2, 1.1);

      $oFragColor = vec4( 1.-s3, 1.-s3, 1.-s3, 1. );

      //gl_FragColor = vec4( mod(vPosition.x*10.0,2.0) ,
      //                       mod(vPosition.y*20.0,2.0),
      //                       mod(vPosition.z*10.0,2.0), 1. );
}
""",
      ]);

void main() {
  final fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  canvas.tabIndex = 0;
  canvas.focus();
  final cgl = ChronosGL.fromCanvas(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 1000);
  final orbit = lifetime.own(
    OrbitControls.forCamera(camera: camera, eventTarget: canvas, radius: 25),
  );
  final perspective = CameraUniforms(camera);
  final phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  final sceneBuilding = lifetime.ownBatch(
    RenderBatch(
      "building",
      lifetime.own(
        RenderProgram(
          "building",
          cgl,
          skyScraperVertexShader,
          skyScraperFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  phase.add(sceneBuilding);

  final sceneSky = lifetime.ownBatch(
    RenderBatch(
      "sky",
      lifetime.own(
        RenderProgram("sky", cgl, demoVertexShader, demoFragmentShader),
      ),
      [perspective],
    ),
  );
  phase.add(sceneSky);

  final mat = lifetime.own(Material("mat"));
  // Sky Sphere
  final md = lifetime.own(shapeIcosahedron(sceneSky.program, subdivisions: 3));
  //..multiplyVertices(100);
  final m = MeshNode(md.name, md, mat)
    ..transform.scaleByDouble(100.0, 100.0, 100.0, 1.0);
  sceneSky.add(m);

  // 0.01 and 0.99 is to remove some artifacts on the edges
  vm.Vector2 q = vm.Vector2(0.01, 0.01);
  GeometryBuilder gb = cubeGeometry(
    x: 1.0,
    y: 2.0,
    z: 1.0,
    uMin: 0.01,
    uMax: 0.99,
    vMin: 0.01,
    vMax: 0.99,
  );
  final uvs = gb.attributes[aTexUV]! as List<vm.Vector2>;
  // change top and bottom face
  for (int i = 2 * 4; i < 4 * 4; i++) {
    uvs[i].setFrom(q);
  }
  final house = lifetime.own(
    uploadGeometry("house", sceneBuilding.program, gb),
  );

  for (int x = -10; x < 10; x += 4) {
    for (int z = -10; z < 10; z += 4) {
      final m = MeshNode(house.name, house, mat)
        ..setPos(x.toDouble(), 0.0, z.toDouble());
      sceneBuilding.add(m);
    }
  }

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
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
