// These bindings match the engine's current browser backend.
// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'golden_image.dart';

const goldenSceneNames = [
  'geometry',
  'perspective',
  'orthographic',
  'texture',
  'depth',
  'blending',
  'lighting',
];

/// No DOM attachment, input listeners, clocks, random data, or network assets.
class GoldenScene {
  GoldenScene(String name, {bool mutate = false}) {
    final canvas = html.CanvasElement(width: size, height: size);
    cgl = ChronosGL(canvas, antialiasing: false);
    cgl.disable(glDither);
    framebuffer = Framebuffer.defaultFramebuffer(cgl, size, size);
    phase = RenderPhase('golden', cgl, framebuffer)
      ..viewPortW = size
      ..viewPortH = size;
    switch (name) {
      case 'geometry':
        _geometry(mutate);
      case 'perspective':
        _camera(false);
      case 'orthographic':
        _camera(true);
      case 'texture':
        _texture();
      case 'depth':
        _depth();
      case 'blending':
        _blending();
      case 'lighting':
        _lighting();
      default:
        throw ArgumentError.value(name, 'scene');
    }
  }

  static const size = 256;
  late final ChronosGL cgl;
  late final Framebuffer framebuffer;
  late final RenderPhase phase;

  Map<String, Object> get environment {
    final extension = cgl.getExtension('WEBGL_debug_renderer_info');
    final renderer = extension == null
        ? cgl.getParameter(glRenderer).toString()
        : cgl.getParameter(glUnmaskedRendererWebgl).toString();
    return {
      'userAgent': html.window.navigator.userAgent,
      'renderer': renderer,
      'webglVersion': cgl.getParameter(glVersion).toString(),
      'imageSize': [size, size],
      'channelTolerance': 2,
    };
  }

  GoldenImage render() {
    // Transparent materials leave depth writes disabled. gl.clear respects
    // that mask, so restore the fixture's starting state before clearing.
    cgl.depthMask(true);
    phase.draw();
    final pixels = framebuffer.extractByteData(null, 0, 0, size, size);
    final error = cgl.getError();
    if (error != glNoError) throw StateError('WebGL error: $error');
    return GoldenImage.fromFramebuffer(size, size, pixels);
  }

  void dispose() {
    final dynamic extension = cgl.getExtension('WEBGL_lose_context');
    if (extension != null) extension.loseContext();
  }

  RenderProgram _solid() => RenderProgram(
    'solid',
    cgl,
    solidColorVertexShader,
    solidColorFragmentShader,
  );

  UniformGroup _identity() =>
      UniformGroup('clip-space')
        ..setUniform(uPerspectiveViewMatrix, vm.Matrix4.identity());

  Material _color(String name, vm.Vector3 color) =>
      Material(name)..setUniform(uColor, color);

  MeshData _quad(RenderProgram program, double size) =>
      geometryBuilderToMeshData('quad', program, quadGeometry(size));

  void _geometry(bool mutate) {
    final program = _solid();
    final root = Node.container('parent')
      ..rotZ(-0.12)
      ..setPos(0.02, 0.04, 0.0);
    root.add(
      Node(
          'cube',
          shapeCube(program, x: 0.28, y: 0.28, z: 0.28),
          _color('cube', mutate ? colorGreen : colorRed),
        )
        ..rotX(0.4)
        ..rotY(0.55)
        ..setPos(-0.43, -0.25, 0.0),
    );
    root.add(
      Node(
        'sphere',
        shapeIcosahedron(program, subdivisions: 2, scale: 0.3),
        _color('sphere', colorCyan),
      )..setPos(0.43, -0.25, 0.0),
    );
    root.add(
      Node(
          'wedge',
          shapeWedge(program, x: 0.25, y: 0.25, z: 0.25),
          _color('wedge', colorYellow),
        )
        ..rotY(0.4)
        ..rotX(0.3)
        ..setPos(0.0, 0.43, 0.0),
    );
    phase.add(Scene('geometry', program, [_identity()])..add(root));
  }

  UniformGroup _projection(bool orthographic) {
    final camera = _FixedCamera();
    if (orthographic) {
      return Orthographic(camera, -2.1, 2.1, -2.1, 0.1, 30.0)
        ..adjustAspect(size, size);
    }
    return Perspective(camera, 0.1, 30.0)
      ..updateFov(28.0)
      ..adjustAspect(size, size);
  }

  void _camera(bool orthographic) {
    final program = _solid();
    final scene = Scene('camera', program, [_projection(orthographic)]);
    final positions = [
      vm.Vector3(-0.95, -0.45, 0.6),
      vm.Vector3(0.7, -0.45, -0.8),
      vm.Vector3(0.0, 0.8, 0.0),
    ];
    final colors = [colorRed, colorGreen, colorBlue];
    for (var i = 0; i < positions.length; i++) {
      scene.add(
        Node(
            'cube-$i',
            shapeCube(program, x: 0.4, y: 0.4, z: 0.4),
            _color('color-$i', colors[i]),
          )
          ..rotY(0.2 + i * 0.2)
          ..setPosFromVec(positions[i]),
      );
    }
    phase.add(scene);
  }

