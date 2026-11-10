@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final buffers = <GlBuffer>[];
  final deletedBuffers = <GlBuffer>[];
  final framebuffers = <GlFramebuffer>[];
  final deletedFramebuffers = <GlFramebuffer>[];
  final deletedTextures = <GlTexture>[];
  final failure = StateError('injected replacement failure');
  String? failAt;
  bool failDeletion = false;
  bool pointerError = false;
  bool pendingError = false;

  void checkpoint(String operation) {
    if (failAt == operation) {
      failAt = null;
      throw failure;
    }
  }

  @override
  GlBuffer createBuffer() {
    checkpoint('createBuffer');
    final buffer = super.createBuffer();
    buffers.add(buffer);
    return buffer;
  }

  @override
  void changeArrayBuffer(GlBuffer buffer, List<num> data) {
    super.changeArrayBuffer(buffer, data);
    checkpoint('arrayUpload');
  }

  @override
  void changeElementArrayBuffer(GlBuffer buffer, TypedData data) {
    super.changeElementArrayBuffer(buffer, data);
    checkpoint('indexUpload');
  }

  @override
  void enableVertexAttribArray(int index, int divisor) {
    super.enableVertexAttribArray(index, divisor);
    checkpoint('enable');
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
    if (pointerError) {
      pointerError = false;
      pendingError = true;
    }
    checkpoint('pointer');
  }

  @override
  int getError() {
    if (pendingError) {
      pendingError = false;
      return glInvalidOperation;
    }
    return super.getError();
  }

  @override
  GlFramebuffer createFramebuffer() {
    checkpoint('createFramebuffer');
    final framebuffer = super.createFramebuffer();
    framebuffers.add(framebuffer);
    return framebuffer;
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
    checkpoint('attachment');
  }

  @override
  int checkFramebufferStatus(int target) {
    checkpoint('status');
    return super.checkFramebufferStatus(target);
  }

  @override
  void bindFramebuffer(int kind, GlFramebuffer? framebuffer) {
    super.bindFramebuffer(kind, framebuffer);
    if (framebuffer == null) checkpoint('unbind');
    if (kind == glReadFramebuffer) checkpoint('restoreRead');
  }

  @override
  void deleteBuffer(GlBuffer buffer) {
    deletedBuffers.add(buffer);
    super.deleteBuffer(buffer);
    if (failDeletion) throw failure;
  }

  @override
  void deleteFramebuffer(GlFramebuffer framebuffer) {
    deletedFramebuffers.add(framebuffer);
    super.deleteFramebuffer(framebuffer);
    if (failDeletion) throw failure;
  }

  @override
  void deleteTexture(GlTexture texture) {
    deletedTextures.add(texture);
    super.deleteTexture(texture);
    if (failDeletion) throw failure;
  }
}

Float32List _vertices() =>
    Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]);

