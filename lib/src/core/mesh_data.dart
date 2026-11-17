part of 'lib.dart';

Float32List flattenVector3List(List<vm.Vector3> v, [Float32List? data]) {
  data ??= Float32List(v.length * 3);
  for (int i = 0; i < v.length; ++i) {
    data[i * 3 + 0] = v[i].x;
    data[i * 3 + 1] = v[i].y;
    data[i * 3 + 2] = v[i].z;
  }
  return data;
}

Float32List flattenVector2List(List<vm.Vector2> v, [Float32List? data]) {
  data ??= Float32List(v.length * 2);
  for (int i = 0; i < v.length; ++i) {
    data[i * 2 + 0] = v[i].x;
    data[i * 2 + 1] = v[i].y;
  }
  return data;
}

Float32List flattenVector4List(List<vm.Vector4> v, [Float32List? data]) {
  data ??= Float32List(v.length * 4);
  for (int i = 0; i < v.length; ++i) {
    data[i * 4 + 0] = v[i].x;
    data[i * 4 + 1] = v[i].y;
    data[i * 4 + 2] = v[i].z;
    data[i * 4 + 3] = v[i].w;
  }
  return data;
}

Uint32List flattenUvec4List(List<List<int>> v, [Uint32List? data]) {
  data ??= Uint32List(v.length * 4);
  for (int i = 0; i < v.length; ++i) {
    data[i * 4 + 0] = v[i][0];
    data[i * 4 + 1] = v[i][1];
    data[i * 4 + 2] = v[i][2];
    data[i * 4 + 3] = v[i][3];
  }
  return data;
}

Float32List flattenMatrix4List(List<vm.Matrix4> v, [Float32List? data]) {
  data ??= Float32List(v.length * 16);
  for (int i = 0; i < v.length; ++i) {
    vm.Matrix4 m = v[i];
    for (int j = 0; j < 16; ++j) {
      data[i * 16 + j] = m[j];
    }
  }
  return data;
}

/// One immutable attribute binding in a GPU vertex layout.
class VertexAttributeLayout {
  const VertexAttributeLayout({
    required this.location,
    required this.type,
    required this.width,
    required this.divisor,
  });

  final int location;
  final String type;
  final int width;
  final int divisor;

  bool get isInteger =>
      type == varTypeInt ||
      type == varTypeUvec2 ||
      type == varTypeUvec3 ||
      type == varTypeUvec4;

  bool _matches(VertexAttributeLayout other) =>
      location == other.location &&
      type == other.type &&
      width == other.width &&
      divisor == other.divisor;
}

/// A snapshot of canonical attribute names, shader types and VAO bindings.
///
/// Later edits to shader builders, their location maps or the canonical shader
/// registry cannot change an existing program or mesh layout.
class MeshAttributeLayout {
  MeshAttributeLayout(Map<String, int> locations)
    : attributes = Map.unmodifiable({
        for (final entry in locations.entries)
          entry.key: _describe(entry.key, entry.value),
      }) {
    final used = <int>{};
    for (final attribute in attributes.values) {
      if (attribute.location < 0 || !used.add(attribute.location)) {
        throw ArgumentError(
          'Attribute locations must be distinct and nonnegative',
        );
      }
    }
  }

  final Map<String, VertexAttributeLayout> attributes;

  static VertexAttributeLayout _describe(String canonical, int location) {
    final desc = retrieveShaderVarDesc(canonical);
    final width = switch (desc.type) {
      varTypeFloat || varTypeInt => 1,
      varTypeVec2 || varTypeUvec2 => 2,
      varTypeVec3 || varTypeUvec3 => 3,
      varTypeVec4 || varTypeUvec4 => 4,
      _ => throw ArgumentError(
        'Unsupported vertex attribute type: ${desc.type}',
      ),
    };
    if (desc.arraySize != 0) {
      throw ArgumentError(
        'Array vertex attributes are unsupported: $canonical',
      );
    }
    return VertexAttributeLayout(
      location: location,
      type: desc.type,
      width: width,
      divisor: canonical.codeUnitAt(0) == prefixInstancer ? 1 : 0,
    );
  }

