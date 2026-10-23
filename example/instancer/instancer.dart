import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

final ShaderObject instancedVertexShader = ShaderObject("InstancedV")
  ..addAttributeVars([aPosition])
  ..addAttributeVars([iaRotation, iaTranslation])
  ..addVaryingVars([vColor])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBody([
    """
vec3 rotate_vertex_position(vec3 pos, vec4 rot) {
    return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
}

void main() {
    vec3 P = rotate_vertex_position($aPosition, $iaRotation) +
             $iaTranslation;
    gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4(P, 1);
    $vColor = vec3(sin($aPosition.x)/2.0+0.5,
                     cos($aPosition.y)/2.0+0.5,
                     sin($aPosition.z)/2.0+0.5);
}
""",
  ]);

final ShaderObject instancedFragmentShader = ShaderObject("InstancedF")
  ..addVaryingVars([vColor])
  ..setBody([
    """
void main() {
     $oFragColor = vec4( $vColor, 1. );
}
     """,
  ]);

void addInstanceData(MeshData md) {
  int count = 1000;
  Float32List translations = Float32List(count * 3);
  Float32List rotations = Float32List(count * 4);

  Spatial spatial = Spatial("dummy");
  int pos = 0;
  for (int x = -5; x < 5; x++) {
    for (int y = -5; y < 5; y++) {
      for (int z = -5; z < 5; z++) {
        spatial.setPos(x * 40.0, y * 40.0, z * 30.0);
        translations.setAll(pos * 3, spatial.getPos().storage);
        vm.Quaternion q = vm.Quaternion.fromRotation(
          spatial.transform.getRotation(),
        );
        rotations.setAll(pos * 4, q.storage);
        pos++;
      }
    }
  }

  md.addAttribute(iaRotation, rotations, 4);
  md.addAttribute(iaTranslation, translations, 3);
}

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;

  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = OrbitCamera(265.0, 0.0, 0.0, canvas);
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram progInstanced = RenderProgram(
    "instanced",
    cgl,
    instancedVertexShader,
    instancedFragmentShader,
  );
  final Material mat = Material("mat")
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData md = shapeTorusKnot(progInstanced, radius: 12.0);
  addInstanceData(md);

  final RenderProgram progStars = RenderProgram(
    "stars",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );
  final Material matStars = Utils.makeStarMaterial(cgl)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData mdStars = Utils.makeStarMesh(progStars, 2000, 100.0);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    progInstanced.draw(md, [mat, perspective]);
    progStars.draw(mdStars, [matStars, perspective]);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
