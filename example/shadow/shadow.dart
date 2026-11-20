import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

const double kShadowBias1 = 0.001;
const double kShadowBias2 = 0.001;

final ShaderObject lightVertexShaderBlinnPhongWithShadow =
    ShaderObject.vertex("LightBlinnPhongShadowV")
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
    ShaderObject.fragment("LightBlinnPhongShadowF")
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
  idDirectional: DirectionalLight(
    "dir",
    dirLight,
    colorBlue.toVector3(),
    colorBlack.toVector3(),
    40.0,
  ),
  idSpot: SpotLight(
    "spot",
    posLight,
    dirLight,
    colorBlue.toVector3(),
    colorBlack.toVector3(),
    range,
    angle,
    0.5,
    0.5,
    range * 1.1,
  ),
  idPoint: PointLight(
    "point",
    posLight,
    colorLiteBlue.toVector3(),
    colorBlue.toVector3(),
    range,
  ),
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

double getInputValue(web.HTMLInputElement e) {
  return double.parse(e.value);
}

void swallowEvent(web.Event e) {
  e.stopPropagation();
}

final Material matGray = lifetime.own(Material("matGray"))
  ..setUniform(uColor, colorGray4.toVector3())
  ..setUniform(uShininess, glossiness);

final Material matObjects = lifetime.own(Material("objects"))
  ..setUniform(uColor, colorGray2.toVector3())
  ..setUniform(uShininess, glossiness);

final Material matNormals = lifetime.own(Material("normals"))
  ..setUniform(uColor, colorRed.toVector3())
  ..setUniform(uShininess, glossiness);

final Material lightSourceMat = lifetime.own(Material("light"))
  ..setUniform(uColor, colorYellow.toVector3());

void addShapesToScene(RenderBatch scene) {
  scene.add(
    MeshNode(
      "sphere",
      lifetime.own(shapeIcosahedron(scene.program, subdivisions: 3)),
      matObjects,
    )..setPos(0.0, 0.0, 0.0),
  );

  scene.add(
    MeshNode("cube", lifetime.own(shapeCube(scene.program)), matObjects)
      ..setPos(-5.0, 0.0, -5.0),
  );

  scene.add(
    MeshNode(
      "cylinder",
      lifetime.own(shapeCylinder(scene.program, 3.0, 6.0, 2.0, 32)),
      matObjects,
    )..setPos(5.0, 0.0, -5.0),
  );

  scene.add(
    MeshNode(
      "torusknot",
      lifetime.own(shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4)),
      matObjects,
    )..setPos(5.0, 0.0, 5.0),
  );

  scene.add(
    MeshNode(
      "plane",
      lifetime.own(shapeCube(scene.program, x: 30.0, y: 0.1, z: 30.0)),
      matGray,
    )..setPos(0.0, -10.0, 0.0),
  );
}

double kNear = 0.1;
double kFar = 50.0;

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
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas, faceCulling: false);

  final camera = PerspectiveCamera(near: kNear, far: kFar);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );

  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;

  final CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final Illumination illumination = Illumination();
  for (Light l in lightSources.values) {
    illumination.addLight(l);
  }

  final ShadowMap shadowMap = lifetime.own(ShadowMap(cgl, 512, 512, 0.5, 20.0));
  final ShadowMapVisualizer shadowVisualizer = lifetime.own(
    ShadowMapVisualizer(shadowMap),
  );
  final UniformGroup uniforms = lifetime.own(UniformGroup("plain"))
    ..setUniform(uShadowMap, shadowMap.getMapTexture())
    ..setUniform(uCanvasSize, shadowMap.getMapSize())
    ..setUniform(uShadowBias, 0.03);

  // display scene with shadow on left part of screen.
  final RenderPass phaseMain = lifetime.ownPass(RenderPass("main", cgl));
  final RenderBatch sceneBasic = lifetime.ownBatch(
    RenderBatch(
      "solid",
      lifetime.own(
        RenderProgram.create(
          name: "solid",
          context: cgl,
          vertexShader: lightVertexShaderBlinnPhongWithShadow,
          fragmentShader: lightFragmentShaderBlinnPhongWithShadow,
        ),
      ),
      [perspective, illumination, uniforms],
    ),
  );
  phaseMain.add(sceneBasic);

  final RenderBatch sceneFixed = lifetime.ownBatch(
    RenderBatch(
      "solid",
      lifetime.own(
        RenderProgram.create(
          name: "solid",
          context: cgl,
          vertexShader: solidColorVertexShader,
          fragmentShader: solidColorFragmentShader,
        ),
      ),
      [perspective, illumination],
    ),
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
  final GpuMesh mdLight = lifetime.own(
    emptyLightVisualizer(sceneFixed.program, "light"),
  );
  sceneFixed.add(MeshNode("light", mdLight, lightSourceMat));

  // Event Handling
  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLInputElement input = node as web.HTMLInputElement;
    lifetime.own(
      input.onChange.listen((web.Event e) {
        web.HTMLInputElement input = e.target as web.HTMLInputElement;
        if (input.type == "radio") {
          eventRadioChanged(input.id);
        }
      }),
    );

    lifetime.own(
      input.onInput.listen((web.Event e) {
        web.HTMLInputElement input = e.target as web.HTMLInputElement;
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
      }),
    );

    lifetime.own(input.onMouseMove.listen(swallowEvent));
  }

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLInputElement input = node as web.HTMLInputElement;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(web.Event("change"));
    input.dispatchEvent(web.Event("input"));
  }

  bool updateViewports() {
    final width = viewport.drawingBufferWidthPixels ~/ 2;
    final height = viewport.drawingBufferHeightPixels;
    if (width == 0 || height == 0) return false;
    viewport.setViewport(width: width, height: height);
    phaseMain.viewPortW = width;
    phaseMain.viewPortH = height;
    shadowVisualizer.setViewport(width, 0, width, height);
    return true;
  }

  double lastTimeMs = 0.0;
  bool firstFrame = true;

  //web.document.getElementById("posx").onChange.listen((web.Event ev) =>
  //light.pos.x = getInputValue(ev));

  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update() || !updateViewports()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    //orbit.azimuth += 0.06 * elapsed / 1000;
    orbit.update(elapsed / 1000);

    vm.Matrix4 lm = gActiveLight.extractShadowProjViewMatrix();
    updateLightVisualizer(mdLight, gActiveLight);
    fps.changeExtra("$gActiveLight");

    shadowMap.compute(lm);
    uniforms.forceUniform(uLightPerspectiveViewMatrix, lm);
    // render scene utilizing shadow map
    phaseMain.draw();
    shadowVisualizer.draw();

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
