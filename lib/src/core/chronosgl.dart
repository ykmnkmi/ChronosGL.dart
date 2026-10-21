part of 'lib.dart';

const String noWebglMessage = """
Calling canvas.getContext("webgl2") failed,
make sure you run on a computer that supports WebGL2.

You can test your browser's compatibility here: http://webglreport.com/

(If you are using Dartium make sure you start it with the
option: --enable-unsafe-es3-apis)
""";

const int kNoAnisotropicFilterLevel = 1;

String _addLineNumbers(String text) {
  List<String> out = text.split("\n");
  for (int i = 0; i < out.length; ++i) {
    out[i] = "${i + 1}: ${out[i]}";
  }
  return out.join("\n");
}

JSObject _toJSBufferView(TypedData data) => switch (data) {
  Int8List() => data.toJS,
  Uint8List() => data.toJS,
  Uint8ClampedList() => data.toJS,
  Int16List() => data.toJS,
  Uint16List() => data.toJS,
  Int32List() => data.toJS,
  Uint32List() => data.toJS,
  Float32List() => data.toJS,
  Float64List() => data.toJS,
  ByteData() => data.toJS,
  _ => data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes).toJS,
};

JSObject _toJSNumericBuffer(List<num> data) => data is TypedData
    ? _toJSBufferView(data as TypedData)
    : Float32List.fromList([for (final value in data) value.toDouble()]).toJS;

