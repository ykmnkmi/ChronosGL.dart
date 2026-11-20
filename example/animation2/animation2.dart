import 'dart:js_interop';
import 'dart:async';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/shaders.dart';

import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

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

final ShaderObject animationVertexShader = ShaderObject.vertex("AnimationV")
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

final ShaderObject animationFragmentShader = ShaderObject.fragment("AnimationV")
  ..addVaryingVars([vColor])
  //..AddVaryingVar(vTexUV)
  //..AddUniformVar(uTextureSampler)
  ..setBody([skinningFragmentShader]);

final double kAnimTimeStep = 0.0333;

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

  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 20.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);

  final RenderBatch sceneAnim = lifetime.ownBatch(
    RenderBatch(
      "animation",
      lifetime.own(
        RenderProgram(
          "animation",
          cgl,
          animationVertexShader,
          animationFragmentShader,
        ),
      ),
      [perspective],
    ),
  );

  final RenderBatch sceneSkeleton = lifetime.ownBatch(
    RenderBatch(
      "solid",
      lifetime.own(
        RenderProgram(
          "solid",
          cgl,
          solidColorVertexShader,
          solidColorFragmentShader,
        ),
      ),
      [perspective],
    ),
  );

  final RenderBatch sceneDemo = lifetime.ownBatch(
    RenderBatch(
      "demo",
      lifetime.own(
        RenderProgram("demo", cgl, demoVertexShader, demoFragmentShader),
      ),
      [perspective],
    ),
  );

  assert(
    sceneSkeleton.program.hasDownwardCompatibleAttributesTo(sceneAnim.program),
  );

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl))
    ..add(sceneSkeleton)
    ..add(sceneAnim)
    ..add(sceneDemo);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  final Material matWire = lifetime.own(Material("wire"))
    ..setUniform(uColor, vm.Vector3(1.0, 1.0, 0.0));

  late BoneVisualizer boneVisualizer;
  late TypedTextureMutable animationTable;
  late List<double> animationSteps;

  Material mat = lifetime.own(Material("mat"));

  Map<String, RenderProgram> programMap = {
    "idSkeleton": sceneSkeleton.program,
    "idStatic": sceneDemo.program,
    "idAnimation": sceneAnim.program,
  };

  for (web.Node node in web.JSImmutableListWrapper(
    web.document.getElementsByTagName("input"),
  )) {
    web.HTMLElement input = node as web.HTMLElement;
    lifetime.own(
      input.onChange.listen((web.Event e) {
        web.HTMLInputElement input = e.target as web.HTMLInputElement;
        print("${input.id} toggle ${input.checked}");
        programMap[input.id]!.enabled = input.checked;
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

  double? lastTimeMs;
  mat.forceUniform(uTime, 0.0);

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
    phase.draw([]);

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);

    int step =
        ((timeMs / 1000.0) / kAnimTimeStep).floor() % animationSteps.length;
    mat.forceUniform(uTime, step + 0.0);

    boneVisualizer.update(timeMs / 1000.0);
  }

  onFrame = animate.toJS;

  List<Future<Object>> futures = [loadJson(meshFile)];

  Future.wait(futures).then((list) {
    if (lifetime.isDisposed) return;
    vm.Matrix4 globalOffsetTransform = vm.Matrix4.identity();
    // Setup Mesh
    final json = list[0] as Map<String, Object?>;
    List<GeometryBuilder> gb = importGeometryFromThreeJsJson(json);
    List<Bone> skeleton = importSkeletonFromThreeJsJson(json);
    SkeletalAnimation anim = importAnimationFromThreeJsJson(json, skeleton);
    // skin mesh
    {
      GpuMesh md = lifetime.own(
        uploadGeometry(meshFile, sceneAnim.program, gb[0]),
      );
      Node mesh = MeshNode(md.name, md, mat)..rotX(-3.14 / 4);
      Node n = GroupNode("wrapper", mesh);
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
      animationTable = lifetime.own(
        TypedTextureMutable(
          cgl,
          "anim",
          skeleton.length * 4,
          animationSteps.length,
          glRgba32f,
          texturePropertiesFramebuffer,
          glRgba,
          glFloat,
          animationData,
        ),
      );
      mat.setUniform(uAnimationTable, animationTable);
    }
    // bone wire mesh
    {
      boneVisualizer = lifetime.own(
        BoneVisualizer(sceneSkeleton.program, matWire, skeleton, anim),
      );
      Node mesh = boneVisualizer.mesh..rotX(3.14 / 4);
      Node n = GroupNode("wrapper", mesh);
      n.lookAt(vm.Vector3(100.0, 0.0, 0.0));
      sceneSkeleton.add(n);
    }

    lifetime.requestAnimationFrame(onFrame);
  });
}
