import 'package:chronosgl/chronosgl.dart';

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

import 'dart:math' as math;

// Sketch shader based on:
// http://www.thomaseichhorn.de/npr-sketch-shader-vvvv/
// https://github.com/spite/npr-shading

//
// Final Shader
//

final ShaderObject instancedVertexShader = ShaderObject("finalV")
  ..addAttributeVars([aPosition, aNormal, aTexUV])
  ..addAttributeVars([iaRotation, iaTranslation, iaScale])
  ..addVaryingVars([vColor, vNormal, vTexUV, vPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime])
  ..setBody([
    """
vec3 rotate_vertex_position(vec3 pos, vec4 rot) {
    rot.xyz *= sin(0.5 * rot.w * $uTime) /  length(rot.xyz);
    rot.w = cos(0.5 * rot.w * $uTime);
    return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
}

void main() {
  {
    vec3 p = $aPosition * $iaScale;
    p = rotate_vertex_position(p, $iaRotation);
    p = p + $iaTranslation;
    gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4(p, 1);
  }
  {
      vec3 n = $aNormal;
      n = rotate_vertex_position(n, $iaRotation);
      $vNormal = normalize(n);
  }
  $vTexUV = $aTexUV;
  $vPosition = gl_Position.xyz;
}
""",
  ]);

final ShaderObject instancedFragmentShader = ShaderObject("finalF")
  ..addVaryingVars([vColor, vNormal, vTexUV, vPosition])
  ..addUniformVars([
    uTexture,
    uTexture2,
    uLightDescs,
    uLightTypes,
    uShininess,
    uEyePosition,
  ])
  ..setBody(
    [
      """
float Edge(sampler2D t, ivec2 p) {
		vec4 hEdge = vec4(0.0);
		hEdge -= texelFetch(t, ivec2(p.x - 1, p.y - 1), 0) * 1.0;
		hEdge -= texelFetch(t, ivec2(p.x - 1, p.y    ), 0) * 2.0;
		hEdge -= texelFetch(t, ivec2(p.x - 1, p.y + 1), 0) * 1.0;
		hEdge += texelFetch(t, ivec2(p.x + 1, p.y - 1), 0) * 1.0;
		hEdge += texelFetch(t, ivec2(p.x + 1, p.y    ), 0) * 2.0;
		hEdge += texelFetch(t, ivec2(p.x + 1, p.y + 1), 0) * 1.0;
		vec4 vEdge = vec4(0.0);
		vEdge -= texelFetch(t, ivec2(p.x - 1, p.y - 1), 0) * 1.0;
		vEdge -= texelFetch(t, ivec2(p.x    , p.y - 1), 0) * 2.0;
		vEdge -= texelFetch(t, ivec2(p.x + 1, p.y - 1), 0) * 1.0;
		vEdge += texelFetch(t, ivec2(p.x - 1, p.y + 1), 0) * 1.0;
		vEdge += texelFetch(t, ivec2(p.x    , p.y + 1), 0) * 2.0;
		vEdge += texelFetch(t, ivec2(p.x + 1, p.y + 1), 0) * 1.0;
		vec3 edge = sqrt((hEdge.rgb * hEdge.rgb) + (vEdge.rgb * vEdge.rgb));
		return length(edge);
}

void main() {
  ColorComponents acc = CombinedLight($vPosition,
                                      $vNormal,
                                      $uEyePosition,
                                      $uLightDescs,
                                      $uLightTypes,
                                      $uShininess);

  float edge = Edge($uTexture, ivec2(gl_FragCoord.xy));
  vec4 info = texelFetch($uTexture, ivec2(gl_FragCoord.xy), 0);
  if (edge > 0.3) {
      //$oFragColor.rgb = vec3(0.0);
      $oFragColor.rgb = vec3(0.5 - edge);
     // $oFragColor.rgb = vec3(edge / (100.0 * info.w));
    return;
  }

  $oFragColor.rgb = texture($uTexture2, $vTexUV).rgb * 0.5 +
                      acc.diffuse +
                      acc.specular;
}
  """,
    ],
    prolog: [stdLibShader],
  );

//
// Preparation Shader
//

final ShaderObject preparationVertexShader = ShaderObject("preparationV")
  ..addAttributeVars([aPosition, aNormal, aTexUV])
  ..addAttributeVars([iaRotation, iaTranslation, iaScale])
  ..addVaryingVars([vNormal])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix, uTime])
  ..setBody([
    """
vec3 rotate_vertex_position(vec3 pos, vec4 rot) {
    rot.xyz *= sin(0.5 * rot.w * $uTime) /  length(rot.xyz);
    rot.w = cos(0.5 * rot.w * $uTime);
    return pos + 2.0 * cross(rot.xyz, cross(rot.xyz, pos) + rot.w * pos);
}

void main() {
    {
      vec3 p = $aPosition * $iaScale;
      p = rotate_vertex_position(p, $iaRotation);
      p = p + $iaTranslation;
      gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4(p, 1);
    }
    {
      vec3 n = $aNormal;
      n = rotate_vertex_position(n, $iaRotation);
      $vNormal = normalize(n);
    }
}
""",
  ]);

final ShaderObject preparationFragmentShader = ShaderObject("preparationF")
  ..addVaryingVars([vNormal])
  ..setBody([
    """
void main() {
  $oFragColor = vec4($vNormal, gl_FragCoord.w);
}
  """,
  ]);