  ImageTexture _canvasTexture({bool black = false}) {
    final canvas = html.CanvasElement(width: 8, height: 8);
    final context = canvas.context2D;
    if (black) {
      context
        ..fillStyle = '#000000'
        ..fillRect(0, 0, 8, 8);
    } else {
      final colors = ['#ef4444', '#22c55e', '#3b82f6', '#facc15'];
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          context
            ..fillStyle = (x + y) % 2 == 0
                ? colors[(y ~/ 4) * 2 + x ~/ 4]
                : '#ffffff'
            ..fillRect(x, y, 1, 1);
        }
      }
    }
    return ImageTexture(
      cgl,
      'generated-texture',
      canvas,
      TextureProperties()
        ..clamp = true
        ..setFilterNearest(),
    );
  }

  void _texture() {
    final program = RenderProgram(
      'texture',
      cgl,
      texturedVertexShader,
      texturedFragmentShader,
    );
    final material = _color('texture', colorBlack)
      ..setUniform(uTexture, _canvasTexture());
    final quad = Node('quad', _quad(program, 0.72), material)..rotZ(0.18);
    phase.add(Scene('texture', program, [_identity()])..add(quad));
  }

  void _depth() {
    final program = _solid();
    final scene = Scene('depth', program, [_identity()]);
    // Submit the nearest surface first: a broken depth test lets blue cover it.
    scene.add(
      Node('near', _quad(program, 0.44), _color('near', colorRed))
        ..setPos(-0.18, 0.12, -0.4),
    );
    scene.add(
      Node('far', _quad(program, 0.65), _color('far', colorBlue))
        ..setPos(0.13, -0.08, 0.3),
    );
    scene.add(
      Node('middle', _quad(program, 0.32), _color('middle', colorGreen))
        ..setPos(0.35, 0.36, -0.1),
    );
    phase.add(scene);
  }

  void _blending() {
    final solid = _solid();
    phase.add(
      Scene('background', solid, [_identity()])..add(
        Node('blue', _quad(solid, 0.8), _color('blue', colorBlue))
          ..setPos(0.0, 0.0, 0.5),
      ),
    );
    final fragment = ShaderObject('half-alpha')
      ..addUniformVars([uColor])
      ..setBodyWithMain(['$oFragColor = vec4($uColor, 0.5);']);
    final program = RenderProgram(
      'alpha',
      cgl,
      solidColorVertexShader,
      fragment,
    );
    final red = Material.transparent('red', blendEquationStandard)
      ..setUniform(uColor, colorRed);
    final green = Material.transparent('green', blendEquationStandard)
      ..setUniform(uColor, colorGreen);
    phase.add(
      Scene('transparent', program, [_identity()])
        ..add(Node('red', _quad(program, 0.48), red)..setPos(-0.22, 0.12, 0.0))
        ..add(
          Node('green', _quad(program, 0.48), green)..setPos(0.22, -0.12, -0.2),
        ),
    );
  }

  void _lighting() {
    final program = RenderProgram(
      'light',
      cgl,
      lightVertexShaderBlinnPhong,
      lightFragmentShaderBlinnPhong,
    );
    final illumination = Illumination()
      ..addLight(
        DirectionalLight(
          'key',
          vm.Vector3(-1.0, -1.5, -2.0),
          vm.Vector3(0.8, 0.55, 0.25),
          vm.Vector3(0.4, 0.4, 0.4),
          10.0,
        ),
      )
      ..addLight(
        DirectionalLight(
          'fill',
          vm.Vector3(1.0, 0.0, -0.5),
          vm.Vector3(0.1, 0.25, 0.5),
          vm.Vector3.zero(),
          10.0,
        ),
      );
    final material = Material('lit')
      ..setUniform(uTexture, _canvasTexture(black: true))
      ..setUniform(uShininess, 24.0);
    phase.add(
      Scene('light', program, [_projection(false), illumination])
        ..add(
          Node(
            'sphere',
            shapeIcosahedron(program, subdivisions: 3, scale: 0.9),
            material,
          )..setPos(-0.65, 0.0, 0.0),
        )
        ..add(
          Node('cube', shapeCube(program, x: 0.5, y: 0.5, z: 0.5), material)
            ..rotY(0.4)
            ..setPos(0.85, 0.0, 0.0),
        ),
    );
  }
}

class _FixedCamera extends Spatial {
  _FixedCamera() : super('fixed-camera');

  final vm.Vector3 _eye = vm.Vector3(4.0, 3.0, 6.0);

  @override
  void getViewMatrix(vm.Matrix4 matrix) => vm.setViewMatrix(
    matrix,
    _eye,
    vm.Vector3.zero(),
    vm.Vector3(0.0, 1.0, 0.0),
  );

  @override
  vm.Vector3 getEyePosition() => _eye;
}
