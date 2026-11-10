part of 'lib.dart';

const int glClearAll = glColorBufferBit | glDepthBufferBit | glStencilBufferBit;

int textureChannelsByType(int format) {
  switch (format) {
    case glLuminance:
      return 1;
    case glLuminanceAlpha:
      return 2;
    case glRgb:
      return 3;
    case glRgba:
      return 4;
    default:
      assert(false, "unexpected format: $format");
      return -1;
  }
}

String _formatName(int format) {
  switch (format) {
    case glLuminance:
      return "GL_LUMINANCE";
    case glLuminanceAlpha:
      return "GL_LUMINANCE_ALPHA";
    case glRgb:
      return "GL_RGB";
    case glRgba:
      return "GL_RGBA";
    default:
      return "$format";
  }
}

String _typeName(int code) {
  switch (code) {
    case glUnsignedByte:
      return "GL_UNSIGNED_BYTE";
    case glFloat:
      return "GL_FLOAT";
    default:
      return "$code";
  }
}

class FramebufferFormat {
  FramebufferFormat(this.format, this.channels, this.type);

  FramebufferFormat.fromActive(ChronosGL cgl)
    : format = cgl.getParameter(glImplementationColorReadFormat) as int,
      type = cgl.getParameter(glImplementationColorReadType) as int {
    channels = textureChannelsByType(format);
  }

  final int format;
  late int channels;
  final int type;

  @override
  String toString() {
    return "FB-FMT: ${_formatName(format)} [$channels] ${_typeName(type)}";
  }
}

/// Owns its framebuffer handle. The unnamed constructor borrows attachments;
/// [Framebuffer.defaultFramebuffer] and [Framebuffer.effect] own theirs.
/// Use [Framebuffer.withAttachments] to explicitly transfer external textures.
/// Activation and readback throw [StateError] before any WebGL call if this
/// framebuffer or one of its attachments is disposed. A live framebuffer may
/// recover from a disposed attachment using [replaceAttachments].
class Framebuffer {
  Framebuffer(
    this._cgl,
    Texture? colorTexture, [
    Texture? depthTexture,
    Texture? stencilTexture,
    bool depthStencilCombined = false,
  ]) : _colorTexture = colorTexture,
       _depthTexture = depthTexture,
       _stencilTexture = stencilTexture {
    _initialize(depthStencilCombined);
  }

  /// Borrows attachments except those explicitly listed in [takeOwnership].
  ///
  /// Ownership transfers only when construction succeeds. On failure all
  /// external textures remain with their previous owner. The iterable is
  /// copied, duplicates count once, and every entry must be an attachment.
  /// A texture already owned by another framebuffer can only be borrowed.
  Framebuffer.withAttachments(
    this._cgl, {
    Texture? colorTexture,
    Texture? depthTexture,
    Texture? stencilTexture,
    bool depthStencilCombined = false,
    Iterable<Texture> takeOwnership = const [],
  }) : _colorTexture = colorTexture,
       _depthTexture = depthTexture,
       _stencilTexture = stencilTexture {
    final transfers = Set<Texture>.identity()..addAll(takeOwnership);
    for (final texture in transfers) {
      if (!identical(texture, colorTexture) &&
          !identical(texture, depthTexture) &&
          !identical(texture, stencilTexture)) {
        throw ArgumentError.value(
          texture,
          'takeOwnership',
          'Only attached textures can be transferred',
        );
      }
      if (texture._framebufferOwner != null) {
        throw StateError('Texture $texture already belongs to a framebuffer');
      }
    }
    _initialize(depthStencilCombined);
    for (final texture in transfers) {
      _ownTexture(texture);
    }
  }

  Framebuffer.screen(this._cgl) : _isScreen = true;

  Framebuffer.defaultFramebuffer(ChronosGL cgl, int w, int h)
    : this._withOwnedTextures(cgl, w, h, true);

