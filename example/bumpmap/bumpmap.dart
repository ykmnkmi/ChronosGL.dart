import 'dart:async';
import 'dart:html' as html;
import "dart:math" as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String dir = "../asset/leeperrysmith/";
const String modelFile = "${dir}LeePerrySmith.js";
const String bumpmapFile = "${dir}Infinite-Level_02_Disp_NoSmoothUV-4096.jpg";

final ShaderObject vertexShader = ShaderObject("LightBlinnPhongFancyV")
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

final ShaderObject fragmentShader = ShaderObject("LightBlinnPhongFancyF")
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
  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);

  final OrbitCamera orbit = OrbitCamera(0.3, 0.0, 0.0, canvas)
    ..mouseWheelFactor = -0.001;
  final Perspective perspective = Perspective(orbit, 0.01, 1000.0);

  final DirectionalLight light = DirectionalLight(
    "dir",
    dirLight,
    colDiffuse,
    colSpecular,
    40.0,
  );

  final Illumination illumination = Illumination();
  illumination.addLight(light);

  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );

  final Scene sceneMain = Scene(
    "main",
    RenderProgram("main", cgl, vertexShader, fragmentShader),
    [perspective, illumination],
  );
  phase.add(sceneMain);

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

  List<Future<Object>> futures = [loadJson(modelFile), loadImage(bumpmapFile)];

  Future.wait(futures).then((list) {
    // Setup Bumpmap
    final TextureProperties tp = TextureProperties()
      ..setMipmapLinear()
      ..clamp = true;
    final Texture bumpmap = ImageTexture(cgl, bumpmapFile, list[1], tp);
    final Material mat = Material("mat")
      ..setUniform(uColor, colSkin)
      ..setUniform(uShininess, glossiness)
      ..setUniform(uBumpMap, bumpmap)
      ..setUniform(uBumpScale, 0.01);
    // Setup Mesh
    List<GeometryBuilder> gbs = importGeometryFromThreeJsJson(
      list[0] as Map<String, Object?>,
    );
    print(gbs[0]);
    MeshData md = geometryBuilderToMeshData(
      modelFile,
      sceneMain.program,
      gbs[0],
    );

    Node mesh = Node(md.name, md, mat);
    Node n = Node.container("wrapper", mesh);
    //n.invert = true;
    n.lookAt(vm.Vector3(100.0, 0.0, 0.0));
    //n.matrix.scale(0.02);
    sceneMain.add(n);
    // GO!
    animate(0.0);
  });
}
