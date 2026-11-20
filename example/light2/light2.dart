import 'dart:js_interop';

import 'package:web/web.dart' as web;

import "dart:math" as math;
import 'dart:async';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

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
    colorBlack.toVector3(),
    colorWhite.toVector3(),
    40.0,
  ),
  idPoint: PointLight(
    "point",
    posLight,
    colorLiteBlue.toVector3(),
    colorWhite.toVector3(),
    range,
  ),
  idSpot: SpotLight(
    "spot",
    posLight,
    spotDirLight,
    colorLiteGreen.toVector3(),
    colorWhite.toVector3(),
    range,
    angle,
    2.0,
    1.0,
    40.0,
  ),
};

final Map<String, Node> gLightVisualizers = {};

final List<Future<void>> gLoadables = [];

RenderBatch lightSourceVisualizerScene(
  ChronosGL cgl,
  List<UniformGroup> uniforms,
) {
  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "Fixed",
      lifetime.own(
        RenderProgram(
          "Fixed",
          cgl,
          solidColorVertexShader,
          solidColorFragmentShader,
        ),
      ),
      uniforms,
    ),
  );

  Material lightSourceMat = lifetime.own(Material("light"))
    ..setUniform(uColor, colorYellow.toVector3());
  for (String k in gLightSources.keys) {
    gLightVisualizers[k] = MeshNode(
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
  final Material mat = lifetime.own(Material("matDragon"))
    ..setUniform(uShininess, glossiness);

  // This will be populated when the model has loaded
  final Node node = GroupNode("dragon");
  var f1 = loadImage(textureFile).then((img) {
    if (lifetime.isDisposed) return;
    mat.setUniform(
      uTexture,
      lifetime.own(
        ImageTexture.fromImage(context: cgl, name: textureFile, image: img),
      ),
    );
  });
  gLoadables.add(f1);

  var f2 = loadRaw(meshFile).then((String content) {
    if (lifetime.isDisposed) return;
    GeometryBuilder gb = importGeometryFromWavefront(content);
    GpuMesh md = lifetime.own(uploadGeometry(meshFile, prog, gb));
    Node mesh = MeshNode(md.name, md, mat);
    //..rotX(-3.14 / 4);
    Node n = GroupNode("wrapper", mesh);
    n.lookAt(vm.Vector3(100.0, 0.0, 0.0));

    node.add(n);
  });
  gLoadables.add(f2);

  return node;
}

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
  final camera = PerspectiveCamera(near: 0.1, far: 10000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 50.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);

  final Illumination illumination = Illumination();
  for (Light l in gLightSources.values) {
    illumination.addLight(l);
  }
  final RenderBatch sceneBlinnPhong = lifetime.ownBatch(
    RenderBatch(
      "BlinnPhong",
      lifetime.own(
        RenderProgram(
          "BlinnPhong",
          cgl,
          lightVertexShaderBlinnPhong,
          lightFragmentShaderBlinnPhong,
        ),
      ),
      [perspective, illumination],
    ),
  );

  final RenderBatch sceneGourad = lifetime.ownBatch(
    RenderBatch(
      "Gourad",
      lifetime.own(
        RenderProgram(
          "Gourad",
          cgl,
          lightVertexShaderGourad,
          lightFragmentShaderGourad,
        ),
      ),
      [perspective, illumination],
    ),
  );
  assert(
    sceneBlinnPhong.program.hasCompatibleAttributesTo(sceneGourad.program),
  );

  final RenderBatch sceneFixed = lightSourceVisualizerScene(cgl, [perspective]);

  // We have two phases (only one will be active)
  // 1 BlinnPhong
  // 2 Gourad
  // Each has two scenes
  // 1 the lighting specific scene
  // 2 the lighting visualization scene which is shared by the two phases
  final RenderPass phaseBlinnPhong =
      lifetime.ownPass(RenderPass("BlinnPhong", cgl))
        ..add(sceneBlinnPhong)
        ..add(sceneFixed);

  final RenderPass phaseGourad = lifetime.ownPass(RenderPass("Gourad", cgl))
    ..add(sceneGourad)
    ..add(sceneFixed);

  final Node dragonNode = dragon(cgl, sceneBlinnPhong.program);
  sceneGourad.add(dragonNode);
  sceneBlinnPhong.add(dragonNode);

  final web.HTMLSelectElement selectPhase =
      web.document.querySelector('#phase') as web.HTMLSelectElement;
  selectPhase.selectedIndex = 0;

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    lifetime.own(
      input.onChange.listen((web.Event e) {
        web.HTMLInputElement input = e.target as web.HTMLInputElement;
        print("${input.id} toggle ${input.checked}");
        gLightSources[input.id]!.enabled = input.checked;
        gLightVisualizers[input.id]!.enabled = input.checked;
      }),
    );
  }

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(web.Event("change"));
  }

  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phaseBlinnPhong,
    ),
  );
  final viewportGourad = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phaseGourad,
    ),
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
    viewportGourad.update();
    final elapsed = lastTimeMs == null ? 0.0 : timeMs - lastTimeMs!;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000.0;
    orbit.update(elapsed / 1000.0);

    RenderPass phase = selectPhase.selectedIndex == 0
        ? phaseBlinnPhong
        : phaseGourad;
    phase.draw();
    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