void addInstanceData(MeshData md, math.Random rand, int count) {
  final Float32List scales = Float32List(count * 1);
  final Float32List translations = Float32List(count * 3);
  final Float32List rotations = Float32List(count * 4);

  for (int i = 0; i < count; i++) {
    final vm.Vector3 t = vm.Vector3.random(rand) - vm.Vector3(0.5, 0.5, 0.5);
    t.scale(60.0);
    translations.setAll(i * 3, t.storage);
    final vm.Vector3 u = vm.Vector3.random(rand);
    final vm.Quaternion q = vm.Quaternion.axisAngle(
      u,
      2.0 * rand.nextDouble() * math.pi,
    );
    rotations.setAll(i * 4, q.storage);

    scales.setAll(i, [2.0 + rand.nextDouble() * 4.0]);
  }

  md.addAttribute(iaRotation, rotations, 4);
  md.addAttribute(iaTranslation, translations, 3);
  md.addAttribute(iaScale, scales, 1);
}

final vm.Vector3 dirLight = vm.Vector3(0.0, -50.0, 0.0);

class Phase {
  Phase(this.program, this.md, this.fb);

  final Framebuffer fb;
  final Material mat = Material("mat");
  final RenderProgram program;
  final MeshData md;

  void run(int width, int height, [List<UniformGroup>? extra]) {
    fb.activate(glClearAll, 0, 0, width, height);
    List<UniformGroup> uniforms = [mat];
    if (extra != null) {
      uniforms.addAll(extra);
    }
    program.draw(md, uniforms);
  }
}

Framebuffer makePrepareFb(ChronosGL cgl, int width, int height) {
  TypedTexture tex = TypedTexture(
    cgl,
    "float",
    width,
    height,
    glRgba32f,
    texturePropertiesFramebuffer,
  );
  TypedTexture depthTexture = TypedTexture(
    cgl,
    "frame::depth",
    width,
    height,
    glDepthComponent24,
    texturePropertiesShadowMap,
  );
  return Framebuffer(cgl, tex, depthTexture);
}

Texture makeNoiseTesture(ChronosGL cgl, math.Random rand) {
  html.CanvasElement canvas = html.CanvasElement();
  canvas.width = 512;
  canvas.height = 512;
  var context = canvas.context2D;
  var image = context.getImageData(0, 0, canvas.width!, canvas.height!);

  for (int i = 0; i < image.data.length; i += 4) {
    int v = 30 + rand.nextInt(225);
    image.data[i + 0] = v;
    image.data[i + 1] = v;
    image.data[i + 2] = v;
    image.data[i + 3] = 255;
  }
  context.putImageData(image, 0, 0);

  return ImageTexture(cgl, "noise", canvas, texturePropertiesMipmap);
}

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;

  final ChronosGL cgl = ChronosGL(canvas, faceCulling: false)
    ..clearColor(0.5, 0.5, 0.5, 1.0);

  Illumination illumination = Illumination()
    ..addLight(
      DirectionalLight("dir", dirLight, colorWhite * 0.5, colorBlack, 100.0),
    );

  final dynamic ext = cgl.getExtension("EXT_color_buffer_float");
  if (ext == null) {
    html.window.alert("extension not available: EXT_color_buffer_float");
  }
  OrbitCamera orbit = OrbitCamera(100.0, 0.0, 0.0, canvas);

  final Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;
  perspective.adjustAspect(width, height);

  final math.Random rand = math.Random(1);

  final RenderProgram progPreparation = RenderProgram(
    "preparation",
    cgl,
    preparationVertexShader,
    preparationFragmentShader,
  );

  final RenderProgram progInstanced = RenderProgram(
    "instanced",
    cgl,
    instancedVertexShader,
    instancedFragmentShader,
  );

  final MeshData cubes = shapeCube(progInstanced, computeNormals: true);
  addInstanceData(cubes, rand, 80);
  print("instances: $cubes.GetNumInstances()}");

  final Phase prepare = Phase(
    progPreparation,
    cubes,
    makePrepareFb(cgl, width, height),
  )..mat.setUniform(uModelMatrix, vm.Matrix4.identity());

  final Phase render = Phase(progInstanced, cubes, Framebuffer.screen(cgl))
    ..mat.setUniform(uModelMatrix, vm.Matrix4.identity())
    ..mat.setUniform(uShininess, 10.0)
    ..mat.setUniform(uTexture2, makeNoiseTesture(cgl, rand))
    ..mat.setUniform(uTexture, prepare.fb.colorTexture!);

  /*
  // The lines show aliasing problems but the experiments below
  // did not help:
  final Phase render =
  Phase(progInstanced, cubes, Framebuffer.defaultFramebuffer(cgl, width, height))
    ..mat.setUniform(uModelMatrix, vm.Matrix4.identity())
    ..mat.setUniform(uShininess, 10.0)
    ..mat.setUniform(uTexture, prepare.fb.colorTexture);


  final RenderProgram blurProg =
  RenderProgram("blur", cgl, effectVertexShader, blur1DShader9);
  final MeshData unitQuad = shapeQuad(blurProg, 1);


  final Phase horizontalBlur =
  Phase(blurProg, unitQuad, Framebuffer.effect(cgl, width, height))
    ..mat.setUniform(uTexture, render.fb.colorTexture)
    ..mat.setUniform(uDirection, vm.Vector2(1.0, 0.0));

  final Phase verticalBlur = Phase(
      blurProg, unitQuad, Framebuffer.screen(cgl))
    ..mat.setUniform(uTexture, horizontalBlur.fb.colorTexture)
    ..mat.setUniform(uDirection, vm.Vector2(0.0, 1.0));
*/

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    prepare.mat.forceUniform(uTime, lastTimeMs / 2000.0);
    prepare.run(width, height, [perspective]);

    render.mat.forceUniform(uTime, lastTimeMs / 2000.0);
    render.run(width, height, [perspective, illumination]);
    /*
    horizontalBlur.run(width, height);
    verticalBlur.run(width, height);
*/

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  animate(0.0);
}