  /// Whether this layout supplies every binding required by [requiredLayout].
  bool supplies(MeshAttributeLayout requiredLayout) {
    for (final entry in requiredLayout.attributes.entries) {
      final supplied = attributes[entry.key];
      if (supplied == null || !supplied._matches(entry.value)) return false;
    }
    return true;
  }
}

/// Represents the GPU storage for a mesh.
/// Wraps a Vertex Array Object (VAO), its buffers and an immutable attribute
/// layout. Populate it directly with [RenderProgram.makeGpuMesh], or upload a
/// CPU [GeometryBuilder] with [uploadGeometry]. A mesh can be shared by programs
/// in the same context whose required bindings match [attributeLayout].
///
/// Owns its VAO and every buffer created by its `add*` methods. Buffers passed
/// to [changeAttributeBuffer] are borrowed unless `takeOwnership: true` is used.
/// Call [dispose] when all consumers have finished using the mesh, or [clearData]
/// to empty it for reuse.
/// After disposal, only metadata ([name], [drawMode], [supportsAttribute] and
/// [toString]) remains readable. Data access, mutation and extraction helpers
/// throw [StateError] before accessing cleared data or allocating GPU resources.
class GpuMesh extends NamedEntity {
  GpuMesh(String name, ChronosGL cgl, int drawMode, Map<String, int> locations)
    : this._withLayout(name, cgl, drawMode, MeshAttributeLayout(locations));

  GpuMesh._withLayout(
    String name,
    this._cgl,
    this._drawMode,
    this.attributeLayout,
  ) : _vao = _cgl.createVertexArray(),
      super("meshdata:$name");

  final ChronosGL _cgl;
  GlVertexArrayObject? _vao;
  final int _drawMode;
  final Map<String, GlBuffer> _buffers = {};
  // Ownership is independent of slots, which can alias or borrow a buffer.
  final Set<GlBuffer> _ownedBuffers = {};
  final MeshAttributeLayout attributeLayout;
  GlBuffer? _indexBuffer;
  int _instances = 0;
  int _indexBufferType = -1;
  bool _isDisposed = false;

  Float32List _vertices = Float32List(0);
  List<int>? _faces;
  final Map<String, List<num>> _attributes = {};

