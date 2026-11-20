import 'dart:js_interop';
import 'dart:async';

import 'package:web/web.dart' as web;

import "dart:math" as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

const String dir = "../asset/leeperrysmith/";
const String modelFile = "${dir}LeePerrySmith.js";
const String bumpmapFile = "${dir}Infinite-Level_02_Disp_NoSmoothUV-4096.jpg";

final ShaderObject vertexShader = ShaderObject.vertex("LightBlinnPhongFancyV")
  ..addAttributeVars([aPosition, aNormal, aTexUV])
  ..addVaryingVars([vPosition, vNormal, vTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
  ..setBody([
    """
void main() {
    vec4 pos = $uModelMatrix * vec4($aPosition, 1.0);
    gl_Position = $uPerspectiveViewMatrix * pos;
    $vPosition = pos.xyz;
    $vTexUV = $aTexUV;
    $vNormal = $uNormalMatrix * $aNormal;
}
""",
  ]);

final ShaderObject fragmentShader =
    ShaderObject.fragment("LightBlinnPhongFancyF")
      ..addVaryingVars([vPosition, vNormal, vTexUV])
      ..addUniformVars([uLightDescs, uLightTypes, uShininess])
      ..addUniformVars([uEyePosition, uColor])
      ..addUniformVars([uBumpScale, uBumpMap])
      ..setBody(
        [
          """
void main() {
   vec3 normal = normalize($vNormal);
   vec2 uv = dHdxy_fwd($vTexUV, $uBumpScale, $uBumpMap);
   normal = perturbNormalArb($vPosition, normal, uv);
   ColorComponents acc = CombinedLight($vPosition - $uEyePosition,
                                    normal,
                                    $uEyePosition,
                                    $uLightDescs,
                                    $uLightTypes,
                                    $uShininess);
    $oFragColor.rgb = acc.diffuse
                    + acc.specular
                    + uColor;
   $oFragColor.a = 1.0;
}
""",
        ],
        prolog: [stdLibShaderDerivative, stdLibShader],
      );

final vm.Vector3 colSkin = vm.Vector3(0.333, 0.157, 0.067);
//const vm.Vector3 colGray = new vm.Vector3(0.2, 0.2, 0.2);
final vm.Vector3 dirLight = vm.Vector3(-1.0, -1.0, 0.0);
final vm.Vector3 colDiffuse = vm.Vector3.all(0.3);
final vm.Vector3 colSpecular = vm.Vector3.all(0.133);

final double glossiness = 10.0;
final double angle = math.pi / 6.0;

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
  final camera = PerspectiveCamera(near: 0.01, far: 1000);
  final orbit = lifetime.own(
    OrbitControls.forCamera(camera: camera, eventTarget: canvas, radius: 0.3),
  );
  final perspective = CameraUniforms(camera);

  final DirectionalLight light = DirectionalLight(
    "dir",
    dirLight,
    colDiffuse,
    colSpecular,
    40.0,
  );

  final Illumination illumination = Illumination();
  illumination.addLight(light);

  final phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  final RenderBatch sceneMain = lifetime.ownBatch(
    RenderBatch(
      "main",
      lifetime.own(RenderProgram("main", cgl, vertexShader, fragmentShader)),
      [perspective, illumination],
    ),
  );
  phase.add(sceneMain);

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

  List<Future<Object>> futures = [loadJson(modelFile), loadImage(bumpmapFile)];

  Future.wait(futures).then((list) {
    if (lifetime.isDisposed) return;
    // Setup Bumpmap
    final TextureProperties tp = const TextureProperties(clamp: true)
        .withMipmapLinear();
    final Texture bumpmap = lifetime.own(
      ImageTexture.fromImage(
        context: cgl,
        name: bumpmapFile,
        image: list[1] as web.HTMLImageElement,
        properties: tp,
      ),
    );
    final Material mat = lifetime.own(Material("mat"))
      ..setUniform(uColor, colSkin)
      ..setUniform(uShininess, glossiness)
      ..setUniform(uBumpMap, bumpmap)
      ..setUniform(uBumpScale, 0.01);
    // Setup Mesh
    List<GeometryBuilder> gbs = importGeometryFromThreeJsJson(
      list[0] as Map<String, Object?>,
    );
    print(gbs[0]);
    GpuMesh md = lifetime.own(
      uploadGeometry(modelFile, sceneMain.program, gbs[0]),
    );

    Node mesh = MeshNode(md.name, md, mat);
    Node n = GroupNode("wrapper", mesh);
    //n.invert = true;
    n.lookAt(vm.Vector3(100.0, 0.0, 0.0));
    //n.matrix.scale(0.02);
    sceneMain.add(n);
    // GO!
    lifetime.requestAnimationFrame(onFrame);
  });
}
