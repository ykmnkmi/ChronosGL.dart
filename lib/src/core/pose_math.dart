import 'package:vector_math/vector_math.dart' as vm;

// Internal, stateless pose operations shared by Transform and Camera. Keeping
// these independent of either owner avoids using a matrix as editable pose state.

void checkFiniteComponents(Iterable<double> values, String name) {
  if (values.any((value) => !value.isFinite)) {
    throw ArgumentError.value(values, name, 'Must contain only finite values');
  }
}

vm.Quaternion normalizedRotation(vm.Quaternion value) {
  checkFiniteComponents(value.storage, 'rotation');
  if (value.length2 == 0) {
    throw ArgumentError.value(value, 'rotation', 'Must be nonzero');
  }
  return vm.Quaternion.copy(value)..normalize();
}

vm.Vector3 unitVector(vm.Vector3 value, String name) {
  checkFiniteComponents(value.storage, name);
  if (value.length2 == 0) {
    throw ArgumentError.value(value, name, 'Must be nonzero');
  }
  return vm.Vector3.copy(value)..normalize();
}

// Returns an orientation mapping local -Z toward target. All inputs share the
// same coordinate space and remain untouched, including on validation failure.
vm.Quaternion lookAtRotation(
  vm.Vector3 position,
  vm.Vector3 target, {
  vm.Vector3? upHint,
}) {
  checkFiniteComponents(target.storage, 'target');
  final forward = unitVector(target - position, 'target - position');
  final hint = unitVector(upHint ?? vm.Vector3(0, 1, 0), 'upHint');
  final right = forward.cross(hint);
  if (right.length <= 1e-6) {
    throw ArgumentError.value(
      upHint,
      'upHint',
      'Must not parallel the view direction',
    );
  }
  right.normalize();
  final up = right.cross(forward);
  final basis = vm.Matrix3.columns(right, up, -forward);
  return vm.Quaternion.fromRotation(basis);
}
