import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String meshFile = "../asset/knight/knight.js";

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


   $vColor = vec3( sin($aPosition.x)/2.0+0.5,
                      cos($aPosition.y)/2.0+0.5,
                      sin($aPosition.z)/2.0+0.5);
   //vTexUV = $aTexUV;
}

""";

const String skinningFragmentShader =
    """
void main() {
  $oFragColor.rgb = $vColor;
}
""";

final ShaderObject animationVertexShader = ShaderObject("AnimationV")
  ..addAttributeVars([aPosition, aBoneIndex, aBoneWeight])
  //..AddAttributeVar(aNormal)
  //..AddAttributeVar(aTexUV)
  ..addVaryingVars([vColor])
  //..AddVaryingVar(vTexUV)
  //..AddVaryingVar(vNormal)
  ..addUniformVars([
    uPerspectiveViewMatrix,
    uModelMatrix,
    uAnimationTable,
    uTime,
  ])
  ..setBody([skinningVertexShader]);

final ShaderObject animationFragmentShader = ShaderObject("AnimationV")
  ..addVaryingVars([vColor])
  //..AddVaryingVar(vTexUV)
  //..AddUniformVar(uTextureSampler)
  ..setBody([skinningFragmentShader]);

final double kAnimTimeStep = 0.0333;

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(canvas);

  OrbitCamera orbit = OrbitCamera(20.0, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

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

  final Material matWire = Material("wire")
    ..setUniform(uColor, vm.Vector3(1.0, 1.0, 0.0));

  late BoneVisualizer boneVisualizer;
  late TypedTextureMutable animationTable;
  late List<double> animationSteps;

  Material mat = Material("mat");

  Map<String, RenderProgram> programMap = {
    "idSkeleton": sceneSkeleton.program,
    "idStatic": sceneDemo.program,
    "idAnimation": sceneAnim.program,
  };

  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    input.onChange.listen((html.Event e) {
      html.InputElement input = e.target as html.InputElement;
      print("${input.id} toggle ${input.checked}");
      programMap[input.id]!.enabled = input.checked!;
    });
  }

  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    print("initialize inputs ${input.id}");
    input.dispatchEvent(html.Event("change"));
  }

  double lastTimeMs = 0.0;
  mat.forceUniform(uTime, 0.0);

  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    phase.draw([]);

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);

    int step =
        ((timeMs / 1000.0) / kAnimTimeStep).floor() % animationSteps.length;
    mat.forceUniform(uTime, step + 0.0);

    boneVisualizer.update(timeMs / 1000.0);
  }

  List<Future<Object>> futures = [loadJson(meshFile)];

  Future.wait(futures).then((list) {
    vm.Matrix4 globalOffsetTransform = vm.Matrix4.identity();
    // Setup Mesh
    final json = list[0] as Map<String, Object?>;
    List<GeometryBuilder> gb = importGeometryFromThreeJsJson(json);
    List<Bone> skeleton = importSkeletonFromThreeJsJson(json);
    SkeletalAnimation anim = importAnimationFromThreeJsJson(json, skeleton);
    // skin mesh
    {
      MeshData md = geometryBuilderToMeshData(
        meshFile,
        sceneAnim.program,
        gb[0],
      );
      Node mesh = Node(md.name, md, mat)..rotX(-3.14 / 4);
      Node n = Node.container("wrapper", mesh);
      n.lookAt(vm.Vector3(100.0, 0.0, 0.0));
      sceneDemo.add(n);
      sceneAnim.add(n);
    }
    {
      animationSteps = [];
      for (double t = 0.0; t < anim.duration; t += kAnimTimeStep) {
        animationSteps.add(t);
      }
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
    }
    // bone wire mesh
    {
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

    animate(0.0);
  });
}
