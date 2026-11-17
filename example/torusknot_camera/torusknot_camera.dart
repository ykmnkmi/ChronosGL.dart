import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'torus_knot_controls.dart';

void updateTorusTexture(double time, web.HTMLCanvasElement canvas) {
  web.CanvasRenderingContext2D ctx =
      canvas.getContext('2d') as web.CanvasRenderingContext2D;
  double sint = math.sin(time);
  double n = (sint + 1) / 2;
  ctx.rect(0, 0, canvas.width, canvas.height);
  // Direction of gradient is diagonal
  web.CanvasGradient grad = ctx.createLinearGradient(
    0,
    0,
    canvas.width * n,
    canvas.height,
  );
  double cs1 = (360 * n).floorToDouble();
  double cs2 = (90 * n).floorToDouble();
  grad.addColorStop(0, 'hsla($cs1, 100%, 40%, 1)');
  grad.addColorStop(0.2, 'black');
  grad.addColorStop(0.3, 'black');
  grad.addColorStop(0.5, 'hsla($cs2, 100%, 40%, 1)');
  grad.addColorStop(0.7, 'black');
  grad.addColorStop(0.9, 'black');
  grad.addColorStop(1, 'hsla($cs1, 100%, 40%, 1)');
  ctx.fillStyle = grad;
  ctx.fill();
}

final List<vm.Vector2> T = [
  vm.Vector2(1.0, 0.2),
  vm.Vector2(0.0, 0.7),
  vm.Vector2(0.0, 0.7),
];

MeshData torusKnotWithCustumUV(RenderProgram program) {
  final int w = 17; // Try different values
  final int h = 128;

  final GeometryBuilder gb = torusKnotGeometry(
    segmentsR: h,
    segmentsT: w,
    computeUVs: false,
    computeNormals: false,
    wrap: true,
  );
  //assert(gb.vertices.length == w * h);

  gb.enableAttribute(aTexUV);
  final List<vm.Vector2> uvs = [];
  for (int n = 0; n < gb.vertices.length; n++) {
    uvs.add(T[n % T.length]);
  }

  gb.addAttributesVector2(aTexUV, uvs);

  return geometryBuilderToMeshData("torusknot", program, gb);
}

void addHexagonalWireframeCenters(GeometryBuilder gb) {
  List<vm.Vector4> center = List.generate(
    gb.vertices.length,
    (i) => vm.Vector4.zero(),
  );

  List<vm.Vector4> center3 = [
    vm.Vector4(1.0, 100.0, 0.0, 0.0),
    vm.Vector4(100.0, 1.0, 0.0, 0.0),
    vm.Vector4(100.0, 100.0, 1.0, 0.0),
    vm.Vector4(1.0, 100.0, 100.0, 0.0),
    vm.Vector4(0.0, 1.0, 100.0, 0.0),
    vm.Vector4(0.0, 100.0, 1.0, 0.0),
    vm.Vector4(1.0, 100.0, 100.0, 0.0),
    vm.Vector4(0.0, 1.0, 100.0, 0.0),
    vm.Vector4(0.0, 100.0, 1.0, 0.0),
    vm.Vector4(1.0, 100.0, 0.0, 0.0),
    vm.Vector4(100.0, 1.0, 0.0, 0.0),
    vm.Vector4(100.0, 100.0, 1.0, 0.0),
    vm.Vector4(1.0, 0.0, 100.0, 0.0),
    vm.Vector4(100.0, 1.0, 100.0, 0.0),
    vm.Vector4(100.0, 0.0, 1.0, 0.0),
    vm.Vector4(1.0, 0.0, 100.0, 0.0),
    vm.Vector4(100.0, 1.0, 100.0, 0.0),
    vm.Vector4(100.0, 0.0, 1.0, 0.0),
  ];

  int count = 0;
  for (Face3 f in gb.faces3) {
    center[f.a] = center3[count + 0];
    center[f.b] = center3[count + 1];
    center[f.c] = center3[count + 2];
    count += 3;
    if (count == center3.length) count = 0;
  }

  vm.Vector4 a4 = vm.Vector4(1.0, 0.0, 0.0, 1.0);
  vm.Vector4 b4 = vm.Vector4(1.0, 1.0, 0.0, 1.0);
  vm.Vector4 c4 = vm.Vector4(0.0, 1.0, 0.0, 1.0);
  vm.Vector4 d4 = vm.Vector4(0.0, 0.0, 0.0, 1.0);

  for (Face4 f in gb.faces4) {
    center[f.a] = a4.clone();
    center[f.b] = b4.clone();
    center[f.c] = c4.clone();
    center[f.d] = d4.clone();
  }
  gb.attributes[aCenter] = center;
}

class SimpleScene {
  void draw(ChronosGL cgl, double timeMs, CameraUniforms perspective) {
    program.draw(mesh, [perspective, mat]);
  }

  late Material mat;
  late RenderProgram program;
  late MeshData mesh;
}