  bool get isDisposed => _isDisposed;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('MeshData $name has been disposed');
  }

  void _releaseUnusedBuffer(GlBuffer? buffer) {
    if (buffer == null ||
        _buffers.containsValue(buffer) ||
        _indexBuffer == buffer ||
        !_ownedBuffers.remove(buffer)) {
      return;
    }
    // Commit removal before deletion, including when the backend throws.
    _cgl.deleteBuffer(buffer);
  }

  void _checkBufferError() {
    final error = _cgl.getError();
    if (error != glNoError) {
      throw StateError('MeshData $name buffer update error: $error');
    }
  }

  void _releaseData(GlVertexArrayObject vao) {
    final buffers = _ownedBuffers.toList();
    _ownedBuffers.clear();
    _buffers.clear();
    _indexBuffer = null;
    _attributes.clear();
    _vertices = Float32List(0);
    _faces = null;
    _instances = 0;
    _indexBufferType = -1;

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

    // Release the VAO's references, including borrowed buffers, first.
    release(() => _cgl.deleteVertexArray(vao));
    for (final buffer in buffers) {
      release(() => _cgl.deleteBuffer(buffer));
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  /// Releases owned buffers and CPU data, leaving an empty, reusable mesh.
  ///
  /// Replaces the VAO to detach all attribute/index bindings, including borrowed
  /// buffers. If creating the replacement fails, the old mesh stays intact.
  void clearData() {
    _checkNotDisposed();
    final replacement = _cgl.createVertexArray();
    final previous = _vao!;
    _vao = replacement;
    _releaseData(previous);
  }

  /// Releases the VAO, owned buffers and retained CPU data exactly once.
  ///
  /// Borrowed buffers are not deleted. Repeated calls do nothing, including
  /// after a cleanup error. Data access and GPU operations then throw
  /// [StateError]; diagnostic metadata and [isDisposed] remain readable.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final vao = _vao!;
    _vao = null;
    _releaseData(vao);
  }

  void changeAttributeData(String canonical, List<num> data, int width) {
    _checkNotDisposed();
    final attribute = attributeLayout.attributes[canonical];
    if (attribute == null ||
        width != attribute.width ||
        data.length % width != 0) {
      throw ArgumentError('Invalid attribute or data width: $canonical');
    }
    if (debug) print("ChangeBuffer $canonical ${data.length}");
    if (canonical.codeUnitAt(0) == prefixInstancer) {
      assert(data.length ~/ width == _instances, "ChangeAttribute $_instances");
    } else {
      assert(
        data.length ~/ width == _vertices.length ~/ 3,
        "wrong size for attribute: $canonical expected: ${_vertices.length ~/ 3} got: ${data.length ~/ width}",
      );
    }
    final uploadData = _uploadData(attribute, data);
    _attributes[canonical] = data;
    _cgl.changeArrayBuffer(_buffers[canonical]!, uploadData);
  }

  void changeVertexData(Float32List data) {
    _checkNotDisposed();
    final String canonical = aPosition;
    _vertices = data;
    changeAttributeData(canonical, data, 3);
  }

  bool supportsAttribute(String canonical) {
    return attributeLayout.attributes.containsKey(canonical);
  }

  /// Layout and context compatibility, independent of populated buffers.
  bool isCompatibleWith(RenderProgram program) =>
      identical(_cgl, program.getContext()) &&
      attributeLayout.supplies(program.attributeLayout);

  int get drawMode => _drawMode;

  int get elementArrayBufferType {
    _checkNotDisposed();
    return _indexBufferType;
  }

  int getNumItems() {
    _checkNotDisposed();
    if (_faces != null) {
      return _faces!.length;
    }
    return _vertices.length ~/ 3;
  }

  int getNumInstances() {
    _checkNotDisposed();
    return _instances;
  }

  List<num> getAttribute(String canonical) {
    _checkNotDisposed();
    return _attributes[canonical]!;
  }

  /// Returns a borrowed handle; this does not transfer ownership to the caller.
  GlBuffer getBuffer(String canonical) {
    _checkNotDisposed();
    return _buffers[canonical]!;
  }

  /// Borrows [buffer] by default; its owner must keep it alive while in use.
  ///
  /// With [takeOwnership], this mesh accepts responsibility for deletion only
  /// after binding succeeds. The caller must not transfer a buffer still owned
  /// by another mesh. Raw handles cannot track that ownership for the caller.
  /// Rebinding an already owned buffer never relinquishes ownership, even when
  /// [takeOwnership] is false. The previous owned buffer is deleted after the
  /// last slot using it is replaced. Borrowed buffers are only detached.
  /// On a binding failure the old configuration and caller bindings survive.
  /// A deletion error occurs after commit: the new buffer is already installed.
  void changeAttributeBuffer(
    String canonical,
    GlBuffer buffer, {
    bool takeOwnership = false,
  }) {
    _replaceAttributeBuffer(canonical, buffer, takeOwnership: takeOwnership);
  }

  void _replaceAttributeBuffer(
    String canonical,
    GlBuffer buffer, {
    required bool takeOwnership,
    void Function()? upload,
    void Function()? commitData,
  }) {
    _checkNotDisposed();
    final attribute = attributeLayout.attributes[canonical];
    if (attribute == null) {
      throw ArgumentError.value(
        canonical,
        'canonical',
        'Unsupported attribute',
      );
    }
    final int index = attribute.location;
    final bool instanced = attribute.divisor != 0;
    final previous = _buffers[canonical];
    final previousVao =
        _cgl.getParameter(glVertexArrayBinding) as GlVertexArrayObject?;
    final previousArray = _cgl.getParameter(glArrayBufferBinding) as GlBuffer?;
    bool bindingStarted = false;
    try {
      // Upload new storage before changing any live attribute reference.
      upload?.call();
      _checkBufferError();
      _cgl.bindVertexArray(_vao!);
      bindingStarted = true;
      _cgl.enableVertexAttribArray(index, instanced ? 1 : 0);
      if (attribute.isInteger) {
        _cgl.bindBuffer(glArrayBuffer, buffer);
        _cgl._gl.vertexAttribIPointer(
          index,
          attribute.width,
          attribute.type == varTypeInt ? glInt : glUnsignedInt,
          0,
          0,
        );
      } else {
        _cgl.vertexAttribPointer(
          buffer,
          index,
          attribute.width,
          glFloat,
          false,
          0,
          0,
        );
      }
      _checkBufferError();
    } catch (_) {
      _cleanupAfterFailure([
        if (bindingStarted)
          () {
            final gl = _cgl._gl;
            gl.bindVertexArray(_vao);
            gl.bindBuffer(glArrayBuffer, previous);
            // WebGL permits a null buffer with offset zero to reset a slot.
            if (previous != null && attribute.isInteger) {
              gl.vertexAttribIPointer(
                index,
                attribute.width,
                attribute.type == varTypeInt ? glInt : glUnsignedInt,
                0,
                0,
              );
            } else {
              gl.vertexAttribPointer(
                index,
                previous == null ? 4 : attribute.width,
                glFloat,
                false,
                0,
                0,
              );
            }
            gl.vertexAttribDivisor(
              index,
              previous != null && instanced ? 1 : 0,
            );
            if (previous == null) {
              gl.disableVertexAttribArray(index);
            } else {
              gl.enableVertexAttribArray(index);
            }
          },
        () => _cgl._gl.bindVertexArray(previousVao),
        () => _cgl.bindBuffer(glArrayBuffer, previousArray),
      ]);
      rethrow;
    }
    _buffers[canonical] = buffer;
    if (takeOwnership) _ownedBuffers.add(buffer);
    commitData?.call();
    _releaseUnusedBuffer(previous);
  }

  void _addAttribute(String canonical, List<num> data, int width) {
    _checkNotDisposed();
    final attribute = attributeLayout.attributes[canonical];
    if (attribute == null) {
      throw ArgumentError.value(
        canonical,
        'canonical',
        'Unsupported attribute',
      );
    }
    if (width <= 0 || width != attribute.width || data.length % width != 0) {
      throw ArgumentError('Invalid width or data length for $canonical');
    }
    final instanced = attribute.divisor != 0;
    final uploadData = _uploadData(attribute, data);
    final count = data.length ~/ width;
    if ((instanced && _instances != 0 && count != _instances) ||
        (!instanced &&
            canonical != aPosition &&
            count != _vertices.length ~/ 3)) {
      throw ArgumentError('Wrong number of items for $canonical');
    }
    final positions = canonical == aPosition
        ? (data is Float32List
              ? data
              : Float32List.fromList([
                  for (final value in data) value.toDouble(),
                ]))
        : null;
    final buffer = _cgl.createBuffer();
    bool committed = false;
    try {
      _replaceAttributeBuffer(
        canonical,
        buffer,
        takeOwnership: true,
        upload: () => _cgl.changeArrayBuffer(buffer, uploadData),
        commitData: () {
          _attributes[canonical] = data;
          if (positions != null) _vertices = positions;
          if (instanced && _instances == 0) _instances = count;
          committed = true;
        },
      );
    } catch (_) {
      // An old-buffer deletion failure occurs after commit; keep the new one.
      if (!committed) {
        _cleanupAfterFailure([() => _cgl.deleteBuffer(buffer)]);
      }
      rethrow;
    }
  }

  List<num> _uploadData(VertexAttributeLayout attribute, List<num> data) {
    if (!attribute.isInteger) {
      return data is Float32List
          ? data
          : Float32List.fromList([for (final value in data) value.toDouble()]);
    }
    final signed = attribute.type == varTypeInt;
    for (final value in data) {
      if (value is! int ||
          value < (signed ? -0x80000000 : 0) ||
          value > (signed ? 0x7fffffff : 0xffffffff)) {
        throw ArgumentError(
          'Integer attribute values must fit their 32-bit type',
        );
      }
    }
    if (signed) {
      return data is Int32List ? data : Int32List.fromList(data.cast<int>());
    }
    return data is Uint32List ? data : Uint32List.fromList(data.cast<int>());
  }

  /// Creates and uploads a replacement, then releases the old owned buffer
  /// when no other slot needs it. Failed preparation leaves CPU/GPU data intact.
  void addAttribute(String canonical, List<num> data, int width) {
    _addAttribute(canonical, data, width);
  }

  /// Atomically replaces position storage; see [addAttribute].
  void addVertices(Float32List data) {
    _addAttribute(aPosition, data, 3);
  }

  void changeFaces(List<int> faces) {
    _checkNotDisposed();
    if (_vertices.length < 3 * 256) {
      _faces = Uint8List.fromList(faces);
      _indexBufferType = glUnsignedByte;
    } else if (_vertices.length < 3 * 65536) {
      _faces = Uint16List.fromList(faces);
      _indexBufferType = glUnsignedShort;
    } else {
      _faces = Uint32List.fromList(faces);
      _indexBufferType = glUnsignedInt;
    }

    _cgl.bindVertexArray(_vao!);
    _cgl.changeElementArrayBuffer(_indexBuffer!, _faces as TypedData);
  }

  /// Uploads new index storage before releasing the previous owned buffer.
  void addFaces(List<int> faces) {
    _checkNotDisposed();
    final List<int> data;
    final int type;
    if (_vertices.length < 3 * 256) {
      data = Uint8List.fromList(faces);
      type = glUnsignedByte;
    } else if (_vertices.length < 3 * 65536) {
      data = Uint16List.fromList(faces);
      type = glUnsignedShort;
    } else {
      data = Uint32List.fromList(faces);
      type = glUnsignedInt;
    }
    final previous = _indexBuffer;
    final previousVao =
        _cgl.getParameter(glVertexArrayBinding) as GlVertexArrayObject?;
    final buffer = _cgl.createBuffer();
    try {
      _cgl.bindVertexArray(_vao!);
      _cgl.changeElementArrayBuffer(buffer, data as TypedData);
      _checkBufferError();
    } catch (_) {
      _cleanupAfterFailure([
        () => _cgl._gl.bindVertexArray(_vao),
        () => _cgl.bindBuffer(glElementArrayBuffer, previous),
        () => _cgl._gl.bindVertexArray(previousVao),
        () => _cgl.deleteBuffer(buffer),
      ]);
      rethrow;
    }
    _indexBuffer = buffer;
    _ownedBuffers.add(buffer);
    _faces = data;
    _indexBufferType = type;
    _releaseUnusedBuffer(previous);
  }

  void activate() {
    _checkNotDisposed();
    _cgl.bindVertexArray(_vao!);
  }

  Iterable<String> getAttributes() {
    _checkNotDisposed();
    return _attributes.keys;
  }

  @override
  String toString() {
    int nf = _faces == null ? 0 : _faces!.length;
    List<String> lst = ["Faces:$nf"];
    for (String c in _attributes.keys) {
      lst.add("$c:${_attributes[c]!.length}");
    }

    return "MESH[$name] ${lst.join("  ")}";
  }
}

