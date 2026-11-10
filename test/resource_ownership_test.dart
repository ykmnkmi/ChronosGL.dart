@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final framebuffers = <GlFramebuffer>[];
  final deletedFramebuffers = <GlFramebuffer>[];
  final deletedTextures = <GlTexture>[];
  final deletedBuffers = <GlBuffer>[];
  final deletionOrder = <String>[];
  final failure = StateError('injected ownership failure');
  String? failAt;
  bool failDeletion = false;

  void checkpoint(String operation) {
    if (failAt == operation) {
      failAt = null;
      throw failure;
    }
  }

  @override
  GlFramebuffer createFramebuffer() {
    checkpoint('create');
    final framebuffer = super.createFramebuffer();
    framebuffers.add(framebuffer);
    return framebuffer;
  }

  @override
  void bindFramebuffer(int kind, GlFramebuffer? framebuffer) {
    super.bindFramebuffer(kind, framebuffer);
    if (framebuffer == null) checkpoint('unbind');
  }

  @override
  void framebufferTexture2D(
    int target,
    int attachment,
    int textarget,
    GlTexture texture,
    int level,
  ) {
    super.framebufferTexture2D(target, attachment, textarget, texture, level);
    checkpoint('attach');
  }

  @override
  int checkFramebufferStatus(int target) {
    checkpoint('status');
    return super.checkFramebufferStatus(target);
  }

  @override
  void vertexAttribPointer(
    GlBuffer buffer,
    int index,
    int size,
    int type,
    bool normalized,
    int stride,
    int offset,
  ) {
    super.vertexAttribPointer(
      buffer,
      index,
      size,
      type,
      normalized,
      stride,
      offset,
    );
    checkpoint('pointer');
  }

  @override
  void deleteFramebuffer(GlFramebuffer framebuffer) {
    deletedFramebuffers.add(framebuffer);
    deletionOrder.add('framebuffer');
    super.deleteFramebuffer(framebuffer);
  }

  @override
  void deleteTexture(GlTexture texture) {
    deletedTextures.add(texture);
    deletionOrder.add('texture');
    super.deleteTexture(texture);
    if (failDeletion) throw failure;
  }

  @override
  void deleteBuffer(GlBuffer buffer) {
    deletedBuffers.add(buffer);
    super.deleteBuffer(buffer);
  }
}

// Named construction remains available to subclasses.
class _OwnedFramebuffer extends Framebuffer {
  _OwnedFramebuffer(super.cgl, Texture texture)
    : super.withAttachments(colorTexture: texture, takeOwnership: [texture]);
}

