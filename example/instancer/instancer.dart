import 'dart:math' as math;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final ShaderObject instancedVertexShader = ShaderObject.vertex("InstancedV")
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

final ShaderObject instancedFragmentShader = ShaderObject.fragment("InstancedF")
  ..addVaryingVars([vColor])
  ..setBody([
    """
void main() {
     $oFragColor = vec4( $vColor, 1. );
}
     """,
  ]);

void addInstanceData(GpuMesh md) {
  int count = 1000;
  Float32List translations = Float32List(count * 3);
  Float32List rotations = Float32List(count * 4);

  int pos = 0;
  for (int x = -5; x < 5; x++) {
    for (int y = -5; y < 5; y++) {
      for (int z = -5; z < 5; z++) {
        translations.setAll(pos * 3, [x * 40.0, y * 40.0, z * 30.0]);
        rotations.setAll(pos * 4, vm.Quaternion.identity().storage);
        pos++;
      }
    }
  }

  md.addAttribute(iaRotation, rotations, 4);
  md.addAttribute(iaTranslation, translations, 3);
}

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

  ChronosGL cgl = ChronosGL.fromCanvas(canvas, faceCulling: true);
  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 265.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram progInstanced = lifetime.own(
    RenderProgram(
      "instanced",
      cgl,
      instancedVertexShader,
      instancedFragmentShader,
    ),
  );
  final Material mat = lifetime.own(Material("mat"))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh md = lifetime.own(shapeTorusKnot(progInstanced, radius: 12.0));
  addInstanceData(md);

  final RenderProgram progStars = lifetime.own(
    RenderProgram(
      "stars",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    ),
  );
  final Material matStars = lifetime.own(makeStarMaterial(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh mdStars = lifetime.own(
    makeStarMesh(progStars, 2000, 100.0, random: math.Random()),
  );

  double? lastTimeMs;
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

    progInstanced.draw(md, [mat, perspective]);
    progStars.draw(mdStars, [matStars, perspective]);

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