/// Compatibility spelling for [GpuMesh].
typedef MeshData = GpuMesh;

void _geometryBuilderAttributesToMeshData(GeometryBuilder gb, MeshData md) {
  for (String canonical in gb.attributes.keys) {
    if (!md.supportsAttribute(canonical)) {
      logInfo("Dropping unnecessary attribute: $canonical");
      continue;
    }
    List<Object> lst = gb.attributes[canonical]!;
    final type = md.attributeLayout.attributes[canonical]!.type;

    //print("${md.name} ${canonical} ${lst}");
    switch (type) {
      case varTypeVec2:
        md.addAttribute(
          canonical,
          flattenVector2List(lst as List<vm.Vector2>),
          2,
        );
        break;
      case varTypeVec3:
        md.addAttribute(
          canonical,
          flattenVector3List(lst as List<vm.Vector3>),
          3,
        );
        break;
      case varTypeVec4:
        md.addAttribute(
          canonical,
          flattenVector4List(lst as List<vm.Vector4>),
          4,
        );
        break;
      case varTypeFloat:
        md.addAttribute(
          canonical,
          Float32List.fromList(lst as List<double>),
          1,
        );
        break;
      case varTypeUvec4:
        md.addAttribute(canonical, flattenUvec4List(lst as List<List<int>>), 4);
        break;
      default:
        throw ArgumentError('Unsupported geometry attribute $canonical: $type');
    }
  }
}

