import "dart:async";
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'shader.dart';

const double musicSlowBegin = 95.0;
const double musicSlowEnd = 123.0;

const double musicMuteBegin = 159.2;
const double musicMuteEnd = 161.72;

const double musicBeatsBegin = 28.32;
const double flySpeedDivider = 3.0;

const double cameraIntroEnd = 6.0;
const double cameraTargetDistance = 0.3;

const String modelFile = "../ct_logo.obj";

const String about = """ 
Music: Life's things by Mindthings.
Browser demo for c't competition 2013 by ray@systaro.de.
Inspiration from clicktorelease.com.
""";

final List<Future<Object>> gLoadables = [];

void positionInTorus(double time, vm.Vector3 out) {
  torusKnotGetPos(time / 2.0, 3, 2, 20.0, 1.0, out);
}

double getTweenFactor(double begin, double end, double current) {
  double diff = end - begin;
  return (current - begin) / diff;
}

double tween(double now) {
  double offset = musicBeatsBegin / flySpeedDivider - cameraIntroEnd;
  if (now > musicSlowBegin && now < musicSlowEnd) {
    // music is slow: slow camera down
    double diff = musicSlowEnd - musicSlowBegin;
    double drag = math.sin(((now - musicSlowBegin) / diff) * math.pi / 2) * 3;
    return drag + offset;
  } else if (now > musicMuteBegin && now < musicMuteEnd) {
    double diff = musicMuteEnd - musicMuteBegin;
    double drag = math.sin(((now - musicMuteBegin) / diff) * math.pi / 2) * 3;
    return drag + offset;
  } else {
    return offset;
  }
}

class TheNodes {
  TheNodes() {
    positionInTorus(cameraIntroEnd, cameraIntroEndPoint);
  }

  late Material material;
  late Node knot;
  late Node icoBig;
  late Node icoSmall;
  late Node ctLogo;
  late Spatial camera;
  final vm.Vector3 cameraIntroStartPoint = vm.Vector3(60.0, -70.0, 150.0);
  final vm.Vector3 cameraIntroEndPoint = vm.Vector3.zero();
  bool switched = false;
  int switchCount = 0;
  final vm.Vector3 _p1 = vm.Vector3.zero();
  final vm.Vector3 _p2 = vm.Vector3.zero();

  // now == -1.0 signals music ended
  void advanceTimeline(double now) {
    final double tweenAmount = tween(now);

    if (now <= 2.0) {
      // do nothing
    } else if (now < musicBeatsBegin) {
      // intro time: slowly move camera to torus
      knot.enabled = true;
      icoBig.enabled = true;
      // icoSmall.enabled = true;
      final double frac = now / 30.0; // 30.0 is close to musicBeatsBegin
      vm.Vector3.mix(cameraIntroStartPoint, cameraIntroEndPoint, frac, _p1);
      camera.setPosFromVec(_p1);
      camera.lookAt(cameraIntroEndPoint);
    } else {
      knot.enabled = true;
      icoBig.enabled = false;
      if (now > 180.0) {
        material.setUniform(uFadeFactor, getTweenFactor(180.0, 192.0, now));
      }
      final double pos = now / flySpeedDivider - tweenAmount;
      positionInTorus(pos, _p1);
      positionInTorus(pos + cameraTargetDistance, _p2);
      camera.setPosFromVec(_p1);
      camera.lookAt(_p2);
    }

    final double amp = math.sin(now / 6.0 - 1.5);
    if (amp > 0.9) {
      if (!switched) {
        if (icoSmall.enabled) {
          ctLogo.enabled = true;
          icoSmall.enabled = false;
        } else {
          ctLogo.enabled = false;
          icoSmall.enabled = true;
        }
        switched = true;
        switchCount++;
      }
    } else {
      switched = false;
    }

    if (switchCount >= 5) {
      // music is about to end
      icoSmall.enabled = false;
      ctLogo.enabled = false;
    }

    // ctLogo.enabled = true;
    final Node active = ctLogo.enabled ? ctLogo : icoSmall;
    final double pos = now / flySpeedDivider + amp + 1.1 - tweenAmount;

    positionInTorus(pos, _p1);
    positionInTorus(pos + cameraTargetDistance, _p2);
    active.rotZ(now / 1000.0);
    active.setPosFromVec(_p1);

    //active.lookAt(_p2, camera.getUp());
    //active.setPosFromVec(_p1);
    // we want the ct sign to stand upward
    // why does this change the position?
  }
}

