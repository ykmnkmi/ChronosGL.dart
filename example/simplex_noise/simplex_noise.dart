import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String uFreqMul = "uFreqMul";
const String uAmplMul = "uAmplMul";

// consider moving these into a vector
const String uAmpl1 = "uAmpl1";
const String uAmpl2 = "uAmpl2";
const String uAmpl3 = "uAmpl3";
const String uMode = "uMode";
const String uSpeed = "uSpeed";

final ShaderObject nullVertexShader = ShaderObject("nullShaderV")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

String shader =
    """
   #define D 3
   // default:
   // const float ampls[D] = float[](1.0, 0.5, 0.25);

   const float freqs[D] = float[](1.0, 2.0, 4.0);
  
   float ComplexNoise(vec2 xy, 
                      float baseFreq, float freqs[D], 
                      float baseAmpl, float ampls[D]) {
       float total = 0.0;
       for(int i = 0; i < D; i++) {
           total += baseAmpl * ampls[i] * snoise3(vec3(xy * baseFreq * freqs[i], $uTime * $uSpeed));
       }             
       return total;
   }
   
   float Standard(vec2 xy) {
       float ampls[D] = float[]($uAmpl1, $uAmpl2, $uAmpl3);
       return ComplexNoise(xy, $uFreqMul, freqs, $uAmplMul, ampls);
   }
 
   float Marble(vec2 xy) {
       float ampls[D] = float[]($uAmpl1, $uAmpl2, $uAmpl3);
       float n = ComplexNoise(xy, $uFreqMul, freqs, $uAmplMul, ampls);
       return abs(cos(xy.x * 0.008 + xy.y * 0.008 + 4.0 * n)); 
   }
   
   float Wood(vec2 xy) {
       float ampls[D] = float[]($uAmpl1, $uAmpl2, $uAmpl3);
       vec2 p = xy / 40.0;
       float n = ComplexNoise(xy, $uFreqMul, freqs, $uAmplMul, ampls);
       return cos((length(p) + n) * 4.0); 
   
       //float n = 0.4 * snoise2(xy * 0.005);   
       //float n = ComplexNoise(xy, 0.01, freqs, 0.2, ampls);
   }  

   vec3 Cloud(vec2 xy) {
       float ampls[D] = float[]($uAmpl1, $uAmpl2, $uAmpl3);
       float n = ComplexNoise(xy, $uFreqMul, freqs, $uAmplMul, ampls);
       return HSLtoRGB(vec3(0.66, 1.0, 0.75 + n / 4.0));
   }  
   
   void main() {
       // This are pixel coordinates  0, 0 being lowel left
       vec2 xy = gl_FragCoord.xy - 0.5 * $uCanvasSize;
       
       // see simple_noise.html for mode coding 
       if ($uMode == 4.0) {
           $oFragColor.g = Marble(xy);
       } else if ($uMode == 3.0) {
           $oFragColor.rgb = Cloud(xy);
       } else if ($uMode == 2.0) {
           $oFragColor.g = Wood(xy);
       } else {
           $oFragColor.g =  Standard(xy);
       }
   }
 """;

final ShaderObject noiseFragmentShader = ShaderObject("noiseShaderF")
  ..addUniformVars([
    uTime,
    uCanvasSize,
    uAmpl1,
    uAmpl2,
    uAmpl3,
    uAmplMul,
    uFreqMul,
    uMode,
    uSpeed,
  ])
  ..setBody([
    colorFunctions,
    simplexNoiseHelpers,
    simplexNoiseFunction3,
    shader,
  ]);

void main() {
  introduceNewShaderVar(uFreqMul, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uAmplMul, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uAmpl1, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uAmpl2, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uAmpl3, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uMode, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uSpeed, const ShaderVarDesc("float", ""));

  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final int w = canvas.clientWidth;
  final int h = canvas.clientHeight;
  canvas.width = w;
  canvas.height = h;

  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);

  final RenderProgram programPerlin = RenderProgram(
    "perlin",
    cgl,
    nullVertexShader,
    noiseFragmentShader,
  );

  final MeshData quad = shapeQuad(programPerlin, 1);

  final UniformGroup uniforms = UniformGroup("simplex")
    ..forceUniform(uTime, 0.0)
    ..forceUniform(uCanvasSize, vm.Vector2(w + 0.0, h + 0.0));

  // Event Handling
  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    input.onChange.listen((html.Event e) {
      html.InputElement input = e.target as html.InputElement;
      if (input.type == "range") {
        html.OutputElement output =
            html.document.getElementById(input.name!) as html.OutputElement;
        uniforms.forceUniform(input.name!, double.parse(input.value!));
        output.value = input.value;
      }
      if (input.type == "radio") {
        uniforms.forceUniform(input.name!, double.parse(input.value!));
      }
    });
  }

  // Trigger handlers
  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.InputElement input = node as html.InputElement;
    if (input.type! == "radio" && !input.checked!) continue;
    input.dispatchEvent(html.Event("change"));
  }

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    lastTimeMs = timeMs + 0.0;

    uniforms.forceUniform(uTime, timeMs / 1000.0);
    programPerlin.draw(quad, [uniforms]);

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  animate(0.0);
}