/// Validates CPU geometry, uploads independent storage and returns an owned mesh.
///
/// The caller must dispose the result. Failed uploads release partial GPU
/// storage without changing the builder or replacing the original exception.
GpuMesh uploadGeometry(String name, RenderProgram prog, GeometryBuilder gb) {
  prog._checkNotDisposed();
  gb.validate();
  final DateTime start = DateTime.now();
  final md = prog.makeGpuMesh(name, gb.pointsOnly ? glPoints : glTriangles);
  try {
    md.addVertices(flattenVector3List(gb.vertices));
    if (!gb.pointsOnly) md.addFaces(gb.generateFaceIndices());
    _geometryBuilderAttributesToMeshData(gb, md);
  } catch (_) {
    _cleanupAfterFailure([md.dispose]);
    rethrow;
  }
  final Duration delta = DateTime.now().difference(start);
  logInfo("GeometryBuilderToMeshData took ($delta) $md");
  return md;
}

/// Compatibility wrapper for [uploadGeometry].
MeshData geometryBuilderToMeshData(
  String name,
  RenderProgram prog,
  GeometryBuilder gb,
) => uploadGeometry(name, prog, gb);

MeshData _extractWireframeNormals(
  MeshData out,
  List<double> vertices,
  List<double> normals,
  double scale,
) {
  assert(vertices.length == normals.length);
  Float32List v = Float32List(2 * vertices.length);
  for (int i = 0; i < vertices.length; i += 3) {
    v[2 * i + 0] = vertices[i + 0];
    v[2 * i + 1] = vertices[i + 1];
    v[2 * i + 2] = vertices[i + 2];
    v[2 * i + 3] = vertices[i + 0] + scale * normals[i + 0];
    v[2 * i + 4] = vertices[i + 1] + scale * normals[i + 1];
    v[2 * i + 5] = vertices[i + 2] + scale * normals[i + 2];
  }
  out.addVertices(v);

  final int n = 2 * vertices.length ~/ 3;
  List<int> lines = List.generate(n, (i) => i);

  out.addFaces(lines);
  return out;
}

