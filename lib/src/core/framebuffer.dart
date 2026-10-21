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

class Framebuffer {
  Framebuffer(
    this._cgl,
    this.colorTexture, [
    this.depthTexture,
    this.stencilTexture,
    bool depthStencilCombined = false,
  ]) {
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
      assert(
        !depthStencilCombined,
        "in combined mode - the stencil parameter must be null",
      );
      _cgl.framebufferTexture2D(
        glFramebuffer,
        glStencilAttachment,
        glTexture2D,
        stencilTexture!.getTexture(),
        0,
      );
    }

    int err = _cgl.checkFramebufferStatus(glFramebuffer);
    assert(err == glFramebufferComplete, "framebuffer error: $err");
    if (err != glFramebufferComplete) {
      throw "Error Incomplete Framebuffer: $err";
    }
    _cgl.bindFramebuffer(glFramebuffer, null);
  }

  Framebuffer.screen(this._cgl) : _framebuffer = null;

  Framebuffer.defaultFramebuffer(ChronosGL cgl, int w, int h)
    : this(
        cgl,
        TypedTexture(
          cgl,
          "frame::color",
          w,
          h,
          glRgba8,
          texturePropertiesFramebuffer,
        ),
        TypedTexture(
          cgl,
          "frame::depth",
          w,
          h,
          glDepthComponent24,
          texturePropertiesFramebuffer,
        ),
      );

  Framebuffer.effect(ChronosGL cgl, int w, int h)
    : this(
        cgl,
        TypedTexture(
          cgl,
          "frame::color",
          w,
          h,
          glRgba8,
          texturePropertiesFramebuffer,
        ),
      );

  ChronosGL _cgl;

  GlFramebuffer? _framebuffer;
  Texture? colorTexture;
  Texture? depthTexture;
  Texture? stencilTexture;

  void activate(
    int clearMode,
    int viewPortX,
    int viewPortY,
    int viewPortW,
    int viewPortH,
  ) {
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
    _cgl.bindFramebuffer(glFramebuffer, _framebuffer);
    buf ??= Float32List(4 * w * h);
    _cgl.readPixels(x, y, w, h, glRgba, glFloat, buf);
    _cgl.bindFramebuffer(glFramebuffer, null);
    return buf;
  }

  /// If buf is non-null it must have size 4*w*h elements
  Uint8List extractByteData(Uint8List? buf, int x, int y, int w, int h) {
    _cgl.bindFramebuffer(glFramebuffer, _framebuffer);
    buf ??= Uint8List(4 * w * h);
    _cgl.readPixels(x, y, w, h, glRgba, glUnsignedByte, buf);
    _cgl.bindFramebuffer(glFramebuffer, null);
    return buf;
  }
}
