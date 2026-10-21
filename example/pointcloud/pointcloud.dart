import 'dart:html' as html;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String aCurrentPosition = "aCurrentPosition";

final ShaderObject fireworksVertexShader = ShaderObject("FireWorksV")
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

final ShaderObject fireworksFragmentShader = ShaderObject("FireWorksF")
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

  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final ChronosGL cgl = ChronosGL(canvas);

  final OrbitCamera orbit = OrbitCamera(7.0, 0.0, 0.0, html.document.body!);

  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram prog = RenderProgram(
    "fireworks",
    cgl,
    fireworksVertexShader,
    fireworksFragmentShader,
  );
  final int bindingIndex = prog.getTransformBindingIndex(tPosition);

  final Material material = Material("torus-mat")
    ..setUniform(uPointSize, 20.0)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());

  final detail = 2;
  final MeshData torus = shapeTorusKnot(
    prog,
    radius: 1.0,
    tubeRadius: 0.2,
    computeNormals: true,
    segmentsR: 256 * detail,
    segmentsT: 16 * detail,
  );
  final MeshData points = extractPointCloud(prog, torus, 200000);
  points.addAttribute(aCurrentPosition, points.getAttribute(aPosition), 3);

  MeshData out0 = prog.makeMeshData("out", glPoints)
    ..addVertices(points.getAttribute(aPosition) as Float32List);
  MeshData out1 = prog.makeMeshData("out", glPoints)
    ..addVertices(points.getAttribute(aPosition) as Float32List);

  cgl.bindBufferBase(
    glTransformFeedbackBuffer,
    bindingIndex,
    out0.getBuffer(aPosition),
  );

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    // animate the camera a little
    orbit.azimuth += 0.003;
    // allow the camera to also reflect mouse movement.
    orbit.animate(elapsed);

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

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(timeMs + 0.0);
  }

  animate(0.0);
}
