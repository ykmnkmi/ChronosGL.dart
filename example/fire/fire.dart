import 'package:chronosgl/chronosgl.dart';

import 'dart:html' as html;

const String uFlameHeight = "uFlameHeight";
const String uFlameWidth = "uFlameWidth";
const String uFlameTurbulence = "uFlameTurbulence";
const String uFlameThrottle = "uFlameThrottle";

const String uRandomSeed = "uRandomSeed";

// Background:
// http://lodev.org/cgtutor/fire.html

final ShaderObject nullVertexShader = ShaderObject("nullShaderV")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

final ShaderObject fireFragmentShader = ShaderObject("fireShaderF")
  ..addUniformVars([
    uTexture,
    uFlameThrottle,
    uRandomSeed,
    uFlameWidth,
    uFlameHeight,
    uFlameTurbulence,
  ])
  ..setBody([
    """
float rand(vec2 xy){
    return fract(sin(dot(xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float get(vec2 xy) {
    vec2 DIM = vec2(textureSize($uTexture, 0));
    return texture($uTexture, xy / DIM).r;
}

float NextValue(vec2 xy) {
    if (xy.y < 1.0) {
        float r = rand(vec2($uRandomSeed, xy.x));
        return get(xy) + (r - 0.5) * $uFlameTurbulence;
    }

    float height = $uFlameHeight;
    float width =  $uFlameWidth;
    return (4.0 * get(xy) +
            get(xy + vec2(0.0, -height)) +
            get(xy + vec2(-width,  -height)) +
            get(xy + vec2(width,  -height)) +
            get(xy + vec2(0.0, -2.0 * height))) * $uFlameThrottle * 0.5;
}

void main() {
    float v = NextValue(gl_FragCoord.xy);
    $oFragColor.r = v;
}
""",
  ]);

final ShaderObject colorFragmentShader = ShaderObject("colorShaderF")
  ..addUniformVars([uTexture])
  ..setBody([
    colorFunctions,
    """
float get(vec2 xy) {
    vec2 DIM = vec2(textureSize($uTexture, 0));
    return texture($uTexture, xy / DIM).r;
}

void main() {
    float v  = get(gl_FragCoord.xy);
    vec3 hsl = vec3(v / 3.0, 1.0, clamp(2.0 * v, 0.0, 1.0));
    $oFragColor.rgb = HSLtoRGB(hsl);
}
""",
  ]);

void main() {
  introduceNewShaderVar(uFlameHeight, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uFlameWidth, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uFlameTurbulence, const ShaderVarDesc("float", ""));
  introduceNewShaderVar(uFlameThrottle, const ShaderVarDesc("float", ""));

  introduceNewShaderVar(uRandomSeed, const ShaderVarDesc("float", ""));

  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final int w = canvas.clientWidth;
  final int h = canvas.clientHeight;
  canvas.width = w;
  canvas.height = h;

  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  final Framebuffer screen = Framebuffer.screen(cgl);

  final TypedTextureMutable t1 = TypedTextureMutable(
    cgl,
    "t1",
    w,
    h,
    glRgba,
    texturePropertiesFramebuffer,
    glRgba,
    glUnsignedByte,
    null,
  );

  final TypedTextureMutable t2 = TypedTextureMutable(
    cgl,
    "t2",
    w,
    h,
    glRgba,
    texturePropertiesFramebuffer,
    glRgba,
    glUnsignedByte,
    null,
  );

  final RenderProgram programFire = RenderProgram(
    "fire",
    cgl,
    nullVertexShader,
    fireFragmentShader,
  );

  final RenderProgram programColor = RenderProgram(
    "color",
    cgl,
    nullVertexShader,
    colorFragmentShader,
  );

  final MeshData unit = shapeQuad(programFire, 1);

  // Set up Ping-Ponging
  final Framebuffer fb1 = Framebuffer(cgl, t1);
  final Framebuffer fb2 = Framebuffer(cgl, t2);
  final UniformGroup ug = UniformGroup("ug")
    ..forceUniform(uRandomSeed, 0.0)
    ..forceUniform(uFlameTurbulence, 0.2)
    ..forceUniform(uFlameHeight, 3.5)
    ..forceUniform(uFlameWidth, 1.2)
    ..forceUniform(uFlameThrottle, 0.248); // needs to smaller than 1/4.0

  // Event Handling
  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    input.onChange.listen((html.Event e) {
      html.InputElement input = e.target as html.InputElement;
      if (input.type == "range") {
        html.OutputElement output =
            html.document.getElementById("${input.id}2") as html.OutputElement;
        ug.forceUniform(input.id, double.parse(input.value!));
        output.value = input.value;
      }
    });
  }

  // Trigger handlers
  for (html.Node node in html.document.getElementsByTagName("input")) {
    html.Element input = node as html.Element;
    input.dispatchEvent(html.Event("change"));
  }

  double lastTimeMs = 0.0;
  int frame = 0;
  void animate(num timeMs) {
    lastTimeMs = timeMs + 0.0;
    frame++;
    ug.forceUniform(uRandomSeed, lastTimeMs);

    if (frame % 2 == 0) {
      fb1.activate(glClearAll, 0, 0, w, h);
      ug.forceUniform(uTexture, t2);
      programFire.draw(unit, [ug]);
      screen.activate(glClearAll, 0, 0, w, h);
      ug.forceUniform(uTexture, t1);
      programColor.draw(unit, [ug]);
    } else {
      fb2.activate(glClearAll, 0, 0, w, h);
      ug.forceUniform(uTexture, t1);
      programFire.draw(unit, [ug]);
      screen.activate(glClearAll, 0, 0, w, h);
      ug.forceUniform(uTexture, t2);
      programColor.draw(unit, [ug]);
    }

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs, "$frame");
  }

  animate(0.0);
}
