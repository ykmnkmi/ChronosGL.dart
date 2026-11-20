import 'dart:js_interop';
import 'dart:async';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

String dir = "../asset/leeperrysmith/";
String modelFile = "${dir}LeePerrySmith.js";
String normalmapFile = "${dir}Infinite-Level_02_Tangent_SmoothUV.jpg";
String textureFile = "${dir}Map-COL.jpg";
String specularmapFile = "${dir}Map-SPEC.jpg";

final ShaderObject vertexShader = ShaderObject.vertex("LightBlinnPhongV")
  ..addAttributeVars([aPosition, aNormal, aTexUV])
  ..addVaryingVars([vPosition, vNormal, vTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uNormalMatrix])
  ..setBody([
    """
void main() {
    vec4 pos = $uModelMatrix * vec4($aPosition, 1.0);
    gl_Position = $uPerspectiveViewMatrix * pos;
    $vPosition = pos.xyz;
    $vNormal = $uNormalMatrix * $aNormal;
    $vTexUV = $aTexUV;
}
""",
  ]);

final ShaderObject fragmentShader = ShaderObject.fragment("LightBlinnPhongF")
  ..addVaryingVars([vPosition, vNormal, vTexUV])
  ..addUniformVars([uLightDescs, uLightTypes, uShininess])
  ..addUniformVars([uEyePosition, uColor, uTexture])
  ..setBody(
    [
      """
void main() {
    ColorComponents acc = CombinedLight($vPosition - $uEyePosition,
                                        $vNormal,
                                        $uEyePosition,
                                        $uLightDescs,
                                        $uLightTypes,
                                        $uShininess);
    
    vec4 diffuseMap = texture($uTexture, $vTexUV );
    
    $oFragColor.rgb = diffuseMap.rgb + acc.diffuse + acc.specular + uColor;
    $oFragColor.a = 1.0;
}

""",
    ],
    prolog: [stdLibShader],
  );

vm.Vector3 posLight = vm.Vector3(0.5, 1.0, 0.0);
vm.Vector3 dirLight = vm.Vector3(0.0, 10.0, 0.0);
vm.Vector3 colDiffuse = vm.Vector3.all(0.866);
vm.Vector3 colSpecular = vm.Vector3.all(0.133);

void main() {
  FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL.fromCanvas(canvas);

  final camera = PerspectiveCamera(near: 0.1, far: 100.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 0.5,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  CameraUniforms perspective = CameraUniforms(camera);
  Illumination illumination = Illumination();
  illumination.addLight(
    SpotLight(
      "spot",
      posLight,
      posLight,
      colDiffuse,
      colSpecular,
      50.0,
      0.95,
      2.0,
      1.0,
      50.0,
    ),
  );

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );
  RenderBatch sceneFixed = lifetime.ownBatch(
    RenderBatch(
      "Fixed",
      lifetime.own(
        RenderProgram.create(
          name: "Fixed",
          context: cgl,
          vertexShader: solidColorVertexShader,
          fragmentShader: solidColorFragmentShader,
        ),
      ),
      [perspective, illumination],
    ),
  );
  phase.add(sceneFixed);

  Material lightSourceMat = lifetime.own(Material("light"))
    ..setUniform(uColor, colorYellow.toVector3())
    ..setUniform(uShininess, 25.0);
  Node shapePointLight = MeshNode(
    "pointLight",
    lifetime.own(
      shapeIcosahedron(sceneFixed.program, subdivisions: 4, scale: 0.1),
    ),
    lightSourceMat,
  )..setPosFromVec(posLight);
  sceneFixed.add(shapePointLight);

  RenderBatch sceneMain = lifetime.ownBatch(
    RenderBatch(
      "main",
      lifetime.own(
        RenderProgram.create(
          name: "main",
          context: cgl,
          vertexShader: vertexShader,
          fragmentShader: fragmentShader,
        ),
      ),
      [perspective, illumination],
    ),
  );
  phase.add(sceneMain);

  double lastTimeMs = 0.0;
  bool firstFrame = true;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000;
    orbit.update(elapsed / 1000);
    phase.draw();

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Material mat = lifetime.own(Material("mat"))
    ..setUniform(uColor, colorGray4.toVector3())
    ..setUniform(uShininess, 25.0);

  List<Future<Object>> futures = [
    loadJson(modelFile),
    loadImage(textureFile),
    loadImage(specularmapFile),
    loadImage(normalmapFile),
  ];

  Future.wait(futures).then((list) {
    if (lifetime.isDisposed) return;
    // Setup Maps
    ImageTexture texture = lifetime.own(
      ImageTexture.fromImage(
        context: cgl,
        name: textureFile,
        image: list[1] as web.HTMLImageElement,
      ),
    );
    mat.setUniform(uTexture, texture);
    //mat.setUniform(uNormalMap, normalmap);
    //mat.setUniform(uSpecularMap, specularmap);
    mat.setUniform(uNormalScale, 0.8);

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
