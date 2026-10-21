import 'package:chronosgl/chronosgl.dart';

import 'dart:math' as math;
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

const double kMaxDistance = 100.1;
const double kMinDistance = 0.2;

final vm.Vector3 kVecOutOfBounds = vm.Vector3.all(kMaxDistance * 100.0);

const String uSources = "uSources";
const String uSinks = "uSinks";

final html.SelectElement gParticles =
    html.document.querySelector('#particles') as html.SelectElement;

final html.InputElement gCpuCompute =
    html.document.querySelector('#cpucompute') as html.InputElement;

final ShaderObject particleVertexShader = ShaderObject("ParticleV")
  ..addAttributeVars([aPosition])
  ..addUniformVars([
    uPerspectiveViewMatrix,
    uModelMatrix,
    uPointSize,
    uSources,
    uSinks,
  ])
  ..addTransformVars([tPosition])
  ..setBody([
    """
const float kMaxDistance = $kMaxDistance;
const float kMinDistance = $kMinDistance;
const float dt = 0.06;

float rand(vec2 seed){
    return fract(sin(dot(seed, vec2(12.9898,78.233))) * 43758.5453);
}

int irand(int n, vec2 seed) {
    return int(floor(rand(seed) * float(n)));
}

vec3 vec3rand(vec3 seed) {
    return vec3(rand(seed.yz) - 0.5, rand(seed.xz) - 0.5, rand(seed.xy) - 0.5);
}

vec3 RandomSource(vec3 seed) {
    return $uSources[irand($uSources.length(), seed.xy * seed.z)];
}

vec3 Update(vec3 pos, vec3 seed) {
    vec3 force = vec3(0.0, 0.0, 0.0);
    for (int i = 0; i < $uSources.length(); ++i) {
       vec3 d = pos - $uSources[i];
       float l = length(d);
       if (l <= kMinDistance) continue;
       if (l >= kMaxDistance) {
           return RandomSource(seed) + vec3rand(seed) * 0.35;
       }
       force += d / (l * l);
    }

    for (int i = 0; i < $uSinks.length(); ++i) {
       vec3 d = $uSinks[i] - pos;
       float l = length(d);
       if (l <= kMinDistance) {
          return RandomSource(seed) + vec3rand(seed) * 0.35;
       }
       force += d / (l * l);
    }
    return pos + normalize(force) * dt;
}

void main() {
    gl_Position = $uPerspectiveViewMatrix * $uModelMatrix *
                  vec4($aPosition, 1.0);
    gl_PointSize = $uPointSize/gl_Position.z;

    // new position for next round
    $tPosition = Update($aPosition, gl_Position.xyz);
}
""",
  ]);

final ShaderObject particleFragmentShader = ShaderObject("ParticleF")
  ..addUniformVars([uTexture])
  ..setBody([
    """
void main() {
      $oFragColor = texture( $uTexture,  gl_PointCoord);
}
""",
  ]);

String dumpVec(vm.Vector3 v) => "${v.x} ${v.y} ${v.z}";

// Source or Sink for Ions. Can move themselves - currently not used.
class Pole {
  Pole(vm.Vector3 pos) : _pos = pos.clone();

  final vm.Vector3 _pos;

  vm.Vector3 pos() => _pos;

  @override
  String toString() => "POLE: ${dumpVec(_pos)}";
}

// Particle emitted from a Source Pole and heading towards a Sink Pole.
class Ion {
  Ion(vm.Vector3 pos) : _pos = pos.clone();

  vm.Vector3 _pos;

  vm.Vector3 pos() => _pos;

  // Update position based on distance Source/Sink Poles
  void update(List<Pole> srcs, List<Pole> dsts, math.Random rng, double dt) {
    vm.Vector3 force = vm.Vector3.zero();

    for (Pole pole in srcs) {
      // accumulate pushing forces
      vm.Vector3 t = _pos - pole.pos();
      final double dist = t.length;
      if (dist <= kMinDistance) continue;
      if (dist > kMaxDistance) {
        // too far away
        Pole p = srcs[rng.nextInt(srcs.length)];
        _pos = p.pos() + randomVector(rng, 0.35);
        return;
      }
      force += t / (dist * dist);
    }

    for (Pole pole in dsts) {
      // accumulate pulling forces
      vm.Vector3 t = pole.pos() - _pos; //
      final double dist = t.length;
      if (dist <= kMinDistance) {
        // too close to dst pole
        Pole p = srcs[rng.nextInt(srcs.length)];
        _pos = p.pos() + randomVector(rng, 0.35);
        return;
      }
      force += t / (dist * dist);
    }

    // the normalization sacrifices physics for aesthetics
    _pos += force.normalized() * dt;
  }

  @override
  String toString() => "ION: ${dumpVec(_pos)}";
}

vm.Vector3 randomVector(math.Random rng, double d) {
  return vm.Vector3(
    (rng.nextDouble() - 0.5),
    (rng.nextDouble() - 0.5),
    (rng.nextDouble() - 0.5),
  )..scale(d);
}

List<Pole> makeRowOfPoles(List<double> xx, double y, double z, double scale) {
  List<Pole> out = [];
  for (double x in xx) {
    out.add(Pole(vm.Vector3(x, y, z) * scale));
  }
  return out;
}

