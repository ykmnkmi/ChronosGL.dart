part of 'lib.dart';

class Utils {
  /*
  Texture createCheckerboardTexture() {
    var pixels = new Uint8List.fromList(
        [255, 255, 255, 0, 0, 0, 0, 0, 0, 255, 255, 255]);
    var texture = gl.createTexture();
    gl.bindTexture(TEXTURE_2D, texture);
    gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
    gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, CLAMP_TO_EDGE);
    gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
    gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
    //  gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR);
    //  gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR);
    gl.pixelStorei(UNPACK_ALIGNMENT, 1);
    gl.texImage2DTyped(TEXTURE_2D, 0, RGB, 2, 2, 0, RGB, UNSIGNED_BYTE, pixels);
    return texture;
  }
*/

  static Texture createParticleTexture(
    ChronosGL cgl, [
    String name = "Utils::Particles",
  ]) {
    return ImageTexture(cgl, name, createParticleCanvas());
  }

  static html.CanvasElement createParticleCanvas() {
    int d = 64;
    html.CanvasElement canvas = html.CanvasElement(width: d, height: d);
    html.CanvasRenderingContext2D ctx =
        canvas.getContext('2d') as html.CanvasRenderingContext2D;
    int x = d ~/ 2, y = d ~/ 2;

    var gradient = ctx.createRadialGradient(x, y, 1, x, y, 22);
    gradient.addColorStop(0, 'gray');
    gradient.addColorStop(1, 'black');

    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, d, d);

    gradient = ctx.createRadialGradient(x, y, 1, x, y, 6);
    gradient.addColorStop(0, 'white');
    gradient.addColorStop(1, 'gray');

    ctx.globalAlpha = 0.9;
    ctx.fillStyle = gradient;
    ctx.arc(x, y, 4, 0, 2 * math.pi);
    ctx.fill();
    return canvas;
  }

  static int id = 1;

  static math.Random rand = math.Random();

  static MeshData makeStarMesh(
    RenderProgram prog,
    int numPoints,
    double dimension,
  ) {
    final String name = 'stars_$numPoints';
    Float32List pos = Float32List(numPoints * 3);
    for (var i = 0; i < numPoints * 3; i++) {
      pos[i] = (rand.nextDouble() - 0.5) * dimension;
    }
    return prog.makeMeshData(name, glPoints)..addVertices(pos);
  }

  static Material makeStarMaterial(ChronosGL cgl, [double size = 1000.0]) {
    return Material.transparent("stars", blendEquationMix)
      ..setUniform(uTexture, createParticleTexture(cgl))
      ..setUniform(uPointSize, size);
  }

  static Node makeParticles(
    RenderProgram prog,
    int numPoints, [
    double dimension = 100.0,
  ]) {
    Material mat = makeStarMaterial(prog.getContext());
    MeshData md = makeStarMesh(prog, numPoints, dimension);
    return Node(md.name, md, mat);
  }
}

MeshData shapeCube(
  RenderProgram prog, {
  double x = 1.0,
  double y = 1.0,
  double z = 1.0,
  double uMin = 0.0,
  double uMax = 1.0,
  double vMin = 0.0,
  double vMax = 1.0,
  bool computeNormals = true,
}) {
  GeometryBuilder gb = cubeGeometry(
    x: x,
    y: y,
    z: z,
    uMin: uMin,
    uMax: uMax,
    vMin: vMin,
    vMax: vMax,
  );
  return geometryBuilderToMeshData("cube", prog, gb);
}

MeshData shapeWedge(
  RenderProgram prog, {
  double x = 1.0,
  double y = 1.0,
  double z = 1.0,
  double uMin = 0.0,
  double uMax = 1.0,
  double vMin = 0.0,
  double vMax = 1.0,
}) {
  GeometryBuilder gb = wedgeGeometry(
    x: x,
    y: y,
    z: z,
    uMin: uMin,
    uMax: uMax,
    vMin: vMin,
    vMax: vMax,
  );
  return geometryBuilderToMeshData("wedge", prog, gb);
}

MeshData shapeCylinder(
  RenderProgram prog,
  double radTop,
  double radBot,
  double height,
  int radialSubdivisions, [
  bool computeNormals = true,
]) {
  GeometryBuilder gb = cylinderGeometry(
    radTop,
    radBot,
    height,
    radialSubdivisions,
    computeNormals,
  );
  return geometryBuilderToMeshData("cylinder-$radialSubdivisions", prog, gb);
}

MeshData shapeIcosahedron(
  RenderProgram prog, {
  int subdivisions = 4,
  double scale = 1.0,
  bool computeNormals = true,
}) {
  GeometryBuilder gb = icosahedronGeometry(
    subdivisions: subdivisions,
    scale: scale,
    computeNormals: computeNormals,
  );
  return geometryBuilderToMeshData("icosahedron-$subdivisions", prog, gb);
}

