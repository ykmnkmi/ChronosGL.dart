import 'dart:js_interop';

import 'package:web/web.dart' as web;

import "dart:math" as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

final vm.Vector3 posLight = vm.Vector3(11.0, 20.0, 0.0);
final vm.Vector3 dirLight = vm.Vector3(0.0, -50.0, 0.0);
final vm.Vector3 spotDirLight = vm.Vector3(-11.0, -30.0, 0.0);

final double range = 80.0;
final double angle = math.pi / 7.0;
final double glossiness = 50.0;

// These must be in-sync with the .html file
const String idPoint = "idPoint";
const String idSpot = "idSpot";
const String idDirectional = "idDirectional";

final Map<String, Light> gLightSources = {
  idDirectional: DirectionalLight(
    "dir",
    dirLight,
    colorWhite,
    colorWhite,
    40.0,
  ),
  idPoint: PointLight("point", posLight, colorWhite, colorWhite, range),
  idSpot: SpotLight(
    "spot",
    posLight,
    spotDirLight,
    colorWhite,
    colorWhite,
    range,
    angle,
    2.0,
    1.0,
    40.0,
  ),
};

final Map<String, Node> gLightVisualizers = {};

Scene lightSourceVisualizerScene(ChronosGL cgl, List<UniformGroup> uniforms) {
  Scene scene = Scene(
    "Fixed",
    RenderProgram(
      "Fixed",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    uniforms,
  );

  Material lightSourceMat = Material("light")..setUniform(uColor, colorYellow);
  for (String k in gLightSources.keys) {
    gLightVisualizers[k] = Node(
      k,
      lightVisualizer(scene.program, gLightSources[k]!),
      lightSourceMat,
    );
  }
  for (Node n in gLightVisualizers.values) {
    scene.add(n);
  }
  return scene;
}

void makeSceneCubeSphere(ChronosGL cgl, RenderProgram prog, Node container) {
  MeshData cubeMeshData = shapeCube(prog, x: 2.0, y: 2.0, z: 2.0);
  MeshData sphereMeshData = shapeIcosahedron(prog);

  List<Material> mats = [
    Material("mat0")
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "blue", colorBlue * 0.5),
      )
      ..setUniform(uShininess, glossiness),
    Material("mat1")
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "red", colorRed * 0.5),
      )
      ..setUniform(uShininess, glossiness),
    Material("mat2")
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "white", colorWhite * 0.5),
      )
      ..setUniform(uShininess, glossiness),
    Material("mat3")
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "green", colorGreen * 0.5),
      )
      ..setUniform(uShininess, glossiness),
  ];

  for (int i = 0; i < 8; i++) {
    double x = i & 1 == 0 ? -10.0 : 10.0;
    double y = i & 2 == 0 ? -10.0 : 10.0;
    double z = i & 4 == 0 ? -10.0 : 10.0;

    container.add(
      Node("mesh", i % 2 == 0 ? cubeMeshData : sphereMeshData, mats[i % 4])
        ..setPos(x, y, z)
        ..lookUp(1.0)
        ..lookLeft(0.7),
    );
  }

  // Subdivide plane to show Gourad shading issues
  Node grid = Node("grid", shapeGrid(prog, 20, 20, 80.0, 80.0), mats[2]);
  grid.rotX(-math.pi * 0.48);
  grid.setPos(0.0, -20.0, 20.0);
  container.add(grid);
}

void main() {
  final StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);

  final OrbitCamera orbit = OrbitCamera(50.0, 10.0, 0.0, canvas)
    ..setPos(0.0, 0.0, 56.0);
  final Perspective perspective = Perspective(orbit, 0.1, 10000.0);

  final Illumination illumination = Illumination();
  for (Light l in gLightSources.values) {
    illumination.addLight(l);
  }

  final Scene sceneFixed = lightSourceVisualizerScene(cgl, [perspective]);

  final Scene sceneBlinnPhong = Scene(
    "BlinnPhong",
    RenderProgram(
      "BlinnPhong",
      cgl,
      lightVertexShaderBlinnPhong,
      lightFragmentShaderBlinnPhong,
    ),
    [perspective, illumination],
  );

  final Scene sceneGourad = Scene(
    "Gourad",
    RenderProgram(
      "Gourad",
      cgl,
      lightVertexShaderGourad,
      lightFragmentShaderGourad,
    ),
    [perspective, illumination],
  );
  assert(
    sceneBlinnPhong.program.hasCompatibleAttributesTo(sceneGourad.program),
  );

  // We have two phases
  // 1 BlinnPhong
  // 2 Gourad
  // Each has two scenes
  // 1 the lighting specific scene
  // 2 the lighting visualization scene which is shared by the two phases
  final RenderPhase phaseBlinnPhong = RenderPhase("BlinnPhong", cgl)
    ..add(sceneBlinnPhong)
    ..add(sceneFixed);

  final RenderPhase phaseGourad = RenderPhase("Gourad", cgl)
    ..add(sceneGourad)
    ..add(sceneFixed);

  Node node = Node.container("scene");
  makeSceneCubeSphere(cgl, sceneBlinnPhong.program, node);

  sceneGourad.add(node);
  sceneBlinnPhong.add(node);

  web.HTMLSelectElement selectPhase =
      web.document.querySelector('#phase') as web.HTMLSelectElement;
  selectPhase.selectedIndex = 0;

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    input.onChange.listen((web.Event e) {
      web.HTMLInputElement input = e.target as web.HTMLInputElement;
      final String tag = input.id;
      print("$tag toggle ${input.checked}");
      if (tag == "lightDiffuse") {
        for (Light light in gLightSources.values) {
          double v = input.checked ? 1.0 : 0.0;
          light.colorDiffuse.setValues(v, v, v);
        }
      } else if (tag == "lightSpecular") {
        for (Light light in gLightSources.values) {
          double v = input.checked ? 1.0 : 0.0;
          light.colorSpecular.setValues(v, v, v);
        }
      } else {
        gLightSources[tag]!.enabled = input.checked;
        gLightVisualizers[tag]!.enabled = input.checked;
      }
    });
  }

  // Update default settings
  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(web.Event("change"));
  }

  void resolutionChange(web.Event? ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    perspective.adjustAspect(w, h);
    phaseGourad.viewPortW = w;
    phaseGourad.viewPortH = h;

    phaseBlinnPhong.viewPortW = w;
    phaseBlinnPhong.viewPortH = h;
  }

  resolutionChange(null);
  web.EventStreamProviders.resizeEvent
      .forTarget(web.window)
      .listen(resolutionChange);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    for (Node m in node.children) {
      if (m.name != "grid") {
        m.rollLeft(elapsed * 0.0003);
        m.lookLeft(elapsed * 0.0003);
      }
    }

    RenderPhase phase = selectPhase.selectedIndex == 0
        ? phaseBlinnPhong
        : phaseGourad;
    phase.draw();
    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
