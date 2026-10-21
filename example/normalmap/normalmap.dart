import 'dart:async';
import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

String dir = "../asset/leeperrysmith/";
String modelFile = "${dir}LeePerrySmith.js";
String normalmapFile = "${dir}Infinite-Level_02_Tangent_SmoothUV.jpg";
String textureFile = "${dir}Map-COL.jpg";
String specularmapFile = "${dir}Map-SPEC.jpg";

final ShaderObject vertexShader = ShaderObject("LightBlinnPhongV")
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

final ShaderObject fragmentShader = ShaderObject("LightBlinnPhongF")
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
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(canvas);

  OrbitCamera orbit = OrbitCamera(0.5, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 100.0);
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

  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );
  Scene sceneFixed = Scene(
    "Fixed",
    RenderProgram(
      "Fixed",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [perspective, illumination],
  );
  phase.add(sceneFixed);

  Material lightSourceMat = Material("light")
    ..setUniform(uColor, colorYellow)
    ..setUniform(uShininess, 25.0);
  Node shapePointLight = Node(
    "pointLight",
    shapeIcosahedron(sceneFixed.program, subdivisions: 4, scale: 0.1),
    lightSourceMat,
  )..setPosFromVec(posLight);
  sceneFixed.add(shapePointLight);

  Scene sceneMain = Scene(
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

  Material mat = Material("mat")
    ..setUniform(uColor, colorGray4)
    ..setUniform(uShininess, 25.0);

  List<Future<Object>> futures = [
    loadJson(modelFile),
    loadImage(textureFile),
    loadImage(specularmapFile),
    loadImage(normalmapFile),
  ];

  Future.wait(futures).then((list) {
    // Setup Maps
    ImageTexture texture = ImageTexture(cgl, textureFile, list[1]);
    /*
    Texture specularmap =
        new ImageTexture(cgl, specularmapFile, list[2]);
    Texture normalmap = new ImageTexture(cgl, normalmapFile, list[3]);
    */
    mat.setUniform(uTexture, texture);
    //mat.setUniform(uNormalMap, normalmap);
    //mat.setUniform(uSpecularMap, specularmap);
    mat.setUniform(uNormalScale, 0.8);

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
