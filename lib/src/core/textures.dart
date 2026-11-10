part of 'lib.dart';

/// properties like clamping and mip-mapping.
class TextureProperties {
  TextureProperties();

  bool mipmap = false;
  bool clamp = false;
  bool shadow = false;
  bool flipY = true;
  int anisotropicFilterLevel = kNoAnisotropicFilterLevel;
  int minFilter = glLinear;
  int magFilter = glLinear;

  void setFilterNearest() {
    minFilter = glNearest;
    magFilter = glNearest;
  }

  // Very good but also a bit slow
  void setMipmapLinear() {
    mipmap = true;
    minFilter = glLinearMipmapLinear;
    magFilter = glLinear; // is this the best?
  }

  // This assumes a texture is already bound
  void installEarly(ChronosGL cgl, int type) {
    cgl.pixelStorei(glUnpackFlipYWebgl, flipY ? 1 : 0);
  }

  // This assumes a texture is already bound
  void installLate(ChronosGL cgl, int type) {
    if (anisotropicFilterLevel != kNoAnisotropicFilterLevel) {
      cgl.texParameterf(
        type,
        glTextureMaxAnisotropyExt,
        anisotropicFilterLevel + 0.0,
      );
    }
    cgl.texParameteri(type, glTextureMagFilter, magFilter);
    cgl.texParameteri(type, glTextureMinFilter, minFilter);

    if (clamp) {
      // this fixes glitches on skybox seams
      cgl.texParameteri(type, glTextureWrapS, glClampToEdge);
      cgl.texParameteri(type, glTextureWrapT, glClampToEdge);
    }
    if (mipmap) {
      cgl.generateMipmap(type);
    }

    if (shadow) {
      /*
      from: https://www.opengl.org/discussion_boards/showthread.php/180780-How-does-sampler2DArrayShadow-in-glsl-works

      Hardware depth comparisons happen internal to your texture lookup (i.e. texture() call).
      What you get back is not a filtered texture value, but rather a filtered depth comparison
      result (where the depth value you pass into the texturre call is compared against one or
      more texels). This gives you a filtered 0..1 visibility value, which is usually what you
      want anyway.
      */

      cgl.texParameteri(type, glTextureCompareMode, glCompareRefToTexture);
    }
  }
}

final TextureProperties texturePropertiesFramebuffer = TextureProperties()
  ..flipY = false
  ..clamp = true
  ..mipmap = false
  ..setFilterNearest();

final TextureProperties texturePropertiesFramebufferWrapped =
    TextureProperties()
      ..flipY = false
      ..clamp = false
      ..mipmap = false
      ..setFilterNearest();

final TextureProperties texturePropertiesVideo = TextureProperties()
  ..clamp = true;

// http://stackoverflow.com/questions/22419682/glsl-sampler2dshadow-and-shadow2d-clarification\
final TextureProperties texturePropertiesShadowMap = TextureProperties()
  ..flipY = false
  ..clamp = true
  ..mipmap = false
  ..shadow = true;
//..setFilterNearest();

final TextureProperties texturePropertiesMipmap = TextureProperties()
  ..setMipmapLinear();

bool isCubeChildTextureType(int t) {
  switch (t) {
    case glTextureCubeMapNegativeX:
    case glTextureCubeMapPositiveX:
    case glTextureCubeMapNegativeY:
    case glTextureCubeMapPositiveY:
    case glTextureCubeMapNegativeZ:
    case glTextureCubeMapPositiveZ:
      return true;
    default:
      return false;
  }
}

/// Base class for textures. Owns its GPU handle; call [dispose] after use.
/// Handle access, uploads, updates and installation throw [StateError] after
/// disposal. [getTextureType], [properties] and [toString] remain available for
/// inspection; changing properties cannot revive the released GPU handle.
class Texture {
  Texture(this._cgl, this._textureType, this._url, this.properties)
    : _texture = _cgl.createTexture();

  final String _url;
  GlTexture? _texture;
  final int _textureType;
  final ChronosGL _cgl;
  final TextureProperties properties;
  bool _isDisposed = false;
  // Only framebuffer containers can currently accept an external texture.
  // Borrowers do not register here; they must finish before the owner disposes.
  Framebuffer? _framebufferOwner;

  // Constructors must release their handle even when an upload or settings
  // installation fails. Successful construction keeps the existing null bind.
  void _initialize(void Function() upload) {
    GlTexture? previousTexture;
    bool bindingSaved = false;
    try {
      previousTexture = _cgl.getParameter(
        _textureType == glTextureCubeMap
            ? glTextureBindingCubeMap
            : glTextureBinding2D,
      ) as GlTexture?;
      bindingSaved = true;
      upload();
      final error = _cgl.getError();
      if (error != glNoError) {
        throw StateError('Texture $_url initialization error: $error');
      }
      _cgl.bindTexture(_textureType, null);
    } catch (_) {
      _cleanupAfterFailure([
        dispose,
        if (bindingSaved) () => _cgl.bindTexture(_textureType, previousTexture),
      ]);
      rethrow;
    }
  }