MeshData shapeTorusKnot(
  RenderProgram prog, {
  double radius = 20.0,
  double tubeRadius = 4.0,
  int segmentsR = 128,
  int segmentsT = 16,
  int p = 2,
  int q = 3,
  double heightScale = 1.0,
  bool computeNormals = true,
}) {
  GeometryBuilder gb = torusKnotGeometry(
    radius: radius,
    tubeRadius: tubeRadius,
    segmentsR: segmentsR,
    segmentsT: segmentsT,
    p: p,
    q: q,
    heightScale: heightScale,
    computeNormals: computeNormals,
  );
  return geometryBuilderToMeshData("torusknot", prog, gb);
}

MeshData shapeQuad(RenderProgram prog, int size) {
  GeometryBuilder gb = quadGeometry(size);
  return geometryBuilderToMeshData("quad", prog, gb);
}

MeshData shapeGrid(
  RenderProgram prog,
  int xstrips,
  int ystrips,
  double xlen,
  double ylen,
) {
  GeometryBuilder gb = gridGeometry(xstrips, ystrips, xlen, ylen);
  return geometryBuilderToMeshData("strips", prog, gb);
}

final Material emptyMaterial = Material("empty-mat");

Node unitNode(RenderProgram prog) {
  final MeshData unitQuad = shapeQuad(prog, 1);
  return Node("unit-mesh", unitQuad, emptyMaterial);
}

final vm.Vector3 colorWhite = vm.Vector3(1.0, 1.0, 1.0);
final vm.Vector3 colorGray8 = vm.Vector3(0.8, 0.8, 0.8);
final vm.Vector3 colorGray6 = vm.Vector3(0.6, 0.6, 0.6);
final vm.Vector3 colorGray4 = vm.Vector3(0.4, 0.4, 0.4);
final vm.Vector3 colorGray2 = vm.Vector3(0.2, 0.2, 0.2);
final vm.Vector3 colorBlack = vm.Vector3(0.0, 0.0, 0.0);

final vm.Vector3 colorBlue = vm.Vector3(0.0, 0.0, 1.0);
final vm.Vector3 colorLiteBlue = vm.Vector3(0.0, 0.0, 0.5);

final vm.Vector3 colorRed = vm.Vector3(1.0, 0.0, 0.0);
final vm.Vector3 colorLiteRed = vm.Vector3(0.5, 0.0, 0.0);

final vm.Vector3 colorGreen = vm.Vector3(0.0, 1.0, 0.0);
final vm.Vector3 colorLiteGreen = vm.Vector3(0.0, 0.5, 0.0);

final vm.Vector3 colorYellow = vm.Vector3(1.0, 1.0, 0.0);
final vm.Vector3 colorLiteYellow = vm.Vector3(0.5, 0.5, 0.0);

final vm.Vector3 colorMagenta = vm.Vector3(1.0, 0.0, 1.0);
final vm.Vector3 colorLiteMagenta = vm.Vector3(0.5, 0.0, 0.5);

final vm.Vector3 colorCyan = vm.Vector3(0.0, 1.0, 1.0);
final vm.Vector3 colorLiteCyan = vm.Vector3(0.0, 0.5, 0.5);

/// A RenderPhase which automatically updates perspective and viewport when
/// the window size is changed.
/// This assumes that the canvas is always "full screen".
class RenderPhaseResizeAware extends RenderPhase {
  RenderPhaseResizeAware(
    super.name,
    super.cgl,
    this._canvas,
    this._perspective,
  ) {
    resolutionChange(null);
    html.window.onResize.listen(resolutionChange);
  }

  final html.CanvasElement _canvas;
  final Perspective _perspective;

  void resolutionChange(html.Event? ev) {
    int w = _canvas.clientWidth;
    int h = _canvas.clientHeight;
    _canvas.width = w;
    _canvas.height = h;
    print("size change $w $h");
    _perspective.adjustAspect(w, h);
    viewPortW = w;
    viewPortH = h;
  }
}

class PerspectiveResizeAware extends Perspective {
  PerspectiveResizeAware(
    this._cgl,
    this._canvas,
    Spatial camera,
    double near,
    double far,
  ) : super(camera, near, far) {
    resolutionChange(null);
    html.window.onResize.listen(resolutionChange);
  }

  final html.CanvasElement _canvas;
  final ChronosGL _cgl;

  void resolutionChange(html.Event? ev) {
    int w = _canvas.clientWidth;
    int h = _canvas.clientHeight;
    _canvas.width = w;
    _canvas.height = h;
    print("size change $w $h");
    adjustAspect(w, h);

    _cgl.viewport(0, 0, w, h);
  }
}