MeshData geometryBuilderToWireframeNormals(
  RenderProgram prog,
  GeometryBuilder gb, [
  double scale = 1.0,
]) {
  MeshData out = prog.makeMeshData("norm", glLines);
  return _extractWireframeNormals(
    out,
    flattenVector3List(gb.vertices),
    flattenVector3List(gb.attributes[aNormal] as List<vm.Vector3>),
    scale,
  );
}

/// Uploads CPU geometry edges as an owned GPU mesh of lines.
GpuMesh uploadWireframeGeometry(
  String name,
  RenderProgram prog,
  GeometryBuilder gb,
) {
  prog._checkNotDisposed();
  gb.validate();
  final md = prog.makeGpuMesh(name, glLines);
  try {
    md.addVertices(flattenVector3List(gb.vertices));
    md.addFaces(gb.generateLineIndices());
    _geometryBuilderAttributesToMeshData(gb, md);
  } catch (_) {
    _cleanupAfterFailure([md.dispose]);
    rethrow;
  }
  return md;
}

/// Compatibility wrapper for [uploadWireframeGeometry].
MeshData geometryBuilderToMeshDataWireframe(
  String name,
  RenderProgram prog,
  GeometryBuilder gb,
) => uploadWireframeGeometry(name, prog, gb);

MeshData lineEndPointsToMeshData(
  String name,
  RenderProgram prog,
  List<vm.Vector3> points,
) {
  MeshData md = prog.makeMeshData(name, glLines);
  md.addVertices(flattenVector3List(points));
  List<int> faces = List.generate(points.length, (i) => i);
  md.addFaces(faces);
  return md;
}

