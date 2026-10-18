part of importer;

// JSON is untyped at the decoding boundary. Check container and numeric types
// before passing values to geometry and animation code.
List<Object?> _JsonList(Object? value) => value as List<Object?>;
Map<String, Object?> _JsonMap(Object? value) => value as Map<String, Object?>;
Iterable<Map<String, Object?>> _JsonObjects(Object? value) =>
    _JsonList(value).cast<Map<String, Object?>>();
Iterable<List<Object?>> _JsonLists(Object? value) =>
    _JsonList(value).cast<List<Object?>>();
double _JsonDouble(Object? value) => (value as num).toDouble();

List<VM.Vector3> ConvertToVector3List(List<Object?> lst) {
  List<VM.Vector3> out = List.generate(
    lst.length ~/ 3,
    (i) => VM.Vector3(
      _JsonDouble(lst[3 * i + 0]),
      _JsonDouble(lst[3 * i + 1]),
      _JsonDouble(lst[3 * i + 2]),
    ),
  );
  return out;
}

List<VM.Vector2> ConvertToVector2List(List<Object?> lst) {
  List<VM.Vector2> out = List.generate(
    lst.length ~/ 2,
    (i) => VM.Vector2(_JsonDouble(lst[2 * i + 0]), _JsonDouble(lst[2 * i + 1])),
  );

  return out;
}

List<VM.Vector4> ConvertToVector4List(int nFill, List<Object?> lst) {
  List<VM.Vector4> out = List.generate(lst.length ~/ nFill, (i) {
    int pos = i * nFill;
    VM.Vector4 v = VM.Vector4.zero();
    for (int x = 0; x < nFill; ++x) {
      v[x] = _JsonDouble(lst[pos + x]);
    }
    return v;
  });
  return out;
}

VM.Vector3 MakeVector3(List<Object?> lst) {
  return VM.Vector3(
    _JsonDouble(lst[0]),
    _JsonDouble(lst[1]),
    _JsonDouble(lst[2]),
  );
}

VM.Vector3 MakeTransVector3(List<Object?>? lst) {
  if (lst == null) return VM.Vector3.zero();
  return MakeVector3(lst);
}

VM.Vector3 MakeScaleVector3(List<Object?>? lst) {
  if (lst == null) return VM.Vector3(1.0, 1.0, 1.0);
  return MakeVector3(lst);
}

VM.Quaternion MakeQuaternion(List<Object?>? lst) {
  if (lst == null) return VM.Quaternion.identity();

  return VM.Quaternion(
    _JsonDouble(lst[0]),
    _JsonDouble(lst[1]),
    _JsonDouble(lst[2]),
    _JsonDouble(lst[3]),
  );
}