void main() {
  late _TrackingGL cgl;
  late web.WebGL2RenderingContext gl;
  late web.HTMLCanvasElement canvas;

  _TrackingGL context(web.HTMLCanvasElement element) {
    final result = _TrackingGL(element);
    addTearDown(() {
      (result.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    return result;
  }

  setUp(() {
    canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = context(canvas);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
  });

  MeshData mesh() =>
      MeshData('ownership', cgl, glTriangles, {aPosition: 0, aNormal: 1});

  GlBuffer buffer() {
    final result = cgl.createBuffer();
    cgl.changeArrayBuffer(result, Float32List(9));
    return result;
  }

  TypedTexture texture([int format = glRgba8, ChronosGL? source]) =>
      TypedTexture(
        source ?? cgl,
        'ownership',
        2,
        2,
        format,
        texturePropertiesFramebuffer,
      );

  test('Explicitly owned buffer survives borrowers and is deleted once', () {
    final shared = buffer();
    final owner = mesh()
      ..changeAttributeBuffer(aPosition, shared, takeOwnership: true);
    final borrower = mesh()..changeAttributeBuffer(aPosition, shared);
    borrower.dispose();
    expect(cgl.deletedBuffers, isEmpty);
    expect(gl.isBuffer(shared), isTrue);
    owner.activate();
    expect(gl.getVertexAttrib(0, glVertexAttribArrayBufferBinding), shared);
    owner.dispose();
    owner.dispose();
    expect(cgl.deletedBuffers, [shared]);
    expect(gl.isBuffer(shared), isFalse);
    expect(cgl.getError(), glNoError);
  });

  test(
    'Repeated transfer and borrowed aliases do not duplicate or drop ownership',
    () {
      final shared = buffer();
      final md = mesh()..changeAttributeBuffer(aPosition, shared);
      md.changeAttributeBuffer(aPosition, shared, takeOwnership: true);
      final alias = gl.getParameter(glArrayBufferBinding) as GlBuffer;
      md.changeAttributeBuffer(aNormal, alias, takeOwnership: true);
      md.changeAttributeBuffer(aPosition, alias);
      md.dispose();
      expect(cgl.deletedBuffers, [shared]);
      expect(gl.isBuffer(shared), isFalse);
      expect(cgl.getError(), glNoError);
    },
  );

  test(
    'clearData releases transferred buffers and preserves borrowed ones',
    () {
      final owned = buffer();
      final borrowed = buffer();
      final md = mesh()
        ..changeAttributeBuffer(aPosition, owned, takeOwnership: true)
        ..changeAttributeBuffer(aNormal, borrowed);
      md.clearData();
      expect(cgl.deletedBuffers, [owned]);
      expect(gl.isBuffer(borrowed), isTrue);
      final next = buffer();
      md.changeAttributeBuffer(aPosition, next, takeOwnership: true);
      md.dispose();
      expect(cgl.deletedBuffers, [owned, next]);
      cgl.deleteBuffer(borrowed);
      expect(cgl.getError(), glNoError);
    },
  );

  for (final failure in ['attribute', 'pointer', 'disposed']) {
    test(
      'Failed buffer acceptance ($failure) leaves ownership with caller',
      () {
        final external = buffer();
        final md = mesh()..addVertices(Float32List(9));
        final previous = md.getBuffer(aPosition);
        if (failure == 'disposed') md.dispose();
        if (failure == 'pointer') cgl.failAt = 'pointer';
        expect(
          () => md.changeAttributeBuffer(
            failure == 'attribute' ? aColor : aPosition,
            external,
            takeOwnership: true,
          ),
          failure == 'attribute'
              ? throwsArgumentError
              : failure == 'pointer'
              ? throwsA(same(cgl.failure))
              : throwsStateError,
        );
        if (!md.isDisposed) expect(md.getBuffer(aPosition), previous);
        md.dispose();
        expect(cgl.deletedBuffers, [previous]);
        expect(gl.isBuffer(external), isTrue);
        cgl.deleteBuffer(external);
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test('WebGL rejection of a foreign buffer does not transfer ownership', () {
    final other = context(web.HTMLCanvasElement());
    final external = other.createBuffer();
    other.changeArrayBuffer(external, Float32List(9));
    final md = mesh();
    expect(
      () => md.changeAttributeBuffer(aPosition, external, takeOwnership: true),
      throwsStateError,
    );
    md.dispose();
    expect(cgl.deletedBuffers, isEmpty);
    other.deleteBuffer(external);
    // A failed WebGL call can set more than one error flag.
    while (cgl.getError() != glNoError) {}
    expect(other.getError(), glNoError);
  });

  test('Named framebuffer constructor borrows all textures by default', () {
    final color = texture();
    final depth = texture(glDepthComponent24);
    final fb = Framebuffer.withAttachments(
      cgl,
      colorTexture: color,
      depthTexture: depth,
    );
    fb.dispose();
    expect(cgl.deletedTextures, isEmpty);
    expect(color.isDisposed, isFalse);
    expect(depth.isDisposed, isFalse);
    color.dispose();
    depth.dispose();
    expect(cgl.getError(), glNoError);
  });

  for (final transferDepth in [false, true]) {
    test(
      'Mixed framebuffer ownership (transferDepth=$transferDepth) preserves borrowers',
      () {
        final color = texture();
        final depth = texture(glDepthComponent24);
        final owned = transferDepth ? depth : color;
        final borrowed = transferDepth ? color : depth;
        final ownedHandle = owned.getTexture();
        final transfers = [owned, owned];
        final fb = Framebuffer.withAttachments(
          cgl,
          colorTexture: color,
          depthTexture: depth,
          takeOwnership: transfers,
        );
        transfers
          ..clear()
          ..add(borrowed);
        final consumer = Framebuffer(cgl, color, depth);
        consumer.dispose();
        expect(cgl.deletedTextures, isEmpty);
        fb.activate(glColorBufferBit, 0, 0, 2, 2);
        cgl.clearColor(0, 1, 0, 1);
        cgl.clear(glColorBufferBit);
        expect(fb.extractByteData(null, 0, 0, 1, 1), [0, 255, 0, 255]);
        fb.dispose();
        fb.dispose();
        expect(cgl.deletedTextures, [ownedHandle]);
        expect(gl.isTexture(ownedHandle), isFalse);
        expect(owned.isDisposed, isTrue);
        expect(borrowed.isDisposed, isFalse);
        expect(gl.isTexture(borrowed.getTexture()), isTrue);
        borrowed.dispose();
        expect(cgl.getError(), glNoError);
      },
    );
  }

  for (final combined in [false, true]) {
    test('Depth-stencil aliases are owned once (combined=$combined)', () {
      final color = texture();
      final depthStencil = texture(glDepth24Stencil8);
      final handle = depthStencil.getTexture();
      final fb = Framebuffer.withAttachments(
        cgl,
        colorTexture: color,
        depthTexture: depthStencil,
        stencilTexture: combined ? null : depthStencil,
        depthStencilCombined: combined,
        takeOwnership: [depthStencil, depthStencil],
      );
      fb.dispose();
      expect(cgl.deletedTextures, [handle]);
      expect(color.isDisposed, isFalse);
      color.dispose();
      expect(cgl.getError(), glNoError);
    });
  }

  test('A non-attachment cannot be transferred and nothing is allocated', () {
    final color = texture();
    final unrelated = texture();
    expect(
      () => Framebuffer.withAttachments(
        cgl,
        colorTexture: color,
        takeOwnership: [color, unrelated],
      ),
      throwsArgumentError,
    );
    expect(cgl.framebuffers, isEmpty);
    expect(cgl.deletedTextures, isEmpty);
    color.dispose();
    unrelated.dispose();
  });

  test('A throwing ownership iterable cannot partially transfer textures', () {
    final color = texture();
    Iterable<Texture> transfers() sync* {
      yield color;
      throw cgl.failure;
    }

    expect(
      () => Framebuffer.withAttachments(
        cgl,
        colorTexture: color,
        takeOwnership: transfers(),
      ),
      throwsA(same(cgl.failure)),
    );
    expect(cgl.framebuffers, isEmpty);
    expect(cgl.deletedTextures, isEmpty);
    final owner = _OwnedFramebuffer(cgl, color);
    owner.dispose();
    expect(color.isDisposed, isTrue);
  });

  for (final factoryOwned in [false, true]) {
    test(
      'A texture cannot have two framebuffer owners (factory=$factoryOwned)',
      () {
        final owner = factoryOwned
            ? Framebuffer.effect(cgl, 2, 2)
            : _OwnedFramebuffer(cgl, texture());
        final color = owner.colorTexture!;
        expect(() => _OwnedFramebuffer(cgl, color), throwsStateError);
        expect(cgl.framebuffers, hasLength(1));
        expect(cgl.deletedTextures, isEmpty);
        final borrower = Framebuffer.withAttachments(cgl, colorTexture: color);
        borrower.dispose();
        expect(color.isDisposed, isFalse);
        owner.dispose();
        expect(color.isDisposed, isTrue);
        expect(cgl.deletedTextures, hasLength(1));
        expect(cgl.getError(), glNoError);
      },
    );
  }

  for (final legacy in [false, true]) {
    for (final invalid in ['disposed', 'foreign', 'cube']) {
      test('Rejects $invalid texture before allocation (legacy=$legacy)', () {
        final Texture external;
        if (invalid == 'foreign') {
          external = texture(glRgba8, context(web.HTMLCanvasElement()));
        } else if (invalid == 'cube') {
          external = Texture(
            cgl,
            glTextureCubeMap,
            'cube',
            texturePropertiesFramebuffer,
          );
        } else {
          external = texture()..dispose();
        }
        final deletionsBefore = cgl.deletedTextures.length;
        expect(
          () => legacy
              ? Framebuffer(cgl, external)
              : _OwnedFramebuffer(cgl, external),
          invalid == 'disposed' ? throwsStateError : throwsArgumentError,
        );
        expect(cgl.framebuffers, isEmpty);
        expect(cgl.deletedTextures, hasLength(deletionsBefore));
        external.dispose();
        expect(cgl.getError(), glNoError);
      });
    }
  }

  test('Different ChronosGL wrappers of the same context are compatible', () {
    final other = _TrackingGL(canvas);
    final color = texture(glRgba8, other);
    final handle = color.getTexture();
    final fb = _OwnedFramebuffer(cgl, color);
    fb.dispose();
    expect(other.deletedTextures, [handle]);
    expect(cgl.deletedTextures, isEmpty);
    expect(cgl.getError(), glNoError);
  });

  for (final operation in [
    'create',
    'attach',
    'status',
    'unbind',
    'incomplete',
  ]) {
    test(
      'Framebuffer failure ($operation) never accepts external ownership',
      () {
        final color = texture();
        final depth = texture(glDepthComponent24);
        final previousDraw = Framebuffer.effect(cgl, 2, 2);
        final previousRead = Framebuffer.effect(cgl, 2, 2);
        final drawHandle = cgl.framebuffers[0];
        final readHandle = cgl.framebuffers[1];
        cgl.bindFramebuffer(glDrawFramebuffer, drawHandle);
        cgl.bindFramebuffer(glReadFramebuffer, readHandle);
        cgl.failAt = operation;
        expect(
          () => Framebuffer.withAttachments(
            cgl,
            colorTexture: operation == 'incomplete' ? depth : color,
            depthTexture: operation == 'incomplete' ? color : depth,
            takeOwnership: [color, depth],
          ),
          operation == 'incomplete'
              ? throwsStateError
              : throwsA(same(cgl.failure)),
        );
        expect(cgl.getParameter(glDrawFramebufferBinding), drawHandle);
        expect(cgl.getParameter(glReadFramebufferBinding), readHandle);
        expect(cgl.deletedTextures, isEmpty);
        expect(color.isDisposed, isFalse);
        expect(depth.isDisposed, isFalse);
        if (operation == 'create') {
          expect(cgl.deletedFramebuffers, isEmpty);
        } else {
          expect(cgl.deletedFramebuffers, [cgl.framebuffers.last]);
          expect(gl.isFramebuffer(cgl.framebuffers.last), isFalse);
        }
        // Failed acceptance must leave no owner registration behind.
        final retry = Framebuffer.withAttachments(
          cgl,
          colorTexture: color,
          depthTexture: depth,
          takeOwnership: [color, depth],
        );
        retry.dispose();
        previousDraw.dispose();
        previousRead.dispose();
        expect(color.isDisposed, isTrue);
        expect(depth.isDisposed, isTrue);
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test(
    'Deletion errors still release all transferred textures exactly once',
    () {
      final color = texture();
      final depth = texture(glDepthComponent24);
      final handles = [color.getTexture(), depth.getTexture()];
      final fb = Framebuffer.withAttachments(
        cgl,
        colorTexture: color,
        depthTexture: depth,
        takeOwnership: [color, depth],
      );
      cgl.failDeletion = true;
      expect(fb.dispose, throwsA(same(cgl.failure)));
      fb.dispose();
      expect(cgl.deletedTextures, unorderedEquals(handles));
      expect(cgl.deletionOrder, ['framebuffer', 'texture', 'texture']);
      expect(color.isDisposed, isTrue);
      expect(depth.isDisposed, isTrue);
      expect(cgl.getError(), glNoError);
    },
  );

  test('Attachment setters release removed transferred textures', () {
    final owned = texture();
    final external = texture();
    final handle = owned.getTexture();
    final fb = _OwnedFramebuffer(cgl, owned)..colorTexture = external;
    expect(owned.isDisposed, isTrue);
    fb.dispose();
    expect(cgl.deletedTextures, [handle]);
    expect(external.isDisposed, isFalse);
    external.dispose();
    expect(cgl.getError(), glNoError);
  });
}