  Framebuffer.effect(ChronosGL cgl, int w, int h)
    : this._withOwnedTextures(cgl, w, h, false);

  // Keep generative named constructors available to subclasses.
  Framebuffer._withOwnedTextures(this._cgl, int w, int h, bool withDepth) {
    GlTexture? previousTexture;
    bool bindingSaved = false;
    try {
      previousTexture = _cgl.getParameter(glTextureBinding2D) as GlTexture?;
      bindingSaved = true;
      final color = TypedTexture(
        _cgl,
        "frame::color",
        w,
        h,
        glRgba8,
        texturePropertiesFramebuffer,
      );
      _ownTexture(color);
      _colorTexture = color;
      if (withDepth) {
        final depth = TypedTexture(
          _cgl,
          "frame::depth",
          w,
          h,
          glDepthComponent24,
          texturePropertiesFramebuffer,
        );
        _ownTexture(depth);
        _depthTexture = depth;
      }
      _initialize(false);
    } catch (_) {
      _cleanupAfterFailure([
        dispose,
        if (bindingSaved) () => _cgl.bindTexture(glTexture2D, previousTexture),
      ]);
      rethrow;
    }
  }

  void _ownTexture(Texture texture) {
    _ownedTextures.add(texture);
    texture._framebufferOwner = this;
  }

  void _validateAttachments() {
    for (final texture in [colorTexture, depthTexture, stencilTexture]) {
      if (texture == null) continue;
      texture._checkNotDisposed();
      // Compare native contexts: separate ChronosGL wrappers may share a canvas.
      if (texture._cgl._gl != _cgl._gl) {
        throw ArgumentError('Attachment $texture belongs to another context');
      }
      if (texture.getTextureType() != glTexture2D) {
        throw ArgumentError('Attachment $texture must be a 2D texture');
      }
    }
  }

  // Success retains the existing convention of binding the screen. Failure
  // restores both WebGL2 bindings, which may refer to different framebuffers.
  void _initialize(bool depthStencilCombined) {
    _depthStencilCombined = depthStencilCombined;
    GlFramebuffer? previousDraw;
    GlFramebuffer? previousRead;
    bool bindingsSaved = false;
    try {
      if (depthStencilCombined && stencilTexture != null) {
        throw ArgumentError(
          'In combined mode the stencil texture must be null',
        );
      }
      _validateAttachments();
      previousDraw =
          _cgl.getParameter(glDrawFramebufferBinding) as GlFramebuffer?;
      previousRead =
          _cgl.getParameter(glReadFramebufferBinding) as GlFramebuffer?;
      bindingsSaved = true;
      _framebuffer = _cgl.createFramebuffer();

      _cgl.bindFramebuffer(glFramebuffer, _framebuffer);
      if (colorTexture != null) {
        _cgl.framebufferTexture2D(
          glFramebuffer,
          glColorAttachment0,
          glTexture2D,
          colorTexture!.getTexture(),
          0,
        );
      }
      if (depthTexture != null) {
        _cgl.framebufferTexture2D(
          glFramebuffer,
          depthStencilCombined ? glDepthStencilAttachment : glDepthAttachment,
          glTexture2D,
          depthTexture!.getTexture(),
          0,
        );
      }
      if (stencilTexture != null) {
        _cgl.framebufferTexture2D(
          glFramebuffer,
          glStencilAttachment,
          glTexture2D,
          stencilTexture!.getTexture(),
          0,
        );
      }

      int err = _cgl.checkFramebufferStatus(glFramebuffer);
      if (err != glFramebufferComplete) {
        throw StateError('Incomplete framebuffer: $err');
      }
      final error = _cgl.getError();
      if (error != glNoError) {
        throw StateError('Framebuffer attachment error: $error');
      }
      _cgl.bindFramebuffer(glFramebuffer, null);
    } catch (_) {
      _cleanupAfterFailure([
        dispose,
        if (bindingsSaved) ...[
          () => _cgl.bindFramebuffer(glDrawFramebuffer, previousDraw),
          () => _cgl.bindFramebuffer(glReadFramebuffer, previousRead),
        ],
      ]);
      rethrow;
    }
  }

