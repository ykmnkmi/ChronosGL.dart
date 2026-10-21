import 'dart:html' as html;
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const double kShadowBias1 = 0.001;
const double kShadowBias2 = 0.001;

final ShaderObject lightVertexShaderBlinnPhongWithShadow =
    ShaderObject("LightBlinnPhongShadowV")
      ..addAttributeVars([aPosition, aNormal])
      ..addVaryingVars([vPosition, vNormal, vPositionFromLight])
      ..addUniformVars([
        uPerspectiveViewMatrix,
        uLightPerspectiveViewMatrix,
        uModelMatrix,
        uNormalMatrix,
      ])
      ..setBody([
        """
void main() {
    vec4 pos = $uModelMatrix * vec4($aPosition, 1.0);
    $vPositionFromLight = $uLightPerspectiveViewMatrix * pos;
    gl_Position = $uPerspectiveViewMatrix * pos;
    $vPosition = pos.xyz;
    $vNormal = $uNormalMatrix * $aNormal;
}
    """,
      ]);

final ShaderObject lightFragmentShaderBlinnPhongWithShadow =
    ShaderObject("LightBlinnPhongShadowF")
      ..addVaryingVars([vPosition, vNormal, vPositionFromLight])
      ..addUniformVars([uLightDescs, uLightTypes, uShininess])
      ..addUniformVars([
        uShadowMap, uEyePosition,
        //uShadowBias,
        uColor,
      ])
      ..setBody(
        [
          """
void main() {
    vec3 depth = $vPositionFromLight.xyz / $vPositionFromLight.w;
		// depth is in [-1, 1] but we want [0, 1] for the texture lookup
		depth = 0.5 * depth + vec3(0.5);

    float shadow = GetShadow(depth, $uShadowMap, $kShadowBias1, $kShadowBias2);

    ColorComponents acc = ColorComponents(vec3(0.0), vec3(0.0));
    if (shadow > 0.0) {
        acc = CombinedLight($vPosition, $vNormal, $uEyePosition,
                            $uLightDescs, $uLightTypes, $uShininess);
    }

    $oFragColor.rgb = shadow * acc.diffuse +
                       shadow * acc.specular +
                       uColor;
    $oFragColor.a = 1.0;
    // if ( $oFragColor.r != 66.0)  gl_FragColor.rgb = vec3(shadow);
}
      """,
        ],
        prolog: ["", stdLibShader, shadowMapShaderLib],
      );

final vm.Vector3 posLight = vm.Vector3(11.0, 20.0, 0.0);
final vm.Vector3 dirLight = vm.Vector3(0.0, -30.0, 0.0);

final double range = 40.0;
final double angle = math.pi / 6.0;
final double glossiness = 10.0;

// These must be in-sync with the .html file
final String idPoint = "idPoint";
final String idSpot = "idSpot";
final String idDirectional = "idDirectional";

final Map<String, Light> lightSources = {
  idDirectional: DirectionalLight("dir", dirLight, colorBlue, colorBlack, 40.0),
  idSpot: SpotLight(
    "spot",
    posLight,
    dirLight,
    colorBlue,
    colorBlack,
    range,
    angle,
    0.5,
    0.5,
    range * 1.1,
  ),
  idPoint: PointLight("point", posLight, colorLiteBlue, colorBlue, range),
};

late Light gActiveLight;

void eventRadioChanged(String name) {
  print("$name toggle ");
  gActiveLight = lightSources[name]!;
  lightSources[name]!.enabled = true;
  for (String n in lightSources.keys) {
    if (n != name) lightSources[n]!.enabled = false;
  }
}

void eventPositionChanged(String name, double value) {
  print("EventPositionChanged $name $value");
  switch (name) {
    case "posx":
      (lightSources[idSpot] as SpotLight).pos.x = value;
      (lightSources[idPoint] as PointLight).pos.x = value;
      break;
    case "posy":
      (lightSources[idSpot] as SpotLight).pos.y = value;
      (lightSources[idPoint] as PointLight).pos.y = value;
      break;
    case "posz":
      (lightSources[idSpot] as SpotLight).pos.z = value;
      (lightSources[idPoint] as PointLight).pos.z = value;
      break;
  }
}

void eventDirectionChanged(String name, double value) {
  print("EventDirectionChanged $name $value");
  switch (name) {
    case "dirx":
      (lightSources[idSpot] as SpotLight).dir.x = value;
      (lightSources[idDirectional] as DirectionalLight).dir.x = value;
      break;
    case "diry":
      (lightSources[idSpot] as SpotLight).dir.y = value;
      (lightSources[idDirectional] as DirectionalLight).dir.y = value;
      break;
    case "dirz":
      (lightSources[idSpot] as SpotLight).dir.z = value;
      (lightSources[idDirectional] as DirectionalLight).dir.z = value;
      break;
  }
}

double getInputValue(html.InputElement e) {
  return double.parse(e.value!);
}

void swallowEvent(html.Event e) {
  e.stopPropagation();
}

final Material matGray = Material("matGray")
  ..setUniform(uColor, colorGray4)
  ..setUniform(uShininess, glossiness);