void main() {
  introduceNewShaderVar(uFadeFactor, const ShaderVarDesc("float", ""));
  final html.DivElement infoElement =
      html.document.getElementById("info") as html.DivElement;
  final html.CanvasElement canvas =
      html.document.getElementById("webgl-canvas") as html.CanvasElement;
  final html.AudioElement musicElement =
      html.document.getElementById("music") as html.AudioElement;
  final ChronosGL cgl = ChronosGL(canvas);
  final theNodes = TheNodes();

  theNodes.camera = Spatial("camera");

  Perspective perspective = Perspective(theNodes.camera, 0.1, 1000.0);

  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;
  perspective.adjustAspect(width, height);
  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );

  theNodes.material = Material("matLogo")..setUniform(uFadeFactor, 0.0);

  // =========================================
  final Scene scenePnvc = Scene("", makeVertexColorShader(cgl), [perspective]);
  phase.add(scenePnvc);

  theNodes.knot = Node(
    "knot",
    shapeTorusKnot(scenePnvc.program, segmentsR: 512, segmentsT: 64),
    theNodes.material,
  )..enabled = false;
  scenePnvc.add(theNodes.knot);

  // =========================================
  final RenderProgram pncNovertexmovement = RenderProgram(
    "flying_logo",
    cgl,
    perlinNoiseVertexShader,
    makePerlinNoiseColorFragmentShader(false),
  );

  final Scene scenePncNovertexmovement = Scene("", pncNovertexmovement, [
    perspective,
  ]);
  phase.add(scenePncNovertexmovement);

  // =========================================
  final RenderProgram pncb = RenderProgram(
    "background",
    cgl,
    perlinNoiseVertexShader,
    makePerlinNoiseColorFragmentShader(true),
  );

  final Scene scenePncb = Scene("", pncb, [perspective]);
  phase.add(scenePncb);

  theNodes.icoBig = Node(
    "large_sphere",
    shapeIcosahedron(scenePncb.program, subdivisions: 3, scale: 500),
    theNodes.material,
  )..enabled = false;
  scenePncb.add(theNodes.icoBig);

  // =========================================
  final RenderProgram pnc = RenderProgram(
    "flying_deformaning_ball",
    cgl,
    deformingPerlinNoiseVertexShader,
    makePerlinNoiseColorFragmentShader(false),
  );

  final Scene scenePnc = Scene("", pnc, [perspective]);
  phase.add(scenePnc);
  theNodes.icoSmall = Node(
    "small_sphere",
    shapeIcosahedron(scenePnc.program, subdivisions: 4),
    theNodes.material,
  )..enabled = false;
  scenePnc.add(theNodes.icoSmall);

  var future = loadRaw(modelFile)
    ..then((String content) {
      GeometryBuilder gb = importGeometryFromWavefront(content);
      MeshData md = geometryBuilderToMeshData("", pncNovertexmovement, gb);
      theNodes.ctLogo = Node(md.name, md, theNodes.material)
        ..rotX(math.pi / 2.0)
        ..rotZ(math.pi)
        ..transform.scaleByDouble(0.25, 0.25, 0.25, 1.0)
        ..enabled = false;
      scenePncNovertexmovement.add(theNodes.ctLogo);
      //  ctLogo.invert=true;  // ???????????
    });
  gLoadables.add(future);

  double startMs = -1.0;
  void animate(num timeMs) {
    if (startMs < 0.0) startMs = timeMs.toDouble();
    //final double now = (timeMs - startMs) * 0.001 *  2.0 + 20;
    final double now = musicElement.currentTime.toDouble();
    if (musicElement.ended || now > 192.0) {
      infoElement.text = about;
    } else {
      theNodes.advanceTimeline(now);
      //infoElement.text = "${now}";
    }

    theNodes.material.forceUniform(uTime, timeMs / 1000.0);
    phase.draw();

    html.window.animationFrame.then(animate);
  }

  Future.wait(gLoadables).then((list) {
    musicElement.play();
    infoElement.text = "";

    animate(0.0);
  });
}
