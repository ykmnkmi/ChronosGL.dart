import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

final ShaderObject skyScraperVertexShader = ShaderObject("SkyScraperV")
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

final ShaderObject skyScraperFragmentShader = ShaderObject("SkyScraperF")
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
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  int w = canvas.clientWidth;
  int h = canvas.clientHeight;
  canvas.width = w;
  canvas.height = h;
  ChronosGL cgl = ChronosGL(canvas);
  OrbitCamera orbit = OrbitCamera(25.0, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );

  Scene sceneBuilding = Scene(
    "building",
    RenderProgram(
      "building",
      cgl,
      skyScraperVertexShader,
      skyScraperFragmentShader,
    ),
    [perspective],
  );
  phase.add(sceneBuilding);

  Scene sceneSky = Scene(
    "sky",
    RenderProgram("sky", cgl, demoVertexShader, demoFragmentShader),
    [perspective],
  );
  phase.add(sceneSky);

  Material mat = Material("mat");
  // Sky Sphere
  MeshData md = shapeIcosahedron(sceneSky.program, subdivisions: 3);
  //..multiplyVertices(100);
  Node m = Node(md.name, md, mat)
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
  MeshData house = geometryBuilderToMeshData(
    "house",
    sceneBuilding.program,
    gb,
  );

  for (int x = -10; x < 10; x += 4) {
    for (int z = -10; z < 10; z += 4) {
      Node m = Node(house.name, house, mat)
        ..setPos(x.toDouble(), 0.0, z.toDouble());
      sceneBuilding.add(m);
    }
  }

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    phase.draw();
    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  animate(0.0);
}