final Material matObjects = Material("objects")
  ..setUniform(uColor, colorGray2)
  ..setUniform(uShininess, glossiness);

final Material matNormals = Material("normals")
  ..setUniform(uColor, colorRed)
  ..setUniform(uShininess, glossiness);

final Material lightSourceMat = Material("light")
  ..setUniform(uColor, colorYellow);

void addShapesToScene(Scene scene) {
  scene.add(
    Node("sphere", shapeIcosahedron(scene.program, subdivisions: 3), matObjects)
      ..setPos(0.0, 0.0, 0.0),
  );

  scene.add(
    Node("cube", shapeCube(scene.program), matObjects)..setPos(-5.0, 0.0, -5.0),
  );

  scene.add(
    Node(
      "cylinder",
      shapeCylinder(scene.program, 3.0, 6.0, 2.0, 32),
      matObjects,
    )..setPos(5.0, 0.0, -5.0),
  );

  scene.add(
    Node(
      "torusknot",
      shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4),
      matObjects,
    )..setPos(5.0, 0.0, 5.0),
  );

  scene.add(
    Node("plane", shapeCube(scene.program, x: 30.0, y: 0.1, z: 30.0), matGray)
      ..setPos(0.0, -10.0, 0.0),
  );
}

double kNear = 0.1;
double kFar = 50.0;

void main() {
  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final ChronosGL cgl = ChronosGL(canvas, faceCulling: false);

  final OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);

  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;

  final Perspective perspective = Perspective(orbit, kNear, kFar);

  final Illumination illumination = Illumination();
  for (Light l in lightSources.values) {
    illumination.addLight(l);
  }

  final ShadowMap shadowMap = ShadowMap(cgl, 512, 512, 0.5, 20.0);

  final UniformGroup uniforms = UniformGroup("plain")
    ..setUniform(uShadowMap, shadowMap.getMapTexture())
    ..setUniform(uCanvasSize, shadowMap.getMapSize())
    ..setUniform(uShadowBias, 0.03);

  // display scene with shadow on left part of screen.
  final RenderPhase phaseMain = RenderPhase("main", cgl);
  final Scene sceneBasic = Scene(
    "solid",
    RenderProgram(
      "solid",
      cgl,
      lightVertexShaderBlinnPhongWithShadow,
      lightFragmentShaderBlinnPhongWithShadow,
    ),
    [perspective, illumination, uniforms],
  );
  phaseMain.add(sceneBasic);

  final Scene sceneFixed = Scene(
    "solid",
    RenderProgram(
      "solid",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [perspective, illumination],
  );
  phaseMain.add(sceneFixed);

  assert(
    sceneFixed.program.hasDownwardCompatibleAttributesTo(sceneBasic.program),
  );
  addShapesToScene(sceneBasic);
  for (Node n in sceneBasic.nodes) {
    shadowMap.addShadowCaster(n);
  }

  // Same order as lightSources
  final MeshData mdLight = emptyLightVisualizer(sceneFixed.program, "light");
  sceneFixed.add(Node("light", mdLight, lightSourceMat));

  // Event Handling
  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.InputElement input = node as html.InputElement;
    input.onChange.listen((html.Event e) {
      html.InputElement input = e.target as html.InputElement;
      if (input.type == "radio") {
        eventRadioChanged(input.id);
      }
    });

    input.onInput.listen((html.Event e) {
      html.InputElement input = e.target as html.InputElement;
      if (input.type == "range") {
        String name = input.id;
        double value = getInputValue(input);
        if (name.startsWith("pos")) {
          eventPositionChanged(name, value);
        } else if (name.startsWith("dir")) {
          eventDirectionChanged(name, value);
        } else if (name == "cutoff") {
          print("set cutoff $value");
          //copyToScreen.ForceInput(uCutOff, value);
        }
      }
    });

    input.onMouseMove.listen(swallowEvent);
  }

  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.InputElement input = node as html.InputElement;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(html.Event("change"));
    input.dispatchEvent(html.Event("input"));
  }

  void resolutionChange(html.Event? ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    w = w ~/ 2;
    perspective.adjustAspect(w, h);
    phaseMain.viewPortW = w;
    phaseMain.viewPortH = h;
    // display shadowmap on right part of screen.
    shadowMap.setVisualizationViewPort(phaseMain.viewPortW, 0, w, h);
  }

  resolutionChange(null);
  html.window.onResize.listen(resolutionChange);

  double lastTimeMs = 0.0;

  //html.document.getElementById("posx").onChange.listen((html.Event ev) =>
  //light.pos.x = getInputValue(ev));

  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    //orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    vm.Matrix4 lm = gActiveLight.extractShadowProjViewMatrix();
    updateLightVisualizer(mdLight, gActiveLight);
    fps.changeExtra("$gActiveLight");

    shadowMap.compute(lm);
    uniforms.forceUniform(uLightPerspectiveViewMatrix, lm);
    // render scene utilizing shadow map
    phaseMain.draw();
    shadowMap.visualize();

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  animate(0.0);
}
