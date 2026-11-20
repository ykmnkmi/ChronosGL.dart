import 'dart:js_interop';

import 'package:web/web.dart' as web;

import "dart:math" as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

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
    colorWhite.toVector3(),
    colorWhite.toVector3(),
    40.0,
  ),
  idPoint: PointLight(
    "point",
    posLight,
    colorWhite.toVector3(),
    colorWhite.toVector3(),
    range,
  ),
  idSpot: SpotLight(
    "spot",
    posLight,
    spotDirLight,
    colorWhite.toVector3(),
    colorWhite.toVector3(),
    range,
    angle,
    2.0,
    1.0,
    40.0,
  ),
};

final Map<String, Node> gLightVisualizers = {};

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

void makeSceneCubeSphere(ChronosGL cgl, RenderProgram prog, Node container) {
  GpuMesh cubeMeshData = lifetime.own(shapeCube(prog, x: 2.0, y: 2.0, z: 2.0));
  GpuMesh sphereMeshData = lifetime.own(shapeIcosahedron(prog));

  List<Material> mats = [
    lifetime.own(Material("mat0"))
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "blue", colorBlue.toVector3() * 0.5),
      )
      ..setUniform(uShininess, glossiness),
    lifetime.own(Material("mat1"))
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "red", colorRed.toVector3() * 0.5),
      )
      ..setUniform(uShininess, glossiness),
    lifetime.own(Material("mat2"))
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "white", colorWhite.toVector3() * 0.5),
      )
      ..setUniform(uShininess, glossiness),
    lifetime.own(Material("mat3"))
      ..setUniform(
        uTexture,
        makeSolidColorTextureRGB(cgl, "green", colorGreen.toVector3() * 0.5),
      )
      ..setUniform(uShininess, glossiness),
  ];

  for (int i = 0; i < 8; i++) {
    double x = i & 1 == 0 ? -10.0 : 10.0;
    double y = i & 2 == 0 ? -10.0 : 10.0;
    double z = i & 4 == 0 ? -10.0 : 10.0;

    container.add(
      MeshNode("mesh", i % 2 == 0 ? cubeMeshData : sphereMeshData, mats[i % 4])
        ..setPos(x, y, z)
        ..lookUp(1.0)
        ..lookLeft(0.7),
    );
  }

  // Subdivide plane to show Gourad shading issues
  Node grid = MeshNode(
    "grid",
    lifetime.own(shapeGrid(prog, 20, 20, 80.0, 80.0)),
    mats[2],
  );
  grid.rotX(-math.pi * 0.48);
  grid.setPos(0.0, -20.0, 20.0);
  container.add(grid);
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

  final RenderBatch sceneFixed = lightSourceVisualizerScene(cgl, [perspective]);

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

  // We have two phases
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

  Node node = GroupNode("scene");
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
    lifetime.own(
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
      }),
    );
  }

  // Update default settings
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

    for (Node m in node.children) {
      if (m.name != "grid") {
        m.rollLeft(elapsed * 0.0003);
        m.lookLeft(elapsed * 0.0003);
      }
    }

    RenderPass phase = selectPhase.selectedIndex == 0
        ? phaseBlinnPhong
        : phaseGourad;
    phase.draw();
    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
