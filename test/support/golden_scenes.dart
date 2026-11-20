import 'dart:js_interop';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

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
    if (!goldenSceneNames.contains(name)) {
      throw ArgumentError.value(name, 'scene');
    }
    final canvas = web.HTMLCanvasElement()
      ..width = size
      ..height = size;
    cgl = ChronosGL.fromCanvas(canvas, antialiasing: false);
    cgl.disable(glDither);
    framebuffer = Framebuffer.defaultFramebuffer(cgl, size, size);
    phase =
        RenderPass.named(name: 'golden', context: cgl, framebuffer: framebuffer)
          ..viewPortW = size
          ..viewPortH = size;
    try {
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
      }
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  static const size = 256;
  late final ChronosGL cgl;
  late final Framebuffer framebuffer;
  late final RenderPass phase;
  final _programs = <RenderProgram>[];
  final _meshes = <GpuMesh>[];
  final _textures = <Texture>[];
  bool _isDisposed = false;

  Map<String, Object> get environment {
    final extension = cgl.getExtension('WEBGL_debug_renderer_info');
    final renderer = extension == null
        ? cgl.getParameter(glRenderer).toString()
        : cgl.getParameter(glUnmaskedRendererWebgl).toString();
    return {
      'userAgent': web.window.navigator.userAgent,
      'renderer': renderer,
      'webglVersion': cgl.getParameter(glVersion).toString(),
      'imageSize': [size, size],
      'channelTolerance': 2,
    };
  }

  GoldenImage render() {
    if (_isDisposed) throw StateError('Golden scene has been disposed');
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
    if (_isDisposed) return;
    _isDisposed = true;
    Object? firstError;
    StackTrace? firstStack;
    for (final release in <void Function()>[
      ..._meshes.map((mesh) => mesh.dispose),
      ..._programs.map((program) => program.dispose),
      ..._textures.map((texture) => texture.dispose),
      framebuffer.dispose,
      () {
        final extension = cgl.getExtension('WEBGL_lose_context');
        if (extension != null) {
          (extension as web.WEBGL_lose_context).loseContext();
        }
      },
    ]) {
      try {
        release();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  RenderProgram _program(
    String name,
    ShaderObject vertex,
    ShaderObject fragment,
  ) {
    final program = RenderProgram.create(
      name: name,
      context: cgl,
      vertexShader: vertex,
      fragmentShader: fragment,
    );
    _programs.add(program);
    return program;
  }

  GpuMesh _mesh(GpuMesh mesh) {
    _meshes.add(mesh);
    return mesh;
  }

  RenderProgram _solid() =>
      _program('solid', solidColorVertexShader, solidColorFragmentShader);

  UniformGroup _identity() =>
      UniformGroup('clip-space')
        ..set(UniformKeys.perspectiveViewMatrix, vm.Matrix4.identity());

  Material _color(String name, vm.Vector3 color) =>
      Material(name)..set(UniformKeys.color, color);

  GpuMesh _quad(RenderProgram program, double size) =>
      _mesh(uploadGeometry('quad', program, quadGeometry(size)));

  void _geometry(bool mutate) {
    final program = _solid();
    final root = GroupNode('parent')
      ..rotZ(-0.12)
      ..setPos(0.02, 0.04, 0.0);
    root.add(
      MeshNode(
          'cube',
          _mesh(shapeCube(program, x: 0.28, y: 0.28, z: 0.28)),
          _color(
            'cube',
            mutate ? colorGreen.toVector3() : colorRed.toVector3(),
          ),
        )
        ..rotX(0.4)
        ..rotY(0.55)
        ..setPos(-0.43, -0.25, 0.0),
    );
    root.add(
      MeshNode(
        'sphere',
        _mesh(shapeIcosahedron(program, subdivisions: 2, scale: 0.3)),
        _color('sphere', colorCyan.toVector3()),
      )..setPos(0.43, -0.25, 0.0),
    );
    root.add(
      MeshNode(
          'wedge',
          _mesh(shapeWedge(program, x: 0.25, y: 0.25, z: 0.25)),
          _color('wedge', colorYellow.toVector3()),
        )
        ..rotY(0.4)
        ..rotX(0.3)
        ..setPos(0.0, 0.43, 0.0),
    );
    phase.add(RenderBatch('geometry', program, [_identity()])..add(root));
  }

  UniformGroup _projection(bool orthographic) {
    final Camera camera = orthographic
        ? OrthographicCamera(
            left: -2.1,
            right: 2.1,
            bottom: -2.1,
            top: 2.1,
            near: 0.1,
            far: 30.0,
          )
        : PerspectiveCamera(
            fovYRadians: 28 * math.pi / 180,
            near: 0.1,
            far: 30.0,
          );
    camera
      ..setPosition(4.0, 3.0, 6.0)
      ..lookAt(vm.Vector3.zero());
    return CameraUniforms(camera);
  }

  void _camera(bool orthographic) {
    final program = _solid();
    final scene = RenderBatch('camera', program, [_projection(orthographic)]);
    final positions = [
      vm.Vector3(-0.95, -0.45, 0.6),
      vm.Vector3(0.7, -0.45, -0.8),
      vm.Vector3(0.0, 0.8, 0.0),
    ];
    final colors = [
      colorRed.toVector3(),
      colorGreen.toVector3(),
      colorBlue.toVector3(),
    ];
    for (var i = 0; i < positions.length; i++) {
      scene.add(
        MeshNode(
            'cube-$i',
            _mesh(shapeCube(program, x: 0.4, y: 0.4, z: 0.4)),
            _color('color-$i', colors[i]),
          )
          ..rotY(0.2 + i * 0.2)
          ..setPosFromVec(positions[i]),
      );
    }
    phase.add(scene);
  }

  ImageTexture _canvasTexture({bool black = false}) {
    final canvas = web.HTMLCanvasElement()
      ..width = 8
      ..height = 8;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    if (black) {
      context
        ..fillStyle = '#000000'.toJS
        ..fillRect(0, 0, 8, 8);
    } else {
      final colors = ['#ef4444', '#22c55e', '#3b82f6', '#facc15'];
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          context
            ..fillStyle =
                ((x + y) % 2 == 0 ? colors[(y ~/ 4) * 2 + x ~/ 4] : '#ffffff')
                    .toJS
            ..fillRect(x, y, 1, 1);
        }
      }
    }
    final texture = ImageTexture.fromCanvas(
      context: cgl,
      name: 'generated-texture',
      canvas: canvas,
      properties: const TextureProperties(
        clamp: true,
        minFilter: glNearest,
        magFilter: glNearest,
      ),
    );
    _textures.add(texture);
    return texture;
  }

  void _texture() {
    final program = _program(
      'texture',
      texturedVertexShader,
      texturedFragmentShader,
    );
    final material = _color('texture', colorBlack.toVector3())
      ..set(UniformKeys.texture, _canvasTexture());
    final quad = MeshNode('quad', _quad(program, 0.72), material)..rotZ(0.18);
    phase.add(RenderBatch('texture', program, [_identity()])..add(quad));
  }

  void _depth() {
    final program = _solid();
    final scene = RenderBatch('depth', program, [_identity()]);
    // Submit the nearest surface first: a broken depth test lets blue cover it.
    scene.add(
      MeshNode(
        'near',
        _quad(program, 0.44),
        _color('near', colorRed.toVector3()),
      )..setPos(-0.18, 0.12, -0.4),
    );
    scene.add(
      MeshNode(
        'far',
        _quad(program, 0.65),
        _color('far', colorBlue.toVector3()),
      )..setPos(0.13, -0.08, 0.3),
    );
    scene.add(
      MeshNode(
        'middle',
        _quad(program, 0.32),
        _color('middle', colorGreen.toVector3()),
      )..setPos(0.35, 0.36, -0.1),
    );
    phase.add(scene);
  }

  void _blending() {
    final solid = _solid();
    phase.add(
      RenderBatch('background', solid, [_identity()])..add(
        MeshNode(
          'blue',
          _quad(solid, 0.8),
          _color('blue', colorBlue.toVector3()),
        )..setPos(0.0, 0.0, 0.5),
      ),
    );
    final fragment = ShaderObject.fragment('half-alpha')
      ..addUniformVars([uColor])
      ..setBodyWithMain(['$oFragColor = vec4($uColor, 0.5);']);
    final program = _program('alpha', solidColorVertexShader, fragment);
    final red = Material.transparent('red', blendEquationStandard)
      ..set(UniformKeys.color, colorRed.toVector3());
    final green = Material.transparent('green', blendEquationStandard)
      ..set(UniformKeys.color, colorGreen.toVector3());
    phase.add(
      RenderBatch('transparent', program, [_identity()])
        ..add(
          MeshNode('red', _quad(program, 0.48), red)..setPos(-0.22, 0.12, 0.0),
        )
        ..add(
          MeshNode('green', _quad(program, 0.48), green)
            ..setPos(0.22, -0.12, -0.2),
        ),
    );
  }

  void _lighting() {
    final program = _program(
      'light',
      lightVertexShaderBlinnPhong,
      lightFragmentShaderBlinnPhong,
    );
    final illumination = Illumination()
      ..addLight(
        DirectionalLight.named(
          name: 'key',
          direction: vm.Vector3(-1.0, -1.5, -2.0),
          diffuse: vm.Vector3(0.8, 0.55, 0.25),
          specular: vm.Vector3(0.4, 0.4, 0.4),
          shadowExtent: 10.0,
        ),
      )
      ..addLight(
        DirectionalLight.named(
          name: 'fill',
          direction: vm.Vector3(1.0, 0.0, -0.5),
          diffuse: vm.Vector3(0.1, 0.25, 0.5),
          specular: vm.Vector3.zero(),
          shadowExtent: 10.0,
        ),
      );
    final material = Material('lit')
      ..set(UniformKeys.texture, _canvasTexture(black: true))
      ..set(UniformKeys.shininess, 24.0);
    phase.add(
      RenderBatch('light', program, [_projection(false), illumination])
        ..add(
          MeshNode(
            'sphere',
            _mesh(shapeIcosahedron(program, subdivisions: 3, scale: 0.9)),
            material,
          )..setPos(-0.65, 0.0, 0.0),
        )
        ..add(
          MeshNode(
              'cube',
              _mesh(shapeCube(program, x: 0.5, y: 0.5, z: 0.5)),
              material,
            )
            ..rotY(0.4)
            ..setPos(0.85, 0.0, 0.0),
        ),
    );
  }
}
