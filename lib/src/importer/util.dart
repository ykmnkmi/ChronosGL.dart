part of 'lib.dart';

// JSON is untyped at the decoding boundary. Check container and numeric types
// before passing values to geometry and animation code.
List<Object?> _jsonList(Object? value) => value as List<Object?>;
Map<String, Object?> _jsonMap(Object? value) => value as Map<String, Object?>;
Iterable<Map<String, Object?>> _jsonObjects(Object? value) =>
    _jsonList(value).cast<Map<String, Object?>>();
Iterable<List<Object?>> _jsonLists(Object? value) =>
    _jsonList(value).cast<List<Object?>>();
double _jsonDouble(Object? value) => (value as num).toDouble();

List<vm.Vector3> convertToVector3List(List<Object?> lst) {
  List<vm.Vector3> out = List.generate(
    lst.length ~/ 3,
    (i) => vm.Vector3(
      _jsonDouble(lst[3 * i + 0]),
      _jsonDouble(lst[3 * i + 1]),
      _jsonDouble(lst[3 * i + 2]),
    ),
  );
  return out;
}

List<vm.Vector2> convertToVector2List(List<Object?> lst) {
  List<vm.Vector2> out = List.generate(
    lst.length ~/ 2,
    (i) => vm.Vector2(_jsonDouble(lst[2 * i + 0]), _jsonDouble(lst[2 * i + 1])),
  );

  return out;
}

List<vm.Vector4> convertToVector4List(int nFill, List<Object?> lst) {
  List<vm.Vector4> out = List.generate(lst.length ~/ nFill, (i) {
    int pos = i * nFill;
    vm.Vector4 v = vm.Vector4.zero();
    for (int x = 0; x < nFill; ++x) {
      v[x] = _jsonDouble(lst[pos + x]);
    }
    return v;
  });
  return out;
}

vm.Vector3 makeVector3(List<Object?> lst) {
  return vm.Vector3(
    _jsonDouble(lst[0]),
    _jsonDouble(lst[1]),
    _jsonDouble(lst[2]),
  );
}

vm.Vector3 makeTransVector3(List<Object?>? lst) {
  if (lst == null) return vm.Vector3.zero();
  return makeVector3(lst);
}

vm.Vector3 makeScaleVector3(List<Object?>? lst) {
  if (lst == null) return vm.Vector3(1.0, 1.0, 1.0);
  return makeVector3(lst);
}

vm.Quaternion makeQuaternion(List<Object?>? lst) {
  if (lst == null) return vm.Quaternion.identity();

  return vm.Quaternion(
    _jsonDouble(lst[0]),
    _jsonDouble(lst[1]),
    _jsonDouble(lst[2]),
    _jsonDouble(lst[3]),
  );
}