  bool get isDisposed => _isDisposed;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('Texture $_url has been disposed');
  }

  /// Releases the texture handle exactly once, including after a cleanup error.
  /// Borrowed image/video sources and texture properties are not modified.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final texture = _texture!;
    _texture = null;
    _framebufferOwner = null;
    _cgl.deleteTexture(texture);
  }

  void copyFromFramebuffer2D(int x, int y, int w, int h) {
    _checkNotDisposed();
    _cgl.bindTexture(_textureType, _texture);
    _cgl.copyTexImage2D(_textureType, 0, glRgba, x, y, w, h);
    install();
  }

  void install() {
    _checkNotDisposed();
    _cgl.bindTexture(_textureType, _texture);
    properties.installLate(_cgl, _textureType);
    int err = _cgl.getError();
    assert(err == glNoError);
  }

  int getTextureType() => _textureType;

  GlTexture getTexture() {
    _checkNotDisposed();
    return _texture!;
  }

  @override
  String toString() {
    return "Texture[$_url, $_textureType]";
  }
}

// https://www.khronos.org/registry/OpenGL-Refpages/es3.0/html/glTexImage2D.xhtml
class TypedTexture extends Texture {
  TypedTexture(
    ChronosGL cgl,
    String url,
    this._width,
    this._height,
    this._internalFormat,
    TextureProperties prop,
  ) : super(cgl, glTexture2D, url, prop) {
    _initialize(() {
      _cgl.bindTexture(_textureType, _texture);
      _cgl.texStorage2D(glTexture2D, 1, _internalFormat, _width, _height);
      properties.installLate(_cgl, _textureType);
    });
  }

  final int _width;
  final int _height;
  final int _internalFormat;

  @override
  String toString() {
    return "TypedTexture[$_url, $_internalFormat, $_width X $_height]";
  }
}

class TypedTextureMutable extends Texture {
  TypedTextureMutable(
    ChronosGL cgl,
    String url,
    this._width,
    this._height,
    this._internalFormat,
    TextureProperties prop,
    int format,
    int datatype,
    TypedData? data,
  ) : super(cgl, glTexture2D, url, prop) {
    _initialize(() {
      _cgl.bindTexture(_textureType, _texture);
      _cgl.texImage2D(
        glTexture2D,
        0,
        _internalFormat,
        _width,
        _height,
        0,
        format,
        datatype,
        data,
      );
      properties.installLate(_cgl, _textureType);
    });
  }

  final int _width;
  final int _height;
  final int _internalFormat;

  void updateContent(TypedData data, int format, int datatype) {
    _checkNotDisposed();
    _cgl.bindTexture(_textureType, _texture);
    _cgl.texImage2D(
      glTexture2D,
      0,
      _internalFormat,
      _width,
      _height,
      0,
      format,
      datatype,
      data,
    );
    _cgl.bindTexture(_textureType, null);
  }

  void updateContentPartial(
    TypedData data,
    int formatType,
    int scalarType,
    int x,
    int y,
    int w,
    int h,
  ) {
    _checkNotDisposed();
    _cgl.bindTexture(_textureType, _texture);
    _cgl.texSubImage2D(
      glTexture2D,
      0,
      x,
      y,
      w,
      h,
      formatType,
      scalarType,
      data,
    );
    _cgl.bindTexture(_textureType, null);
  }

  @override
  String toString() {
    return "TypedTextureMutable[$_url, $_internalFormat, $_width X $_height]";
  }
}

// Object sources let package:web and legacy DOM elements share the WebGL
// interop boundary.
// TODO: We want to call  install() in the constructor but this does not
// seem to work for video elements.
class ImageTexture extends Texture {
  ImageTexture(
    ChronosGL cgl,
    String url,
    Object element, [
    TextureProperties? tp,
    int textureType = glTexture2D,
  ]) : _element = element,
       super(cgl, textureType, url, tp ?? TextureProperties()) {
    _initialize(() {
      _cgl.bindTexture(_textureType, _texture);

      properties.installEarly(_cgl, _textureType);
      setImageData(element);
      properties.installLate(_cgl, _textureType);
    });
  }

  Object? _element; // Borrowed CanvasElement, ImageElement, VideoElement

  @override
  void dispose() {
    _element = null;
    super.dispose();
  }

  void setImageData(Object data) {
    _checkNotDisposed();
    _cgl.bindTexture(_textureType, _texture);
    _cgl.texImage2Dweb(_textureType, 0, glRgba, glRgba, glUnsignedByte, data);
  }

  void update() {
    _checkNotDisposed();
    setImageData(_element!);
    _cgl.bindTexture(_textureType, null);
  }
}

const List<int> _kCubeModifier = [
  glTextureCubeMapNegativeX,
  glTextureCubeMapPositiveX,
  glTextureCubeMapNegativeY,
  glTextureCubeMapPositiveY,
  glTextureCubeMapNegativeZ,
  glTextureCubeMapPositiveZ,
];

class CubeTexture extends Texture {
  CubeTexture(ChronosGL cgl, String url, List<Object> images)
    : super(cgl, glTextureCubeMap, url, TextureProperties()..clamp = true) {
    _initialize(() {
      assert(images.length == _kCubeModifier.length);
      properties.installEarly(_cgl, _textureType);

      _cgl.bindTexture(_textureType, _texture);
      for (int i = 0; i < _kCubeModifier.length; ++i) {
        _cgl.texImage2Dweb(
          _kCubeModifier[i],
          0,
          glRgba,
          glRgba,
          glUnsignedByte,
          images[i],
        );
      }
      properties.installLate(_cgl, _textureType);
    });
  }
}