void _copyJSBufferView(JSObject source, TypedData destination) {
  // toJS may clone Dart-owned storage on Wasm. Copy readbacks into the
  // caller's exact view when the conversion does not share its storage.
  final data = source.dartify() as TypedData;
  if (!identical(data, destination)) {
    destination.buffer
        .asUint8List(destination.offsetInBytes, destination.lengthInBytes)
        .setAll(
          0,
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
  }
}

@JS('ArrayBuffer.isView')
external bool _isArrayBufferView(JSAny value);

Object? _fromJSParameter(JSAny? value) {
  if (value == null) return null;
  if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
  if (value.isA<JSNumber>()) {
    final number = (value as JSNumber).toDartDouble;
    return number.isFinite && number == number.truncateToDouble()
        ? number.toInt()
        : number;
  }
  if (value.isA<JSString>()) return (value as JSString).toDart;
  if (value.isA<JSArray<JSAny?>>() || _isArrayBufferView(value)) {
    return value.dartify();
  }
  return value;
}

GlShader _compileShader(web.WebGL2RenderingContext gl, int type, String text) {
  GlShader shader =
      gl.createShader(type) ?? (throw StateError('Cannot create shader'));

  gl.shaderSource(shader, text);
  gl.compileShader(shader);

  bool result =
      (gl.getShaderParameter(shader, glCompileStatus) as JSBoolean).toDart;
  if (!result) {
    String error =
        gl.getShaderInfoLog(shader) ?? 'Unknown shader compilation error';
    logError("Compilation failed:");
    logError(_addLineNumbers(text));
    logError("Failure:");
    logError(error);
    throw error;
  }
  return shader;
}

/// Prepares a canvas for 3d rendering. Contains wrapper for all the
/// WebGL2 bindings
class ChronosGL {
  ChronosGL(
    Object canvas, {
    bool preserveDrawingBuffer = false,
    bool faceCulling = false,
    bool antialiasing = true,
  }) {
    final attributes = web.WebGLContextAttributes(
      alpha: false,
      depth: true,
      stencil: true,
      antialias: antialiasing,
      premultipliedAlpha: true,
      preserveDrawingBuffer: preserveDrawingBuffer,
      failIfMajorPerformanceCaveat: false,
    );

    // Accept both package:web and legacy browser canvas objects while callers
    // migrate. All context calls use static JS interop after this boundary.
    final element = JSObject.fromInteropObject(canvas) as web.HTMLCanvasElement;
    final context =
        element.getContext("webgl2", attributes) as web.WebGL2RenderingContext?;
    if (context == null) {
      throw Exception(noWebglMessage);
    }
    _gl = context;

    final actual = _gl.getContextAttributes();
    logInfo("ChronosGL Config: ${actual.dartify()}");

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.enable(glDepthTest);
    if (faceCulling) {
      _gl.enable(glCullFace);
    }
  }

  late final web.WebGL2RenderingContext _gl;

  GlProgram compileWholeProgram(
    String vertShaderText,
    String fragShaderText,
    List<String> transformVarying,
  ) {
    GlProgram program = createProgram();
    GlShader vs = _compileShader(_gl, glVertexShader, vertShaderText);
    _gl.attachShader(program, vs);
    // delete shader vs?

    GlShader fs = _compileShader(_gl, glFragmentShader, fragShaderText);
    _gl.attachShader(program, fs);
    // delete shader fs?

    if (transformVarying.isNotEmpty) {
      _gl.transformFeedbackVaryings(
        program,
        transformVarying.map((name) => name.toJS).toList().toJS,
        glInterleavedAttribs,
      );
    }

    _gl.linkProgram(program);

    if (!(_gl.getProgramParameter(program, glLinkStatus) as JSBoolean).toDart) {
      throw _gl.getProgramInfoLog(program) ?? 'Unknown program linking error';
    }

    return program;
  }

  void changeArrayBuffer(GlBuffer buffer, List<num> data) {
    _gl.bindBuffer(glArrayBuffer, buffer);
    _gl.bufferData(glArrayBuffer, _toJSNumericBuffer(data), glDynamicDraw);
  }

  void getArrayBuffer(GlBuffer buffer, TypedData data) {
    _gl.bindBuffer(glArrayBuffer, buffer);
    final view = _toJSBufferView(data);
    _gl.getBufferSubData(glArrayBuffer, 0, view);
    _copyJSBufferView(view, data);
  }

  void bufferDataSetSize(int kind, GlBuffer buf, int size, int usage) {
    _gl.bindBuffer(kind, buf);
    _gl.bufferData(kind, size.toJS, usage);
    _gl.bindBuffer(kind, null);
  }

  void getTransformBuffer(GlBuffer buf, TypedData data) {
    _gl.bindBuffer(glTransformFeedbackBuffer, buf);
    final view = _toJSBufferView(data);
    _gl.getBufferSubData(glTransformFeedbackBuffer, 0, view);
    _copyJSBufferView(view, data);
  }

  GlBuffer createBuffer() {
    return _gl.createBuffer() ?? (throw StateError('Cannot create buffer'));
  }

  void changeElementArrayBuffer(GlBuffer buf, TypedData data) {
    assert((data is Uint16List) || (data is Uint32List) || (data is Uint8List));
    _gl.bindBuffer(glElementArrayBuffer, buf);
    _gl.bufferData(glElementArrayBuffer, _toJSBufferView(data), glDynamicDraw);
  }

  // Not really useful other than tesying
  void changeTransformBuffer(GlBuffer buffer, List<num> data) {
    _gl.bindBuffer(glTransformFeedbackBuffer, buffer);
    _gl.bufferData(
      glTransformFeedbackBuffer,
      _toJSNumericBuffer(data),
      glDynamicDraw,
    );
  }

  // Why all these shims?
  // They are useful for instrumentation and may allow us some day
  // to interface with dart-gl
  void deleteBuffer(GlBuffer buffer) {
    _gl.deleteBuffer(buffer);
  }

  void bindBuffer(int kind, GlBuffer? buffer) {
    _gl.bindBuffer(kind, buffer);
  }

  GlVertexArrayObject createVertexArray() {
    return _gl.createVertexArray() ??
        (throw StateError('Cannot create vertex array'));
  }

  void bindVertexArray(GlVertexArrayObject vao) {
    _gl.bindVertexArray(vao);
  }

  void copyBufferSubData(
    int srcBuffer,
    int dstBuffer,
    int srcOffset,
    int dstOffset,
    int size,
  ) {
    _gl.copyBufferSubData(srcBuffer, dstBuffer, srcOffset, dstOffset, size);
  }

  GlFramebuffer createFramebuffer() {
    return _gl.createFramebuffer() ??
        (throw StateError('Cannot create framebuffer'));
  }

  void bindFramebuffer(int kind, GlFramebuffer? framebuffer) {
    _gl.bindFramebuffer(kind, framebuffer);
  }

  int checkFramebufferStatus(int kind) {
    return _gl.checkFramebufferStatus(kind);
  }

  void framebufferTexture2D(
    int target,
    int attachment,
    int textarget,
    GlTexture texture,
    int level,
  ) {
    _gl.framebufferTexture2D(target, attachment, textarget, texture, level);
  }

  GlTexture createTexture() {
    return _gl.createTexture() ?? (throw StateError('Cannot create texture'));
  }

  void bindTexture(int kind, GlTexture? texture) {
    _gl.bindTexture(kind, texture);
  }

  GlTransformFeedback createTransformFeedback() {
    return _gl.createTransformFeedback() ??
        (throw StateError('Cannot create transform feedback'));
  }

  void bindTransformFeedback(GlTransformFeedback transform) {
    //_gl.bindTransformFeedback(glTransformFeedback, null);
    _gl.bindTransformFeedback(glTransformFeedback, transform);
  }

  void bindBufferBase(int kind, int offset, GlBuffer? buffer) {
    // in case buffer is still bound
    // _gl.bindBuffer(glArrayBuffer, null);
    _gl.bindBufferBase(kind, offset, buffer);
  }

  void viewport(int x, int y, int w, int h) {
    _gl.viewport(x, y, w, h);
  }

  void enable(int kind) {
    _gl.enable(kind);
  }

  void cullFace(int kind) {
    _gl.cullFace(kind);
  }

  void disable(int kind) {
    _gl.disable(kind);
  }

  void depthMask(bool flag) {
    _gl.depthMask(flag);
  }

  void depthFunc(int func) {
    _gl.depthFunc(func);
  }

  void blendFunc(int srcFactor, int dstFactor) {
    _gl.blendFunc(srcFactor, dstFactor);
  }

  void blendEquation(int equation) {
    _gl.blendEquation(equation);
  }

  void stencilFunc(int func, int value, int mask) {
    _gl.stencilFunc(func, value, mask);
  }

  void enableVertexAttribArray(int index, int divisor) {
    _gl.enableVertexAttribArray(index);
    if (divisor > 0) _gl.vertexAttribDivisor(index, divisor);
  }

  // Obsolete because of VAOs
  /*
  void disableVertexAttribArray(int index, bool instanced) {
    _gl.disableVertexAttribArray(index);
    if (instanced) _gl.vertexAttribDivisor(index, 0);
  }
*/

  void stencilOp(int fail, int zfail, int zpass) {
    _gl.stencilOp(fail, zfail, zpass);
  }

  void stencilMask(int mask) {
    _gl.stencilMask(mask);
  }

  void colorMask(bool r, bool g, bool b, bool a) {
    _gl.colorMask(r, g, b, a);
  }

  void clear(int kind) {
    _gl.clear(kind);
  }

  void setLineWidth(int w) {
    _gl.lineWidth(w);
  }

  void generateMipmap(int kind) {
    _gl.generateMipmap(kind);
  }

  void texParameteri(int kind1, int kind2, int val) {
    _gl.texParameteri(kind1, kind2, val);
  }

  void texParameterf(int kind1, int kind2, double val) {
    _gl.texParameterf(kind1, kind2, val);
  }

  Object? getParameter(int kind) {
    return _fromJSParameter(_gl.getParameter(kind));
  }

  void vertexAttribPointer(
    GlBuffer buffer,
    int index,
    int size,
    int type,
    bool normalized,
    int stride,
    int offset,
  ) {
    _gl.bindBuffer(glArrayBuffer, buffer);
    _gl.vertexAttribPointer(index, size, type, normalized, stride, offset);
  }

  void texImage2Dweb(
    int target,
    int level,
    int iformat,
    int format,
    int type,
    Object data,
  ) {
    _gl.texImage2D(
      target,
      level,
      iformat,
      format.toJS,
      type.toJS,
      JSObject.fromInteropObject(data),
    );
  }

  void texImage2D(
    int target,
    int level,
    int iformat,
    int w,
    int h,
    int border,
    int format,
    int type,
    TypedData? data,
  ) {
    _gl.texImage2D(
      target,
      level,
      iformat,
      w.toJS,
      h.toJS,
      border.toJS,
      format,
      type,
      data == null ? null : _toJSBufferView(data),
    );
  }

  void texStorage2D(int target, int level, int iformat, int w, int h) {
    _gl.texStorage2D(target, level, iformat, w, h);
  }

  void texSubImage2D(
    int target,
    int level,
    int x,
    int y,
    int w,
    int h,
    int format,
    int type,
    TypedData? data,
  ) {
    _gl.texSubImage2D(
      target,
      level,
      x,
      y,
      w.toJS,
      h.toJS,
      format.toJS,
      type,
      data == null ? null : _toJSBufferView(data),
    );
  }

  void copyTexImage2D(
    int target,
    int level,
    int format,
    int x,
    int y,
    int w,
    int h,
  ) {
    _gl.copyTexImage2D(target, level, format, x, y, w, h, 0);
  }

  void activeTexture(int target) {
    _gl.activeTexture(target);
  }

  GlProgram createProgram() {
    return _gl.createProgram() ?? (throw StateError('Cannot create program'));
  }

  void linkProgram(GlProgram obj) {
    _gl.linkProgram(obj);
  }

  void useProgram(GlProgram obj) {
    _gl.useProgram(obj);
  }

  GlShader createShader(int kind) {
    return _gl.createShader(kind) ?? (throw StateError('Cannot create shader'));
  }

  GlUniformLocation? getUniformLocation(GlProgram program, String uniform) {
    try {
      return _gl.getUniformLocation(program, uniform);
    } catch (e) {
      logError("Unknown uniform [$uniform] for $program");
      return null;
    }
  }

  GlSampler createSampler() {
    return _gl.createSampler() ?? (throw StateError('Cannot create sampler'));
  }

  int getError() {
    return _gl.getError();
  }

  // reads from bound GL_FRAMEBUFFER
  void readPixels(
    int x,
    int y,
    int w,
    int h,
    int implFormat,
    int implType,
    TypedData buf,
  ) {
    final view = _toJSBufferView(buf);
    _gl.readPixels(x, y, w, h, implFormat, implType, view);
    _copyJSBufferView(view, buf);
  }

  void readPixelsToBuffer(
    int x,
    int y,
    int w,
    int h,
    int implFormat,
    int implType,
    int offset,
  ) {
    _gl.readPixels(x, y, w, h, implFormat, implType, offset.toJS);
  }

  String getProgramInfoLog(GlProgram program) {
    return _gl.getProgramInfoLog(program) ?? '';
  }

  void pixelStorei(int type, int value) {
    _gl.pixelStorei(type, value);
  }

  List<String> getSupportedExtensions() {
    return _gl
            .getSupportedExtensions()
            ?.toDart
            .map((extension) => extension.toDart)
            .toList() ??
        <String>[];
  }

  JSObject? getExtension(String name) {
    return _gl.getExtension(name);
  }

  Object? getGlExtensionAnisotropic() {
    Object? ext = getExtension("EXT_texture_filter_anisotropic");
    if (ext == null) {
      logWarn("ExtensionAnisotropic NOT SUPPORTED");
    }
    return ext;
  }

  int maxAnisotropicFilterLevel() {
    var ext = getGlExtensionAnisotropic();
    if (ext == null) {
      return kNoAnisotropicFilterLevel;
    }
    return (getParameter(
      web.EXT_texture_filter_anisotropic.MAX_TEXTURE_MAX_ANISOTROPY_EXT,
    ) as num).toInt();
  }

  void draw(
    int mode,
    int count,
    int type,
    int offset,
    int instanceCount,
    bool hasTransforms,
  ) {
    if (hasTransforms) _gl.beginTransformFeedback(mode);
    if (type != -1) {
      if (instanceCount > 1) {
        _gl.drawElementsInstanced(mode, count, type, offset, instanceCount);
      } else {
        _gl.drawElements(mode, count, type, offset);
      }
    } else {
      if (instanceCount > 1) {
        _gl.drawArraysInstanced(mode, offset, count, instanceCount);
      } else {
        _gl.drawArrays(mode, offset, count);
      }
    }
    if (hasTransforms) _gl.endTransformFeedback();
  }

  void uniform1f(GlUniformLocation location, double value) {
    _gl.uniform1f(location, value);
  }

  void uniform1i(GlUniformLocation location, int value) {
    _gl.uniform1i(location, value);
  }

  void uniform1iv(GlUniformLocation location, Int32List value) {
    _gl.uniform1iv(location, value.toJS);
  }

  void uniform1fv(GlUniformLocation location, Float32List value) {
    _gl.uniform1fv(location, value.toJS);
  }

  void uniform2fv(GlUniformLocation location, Float32List value) {
    _gl.uniform2fv(location, value.toJS);
  }

  void uniform3fv(GlUniformLocation location, Float32List value) {
    _gl.uniform3fv(location, value.toJS);
  }

  void uniform4fv(GlUniformLocation location, Float32List value) {
    _gl.uniform4fv(location, value.toJS);
  }

  void uniformMatrix4fv(
    GlUniformLocation location,
    bool transpose,
    Float32List value,
  ) {
    _gl.uniformMatrix4fv(location, transpose, value.toJS);
  }

  void uniformMatrix3fv(
    GlUniformLocation location,
    bool transpose,
    Float32List value,
  ) {
    _gl.uniformMatrix3fv(location, transpose, value.toJS);
  }

  void clearColor(double r, double g, double b, double a) {
    _gl.clearColor(r, g, b, a);
  }
}