MeshData extractWireframeNormals(
  RenderProgram prog,
  MeshData md, [
  double scale = 1.0,
]) {
  prog._checkNotDisposed();
  md._checkNotDisposed();
  assert(md._drawMode == glTriangles, "expected GL_TRIANGLES");
  final Float32List vertices = md.getAttribute(aPosition) as Float32List;
  final Float32List normals = md.getAttribute(aNormal) as Float32List;
  MeshData out = prog.makeMeshData(md.name, glLines);
  return _extractWireframeNormals(out, vertices, normals, scale);
}

MeshData extractWireframe(RenderProgram prog, MeshData md) {
  prog._checkNotDisposed();
  md._checkNotDisposed();
  assert(false);
  assert(md._drawMode == glTriangles);
  MeshData out = prog.makeMeshData(md.name, glLines);
  out.addVertices(md._vertices);
  final List<int> faces = md._faces!;
  // Probably wrong
  List<int> lines = List.generate(faces.length * 2, (i) => i);
  for (int i = 0; i < faces.length; i += 3) {
    lines[i * 2 + 0] = faces[i + 0];
    lines[i * 2 + 1] = faces[i + 1];
    lines[i * 2 + 2] = faces[i + 1];
    lines[i * 2 + 3] = faces[i + 2];
    lines[i * 2 + 4] = faces[i + 2];
    lines[i * 2 + 5] = faces[i + 0];
  }

  out.addFaces(lines);
  return out;
}

List<double> _getMeshFaceAreas(List<int> faces, Float32List verts) {
  vm.Vector3 v0 = vm.Vector3.zero();
  vm.Vector3 v1 = vm.Vector3.zero();
  vm.Vector3 v2 = vm.Vector3.zero();
  var areas = List<double>.filled(faces.length ~/ 3, 0.0);
  for (int f = 0; f < areas.length; ++f) {
    int i0 = faces[3 * f + 0];
    int i1 = faces[3 * f + 1];
    int i2 = faces[3 * f + 2];
    //
    v0.setValues(verts[3 * i0], verts[3 * i0 + 1], verts[3 * i0 + 2]);
    v1.setValues(verts[3 * i1], verts[3 * i1 + 1], verts[3 * i1 + 2]);
    v2.setValues(verts[3 * i2], verts[3 * i2 + 1], verts[3 * i2 + 2]);
    v1.sub(v0);
    v2.sub(v0);
    v1.crossInto(v2, v0);
    areas[f] = v0.length;
  }

  return areas;
}

double getMeshFaceArea(MeshData md) {
  md._checkNotDisposed();
  List<double> areas = _getMeshFaceAreas(md._faces!, md._vertices);
  double totalArea = 0.0;
  for (var d in areas) {
    totalArea += d;
  }
  return totalArea;
}

