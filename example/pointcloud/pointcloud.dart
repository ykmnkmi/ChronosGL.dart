import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

const String aCurrentPosition = "aCurrentPosition";

final ShaderObject fireworksVertexShader = ShaderObject.vertex("FireWorksV")
  ..addAttributeVars([aPosition, aCurrentPosition, aNormal])
  ..addVaryingVars([vColor])
  ..addTransformVars([tPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime, uPointSize])
  ..setBody([
    """
float rand(vec2 xy){
     return fract(sin(dot(xy, vec2(12.9898, 78.233))) * 43758.5453);
}
     
vec3 NewPos(vec3 orig, vec3 last, float t) {
    float bottom = - 2.0;
   
    t = mod(t, 14.0);
    if (t < 2.0) {            // normal
        return last;
    } else if ( t < 6.0) {    // shrinking
        float speed = 0.1;
        t = t - 2.0;
        // statistically 
        // * x just floats around orig.x
        // * y moves down by -0.25 (middle of  [0.25, -0.75])
        // * z just floats around orig.z
        vec3 delta = vec3(0.5 - rand(vec2(t, last.x)),
                          0.25 - rand(vec2(t, last.y)),
                          0.5 - rand(vec2(t, last.z)));
                          
        if (last.y < bottom + 0.3) {
           speed *= (last.y - bottom);
        }
        vec3 next = last + delta * speed;
        if (next.y < bottom) next.y = bottom;
        return next;  
    } else if ( t < 8.0) {    // flat 
        return last;      
    } else {
       t = t - 8.0;
       vec3 speed = clamp(orig - last, vec3(-1.0), vec3(1.0));
       
       vec3 delta = vec3(0.85 - rand(vec2(t, last.x)),
                         1.0 + rand(vec2(t, last.y)),
                         0.85 - rand(vec2(t, last.z)));
    
      
       return last + delta * 0.05 * speed;
    }
}

void main() {
    vec3 pos = NewPos($aPosition, $aCurrentPosition, $uTime);
    // new current pos for next run
    $tPosition = pos;

    gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4(pos, 1.0);
                  
    gl_PointSize = $uPointSize / gl_Position.z;
    $vColor.r = sin($aPosition.x)/2.0+0.5;
    $vColor.g = cos($aPosition.y)/2.0+0.5;
    $vColor.b = sin($aPosition.z)/2.0+0.5;
}
""",
  ]);

final ShaderObject fireworksFragmentShader = ShaderObject.fragment("FireWorksF")
  ..addVaryingVars([vColor])
  ..setBody([
    """
void main() {  
    $oFragColor.rgb = $vColor;
}
    """,
  ]);

void main() {
  introduceNewShaderVar(aCurrentPosition, const ShaderVarDesc(varTypeVec3, ""));

  FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );

  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);

  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 7.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );

  final CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram prog = lifetime.own(
    RenderProgram.create(
      name: "fireworks",
      context: cgl,
      vertexShader: fireworksVertexShader,
      fragmentShader: fireworksFragmentShader,
    ),
  );
  final int bindingIndex = prog.getTransformBindingIndex(tPosition);

  final Material material = lifetime.own(Material("torus-mat"))
    ..setUniform(uPointSize, 20.0)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());

  final detail = 2;
  final GpuMesh torus = lifetime.own(
    shapeTorusKnot(
      prog,
      radius: 1.0,
      tubeRadius: 0.2,
      computeNormals: true,
      segmentsR: 256 * detail,
      segmentsT: 16 * detail,
    ),
  );
  final GpuMesh points = lifetime.own(extractPointCloud(prog, torus, 200000));
  points.addAttribute(aCurrentPosition, points.getAttribute(aPosition), 3);

  GpuMesh out0 = lifetime.own(prog.makeGpuMesh("out", glPoints))
    ..addVertices(points.getAttribute(aPosition) as Float32List);
  GpuMesh out1 = lifetime.own(prog.makeGpuMesh("out", glPoints))
    ..addVertices(points.getAttribute(aPosition) as Float32List);

  cgl.bindBufferBase(
    glTransformFeedbackBuffer,
    bindingIndex,
    out0.getBuffer(aPosition),
  );

  double lastTimeMs = 0.0;
  bool firstFrame = true;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    // animate the camera a little
    orbit.azimuth += 0.18 * elapsed / 1000;
    // allow the camera to also reflect mouse movement.
    orbit.update(elapsed / 1000);

    material.forceUniform(uTime, timeMs / 1000.0);
    cgl.bindBufferBase(
      glTransformFeedbackBuffer,
      bindingIndex,
      out0.getBuffer(aPosition),
    );
    points.changeAttributeBuffer(aCurrentPosition, out1.getBuffer(aPosition));
    prog.draw(points, [perspective, material]);
    var t = out0;
    out0 = out1;
    out1 = t;

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs + 0.0);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