  final ChronosGL _cgl;

  GlFramebuffer? _framebuffer;
  // A texture can appear in multiple slots but has only one owner.
  final Set<Texture> _ownedTextures = Set.identity();
  bool _isDisposed = false;
  bool _isScreen = false;
  bool _depthStencilCombined = false;
  Texture? _colorTexture;
  Texture? _depthTexture;
  Texture? _stencilTexture;

  /// Borrowed references for inspection; all three getters return null after
  /// disposal. A retained texture reference has its own [Texture.isDisposed].
  Texture? get colorTexture => _colorTexture;
  Texture? get depthTexture => _depthTexture;
  Texture? get stencilTexture => _stencilTexture;

  /// Replaces one attachment, borrowing the new texture by default.
  /// Use [replaceAttachments] to transfer ownership or change several slots.
  set colorTexture(Texture? texture) => replaceAttachments(
    colorTexture: texture,
    depthTexture: _depthTexture,
    stencilTexture: _stencilTexture,
    depthStencilCombined: _depthStencilCombined,
  );

  /// Replaces the depth (or combined depth/stencil) attachment.
  set depthTexture(Texture? texture) => replaceAttachments(
    colorTexture: _colorTexture,
    depthTexture: texture,
    stencilTexture: _stencilTexture,
    depthStencilCombined: _depthStencilCombined,
  );

  /// Replaces the separate stencil attachment.
  set stencilTexture(Texture? texture) => replaceAttachments(
    colorTexture: _colorTexture,
    depthTexture: _depthTexture,
    stencilTexture: texture,
    depthStencilCombined: _depthStencilCombined,
  );

  /// Replaces the entire attachment configuration; omitted slots are detached.
  ///
  /// Validates a temporary framebuffer before committing. Failed preparation
  /// preserves the old configuration, ownership and READ/DRAW bindings. On
  /// success, bindings to this framebuffer follow its replacement handle.
  /// Previously owned textures retained in any slot remain owned; new textures
  /// are borrowed unless listed in [takeOwnership]. Removed owned textures are
  /// disposed after commit. A cleanup exception does not roll back the commit.
  /// Screen framebuffers cannot accept attachments.
  void replaceAttachments({
    Texture? colorTexture,
    Texture? depthTexture,
    Texture? stencilTexture,
    bool depthStencilCombined = false,
    Iterable<Texture> takeOwnership = const [],
  }) {
    _checkNotDisposed();
    if (_isScreen) throw StateError('Cannot replace screen attachments');
    final attachments = Set<Texture>.identity()
      ..addAll(
        [colorTexture, depthTexture, stencilTexture].whereType<Texture>(),
      );
    for (final texture in attachments) {
      texture._checkNotDisposed();
    }
    final transfers = Set<Texture>.identity()..addAll(takeOwnership);
    for (final texture in transfers) {
      if (!attachments.contains(texture)) {
        throw ArgumentError('Only attached textures can be transferred');
      }
      if (texture._framebufferOwner != null &&
          !identical(texture._framebufferOwner, this)) {
        throw StateError('Texture $texture already belongs to a framebuffer');
      }
    }
    final previousDraw =
        _cgl.getParameter(glDrawFramebufferBinding) as GlFramebuffer?;
    final previousRead =
        _cgl.getParameter(glReadFramebufferBinding) as GlFramebuffer?;
    final previous = _framebuffer!;
    Framebuffer? candidate;
    try {
      // Borrow during preparation, including textures this object already owns.
      candidate = Framebuffer(
        _cgl,
        colorTexture,
        depthTexture,
        stencilTexture,
        depthStencilCombined,
      );
      _cgl.bindFramebuffer(
        glDrawFramebuffer,
        previousDraw == previous ? candidate._framebuffer : previousDraw,
      );
      _cgl.bindFramebuffer(
        glReadFramebuffer,
        previousRead == previous ? candidate._framebuffer : previousRead,
      );
    } catch (_) {
      _cleanupAfterFailure([
        if (candidate != null) candidate.dispose,
        () => _cgl.bindFramebuffer(glDrawFramebuffer, previousDraw),
        () => _cgl.bindFramebuffer(glReadFramebuffer, previousRead),
      ]);
      rethrow;
    }
    _framebuffer = candidate._framebuffer;
    candidate._framebuffer = null;
    candidate._isDisposed = true;
    _colorTexture = colorTexture;
    _depthTexture = depthTexture;
    _stencilTexture = stencilTexture;
    _depthStencilCombined = depthStencilCombined;
    final retired = _ownedTextures
        .where((t) => !attachments.contains(t))
        .toList();
    _ownedTextures.removeAll(retired);
    for (final texture in transfers) {
      _ownTexture(texture);
    }
    _deleteResources(previous, retired);
  }

