import 'dart:typed_data';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'dart:js_interop';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';

final ShaderObject demoVertexShader = ShaderObject("demoVertexShader")
  ..addAttributeVars([aPosition, aPointSize, aColor])
  ..addVaryingVars([vColor])
  ..setBody([
    """
void main(void) {
    gl_Position = vec4($aPosition.xy, 0.0, 1.0);
    gl_PointSize = $aPointSize;
    $vColor = $aColor;
}
""",
  ]);

final ShaderObject demoFragmentShader = ShaderObject("demoFragmentShader")
  ..addVaryingVars([vColor])
  ..setBody([
    """
void main(void) {
    float r = length(gl_PointCoord.xy - vec2(0.5, 0.5));
    $oFragColor.rgb = r*r < 0.2 ? $vColor : vec3(0.0, 0.0, 0.0);
}
""",
  ]);

final vm.Vector2 middle = vm.Vector2(0.5, 0.5);

class Sprite {
  Sprite(this.isShip, this.size, math.Random rng)
    : pos = vm.Vector2.random(rng)
        ..sub(middle)
        ..scale(2.0),
      velocity = rng.nextDouble(),
      angle = 2.0 * math.pi * rng.nextDouble(),
      color = vm.Vector3.random(rng) {
    dir.setValues(dirX, dirY);
  }

  final bool isShip;
  double size;
  final vm.Vector2 pos;
  double angle;
  double velocity;
  final vm.Vector2 dir = vm.Vector2.zero(); // cache cartesian direction
  final vm.Vector3 color;

  double get dirX => velocity * math.sin(angle);
  double get dirY => velocity * math.cos(angle);

  void advanceTime(double speed) {
    pos.addScaled(dir, speed);
    if (isShip) {
      if (pos.x < -1.0) pos.x = 2.0 - pos.x;
      if (pos.x > 1.0) pos.x = -2.0 + pos.x;
      if (pos.y < -1.0) pos.y = 2.0 - pos.y;
      if (pos.y > 1.0) pos.y = -2.0 + pos.y;
    }
  }

  void setAngle(double a) {
    angle = a;
    dir.setValues(dirX, dirY);
  }

  void setVelocity(double v) {
    if (v > 10.0) v = 10.0;
    if (v < 0.0) v = 0.0;
    velocity = v;
    dir.setValues(dirX, dirY);
  }

  void turnLeft() {
    setAngle(angle - 2.0 * math.pi * 0.005);
  }

  void accelerate() {
    setVelocity(velocity + 0.05);
  }

  void brake() {
    setVelocity(velocity - 0.05);
  }

  void turnRight() {
    setAngle(angle + 2.0 * math.pi * 0.005);
  }

  bool isInvisible() {
    if (isShip) return false;
    return pos.x > 1.0 || pos.x < -1.0 || pos.y > 1.0 || pos.y < -1.0;
  }
}

const int numBullets = 10;

void extractSpritePositions(List<Sprite> sprites, Float32List out) {
  int offset = 0;
  for (Sprite s in sprites) {
    if (s.isShip) {
      //s.size = 1000.0;
      double dx = math.sin(s.angle);
      double dy = math.cos(s.angle);
      double d2x = -dy * 0.05;
      double d2y = dx * 0.05;
      dx *= 0.07;
      dy *= 0.07;

      out[offset + 0] = s.pos.x + dx;
      out[offset + 1] = s.pos.y + dy;
      out[offset + 2] = 0.0;
      offset += 3;
      out[offset + 0] = s.pos.x + d2x;
      out[offset + 1] = s.pos.y + d2y;
      out[offset + 2] = 0.0;
      offset += 3;
      out[offset + 0] = s.pos.x - d2x;
      out[offset + 1] = s.pos.y - d2y;
      out[offset + 2] = 0.0;
      offset += 3;
    } else {
      out[offset + 0] = s.pos.x;
      out[offset + 1] = s.pos.y;
      out[offset + 2] = 0.0;
      offset += 3;
    }
  }
}

void extractSpriteColors(List<Sprite> sprites, Float32List out) {
  int offset = 0;
  for (Sprite s in sprites) {
    out[offset + 0] = s.color.r;
    out[offset + 1] = s.color.g;
    out[offset + 2] = s.color.b;
    offset += 3;

    if (s.isShip) {
      for (int i = 0; i < 2; i++) {
        out[offset + 0] = s.color.r * 0.5;
        out[offset + 1] = s.color.g * 0.5;
        out[offset + 2] = s.color.b * 0.5;
        offset += 3;
      }
    }
  }
}