class SceneStars extends SimpleScene {
  SceneStars(ChronosGL cgl, int num, double dim) {
    program = RenderProgram(
      "stars",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    );
    mat = makeStarMaterial(cgl)
      ..setUniform(uModelMatrix, vm.Matrix4.identity());
    mesh = makeStarMesh(program, 2000, dim, random: math.Random());
  }
}

class SceneTextured extends SimpleScene {
  SceneTextured(ChronosGL cgl) {
    canvas2d = web.document.querySelector('#texture') as web.HTMLCanvasElement;
    updateTorusTexture(0.0, canvas2d);
    generatedTexture = ImageTexture(cgl, "gen", canvas2d);
    mat = Material.transparent("torus", blendEquationMix)
      ..setUniform(uTexture, generatedTexture)
      ..setUniform(uModelMatrix, vm.Matrix4.identity())
      ..setUniform(uColor, vm.Vector3.zero());
    program = RenderProgram(
      "textured",
      cgl,
      texturedVertexShader,
      texturedFragmentShader,
    );
    mesh = torusKnotWithCustumUV(program);
  }

  @override
  void draw(ChronosGL cgl, double timeMs, CameraUniforms perspective) {
    updateTorusTexture(timeMs / 1000, canvas2d);
    generatedTexture.setImageData(canvas2d);
    program.draw(mesh, [perspective, mat]);
  }

  late web.HTMLCanvasElement canvas2d;
  late ImageTexture generatedTexture;
}

class SceneWireframe extends SimpleScene {
  SceneWireframe(ChronosGL cgl, GeometryBuilder torus) {
    mat = Material("wf")
      ..setUniform(uModelMatrix, vm.Matrix4.identity())
      //..setUniform(uWidth, 1.5)
      ..forceUniform(cBlendEquation, blendEquationStandard)
      ..setUniform(uThickness, 10.0)
      ..setUniform(uColorAlpha, vm.Vector4(0.0, 0.0, 1.0, 1.0))
      ..setUniform(uColorAlpha2, vm.Vector4(0.0, 0.0, 0.1, 0.1));

    program = RenderProgram(
      "wf",
      cgl,
      wireframeVertexShader,
      wireframeFragmentShader,
    );

    mesh = geometryBuilderToMeshData("wf", program, torus);
  }

  factory SceneWireframe.quad(ChronosGL cgl) {
    final GeometryBuilder torus = torusKnotGeometryWireframeFriendly(
      computeUVs: false,
      computeNormals: false,
      inside: true,
    );

    torus.generateWireframeCenters();
    return SceneWireframe(cgl, torus);
  }

  factory SceneWireframe.triangle(ChronosGL cgl) {
    final GeometryBuilder torus = torusKnotGeometryTriangularWireframeFriendly(
      inside: true,
    );
    torus.generateWireframeCenters();
    return SceneWireframe(cgl, torus);
  }

  factory SceneWireframe.hexagon(ChronosGL cgl) {
    final GeometryBuilder torus = torusKnotGeometryTriangularWireframeFriendly(
      segmentsR: 192,
      segmentsT: 48,
      inside: true,
    );
    addHexagonalWireframeCenters(torus);
    return SceneWireframe(cgl, torus);
  }
  /*
      double alpha = math.sin(timeMs / 2000.0) * 10.0 + 11.0;
      insideWireframe.mat.forceUniform(uWidth, alpha);
      insideWireframeHex.mat.forceUniform(uWidth, alpha);
      */
}

void main() {
  final web.HTMLSelectElement modeInput =
      web.document.querySelector('#mode') as web.HTMLSelectElement;
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL(canvas);
  final camera = PerspectiveCamera(
    fovYRadians: 100 * math.pi / 180,
    near: 0.1,
    far: 1000,
  );
  final controls = TorusKnotControls(
    camera,
    positionAt: (parameter, out) =>
        torusKnotGetPos(parameter, 3, 2, 20, 1, out),
  );
  final perspective = CameraUniforms(camera);
  final viewport = CanvasViewport(cgl, canvas, camera);

  final SceneStars sceneStars = SceneStars(cgl, 2000, 1000);
  final SceneTextured sceneTextures = SceneTextured(cgl);
  final SceneWireframe sceneQuad = SceneWireframe.quad(cgl);
  final SceneWireframe sceneTriangle = SceneWireframe.triangle(cgl);
  final SceneWireframe sceneHexagon = SceneWireframe.hexagon(cgl);

  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    final previousTimeMs = lastTimeMs;
    lastTimeMs = timeMs;
    controls.update(
      previousTimeMs == null ? 0 : (timeMs - previousTimeMs) / 1000,
    );

    if (viewport.update()) {
      sceneStars.draw(cgl, timeMs, perspective);

      switch (modeInput.value) {
        case "texture":
          sceneTextures.draw(cgl, timeMs, perspective);
          break;
        case "rectangles":
          sceneQuad.draw(cgl, timeMs, perspective);
          break;
        case "triangles":
          sceneTriangle.draw(cgl, timeMs, perspective);
          break;
        case "hexagons":
          sceneHexagon.draw(cgl, timeMs, perspective);
          break;
        default:
          print("unexpected mode ${modeInput.value}");
      }
    }
    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  web.window.requestAnimationFrame(onFrame);
}