MeshData extractPointCloud(
  RenderProgram prog,
  MeshData md,
  int numPoints, {
  bool extractNormal = true,
  bool extractColor = false,
}) {
  prog._checkNotDisposed();
  md._checkNotDisposed();
  assert(md._drawMode == glTriangles, "expected GL_TRIANGLES");
  if (extractNormal) {
    assert(md.supportsAttribute(aNormal), "expected support for aNormal");
  }
  if (extractColor) {
    assert(md.supportsAttribute(aColor), "expected support for aColor");
  }
  final List<int> faces = md._faces!;
  final Float32List verts = md._vertices;
  final Float32List norms = extractNormal
      ? md.getAttribute(aNormal) as Float32List
      : Float32List(0);
  if (extractNormal) {
    assert(norms.length == verts.length);
  }
  final Float32List cols = extractColor
      ? md.getAttribute(aColor) as Float32List
      : Float32List(0);
  if (extractColor) {
    assert(cols.length == verts.length);
  }

  vm.Vector3 v0 = vm.Vector3.zero();
  vm.Vector3 v1 = vm.Vector3.zero();
  vm.Vector3 v2 = vm.Vector3.zero();
  vm.Vector3 n0 = vm.Vector3.zero();
  vm.Vector3 n1 = vm.Vector3.zero();
  vm.Vector3 n2 = vm.Vector3.zero();
  vm.Vector3 c0 = vm.Vector3.zero();
  vm.Vector3 c1 = vm.Vector3.zero();
  vm.Vector3 c2 = vm.Vector3.zero();

  void getVertsForFace(int f) {
    int i0 = faces[3 * f + 0];
    int i1 = faces[3 * f + 1];
    int i2 = faces[3 * f + 2];
    //
    v0.setValues(verts[3 * i0], verts[3 * i0 + 1], verts[3 * i0 + 2]);
    v1.setValues(verts[3 * i1], verts[3 * i1 + 1], verts[3 * i1 + 2]);
    v2.setValues(verts[3 * i2], verts[3 * i2 + 1], verts[3 * i2 + 2]);
    //
    if (extractNormal) {
      n0.setValues(norms[3 * i0], norms[3 * i0 + 1], norms[3 * i0 + 2]);
      n1.setValues(norms[3 * i1], norms[3 * i1 + 1], norms[3 * i1 + 2]);
      n2.setValues(norms[3 * i2], norms[3 * i2 + 1], norms[3 * i2 + 2]);
    }
    if (extractColor) {
      c0.setValues(cols[3 * i0], cols[3 * i0 + 1], cols[3 * i0 + 2]);
      c1.setValues(cols[3 * i1], cols[3 * i1 + 1], cols[3 * i1 + 2]);
      c2.setValues(cols[3 * i2], cols[3 * i2 + 1], cols[3 * i2 + 2]);
    }
  }

  List<double> areas = _getMeshFaceAreas(faces, verts);
  double totalArea = 0.0;
  for (var d in areas) {
    totalArea += d;
  }
  print(
    "vertices: ${md._vertices.length ~/ 3}  faces: ${faces.length}  total: $totalArea",
  );
  final double areaPerPoint = totalArea / numPoints;
  double ceiling = 0.0;
  int currentFace = 0;
  ceiling += areas[currentFace];
  getVertsForFace(currentFace);

  var rng = math.Random();
  Float32List sampledVerts = Float32List(3 * numPoints);
  Float32List sampledNorms = Float32List(3 * numPoints);
  Float32List sampledCols = Float32List(3 * numPoints);

  for (int i = 0; i < numPoints; ++i) {
    double x = i * areaPerPoint;
    while (x > ceiling) {
      ++currentFace;
      ceiling += areas[currentFace];
      getVertsForFace(currentFace);
    }
    // https://chrischoy.github.io/research/barycentric-coordinate-for-mesh-sampling/
    // Random sampling is easy but not really what we want.
    // We want uniform covering
    double sqrtU = math.sqrt(rng.nextDouble());
    double v = rng.nextDouble();

    double a = 1 - sqrtU;
    double b = sqrtU - sqrtU * v;
    double c = sqrtU * v;
    sampledVerts[3 * i + 0] = a * v0.x + b * v1.x + c * v2.x;
    sampledVerts[3 * i + 1] = a * v0.y + b * v1.y + c * v2.y;
    sampledVerts[3 * i + 2] = a * v0.z + b * v1.z + c * v2.z;
    //
    if (extractNormal) {
      sampledNorms[3 * i + 0] = a * n0.x + b * n1.x + c * n2.x;
      sampledNorms[3 * i + 1] = a * n0.y + b * n1.y + c * n2.y;
      sampledNorms[3 * i + 2] = a * n0.z + b * n1.z + c * n2.z;
    }
    if (extractColor) {
      sampledCols[3 * i + 0] = a * c0.r + b * c1.r + c * c2.r;
      sampledCols[3 * i + 1] = a * c0.g + b * c1.g + c * c2.g;
      sampledCols[3 * i + 2] = a * c0.b + b * c1.b + c * c2.b;
    }
  }
  MeshData out = prog.makeMeshData(md.name, glPoints);
  out.addVertices(sampledVerts);
  if (extractNormal) {
    out.addAttribute(aNormal, sampledNorms, 3);
  }
  if (extractColor) {
    out.addAttribute(aColor, sampledCols, 3);
  }
  return out;
}