  bool get isDisposed => _isDisposed;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('Framebuffer has been disposed');
  }

  void _checkUsable() {
    _checkNotDisposed();
    for (final texture in [_colorTexture, _depthTexture, _stencilTexture]) {
      texture?._checkNotDisposed();
    }
  }

  /// Releases the framebuffer, then its owned attachments, once.
  /// Ownership includes factory-created and explicitly transferred textures.
  /// Borrowed attachments survive. A screen wrapper deletes no GPU object.
  /// If cleanup fails, remaining resources are still attempted and the first
  /// error is rethrown; repeated calls do nothing.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final framebuffer = _framebuffer;
    final textures = _ownedTextures.toList();
    _framebuffer = null;
    _ownedTextures.clear();
    _colorTexture = null;
    _depthTexture = null;
    _stencilTexture = null;
    _deleteResources(framebuffer, textures);
  }

  void _deleteResources(GlFramebuffer? framebuffer, List<Texture> textures) {
    Object? firstError;
    StackTrace? firstStack;
    void release(void Function() action) {
      try {
        action();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    if (framebuffer != null) {
      release(() => _cgl.deleteFramebuffer(framebuffer));
    }
    for (final texture in textures) {
      release(texture.dispose);
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  void activate(
    int clearMode,
    int viewPortX,
    int viewPortY,
    int viewPortW,
    int viewPortH,
  ) {
    _checkUsable();
    _cgl.bindFramebuffer(glFramebuffer, _framebuffer);

    assert(
      viewPortW > 0 && viewPortH > 0,
      "width and height must be > 0: $viewPortW $viewPortW",
    );
    _cgl.viewport(viewPortX, viewPortY, viewPortW, viewPortH);

    if (clearMode != 0) {
      _cgl.clear(clearMode);
    }
  }

  /// If buf is non-null it must have size 4*w*h elements
  Float32List extractFloatData(Float32List? buf, int x, int y, int w, int h) {
    _checkUsable();
    _cgl.bindFramebuffer(glFramebuffer, _framebuffer);
    buf ??= Float32List(4 * w * h);
    _cgl.readPixels(x, y, w, h, glRgba, glFloat, buf);
    _cgl.bindFramebuffer(glFramebuffer, null);
    return buf;
  }

  /// If buf is non-null it must have size 4*w*h elements
  Uint8List extractByteData(Uint8List? buf, int x, int y, int w, int h) {
    _checkUsable();
    _cgl.bindFramebuffer(glFramebuffer, _framebuffer);
    buf ??= Uint8List(4 * w * h);
    _cgl.readPixels(x, y, w, h, glRgba, glUnsignedByte, buf);
    _cgl.bindFramebuffer(glFramebuffer, null);
    return buf;
  }
}
