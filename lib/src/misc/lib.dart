/// Compatibility exports for callers migrating from the former misc layer.
///
/// Prefer the public package entry points. Demo particles and shaders now live
/// in example/shared and are deliberately absent from the package API.
library;

export '../../debug.dart';
export '../../mesh.dart';
export '../../shadows.dart';
export '../core/colors.dart';
export '../scene/lib.dart' show FullscreenPass, unitNode;
export '../webhelper/lib.dart'
    show RenderPhaseResizeAware, PerspectiveResizeAware;
