@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart' as debug;
import 'package:chronosgl/shadows.dart' as shadows;
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

class _Handles<T> {
  final created = <T>[];
  final deleted = <T>[];

  T record(T handle) {
    created.add(handle);
    return handle;
  }

  void expectReleased(bool Function(T) isLive) {
    expect(deleted, unorderedEquals(created));
    for (final handle in created) {
      expect(isLive(handle), isFalse);
    }
  }
}

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false, faceCulling: false);

  final programs = _Handles<GlProgram>();
  final shaders = _Handles<GlShader>();
  final textures = _Handles<GlTexture>();
  final framebuffers = _Handles<GlFramebuffer>();
  final vaos = _Handles<GlVertexArrayObject>();
  final buffers = _Handles<GlBuffer>();
  final samplers = _Handles<GlSampler>();
  final failure = StateError('injected shadow/diagnostic failure');
  bool failProgram = false;
  bool failBuffer = false;
  bool failSamplerParameter = false;
  bool failDraw = false;
  bool failProgramDelete = false;
  bool failSamplerDelete = false;

  @override
  GlProgram createProgram() {
    if (failProgram) throw failure;
    return programs.record(super.createProgram());
  }

  @override
  GlShader createShader(int kind) => shaders.record(super.createShader(kind));

  @override
  GlTexture createTexture() => textures.record(super.createTexture());

  @override
  GlFramebuffer createFramebuffer() =>
      framebuffers.record(super.createFramebuffer());

  @override
  GlVertexArrayObject createVertexArray() =>
      vaos.record(super.createVertexArray());

  @override
  GlBuffer createBuffer() {
    if (failBuffer) throw failure;
    return buffers.record(super.createBuffer());
  }

  @override
  GlSampler createSampler() => samplers.record(super.createSampler());

  @override
  void samplerParameteri(GlSampler sampler, int parameter, int value) {
    if (failSamplerParameter) throw failure;
    super.samplerParameteri(sampler, parameter, value);
  }

  @override
  void draw(
    int mode,
    int count,
    int type,
    int offset,
    int instanceCount,
    bool hasTransforms,
  ) {
    if (failDraw) throw failure;
    super.draw(mode, count, type, offset, instanceCount, hasTransforms);
  }

  @override
  void deleteProgram(GlProgram handle) {
    programs.deleted.add(handle);
    super.deleteProgram(handle);
    if (failProgramDelete) throw failure;
  }

  @override
  void deleteShader(GlShader handle) {
    shaders.deleted.add(handle);
    super.deleteShader(handle);
  }

  @override
  void deleteTexture(GlTexture handle) {
    textures.deleted.add(handle);
    super.deleteTexture(handle);
  }

  @override
  void deleteFramebuffer(GlFramebuffer handle) {
    framebuffers.deleted.add(handle);
    super.deleteFramebuffer(handle);
  }

  @override
  void deleteVertexArray(GlVertexArrayObject handle) {
    vaos.deleted.add(handle);
    super.deleteVertexArray(handle);
  }

  @override
  void deleteBuffer(GlBuffer handle) {
    buffers.deleted.add(handle);
    super.deleteBuffer(handle);
  }

  @override
  void deleteSampler(GlSampler handle) {
    samplers.deleted.add(handle);
    super.deleteSampler(handle);
    if (failSamplerDelete) throw failure;
  }

  void expectReleased(web.WebGL2RenderingContext gl) {
    gl.useProgram(null);
    programs.expectReleased((handle) => gl.isProgram(handle));
    shaders.expectReleased((handle) => gl.isShader(handle));
    textures.expectReleased((handle) => gl.isTexture(handle));
    framebuffers.expectReleased((handle) => gl.isFramebuffer(handle));
    vaos.expectReleased((handle) => gl.isVertexArray(handle));
    buffers.expectReleased((handle) => gl.isBuffer(handle));
    samplers.expectReleased((handle) => gl.isSampler(handle));
    expect(gl.isContextLost(), isFalse);
    expect(getError(), glNoError);
  }
}

