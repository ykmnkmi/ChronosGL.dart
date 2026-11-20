import 'dart:math' as math;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

// http://www.bidouille.org/prog/plasma
// see also: https://www.shadertoy.com/view/XdX3Wn
// and http://iq12.com/2013/04/fifty-shaders-of-grey/

// TODO: Add www.shadertoy.com/view/4dlGDN www.shadertoy.com/view/lsfGzr

final ShaderObject plasmaVertexShader1 = ShaderObject.vertex("Plasma1V")
  ..addAttributeVars([aPosition, aTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vTexUV])
  ..setBody([stdVertexShaderWithTextureForwardString]);

final ShaderObject plasmaFragmentShader1 = ShaderObject.fragment("Plasma1F")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uTime])
  ..setBody([
    """
void main() {  
    #define PI 3.1415926535897932384626433832795
    float u_time = $uTime * 5.0;
    vec2 u_k = vec2(10.0,10.0);

    float v = 0.0;
    vec2 c = $vTexUV * u_k - u_k/2.0;
    v += sin((c.x+u_time));
    v += sin((c.y+u_time)/2.0);
    v += sin((c.x+c.y+u_time)/2.0);
    c += u_k/2.0 * vec2(sin(u_time/3.0), cos(u_time/2.0));
    v += sin(sqrt(c.x*c.x+c.y*c.y+1.0)+u_time);
    v = v / 2.0;
    vec3 col1 = vec3(1.0, sin(PI*v), cos(PI*v));
    vec3 col2 = vec3(sin(PI*v), cos(PI*v), -1.0);
    vec3 col = mix(col1, col2, sin(u_time)*.5+.5);
    $oFragColor = vec4(col*.5 + .5, 1.0);
}
""",
  ]);

final ShaderObject plasmaVertexShader2 = ShaderObject.vertex("Plasma2V")
  ..addAttributeVars([aPosition, aTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vTexUV])
  ..setBody([stdVertexShaderWithTextureForwardString]);

final ShaderObject plasmaFragmentShader2 = ShaderObject.fragment("Plasma2F")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uTime])
  ..setBody([
    """
void main() {  
    float x = $vTexUV.x;
    float y = $vTexUV.y;
    float v = sin(x * cos($uTime/15.0) * 120.0) +
              cos(y * sin($uTime/10.0) * 120.0) +
              sin(sqrt(y * y + x * x) * 40.0);
    $oFragColor = vec4(1, v,1,1);
}
  """,
  ]);

final ShaderObject plasmaVertexShader3 = ShaderObject.vertex("Plasma3V")
  ..addAttributeVars([aPosition, aTexUV])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vTexUV])
  ..setBody([stdVertexShaderWithTextureForwardString]);

final ShaderObject plasmaFragmentShader3 = ShaderObject.fragment("Plasma3F")
  ..addVaryingVars([vTexUV])
  ..addUniformVars([uTime])
  ..setBody([
    """
void main() {  
    float x = $vTexUV.x*1000.0; // gl_FragCoord.x;
    float y = $vTexUV.y*1000.0; // gl_FragCoord.y;
    float time = $uTime;
    float mov0 = x+y+cos(sin(time)*2.)*100.+sin(x/100.)*1000.;
    float mov1 = y / 720.0 / 0.2 + time;
    float mov2 = x / 1280.0 / 0.2;
    float c1 = abs(sin(mov1+time)/2.+mov2/2.-mov1-mov2+time);
    float c2 = abs(sin(c1+sin(mov0/1000.+time)+sin(y/40.+time)+sin((x+y)/100.)*3.));
    float c3 = abs(sin(c2+cos(mov1+mov2+c2)+cos(mov2)+sin(x/1000.)));
    $oFragColor = vec4( c1,c2,c3,1.0);
}
  """,
  ]);

RenderBatch makeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "stars",
      lifetime.own(
        RenderProgram.create(
          name: "stars",
          context: cgl,
          vertexShader: pointSpritesVertexShader,
          fragmentShader: pointSpritesFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  scene.add(makeParticles(scene.program, num, random: math.Random()));
  return scene;
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
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 65.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  CameraUniforms perspective = CameraUniforms(camera);

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );
  // A scene is tied to a single shader, so we must create a separate
  // shader for each plasma type.
  List<RenderBatch> scenes = [
    lifetime.ownBatch(
      RenderBatch(
        "plasma1",
        lifetime.own(
          RenderProgram.create(
            name: "plasma1",
            context: cgl,
            vertexShader: plasmaVertexShader1,
            fragmentShader: plasmaFragmentShader1,
          ),
        ),
        [perspective],
      ),
    ),
    lifetime.ownBatch(
      RenderBatch(
        "plasma2",
        lifetime.own(
          RenderProgram.create(
            name: "plasma2",
            context: cgl,
            vertexShader: plasmaVertexShader2,
            fragmentShader: plasmaFragmentShader2,
          ),
        ),
        [perspective],
      ),
    ),
    lifetime.ownBatch(
      RenderBatch(
        "plasma3",
        lifetime.own(
          RenderProgram.create(
            name: "plasma3",
            context: cgl,
            vertexShader: plasmaVertexShader3,
            fragmentShader: plasmaFragmentShader3,
          ),
        ),
        [perspective],
      ),
    ),
  ];
  for (RenderBatch s in scenes) {
    phase.add(s);
  }

  Material mat = lifetime.own(Material("mat"));
  GpuMesh md = lifetime.own(
    shapeCube(scenes[0].program, x: 10.0, y: 10.0, z: 10.0),
  );

  Node cube = MeshNode(md.name, md, mat)
    ..setPos(0.0, 0.0, 0.0)
    ..lookUp(1.0)
    ..lookLeft(0.7);

  // The cube is initially in scene and we move it from scene to
  // scene as the active scene changes
  int activeScene = 0;
  scenes[activeScene].add(cube);

  // Advance scene when an arbitrary key is pressed
  lifetime.own(
    web.EventStreamProviders.keyPressEvent.forTarget(web.document).listen((
      event,
    ) {
      scenes[activeScene % 3].remove(cube);
      scenes[(activeScene + 1) % 3].add(cube);
      activeScene = (activeScene + 1) % 3;
    }),
  );

  // Chose a specific scene
  web.HTMLSelectElement myselect =
      web.document.querySelector('#myselect') as web.HTMLSelectElement;
  lifetime.own(
    myselect.onChange.listen((web.Event e) {
      scenes[activeScene].remove(cube);
      activeScene = myselect.selectedIndex;
      scenes[(activeScene)].add(cube);
    }),
  );

  phase.add(makeStarScene(cgl, perspective, 2000));

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
    orbit.azimuth += 0.06 * elapsed / 1000;
    orbit.update(elapsed / 1000);

    cube.rollLeft(elapsed * 0.0005);
    cube.lookLeft(elapsed * 0.0005);
    mat.forceUniform(uTime, timeMs / 1000.0);

    phase.draw();
    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