void extractSpriteSizes(List<Sprite> sprites, Float32List out) {
  int offset = 0;
  for (Sprite s in sprites) {
    out[offset] = s.size;
    offset++;

    if (s.isShip) {
      for (int i = 0; i < 2; i++) {
        out[offset] = s.size;
        offset++;
      }
    }
  }
}

final web.HTMLDivElement info =
    web.document.querySelector('#info') as web.HTMLDivElement;

class Gamepad {
  Gamepad();

  double x = 0.0;
  double y = 0.0;
  bool button = false;
  bool justPressed = false;
  bool justReleased = false;

  void poll() {
    web.Gamepad? gp;
    final pads = web.window.navigator.getGamepads().toDart;
    for (final p in pads) {
      if (p == null) continue;
      gp = p;
      break;
    }
    print("polling");
    if (gp != null) {
      List<bool> bs = [];
      for (final b in gp.buttons.toDart) {
        bs.add(b.pressed);
      }
      final axes = gp.axes.toDart.map((axis) => axis.toDartDouble).toList();
      info.style.whiteSpace = 'pre-line';
      info.textContent = "${gp.id}\naxes: $axes\nbuttons: $bs";
    }

    // x = _gp!.axes[0] + 0.0;
    // y = _gp!.axes[1] + 0.0;
    // if (button != _gp!.buttons[0].pressed) {
    //   if (button) {
    //     justReleased = true;
    //   } else {
    //     justPressed = true;
    //   }
    // }
    // button = _gp!.buttons[0].pressed;
  }

  void afterFrameCleanup() {
    justPressed = false;
    justReleased = false;
  }
}

void handleUseInput(Keyboard input, Gamepad gamepad, List<Sprite> sprites) {
  gamepad.poll();

  if (input.currentlyPressedKey(Keyboard.left) || gamepad.x < -0.5) {
    sprites[0].turnLeft();
  } else if (input.currentlyPressedKey(Keyboard.right) || gamepad.x > 0.5) {
    sprites[0].turnRight();
  } else if (input.currentlyPressedKey(Keyboard.up) || gamepad.y < -0.5) {
    sprites[0].accelerate();
  } else if (input.currentlyPressedKey(Keyboard.down) || gamepad.y > 0.5) {
    sprites[0].brake();
  } else if (input.justPressedKey(Keyboard.space) || gamepad.justPressed) {
    print("fire");
    for (Sprite s in sprites) {
      Sprite ship = sprites[0];
      if (s.isInvisible()) {
        s.pos.setFrom(ship.pos);
        s.setAngle(ship.angle);
        s.setVelocity(10.0);
        break;
      }
    }
  }
  gamepad.afterFrameCleanup();
  input.afterFrameCleanup();
}

void main() {
  final math.Random rng = math.Random();
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final int w = canvas.clientWidth;
  final int h = canvas.clientHeight;
  final int d = math.min(w, h);
  // use a square canvas to avoid distortion
  canvas.width = d;
  canvas.height = d;

  final Keyboard input = Keyboard(null);
  final Gamepad gamepad = Gamepad();

  final List<Sprite> sprites = [Sprite(true, 50.0, rng)];
  for (int i = 0; i < numBullets; ++i) {
    sprites.add(Sprite(false, 20.0, rng));
  }

  final ChronosGL cgl = ChronosGL(canvas, antialiasing: false);
  // Create the main shader program for displaying the torus.
  final RenderProgram prog = RenderProgram(
    "basic",
    cgl,
    demoVertexShader,
    demoFragmentShader,
  );

  final Float32List points = Float32List(3 * (sprites.length + 2));
  final Float32List sizes = Float32List(sprites.length + 2);
  final Float32List colors = Float32List(3 * (sprites.length + 2));

  extractSpritePositions(sprites, points);
  extractSpriteSizes(sprites, sizes);
  extractSpriteColors(sprites, colors);

  final MeshData mesh = prog.makeMeshData("points", glPoints)
    ..addVertices(points)
    ..addAttribute(aPointSize, sizes, 1)
    ..addAttribute(aColor, colors, 3);

  Material mat = Material("nodepth")
    ..forceUniform(cBlendEquation, blendEquationAdd)
    ..forceUniform(cDepthTest, false)
    ..forceUniform(cDepthWrite, false);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    for (Sprite s in sprites) {
      s.advanceTime(elapsed / 10000.0);
    }

    handleUseInput(input, gamepad, sprites);

    extractSpritePositions(sprites, points);
    mesh.changeVertexData(points);

    prog.draw(mesh, [mat]);
    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