Float32List extractPolePos(List<Pole> poles) {
  Float32List out = Float32List(3 * poles.length);
  int n = 0;
  for (Pole p in poles) {
    out[n + 0] = p.pos().x;
    out[n + 1] = p.pos().y;
    out[n + 2] = p.pos().z;
    n += 3;
  }
  return out;
}

void extractIonPos(List<Ion> ions, Float32List out) {
  assert(ions.length * 3 == out.length);
  int n = 0;
  for (Ion ion in ions) {
    out[n + 0] = ion.pos().x;
    out[n + 1] = ion.pos().y;
    out[n + 2] = ion.pos().z;
    n += 3;
  }
}

void main() {
  introduceNewShaderVar(
    uSources,
    const ShaderVarDesc(varTypeVec3, "", arraySize: 5),
  );
  introduceNewShaderVar(
    uSinks,
    const ShaderVarDesc(varTypeVec3, "", arraySize: 5),
  );

  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final math.Random rng = math.Random(0);

  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final int width = canvas.clientWidth;
  final int height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;

  final ChronosGL cgl = ChronosGL(canvas);
  final OrbitCamera orbit = OrbitCamera(15.0, 0.5, 0.5, canvas);
  final Perspective perspective = Perspective(orbit, 0.1, 1000.0)
    ..adjustAspect(width, height);

  final RenderProgram programJS = RenderProgram(
    "CPU",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );
  final RenderProgram programGPU = RenderProgram(
    "GPU",
    cgl,
    particleVertexShader,
    particleFragmentShader,
  );
  final int bindingIndex = programGPU.getTransformBindingIndex(tPosition);
  print("@@@@ $bindingIndex");

  final List<Pole> srcPoles = makeRowOfPoles(
    [2.0, 1.0, 0.0, -1.0, -2.0],
    0.0,
    2.0,
    3.0,
  );
  final List<Pole> dstPoles = makeRowOfPoles(
    [2.0, 1.0, 0.0, -1.0, -2.0],
    0.0,
    -2.0,
    3.0,
  );

  List<Ion> ions = [Ion(randomVector(rng, kMaxDistance * 100.0))];
  Float32List ionsPos = Float32List(3 * ions.length);
  extractIonPos(ions, ionsPos);

  // JS version setup
  Material matJS = Material.transparent("stars", blendEquationMix)
    ..setUniform(uTexture, Utils.createParticleTexture(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity())
    ..setUniform(uPointSize, 200.0);
  MeshData mdJS = programJS.makeMeshData("mdJS", glPoints)
    ..addVertices(ionsPos);

  // GPU version setup
  Material matGPU = Material.transparent("stars", blendEquationMix)
    ..setUniform(uTexture, Utils.createParticleTexture(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity())
    ..setUniform(uPointSize, 200.0)
    ..setUniform(uSources, extractPolePos(srcPoles))
    ..setUniform(uSinks, extractPolePos(dstPoles));

  MeshData mdOut = programGPU.makeMeshData("ionsOut", glPoints)
    ..addVertices(ionsPos);
  MeshData mdIn = programGPU.makeMeshData("ionsIn", glPoints)
    ..addVertices(ionsPos);

  void resizeIons(html.Event? ev) {
    int n = int.parse(gParticles.value!);
    print("resize to $n ions");
    ions.clear();
    for (int i = 0; i < n; i++) {
      Ion ion = Ion(randomVector(rng, kMaxDistance * 100.0));
      ions.add(ion);
    }
    ionsPos = Float32List(3 * n);
    extractIonPos(ions, ionsPos);
    cgl.bindBuffer(glArrayBuffer, null);
    cgl.bindBufferBase(glTransformFeedbackBuffer, bindingIndex, null);
    mdOut.changeVertexData(ionsPos);
    mdIn.changeVertexData(ionsPos);
    cgl.bindBufferBase(
      glTransformFeedbackBuffer,
      bindingIndex,
      mdOut.getBuffer(aPosition),
    );
  }

  void updateIonsJS(double t) {
    for (Ion ion in ions) {
      ion.update(srcPoles, dstPoles, rng, t);
    }
    extractIonPos(ions, ionsPos);
    mdJS.changeVertexData(ionsPos);
  }

  var transform = cgl.createTransformFeedback();
  cgl.bindTransformFeedback(transform);

  resizeIons(null);

  void animate(num timeMs) {
    orbit.azimuth += 0.002;
    orbit.animate(0.0); // argument is not used

    if (gCpuCompute.checked!) {
      updateIonsJS(0.06);
      programJS.draw(mdJS, [perspective, matJS]);
    } else {
      programGPU.draw(mdIn, [perspective, matGPU]);
      // use vertex shader output as input for next round
      cgl.bindBuffer(glArrayBuffer, mdIn.getBuffer(aPosition));
      cgl.bindBuffer(glTransformFeedbackBuffer, mdOut.getBuffer(aPosition));
      cgl.copyBufferSubData(
        glTransformFeedbackBuffer,
        glArrayBuffer,
        0,
        0,
        ions.length * 3 * 4,
      );
    }
    html.window.animationFrame.then(animate);
    fps.updateFrameCount(timeMs + 0.0);
  }

  gParticles.onChange.listen(resizeIons);
  animate(0.0);
}