(_TrackingGL, web.WebGL2RenderingContext) _context() {
  final canvas = web.HTMLCanvasElement()
    ..width = 2
    ..height = 2;
  final cgl = _TrackingGL(canvas);
  final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
  addTearDown(() {
    (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
        ?.loseContext();
  });
  return (cgl, gl);
}

RenderProgram _lines(ChronosGL cgl) {
  final vertex = ShaderObject('diagnostic-lines-v')
    ..addAttributeVars([aPosition])
    ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
  final fragment = ShaderObject('diagnostic-lines-f')
    ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
  return RenderProgram('diagnostic-lines', cgl, vertex, fragment);
}

List<int> _pixel(ChronosGL cgl) {
  final pixels = Uint8List(4);
  cgl.readPixels(0, 0, 1, 1, glRgba, glUnsignedByte, pixels);
  return pixels;
}

void _expectHandle(Object? actual, JSObject expected) {
  expect((actual as JSObject).strictEquals(expected).toDart, isTrue);
}

void main() {
  test('ShadowMap creates only compute resources and disposes once', () {
    final (cgl, gl) = _context();
    final map = shadows.ShadowMap(cgl, 2, 2, 1, 9);
    expect(cgl.programs.created, hasLength(1));
    expect(cgl.textures.created, hasLength(2));
    expect(cgl.framebuffers.created, hasLength(1));
    expect(cgl.vaos.created, isEmpty);
    expect(cgl.buffers.created, isEmpty);
    expect(cgl.samplers.created, isEmpty);
    final texture = map.getMapTexture();
    map.getMapSize().setValues(100, 200);
    expect(map.getMapSize().storage, [2, 2]);
    map.compute(vm.Matrix4.identity());
    map.dispose();
    map.dispose();
    expect(map.isDisposed, isTrue);
    expect(texture.isDisposed, isTrue);
    expect(() => map.compute(vm.Matrix4.identity()), throwsStateError);
    expect(map.getMapTexture, throwsStateError);
    expect(map.clearShadowCasters, throwsStateError);
    expect(() => map.addShadowCaster(GroupNode('unused')), throwsStateError);
    cgl.expectReleased(gl);
  });

  test(
    'ShadowMap rejects invalid dimensions and clipping before allocation',
    () {
      final (cgl, gl) = _context();
      for (final create in <void Function()>[
        () => shadows.ShadowMap(cgl, 0, 2, 1, 9),
        () => shadows.ShadowMap(cgl, 2, -1, 1, 9),
        () => shadows.ShadowMap(cgl, 2, 2, 0, 9),
        () => shadows.ShadowMap(cgl, 2, 2, 1, double.infinity),
        () => shadows.ShadowMap(cgl, 2, 2, 9, 1),
      ]) {
        expect(create, throwsArgumentError);
      }
      expect(cgl.textures.created, isEmpty);
      cgl.expectReleased(gl);
    },
  );

  test('ShadowMap construction failure releases attachments and preserves bindings', () {
    final (cgl, gl) = _context();
    final target = Framebuffer.defaultFramebuffer(cgl, 2, 2);
    target.activate(0, 0, 0, 2, 2);
    final previous = cgl.getParameter(glFramebufferBinding) as JSObject;
    final texture = target.colorTexture!;
    cgl.bindTexture(glTexture2D, texture.getTexture());
    cgl.failProgram = true;
    expect(
      () => shadows.ShadowMap(cgl, 2, 2, 1, 9),
      throwsA(same(cgl.failure)),
    );
    _expectHandle(cgl.getParameter(glDrawFramebufferBinding), previous);
    _expectHandle(cgl.getParameter(glReadFramebufferBinding), previous);
    _expectHandle(cgl.getParameter(glTextureBinding2D), texture.getTexture());
    expect(target.isDisposed, isFalse);
    target.dispose();
    cgl.expectReleased(gl);
  });

  test('ShadowMap disposal attempts framebuffer cleanup after program deletion throws', () {
    final (cgl, gl) = _context();
    final map = shadows.ShadowMap(cgl, 2, 2, 1, 9);
    final texture = map.getMapTexture();
    cgl.failProgramDelete = true;
    expect(map.dispose, throwsA(same(cgl.failure)));
    map.dispose();
    expect(texture.isDisposed, isTrue);
    cgl.expectReleased(gl);
  });

  test('Unused and empty-viewport shadow visualizers create no resources', () {
    final (cgl, gl) = _context();
    final map = shadows.ShadowMap(cgl, 2, 2, 1, 9);
    final visualizer = debug.ShadowMapVisualizer(map);
    expect(visualizer.isInitialized, isFalse);
    visualizer.setViewport(0, 0, 0, 2);
    visualizer.draw();
    expect(visualizer.isInitialized, isFalse);
    expect(cgl.programs.created, hasLength(1));
    expect(cgl.vaos.created, isEmpty);
    expect(cgl.samplers.created, isEmpty);
    visualizer.dispose();
    visualizer.dispose();
    expect(visualizer.draw, throwsStateError);
    expect(map.isDisposed, isFalse);
    map.dispose();
    cgl.expectReleased(gl);
  });

  test('Shadow generation after visualization clears depth and keeps casters borrowed', () {
    final (cgl, gl) = _context();
    final program = RenderProgram(
      'caster',
      cgl,
      shadows.shadowVertexShaderDepth,
      shadows.shadowFragmentShaderDepth,
    );
    final md = program.makeMeshData('caster triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]))
      ..addFaces([0, 1, 2]);
    final material = Material('caster');
    final caster = MeshNode('caster', md, material);
    final map = shadows.ShadowMap(cgl, 2, 2, 1, 9)..addShadowCaster(caster);
    final visualizer = debug.ShadowMapVisualizer(map);
    map.compute(vm.Matrix4.identity());
    visualizer.draw();
    final shaded = _pixel(cgl);
    expect(shaded.take(3), everyElement(closeTo(85, 1)));
    expect(shaded[3], 255);
    map.clearShadowCasters();
    map.compute(vm.Matrix4.identity());
    visualizer.draw();
    expect(_pixel(cgl), [255, 255, 255, 255]);
    expect(cgl.samplers.created, hasLength(1));
    visualizer.dispose();
    map.dispose();
    expect(md.isDisposed, isFalse);
    expect(program.isDisposed, isFalse);
    expect(caster.material, same(material));
    md.dispose();
    program.dispose();
    cgl.expectReleased(gl);
  });

  for (final failDraw in [false, true]) {
    test(
      'Shadow visualization restores sampling state (draw failure=$failDraw)',
      () {
        final (cgl, gl) = _context();
        final map = shadows.ShadowMap(cgl, 2, 2, 1, 9);
        final visualizer = debug.ShadowMapVisualizer(map);
        map.compute(vm.Matrix4.identity());
        // Initialize before installing sentinel state to cover repeated draws.
        visualizer.draw();
        final sentinel = TypedTexture(
          cgl,
          'sentinel',
          1,
          1,
          glRgba8,
          texturePropertiesFramebuffer,
        );
        final sampler = cgl.createSampler();
        cgl.activeTexture(glTexture0);
        cgl.bindTexture(glTexture2D, sentinel.getTexture());
        cgl.bindSampler(0, sampler);
        cgl.activeTexture(glTexture0 + 3);
        cgl.bindTexture(glTexture2D, sentinel.getTexture());
        cgl.failDraw = failDraw;
        if (failDraw) {
          expect(visualizer.draw, throwsA(same(cgl.failure)));
        } else {
          visualizer.draw();
        }
        expect(cgl.getParameter(glActiveTexture), glTexture0 + 3);
        _expectHandle(
          cgl.getParameter(glTextureBinding2D),
          sentinel.getTexture(),
        );
        cgl.activeTexture(glTexture0);
        _expectHandle(
          cgl.getParameter(glTextureBinding2D),
          sentinel.getTexture(),
        );
        _expectHandle(cgl.getParameter(glSamplerBinding), sampler);
        cgl.bindTexture(glTexture2D, map.getMapTexture().getTexture());
        expect(
          gl.getTexParameter(glTexture2D, glTextureCompareMode).dartify(),
          glCompareRefToTexture,
        );
        expect(
          gl.getTexParameter(glTexture2D, glTextureMinFilter).dartify(),
          glLinear,
        );
        visualizer.dispose();
        expect(map.isDisposed, isFalse);
        cgl.bindSampler(0, null);
        cgl.deleteSampler(sampler);
        sentinel.dispose();
        map.dispose();
        cgl.expectReleased(gl);
      },
    );
  }

  test(
    'Lazy shadow visualizer creation failure releases resources and can retry',
    () {
      final (cgl, gl) = _context();
      final map = shadows.ShadowMap(cgl, 2, 2, 1, 9);
      final visualizer = debug.ShadowMapVisualizer(map);
      cgl.failSamplerParameter = true;
      expect(visualizer.draw, throwsA(same(cgl.failure)));
      expect(visualizer.isInitialized, isFalse);
      expect(cgl.samplers.deleted, unorderedEquals(cgl.samplers.created));
      expect(cgl.buffers.deleted, unorderedEquals(cgl.buffers.created));
      expect(cgl.vaos.deleted, unorderedEquals(cgl.vaos.created));
      expect(map.getMapTexture().isDisposed, isFalse);
      cgl.failSamplerParameter = false;
      map.compute(vm.Matrix4.identity());
      visualizer.draw();
      expect(_pixel(cgl), [255, 255, 255, 255]);
      cgl.failSamplerDelete = true;
      expect(visualizer.dispose, throwsA(same(cgl.failure)));
      visualizer.dispose();
      map.dispose();
      cgl.expectReleased(gl);
    },
  );

  test('Disposed shadow map prevents lazy debug allocation', () {
    final (cgl, gl) = _context();
    final map = shadows.ShadowMap(cgl, 2, 2, 1, 9);
    final visualizer = debug.ShadowMapVisualizer(map);
    map.dispose();
    expect(visualizer.draw, throwsStateError);
    expect(cgl.programs.created, hasLength(1));
    expect(cgl.samplers.created, isEmpty);
    visualizer.dispose();
    cgl.expectReleased(gl);
  });

  for (final fixture
      in <
        ({
          String name,
          int vertices,
          int indices,
          void Function(GpuMesh, double) update,
        })
      >[
        (
          name: 'directional',
          vertices: 74,
          indices: 74,
          update: (mesh, offset) => debug.updateDirectionalLightVisualizer(
            mesh,
            1,
            0.25,
            vm.Vector3(offset, -1, 0),
          ),
        ),
        (
          name: 'spot',
          vertices: 10,
          indices: 42,
          update: (mesh, offset) => debug.updateSpotLightVisualizer(
            mesh,
            vm.Vector3(offset, 0, 0),
            vm.Vector3(0, 0, -1),
            0.5,
            0.25,
          ),
        ),
        (
          name: 'point rays',
          vertices: 13,
          indices: 24,
          update: (mesh, offset) => debug.updatePointLightVisualizer(
            mesh,
            vm.Vector3(offset, 0, 0),
            0.5,
          ),
        ),
        (
          name: 'point rays and faces',
          vertices: 13,
          indices: 144,
          update: (mesh, offset) => debug.updatePointLightVisualizer2(
            mesh,
            vm.Vector3(offset, 0, 0),
            0.5,
          ),
        ),
      ]) {
    test(
      'Light wireframe ${fixture.name} initializes and reuses equal-size buffers',
      () {
        final (cgl, gl) = _context();
        final program = _lines(cgl);
        addTearDown(program.dispose);
        final mesh = debug.emptyLightVisualizer(program, fixture.name);
        addTearDown(mesh.dispose);
        final placeholder = mesh.getBuffer(aPosition);
        fixture.update(mesh, 0);
        expect(mesh.getAttribute(aPosition), hasLength(fixture.vertices * 3));
        expect(mesh.getNumItems(), fixture.indices);
        expect(gl.isBuffer(placeholder), isFalse);
        mesh.activate();
        final indices = Uint8List(fixture.indices).toJS;
        gl.getBufferSubData(glElementArrayBuffer, 0, indices);
        expect(
          indices.toDart,
          everyElement(inInclusiveRange(0, fixture.vertices - 1)),
        );

        final positionBuffer = mesh.getBuffer(aPosition);
        final indexBuffer =
            cgl.getParameter(glElementArrayBufferBinding) as JSObject;
        final created = cgl.buffers.created.length;
        final before = mesh.getAttribute(aPosition);
        fixture.update(mesh, 0.125);
        expect(mesh.getAttribute(aPosition), isNot(orderedEquals(before)));
        _expectHandle(mesh.getBuffer(aPosition), positionBuffer);
        mesh.activate();
        _expectHandle(
          cgl.getParameter(glElementArrayBufferBinding),
          indexBuffer,
        );
        expect(cgl.buffers.created, hasLength(created));
        expect(mesh.getNumItems(), fixture.indices);
        cgl.viewport(0, 0, 2, 2);
        final stats = <DrawStats>[];
        program.draw(mesh, [Material('wireframe')], stats);
        expect(stats.single.numItems, fixture.indices);
        expect(cgl.getError(), glNoError);
        mesh.dispose();
        program.dispose();
        cgl.expectReleased(gl);
      },
    );
  }

  test(
    'LightVisualizer changes topology while retaining its node and mesh',
    () {
      final (cgl, gl) = _context();
      final program = _lines(cgl);
      addTearDown(program.dispose);
      final material = Material('wireframe');
      final point = PointLight.named(
        name: 'point',
        position: vm.Vector3.zero(),
        diffuse: vm.Vector3.all(1),
        specular: vm.Vector3.zero(),
        range: 0.5,
      );
      final directional = DirectionalLight.named(
        name: 'directional',
        direction: vm.Vector3(0, -1, 0),
        diffuse: vm.Vector3.all(1),
        specular: vm.Vector3.zero(),
        shadowExtent: 1,
      );
      final spot = SpotLight.named(
        name: 'spot',
        position: vm.Vector3.zero(),
        direction: vm.Vector3(0, 0, -1),
        diffuse: vm.Vector3.all(1),
        specular: vm.Vector3.zero(),
        range: 0.5,
        angleRadians: 0.25,
        spotFocus: 1,
        near: 0.1,
        far: 10,
      );
      final visualizer = debug.LightVisualizer(program, material, point);
      addTearDown(visualizer.dispose);
      final node = visualizer.mesh;
      final mesh = node.mesh;
      expect(mesh.getAttribute(aPosition), hasLength(13 * 3));
      for (final (light, vertices, indices) in <(Light, int, int)>[
        (directional, 74, 74),
        (spot, 10, 42),
        (point, 13, 24),
      ]) {
        final previous = mesh.getBuffer(aPosition);
        visualizer.update(light);
        expect(visualizer.mesh, same(node));
        expect(node.mesh, same(mesh));
        expect(mesh.getAttribute(aPosition), hasLength(vertices * 3));
        expect(mesh.getNumItems(), indices);
        expect(gl.isBuffer(previous), isFalse);
        cgl.viewport(0, 0, 2, 2);
        final stats = <DrawStats>[];
        program.draw(mesh, [material], stats);
        expect(stats.single.numItems, indices);
        expect(cgl.getError(), glNoError);
      }
      final positionBuffer = mesh.getBuffer(aPosition);
      final created = cgl.buffers.created.length;
      final before = mesh.getAttribute(aPosition);
      point.pos = vm.Vector3(0.125, 0, 0);
      visualizer.update();
      _expectHandle(mesh.getBuffer(aPosition), positionBuffer);
      expect(mesh.getAttribute(aPosition), isNot(orderedEquals(before)));
      expect(cgl.buffers.created, hasLength(created));
      visualizer.dispose();
      expect(mesh.isDisposed, isTrue);
      expect(program.isDisposed, isFalse);
      program.dispose();
      cgl.expectReleased(gl);
    },
  );

  for (final bone in [false, true]) {
    test(
      'Diagnostic wireframe is lazy and retains its owned mesh (bone=$bone)',
      () {
        final (cgl, gl) = _context();
        final program = _lines(cgl);
        final material = Material('wireframe');
        final bones = [
          Bone('root', 0, -1, vm.Matrix4.identity(), vm.Matrix4.identity()),
          Bone(
            'child',
            1,
            0,
            vm.Matrix4.translationValues(0, 1, 0),
            vm.Matrix4.identity(),
          ),
        ];
        final skeleton = debug.BoneVisualizer(
          program,
          material,
          bones,
          SkeletalAnimation('idle', 1, 2),
        );
        final light = debug.LightVisualizer(
          program,
          material,
          PointLight(
            'point',
            vm.Vector3.zero(),
            vm.Vector3.all(1),
            vm.Vector3.zero(),
            1,
          ),
        );
        skeleton.update(0.5);
        light.update();
        expect(cgl.vaos.created, isEmpty);
        final node = bone ? skeleton.mesh : light.mesh;
        final owned = node.mesh;
        final replacement = program.makeMeshData(
          'borrowed replacement',
          glLines,
        );
        node.mesh = replacement;
        if (bone) {
          skeleton.update(0.75);
        } else {
          light.update();
        }
        skeleton.dispose();
        light.dispose();
        skeleton.dispose();
        light.dispose();
        expect(owned.isDisposed, isTrue);
        expect(replacement.isDisposed, isFalse);
        expect(program.isDisposed, isFalse);
        expect(node.material, same(material));
        expect(() => skeleton.mesh, throwsStateError);
        expect(() => light.mesh, throwsStateError);
        expect(() => skeleton.update(0), throwsStateError);
        expect(light.update, throwsStateError);
        replacement.dispose();
        program.dispose();
        cgl.expectReleased(gl);
      },
    );

    test(
      'Failed diagnostic wireframe upload releases its VAO (bone=$bone)',
      () {
        final (cgl, gl) = _context();
        final program = _lines(cgl);
        final material = Material('wireframe');
        final skeleton = debug.BoneVisualizer(program, material, [
          Bone('root', 0, -1, vm.Matrix4.identity(), vm.Matrix4.identity()),
          Bone('child', 1, 0, vm.Matrix4.identity(), vm.Matrix4.identity()),
        ], SkeletalAnimation('idle', 1, 2));
        final light = debug.LightVisualizer(
          program,
          material,
          PointLight(
            'point',
            vm.Vector3.zero(),
            vm.Vector3.all(1),
            vm.Vector3.zero(),
            1,
          ),
        );
        cgl.failBuffer = true;
        expect(
          () => bone ? skeleton.mesh : light.mesh,
          throwsA(same(cgl.failure)),
        );
        expect(cgl.vaos.deleted, unorderedEquals(cgl.vaos.created));
        expect(skeleton.isInitialized, isFalse);
        expect(light.isInitialized, isFalse);
        skeleton.dispose();
        light.dispose();
        program.dispose();
        cgl.expectReleased(gl);
      },
    );
  }

  test('FpsPanel uses the actual elapsed sampling interval', () {
    final root = web.HTMLDivElement();
    final panel = debug.FpsPanel(root, 'blue', 'gray');
    addTearDown(panel.dispose);
    panel.updateFrameCount(500);
    panel.updateFrameCount(2500);
    expect(root.firstElementChild!.firstChild!.textContent, '0.80 fps');
  });

  test(
    'FPS panels dispose only owned elements and reject subsequent updates',
    () {
      final root = web.HTMLDivElement()..style.color = 'green';
      final originalStyle = root.style.cssText;
      final sibling = web.HTMLSpanElement()..textContent = 'keep';
      root.appendChild(sibling);
      final stats = debug.StatsPanel(root, 'blue', 'gray');
      final fps = debug.FpsPanel(root, 'blue', 'gray');
      expect(root.children.length, 3);
      expect(root.style.cssText, originalStyle);
      fps.updateFrameCount(1000, '<b>frame</b>');
      stats.dispose();
      expect(root.children.length, 2);
      fps.dispose();
      fps.dispose();
      stats.dispose();
      expect(root.children.length, 1);
      _expectHandle(root.firstChild, sibling);
      expect(root.style.cssText, originalStyle);
      expect(() => fps.updateFrameCount(2000), throwsStateError);
      expect(() => stats.changeExtra('unused'), throwsStateError);
      expect(() => stats.addRawValue(1), throwsStateError);
    },
  );
}
