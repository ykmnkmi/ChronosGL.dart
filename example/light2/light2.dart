import 'dart:html' as html;
import "dart:math" as math;
import 'dart:async';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';

final vm.Vector3 posLight = vm.Vector3(11.0, 20.0, 0.0);
final vm.Vector3 dirLight = vm.Vector3(0.0, -50.0, 0.0);
final vm.Vector3 spotDirLight = vm.Vector3(-11.0, -30.0, 0.0);

final double range = 50.0;
final double angle = math.pi / 7.0;
final double glossiness = 10.0;

// These must be in-sync with the .html file
const String idPoint = "idPoint";
const String idSpot = "idSpot";
const String idDirectional = "idDirectional";

const String meshFile = "../asset/dragon/dragon.obj";
const String textureFile = "../asset/dragon/dragon.png";

final Map<String, Light> gLightSources = {
  idDirectional: DirectionalLight(
    "dir",
    dirLight,
    colorBlack,
    colorWhite,
    40.0,
  ),
  idPoint: PointLight("point", posLight, colorLiteBlue, colorWhite, range),
  idSpot: SpotLight(
    "spot",
    posLight,
    spotDirLight,
    colorLiteGreen,
    colorWhite,
    range,
    angle,
    2.0,
    1.0,
    40.0,
  ),
};

final Map<String, Node> gLightVisualizers = {};

final List<Future<dynamic>> gLoadables = [];

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

Node dragon(ChronosGL cgl, RenderProgram prog) {
  final Material mat = Material("matDragon")
    ..setUniform(uShininess, glossiness);

  // This will be populated when the model has loaded
  final Node node = Node.container("dragon");
  var f1 = loadImage(textureFile).then((html.ImageElement img) {
    mat.setUniform(uTexture, ImageTexture(cgl, textureFile, img));
  });
  gLoadables.add(f1);

  var f2 = loadRaw(meshFile).then((String content) {
    GeometryBuilder gb = importGeometryFromWavefront(content);
    MeshData md = geometryBuilderToMeshData(meshFile, prog, gb);
    Node mesh = Node(md.name, md, mat);
    //..rotX(-3.14 / 4);
    Node n = Node.container("wrapper", mesh);
    n.lookAt(vm.Vector3(100.0, 0.0, 0.0));

    node.add(n);
  });
  gLoadables.add(f2);

  return node;
}

void main() {
  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);

  final OrbitCamera orbit = OrbitCamera(50.0, 10.0, 0.0, canvas)
    ..setPos(0.0, 0.0, 56.0);
  final Perspective perspective = Perspective(orbit, 0.1, 10000.0);

  final Illumination illumination = Illumination();
  for (Light l in gLightSources.values) {
    illumination.addLight(l);
  }
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

  final Scene sceneFixed = lightSourceVisualizerScene(cgl, [perspective]);

  // We have two phases (only one will be active)
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

  final Node dragonNode = dragon(cgl, sceneBlinnPhong.program);
  sceneGourad.add(dragonNode);
  sceneBlinnPhong.add(dragonNode);

  final html.SelectElement selectPhase =
      html.document.querySelector('#phase') as html.SelectElement;
  selectPhase.selectedIndex = 0;

  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    input.onChange.listen((html.Event e) {
      html.InputElement input = e.target as html.InputElement;
      print("${input.id} toggle ${input.checked}");
      gLightSources[input.id]!.enabled = input.checked!;
      gLightVisualizers[input.id]!.enabled = input.checked!;
    });
  }

  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(html.Event("change"));
  }

  void resolutionChange(html.Event? ev) {
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
  html.window.onResize.listen(resolutionChange);

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    RenderPhase phase = selectPhase.selectedIndex == 0
        ? phaseBlinnPhong
        : phaseGourad;
    phase.draw();
    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
