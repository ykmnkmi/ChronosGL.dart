import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';

import 'package:web/web.dart' as web;

import 'dart:async';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

const String meshFile = "../asset/monster/monster.json";
const String textureFile = "../asset/monster/monster.jpg";

const String skinningVertexShader =
    """
mat4 GetBoneMatrix(sampler2D table, int index, int time) {
    vec4 v1 = texelFetch(table, ivec2(index * 4 + 0, time), 0);
    vec4 v2 = texelFetch(table, ivec2(index * 4 + 1, time), 0);
    vec4 v3 = texelFetch(table, ivec2(index * 4 + 2, time), 0);
    vec4 v4 = texelFetch(table, ivec2(index * 4 + 3, time), 0);
    return mat4(v1, v2, v3, v4);
    //return uBoneMatrices[index];
}

mat4 adjustMatrix(sampler2D table, vec4 weights, ivec4 indices, int time) {
    return weights.x * GetBoneMatrix(table, indices.x, time) +
           weights.y * GetBoneMatrix(table, indices.y, time) +
           weights.z * GetBoneMatrix(table, indices.z, time) +
           weights.w * GetBoneMatrix(table, indices.w, time);
}

void main() {
   mat4 skinMat = uModelMatrix * adjustMatrix($uAnimationTable,
                                              $aBoneWeight,
                                              ivec4($aBoneIndex),
                                              int($uTime));
   vec4 pos = skinMat * vec4($aPosition, 1.0);
   // vPosition = pos.xyz;
   // This is not quite accurate
   //$vNormal = normalize(mat3(skinMat) * aNormal);
   gl_Position = $uPerspectiveViewMatrix * pos;

   $vTexUV = $aTexUV;
}

""";

const String skinningFragmentShader =
    """
void main() {
  $oFragColor = texture($uTexture, $vTexUV);
}
""";

final ShaderObject animationVertexShader = ShaderObject("AnimationV")
  ..addAttributeVars([aPosition, aTexUV, aBoneIndex, aBoneWeight])
  //..AddAttributeVar(aNormal)
  ..addVaryingVars([vTexUV])
  //..AddVaryingVar(vNormal)
  ..addUniformVars([
    uPerspectiveViewMatrix,
    uModelMatrix,
    uAnimationTable,
    uTime,
  ])
  ..setBody([skinningVertexShader]);

final ShaderObject animationFragmentShader = ShaderObject("AnimationV")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uTexture])
  ..setBody([skinningFragmentShader]);

final double kAnimTimeStep = 0.0333;

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = OrbitCamera(5000.0, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 1.0, 10000.0);

  // Shows the actual animation.
  final Scene sceneAnim = Scene(
    "animation",
    RenderProgram(
      "animation",
      cgl,
      animationVertexShader,
      animationFragmentShader,
    ),
    [perspective],
  );

  // Shows a bone only animation.
  final Scene sceneSkeleton = Scene(
    "solid",
    RenderProgram(
      "solid",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [perspective],
  );

  // Shows the un-animated object.
  final Scene sceneDemo = Scene(
    "demo",
    RenderProgram("demo", cgl, demoVertexShader, demoFragmentShader),
    [perspective],
  );

  assert(
    sceneSkeleton.program.hasDownwardCompatibleAttributesTo(sceneAnim.program),
  );

  final RenderPhaseResizeAware phase =
      RenderPhaseResizeAware("main", cgl, canvas, perspective)
        ..add(sceneSkeleton)
        ..add(sceneAnim)
        ..add(sceneDemo);

  final Material matWire = Material("wire")..setUniform(uColor, colorYellow);

  final Material mat = Material("mat");
  late TypedTextureMutable animationTable;
  late List<double> animationSteps;
  late BoneVisualizer boneVisualizer;

  Map<String, RenderProgram> programMap = {
    "idSkeleton": sceneSkeleton.program,
    "idStatic": sceneDemo.program,
    "idAnimation": sceneAnim.program,
  };

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    input.onChange.listen((web.Event e) {
      web.HTMLInputElement input = e.target as web.HTMLInputElement;
      print("${input.id} toggle ${input.checked}");
      programMap[input.id]!.enabled = input.checked;
    });
  }

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(web.Event("change"));
  }

  double lastTimeMs = 0.0;

  mat.forceUniform(uTime, 0.0);

  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    phase.draw();

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);

    int step =
        ((timeMs / 1000.0) / kAnimTimeStep).floor() % animationSteps.length;
    mat.forceUniform(uTime, step + 0.0);
    boneVisualizer.update(timeMs / 1000.0);
  }

  onFrame = animate.toJS;

  List<Future<Object>> futures = [loadJson(meshFile), loadImage(textureFile)];

  Future.wait(futures).then((list) {
    // Setup Texture
    Texture tex = ImageTexture(cgl, textureFile, list[1]);
    mat.setUniform(uTexture, tex);

    final json = list[0] as Map<String, Object?>;
    final meshJson =
        (json['meshes'] as List<Object?>)[0] as Map<String, Object?>;
    final animJson =
        (json['animations'] as List<Object?>)[0] as Map<String, Object?>;
    vm.Matrix4 globalOffsetTransform = vm.Matrix4.identity();
    List<Bone> skeleton = importSkeletonFromAssimp2Json(json);
    final GeometryBuilder gb = importGeometryFromAssimp2JsonMesh(
      meshJson,
      skeleton,
    );
    SkeletalAnimation anim = importAnimationFromAssimp2Json(animJson, skeleton);
    print("Imnported $anim");
    {
      MeshData md = geometryBuilderToMeshData(meshFile, sceneAnim.program, gb);
      Node mesh = Node(md.name, md, mat)..rotX(-3.14 / 4);
      Node n = Node.container("wrapper", mesh);
      n.lookAt(vm.Vector3(100.0, 0.0, 0.0));
      sceneDemo.add(n);
      sceneAnim.add(n);
    }
    animationSteps = [];
    for (double t = 0.0; t < anim.duration; t += kAnimTimeStep) {
      animationSteps.add(t);
    }

    {
      Float32List animationData = createAnimationTable(
        skeleton,
        globalOffsetTransform,
        anim,
        animationSteps,
      );
      animationTable = TypedTextureMutable(
        cgl,
        "anim",
        skeleton.length * 4,
        animationSteps.length,
        glRgba32f,
        texturePropertiesFramebuffer,
        glRgba,
        glFloat,
        animationData,
      );
      mat.setUniform(uAnimationTable, animationTable);

      boneVisualizer = BoneVisualizer(
        sceneSkeleton.program,
        matWire,
        skeleton,
        anim,
      );

      Node mesh = boneVisualizer.mesh..rotX(3.14 / 4);
      Node n = Node.container("wrapper", mesh);
      n.lookAt(vm.Vector3(100.0, 0.0, 0.0));
      sceneSkeleton.add(n);
    }

    // Start
    animate(0.0);
  });
}