void main() {
  late _TrackingGL cgl;
  late web.WebGL2RenderingContext gl;
  setUp(() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = _TrackingGL(canvas);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  MeshData mesh() => MeshData('replacement', cgl, glTriangles, {
    aPosition: 0,
    aNormal: 1,
    iaTranslation: 2,
  });
  GlBuffer buffer() {
    final result = cgl.createBuffer();
    cgl.changeArrayBuffer(result, _vertices());
    return result;
  }

  TypedTexture texture([int format = glRgba8]) => TypedTexture(
    cgl,
    'replacement',
    2,
    2,
    format,
    texturePropertiesFramebuffer,
  );

  void expectPointer(
    MeshData md,
    int index,
    GlBuffer? buffer, {
    int divisor = 0,
  }) {
    md.activate();
    expect(gl.getVertexAttrib(index, glVertexAttribArrayBufferBinding), buffer);
    expect(
      (gl.getVertexAttrib(
        index,
        glVertexAttribArrayEnabled,
      ) as JSBoolean).toDart,
      buffer != null,
    );
    expect(
      (gl.getVertexAttrib(
        index,
        glVertexAttribArrayDivisor,
      ) as JSNumber).toDartInt,
      divisor,
    );
    expect(cgl.getError(), glNoError);
  }

  test(
    'Last alias replacement deletes an owned buffer once; same handle is safe',
    () {
      final md = mesh()..addVertices(_vertices());
      final old = md.getBuffer(aPosition);
      md.changeAttributeBuffer(aNormal, old);
      md.changeAttributeBuffer(aPosition, old);
      md.addVertices(_vertices());
      expect(cgl.deletedBuffers, isEmpty);
      expect(gl.isBuffer(old), isTrue);
      md.addAttribute(aNormal, Float32List(9), 3);
      expect(cgl.deletedBuffers, [old]);
      expect(gl.isBuffer(old), isFalse);
      md.dispose();
      md.dispose();
      expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
    },
  );

  test(
    'Replacing a borrowed buffer preserves its owner and another consumer',
    () {
      final shared = buffer();
      final owner = mesh()
        ..changeAttributeBuffer(aPosition, shared, takeOwnership: true);
      final borrower = mesh()..changeAttributeBuffer(aPosition, shared);
      final other = mesh()..changeAttributeBuffer(aPosition, shared);
      borrower.addVertices(_vertices());
      borrower.dispose();
      expect(gl.isBuffer(shared), isTrue);
      expectPointer(other, 0, shared);
      other.dispose();
      owner.dispose();
      expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
    },
  );

  for (final populated in [false, true]) {
    for (final operation in ['enable', 'pointer', 'glError']) {
      test(
        'External buffer failure $operation rolls back populated=$populated',
        () {
          final md = mesh();
          if (populated) md.addAttribute(iaTranslation, Float32List(6), 3);
          final previous = populated ? md.getBuffer(iaTranslation) : null;
          final external = buffer();
          final other = mesh()..activate();
          final previousVao = cgl.getParameter(glVertexArrayBinding);
          cgl.bindBuffer(glArrayBuffer, external);
          cgl.failAt = operation;
          cgl.pointerError = operation == 'glError';
          expect(
            () => md.changeAttributeBuffer(
              iaTranslation,
              external,
              takeOwnership: true,
            ),
            throwsStateError,
          );
          expect(cgl.getParameter(glVertexArrayBinding), previousVao);
          expect(cgl.getParameter(glArrayBufferBinding), external);
          expectPointer(md, 2, previous, divisor: populated ? 1 : 0);
          expect(md.getNumInstances(), populated ? 2 : 0);
          md.dispose();
          expect(gl.isBuffer(external), isTrue);
          other.dispose();
          cgl.deleteBuffer(external);
          expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
        },
      );
    }
  }

  for (final operation in ['createBuffer', 'arrayUpload', 'pointer']) {
    test(
      'Failed vertex replacement $operation retains CPU data and drawable geometry',
      () {
        final vertex = ShaderObject('replacement-v')
          ..addAttributeVars([aPosition])
          ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
        final fragment = ShaderObject('replacement-f')
          ..setBodyWithMain(['$oFragColor = vec4(0.0, 1.0, 0.0, 1.0);']);
        final program = RenderProgram('replacement', cgl, vertex, fragment);
        final data = _vertices();
        final md = program.makeMeshData('triangle', glTriangles)
          ..addVertices(data);
        final previous = md.getBuffer(aPosition);
        cgl.failAt = operation;
        expect(
          () => md.addVertices(Float32List(18)),
          throwsA(same(cgl.failure)),
        );
        expect(md.getBuffer(aPosition), previous);
        expect(md.getAttribute(aPosition), same(data));
        expect(md.getNumItems(), 3);
        expectPointer(md, 0, previous);
        cgl.viewport(0, 0, 2, 2);
        cgl.disable(glDepthTest);
        program.draw(md, []);
        final pixels = Uint8List(16);
        cgl.readPixels(0, 0, 2, 2, glRgba, glUnsignedByte, pixels);
        expect(pixels, [
          for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
        ]);
        md.dispose();
        program.dispose();
        expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
      },
    );
  }

  test(
    'Failed first instanced upload does not commit instance count or CPU data',
    () {
      final md = mesh();
      cgl.failAt = 'arrayUpload';
      expect(
        () => md.addAttribute(iaTranslation, Float32List(6), 3),
        throwsStateError,
      );
      expect(md.getNumInstances(), 0);
      expect(md.getAttributes(), isEmpty);
      expectPointer(md, 2, null);
      md.addAttribute(iaTranslation, Float32List(9), 3);
      expect(md.getNumInstances(), 3);
      md.dispose();
      expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
    },
  );

  for (final populated in [false, true]) {
    test(
      'Failed index replacement restores index binding/count/type populated=$populated',
      () {
        final md = mesh()..addVertices(_vertices());
        if (populated) md.addFaces([0, 1, 2]);
        md.activate();
        final previous = cgl.getParameter(glElementArrayBufferBinding);
        final previousType = md.elementArrayBufferType;
        final other = mesh()
          ..addVertices(_vertices())
          ..addFaces([2, 1, 0]);
        final previousVao = cgl.getParameter(glVertexArrayBinding);
        final otherIndex = cgl.getParameter(glElementArrayBufferBinding);
        cgl.failAt = 'indexUpload';
        expect(() => md.addFaces([1, 2]), throwsStateError);
        expect(cgl.getParameter(glVertexArrayBinding), previousVao);
        expect(cgl.getParameter(glElementArrayBufferBinding), otherIndex);
        expect(md.getNumItems(), 3);
        expect(md.elementArrayBufferType, previousType);
        md.activate();
        expect(cgl.getParameter(glElementArrayBufferBinding), previous);
        md.addFaces([2, 0]);
        expect(md.getNumItems(), 2);
        if (previous != null) expect(cgl.deletedBuffers, contains(previous));
        md.dispose();
        other.dispose();
        expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test('Buffer deletion failure leaves replacement committed and never deletes twice', () {
    final md = mesh()..addVertices(_vertices());
    final old = md.getBuffer(aPosition);
    final data = Float32List(18);
    cgl.failDeletion = true;
    expect(() => md.addVertices(data), throwsA(same(cgl.failure)));
    cgl.failDeletion = false;
    expect(md.getBuffer(aPosition), isNot(old));
    expect(md.getAttribute(aPosition), same(data));
    expect(md.getNumItems(), 6);
    expectPointer(md, 0, md.getBuffer(aPosition));
    md.dispose();
    expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
  });

  test('Framebuffer setter updates GPU attachment and releases owned texture immediately', () {
    final fb = Framebuffer.effect(cgl, 2, 2);
    final old = fb.colorTexture!;
    final next = texture();
    final originalHandle = cgl.framebuffers.single;
    fb.activate(0, 0, 0, 2, 2);
    fb.colorTexture = next;
    expect(old.isDisposed, isTrue);
    expect(cgl.deletedFramebuffers, [originalHandle]);
    expect(cgl.getParameter(glDrawFramebufferBinding), cgl.framebuffers.last);
    expect(cgl.getParameter(glReadFramebufferBinding), cgl.framebuffers.last);
    expect(
      gl.getFramebufferAttachmentParameter(
        glFramebuffer,
        glColorAttachment0,
        glFramebufferAttachmentObjectName,
      ),
      next.getTexture(),
    );
    cgl.clearColor(1, 0, 0, 1);
    cgl.clear(glColorBufferBit);
    final reader = Framebuffer(cgl, next);
    expect(reader.extractByteData(null, 0, 0, 1, 1), [255, 0, 0, 255]);
    reader.dispose();
    fb.dispose();
    expect(next.isDisposed, isFalse);
    next.dispose();
    expect(cgl.getError(), glNoError);
  });

  test(
    'Whole replacement keeps retained ownership and borrows new attachments',
    () {
      final fb = Framebuffer.defaultFramebuffer(cgl, 2, 2);
      final color = fb.colorTexture!;
      final depth = fb.depthTexture!;
      fb.replaceAttachments(
        colorTexture: color,
        depthTexture: depth,
        takeOwnership: [color, color],
      );
      expect(cgl.deletedTextures, isEmpty);
      final external = texture();
      fb.replaceAttachments(colorTexture: external, depthTexture: depth);
      expect(color.isDisposed, isTrue);
      expect(depth.isDisposed, isFalse);
      fb.dispose();
      expect(depth.isDisposed, isTrue);
      expect(external.isDisposed, isFalse);
      external.dispose();
      expect(cgl.deletedTextures, hasLength(3));
    },
  );

  test('Borrowed attachments survive replacement and ownership can be accepted explicitly', () {
    final old = texture();
    final owner = Framebuffer.withAttachments(
      cgl,
      colorTexture: old,
      takeOwnership: [old],
    );
    final fb = Framebuffer(cgl, old);
    final next = texture();
    fb.replaceAttachments(colorTexture: next, takeOwnership: [next]);
    expect(old.isDisposed, isFalse);
    expect(
      () => Framebuffer.withAttachments(
        cgl,
        colorTexture: next,
        takeOwnership: [next],
      ),
      throwsStateError,
    );
    fb.dispose();
    expect(next.isDisposed, isTrue);
    owner.activate(0, 0, 0, 2, 2);
    expect(cgl.checkFramebufferStatus(glFramebuffer), glFramebufferComplete);
    owner.dispose();
  });

  for (final operation in [
    'createFramebuffer',
    'attachment',
    'status',
    'unbind',
    'restoreRead',
  ]) {
    test(
      'Failed framebuffer replacement $operation preserves attachments, bindings and ownership',
      () {
        final fb = Framebuffer.effect(cgl, 2, 2);
        final old = fb.colorTexture!;
        final previous = cgl.framebuffers.single;
        final read = Framebuffer.effect(cgl, 2, 2);
        final readHandle = cgl.framebuffers.last;
        final next = texture();
        cgl.bindFramebuffer(glDrawFramebuffer, previous);
        cgl.bindFramebuffer(glReadFramebuffer, readHandle);
        cgl.failAt = operation;
        expect(
          () =>
              fb.replaceAttachments(colorTexture: next, takeOwnership: [next]),
          throwsA(same(cgl.failure)),
        );
        expect(fb.colorTexture, same(old));
        expect(old.isDisposed, isFalse);
        expect(next.isDisposed, isFalse);
        expect(cgl.getParameter(glDrawFramebufferBinding), previous);
        expect(cgl.getParameter(glReadFramebufferBinding), readHandle);
        expect(
          gl.getFramebufferAttachmentParameter(
            glDrawFramebuffer,
            glColorAttachment0,
            glFramebufferAttachmentObjectName,
          ),
          old.getTexture(),
        );
        // A failed acceptance must leave the texture available to a new owner.
        final nextOwner = Framebuffer.withAttachments(
          cgl,
          colorTexture: next,
          takeOwnership: [next],
        );
        fb.dispose();
        expect(next.isDisposed, isFalse);
        nextOwner.dispose();
        read.dispose();
        expect(cgl.deletedFramebuffers, unorderedEquals(cgl.framebuffers));
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test(
    'Invalid framebuffer configuration cannot replace the working target',
    () {
      final fb = Framebuffer.effect(cgl, 2, 2);
      final old = fb.colorTexture;
      final depth = texture(glDepthComponent24);
      expect(() => fb.colorTexture = depth, throwsStateError);
      expect(() => fb.replaceAttachments(), throwsStateError);
      expect(fb.colorTexture, old);
      expect(old!.isDisposed, isFalse);
      expect(depth.isDisposed, isFalse);
      fb.activate(0, 0, 0, 2, 2);
      expect(cgl.checkFramebufferStatus(glFramebuffer), glFramebufferComplete);
      fb.dispose();
      depth.dispose();
      expect(cgl.getError(), glNoError);
    },
  );

  test('Combined depth/stencil mode survives setters and can be replaced atomically', () {
    final color = texture();
    final combined = texture(glDepth24Stencil8);
    final fb = Framebuffer.withAttachments(
      cgl,
      colorTexture: color,
      depthTexture: combined,
      depthStencilCombined: true,
      takeOwnership: [combined],
    );
    fb.colorTexture = color;
    fb.activate(0, 0, 0, 2, 2);
    for (final attachment in [glDepthAttachment, glStencilAttachment]) {
      expect(
        gl.getFramebufferAttachmentParameter(
          glFramebuffer,
          attachment,
          glFramebufferAttachmentObjectName,
        ),
        combined.getTexture(),
      );
    }
    final depth = texture(glDepthComponent24);
    fb.replaceAttachments(
      colorTexture: color,
      depthTexture: depth,
      takeOwnership: [depth],
    );
    expect(combined.isDisposed, isTrue);
    fb.dispose();
    expect(depth.isDisposed, isTrue);
    expect(color.isDisposed, isFalse);
    color.dispose();
    expect(cgl.getError(), glNoError);
  });

  test('Framebuffer cleanup failures leave new ownership committed and attempt all old resources', () {
    final fb = Framebuffer.defaultFramebuffer(cgl, 2, 2);
    final oldColor = fb.colorTexture!;
    final oldDepth = fb.depthTexture!;
    final next = texture();
    cgl.failDeletion = true;
    expect(
      () => fb.replaceAttachments(colorTexture: next, takeOwnership: [next]),
      throwsA(same(cgl.failure)),
    );
    cgl.failDeletion = false;
    expect(fb.colorTexture, same(next));
    expect(oldColor.isDisposed, isTrue);
    expect(oldDepth.isDisposed, isTrue);
    expect(cgl.deletedTextures, hasLength(2));
    fb.dispose();
    fb.dispose();
    expect(next.isDisposed, isTrue);
    expect(cgl.deletedTextures, hasLength(3));
    expect(cgl.deletedFramebuffers, unorderedEquals(cgl.framebuffers));
  });

  test(
    'Depth-stencil aliases survive removal of one slot and are released once',
    () {
      final color = texture();
      final combined = texture(glDepth24Stencil8);
      final handle = combined.getTexture();
      final fb = Framebuffer.withAttachments(
        cgl,
        colorTexture: color,
        depthTexture: combined,
        stencilTexture: combined,
        takeOwnership: [combined],
      );
      fb.stencilTexture = null;
      expect(combined.isDisposed, isFalse);
      expect(cgl.deletedTextures, isEmpty);
      fb.depthTexture = null;
      expect(combined.isDisposed, isTrue);
      expect(cgl.deletedTextures, [handle]);
      fb.dispose();
      expect(cgl.deletedTextures, [handle]);
      color.dispose();
      expect(cgl.getError(), glNoError);
    },
  );

  test('Successful replacement preserves unrelated READ binding and tracks active DRAW', () {
    final fb = Framebuffer.effect(cgl, 2, 2);
    final previous = cgl.framebuffers.single;
    final reader = Framebuffer.effect(cgl, 2, 2);
    final readHandle = cgl.framebuffers.last;
    final next = texture();
    cgl.bindFramebuffer(glDrawFramebuffer, previous);
    cgl.bindFramebuffer(glReadFramebuffer, readHandle);
    fb.replaceAttachments(colorTexture: next, takeOwnership: [next]);
    expect(cgl.getParameter(glReadFramebufferBinding), readHandle);
    expect(cgl.getParameter(glDrawFramebufferBinding), cgl.framebuffers.last);
    fb.dispose();
    reader.dispose();
    expect(cgl.getError(), glNoError);
  });

  test('Replacement rejects invalid ownership before allocating or changing attachments', () {
    final fb = Framebuffer.effect(cgl, 2, 2);
    final old = fb.colorTexture;
    final owner = Framebuffer.effect(cgl, 2, 2);
    final foreignOwned = owner.colorTexture!;
    final next = texture();
    final count = cgl.framebuffers.length;
    expect(
      () => fb.replaceAttachments(
        colorTexture: next,
        takeOwnership: [foreignOwned],
      ),
      throwsArgumentError,
    );
    expect(
      () => fb.replaceAttachments(
        colorTexture: foreignOwned,
        takeOwnership: [foreignOwned],
      ),
      throwsStateError,
    );
    expect(cgl.framebuffers, hasLength(count));
    expect(fb.colorTexture, old);
    expect(next.isDisposed, isFalse);
    expect(foreignOwned.isDisposed, isFalse);
    fb.dispose();
    owner.dispose();
    next.dispose();
  });

  test(
    'Invalid attribute data is rejected before allocating or replacing storage',
    () {
      final md = mesh()..addVertices(_vertices());
      final old = md.getBuffer(aPosition);
      for (final action in <void Function()>[
        () => md.addVertices(Float32List(8)),
        () => md.addAttribute(aNormal, Float32List(9), 0),
        () => md.addAttribute(aNormal, Float32List(9), 2),
        () => md.addAttribute(aNormal, Float32List(6), 3),
        () => md.addAttribute(aColor, Float32List(9), 3),
      ]) {
        expect(action, throwsArgumentError);
      }
      expect(cgl.buffers, [old]);
      expect(md.getNumItems(), 3);
      expectPointer(md, 0, old);
      md.dispose();
    },
  );

  test('Disposed and screen framebuffers reject attachment replacement', () {
    final next = texture();
    final disposed = Framebuffer.effect(cgl, 2, 2)..dispose();
    final screen = Framebuffer.screen(cgl);
    final count = cgl.framebuffers.length;
    for (final fb in [disposed, screen]) {
      expect(() => fb.colorTexture = next, throwsStateError);
      expect(
        () => fb.replaceAttachments(colorTexture: next, takeOwnership: [next]),
        throwsStateError,
      );
    }
    expect(cgl.framebuffers, hasLength(count));
    expect(next.isDisposed, isFalse);
    next.dispose();
    screen.dispose();
  });
}
