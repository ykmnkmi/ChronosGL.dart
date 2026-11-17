# Changelog

## 5.0.0 (unreleased)

This release migrates ChronosGL to `package:web` and introduces source-breaking
API changes. See [MIGRATION.md](MIGRATION.md) before upgrading from 4.x.

### Breaking changes

- Rename functions, methods, fields, constants, parameters, and named
  constructors to lowerCamelCase. The previous names have been removed.
- Replace the core `dart:web_gl` bindings with `package:web` types. The `Gl*`
  aliases now refer to those types, and `getExtension` returns `JSObject?`.
- Return `package:web` elements from image, video, camera, and canvas helpers.
  Update explicitly typed variables and callbacks in consuming applications.
- Require Dart 3.14.0 or later within Dart 3, with `vector_math: ^2.4.4` and
  `web: ^1.1.2`.

### Transform component

- Add browser-independent `Transform` through `core.dart` and `chronosgl.dart`,
  with local-to-parent TRS semantics, explicit movement/rotation spaces,
  position-preserving `lookAt`, copied state, and lossless affine matrix import.
- Document the transition from `Spatial` and the explicit bridge to legacy
  nodes; the legacy camera-position correction is described below.

### Camera contract

- Add browser-independent `Camera`, `PerspectiveCamera`, and `OrthographicCamera`
  through `camera.dart` and `chronosgl.dart`, with a shared world-space pose,
  inverse view matrix, position-preserving `lookAt`, and snapshot getters.
- Add named projection parameters and atomic validation, including explicit
  orthographic bounds with zero or negative near distances.

### Reusable projections

- Add immutable, browser-independent `Projection`, `PerspectiveProjection`, and
  `OrthographicProjection` through `camera.dart` and `chronosgl.dart`, with matrix
  snapshots and explicit copies into caller-owned storage.
- Delegate camera projection math to these values, preserving existing setters
  and adding `fromProjection` constructors for safe sharing across cameras.
- Reuse the same projection math for directional and spot-light shadows;
  invalid shadow projection parameters now throw `ArgumentError`.

### Camera pose storage

- Store camera position and normalized orientation as authoritative components,
  deriving world and view matrices without feeding matrix results back into pose.
- Share stateless validation and `lookAt` orientation math with `Transform`.
  Preserve the public camera API; add regression coverage
  for interleaved edits, snapshot ownership, and recovery after view overflow.

### Camera view matrix

- Verify and document `viewMatrix = inverse(worldMatrix)` for both camera types,
  including inverse rotation of the eye translation, points and directions,
  two-sided matrix inverses, and independence from projection changes.
- Add regression tests with an independent axis-angle reference; retain the
  existing inversion implementation and Float32 overflow behavior.

### Camera position correction

- Fix legacy `Spatial.lookAt` overwriting the world position with view
  translation. Store a pose consistently and derive its inverse for rendering;
  preserve the eye across repeated aiming, movement, and orbit roll.
- Supply world-space `uEyePosition` from both legacy projection adapters.
  Align direction/movement helpers with pose columns and look/roll with local
  axes. Direct users of the old view-valued `transform` must migrate.
- Convert the phase 1.5 reproductions to passing regression tests, add repeated
  aiming checks for both new camera types, and document invalid-input behavior.

### Matrix access and updates

- Define immediate matrix reads and independently owned snapshots, including
  typed storage, for mathematical cameras, transforms, and projections.
- Add `Camera.copyWorldMatrixInto`, `copyViewMatrixInto`,
  `copyProjectionMatrixInto`, and `copyViewProjectionMatrixInto` for reusable
  caller-owned outputs; calculation failures leave the destination unchanged.
- Reject overlapping storage in legacy `Spatial.getViewMatrix`, including
  distinct matrix objects and typed-data views that alias the camera pose.

### Projection parameter contract

- Specify named `fovYRadians`, `aspectRatio`, `near`, and `far` units, defaults,
  and strict ranges for mathematical cameras and reusable projections.
- Verify portrait/landscape frusta, independent parameter changes, signed
  orthographic depth, and Float32 overflow/underflow through constructors and
  camera updates. Rejected updates preserve the projection and entire pose;
  valid updates still work afterward. Retain the existing validation logic.

### Camera uniform adapter

- Add `CameraUniforms(camera, [name])` through `chronosgl.dart` as a
  `UniformGroup` accepted by existing `RenderProgram.draw` and `Scene` calls.
- Read current projection * view and world-space eye position for either camera
  type, returning independent map, matrix, and vector snapshots on each call.
  Camera calculation errors propagate without changing earlier snapshots.
- Keep mathematical imports browser-independent and legacy adapters unchanged.

### VM mathematical imports

- Document `core.dart` and `camera.dart` as the browser-independent entry points
  for transformations, cameras, and projections; retain their existing exports.
- Add a standalone kernel compilation and VM execution regression check that
  exercises both imports without a test framework or browser dependencies.
  Keep `chronosgl.dart` as the browser-facing aggregate.

### VM camera mathematics tests

- Add four regression tests for equivalent quaternion signs and full
  world/NDC projection round trips before and after projection changes.
  Use analytic projection references and a known camera-axis rotation for
  both perspective and orthographic cameras.
- Verify 83 tests across eight selected VM camera/projection suites and
  document coverage of pose, inverses, projections, snapshots, and errors.
  Retain existing mathematical behavior and public APIs.

### Browser camera uniform tests

- Add five WebGL readback tests for all matrix coefficients and world-eye
  coordinates uploaded by `CameraUniforms`, for both camera types.
- Verify pose/projection edits, snapshot independence, separate scene model
  transforms, and alternating adapters on one program in JavaScript and Wasm.
  Retain existing rendering behavior and public APIs.
- Complete the phase 3 camera validation criteria with the selected VM math
  suites, standalone VM import check, and browser uniform checks.

### Browser support and fixes

- Migrate the engine, browser helpers, examples, and browser test harness to
  `package:web` and `dart:js_interop` for JavaScript and Wasm compilation.
- Keep legacy DOM inputs working for JavaScript callers during migration.
- Preserve typed-data views and byte offsets when passing GPU data to WebGL.
- Report HTTP, JSON, image, and video loading failures through returned futures.
- Use `mediaDevices.getUserMedia` for camera capture, and stop the stream if
  video initialization fails.
- Connect the MIDI example after the user selects **Connect MIDI**.

### Development and validation

- Use the Dart CLI directly for local development and selected regression tests.
  Remove Git-aware development orchestration, full-check Make targets, and
  automatic builds of all examples. Keep Make for project-specific tasks.
- Add deterministic WebGL rendering goldens, failure images, and a regression
  self-check using Chrome with SwiftShader.
- Run the VM and JavaScript tests, Wasm browser tests, and regression self-check
  in the Windows CI workflow, using an available Chrome for Testing build.
- Configure Windows sandbox access to the downloaded CI browser.
- Enable strict analysis and recommended Dart lints, and update the example
  build and migration instructions.
