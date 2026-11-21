# Changelog

## 5.0.0 (unreleased)

This release migrates ChronosGL to `package:web` and introduces source-breaking
API changes. It adds VM-compatible camera and transform APIs, separates camera
input and canvas sizing, and makes GPU resource ownership explicit.
See [MIGRATION.md](MIGRATION.md) before upgrading from 4.x.

### Fixes

- Clear framebuffer depth after a fullscreen pass and restore the previous
  depth write mask before drawing the next pass.
- Upload empty indexed geometry and accept attribute lists whose elements
  pass `GeometryBuilder.validate()`. Validate wireframe normals before
  allocating GPU resources and release partial meshes if an upload fails.
- Correct rectangular grid indexing and compute height from the Y length.
  The fix applies to both `gridGeometry` and `shapeGrid`.
- Ignore uniforms optimized out by the shader linker, including inactive
  samplers. Continue reporting missing active inputs.
- Let a primary click focus an orbit-controlled canvas for keyboard input.
- Hold each bone track's final keyframe from its timestamp onward.
- Keep Tunnel Vision running while its fade begins after 180 seconds.

### Examples

- Migrate the complete gallery to mathematical cameras, `CameraUniforms`,
  elapsed-second controls, `CanvasViewport` and supported scene/mesh names.
  Keep orthographic bounds and offscreen attachment sizes explicit.
- Replace light wireframe vertex storage when switching topology, retaining
  buffer reuse for fixed-size updates under the strict mesh contract. Resize
  the transform-feedback example's CPU and GPU particle meshes together.
- Add a standalone minimal cube scene with typed public constructors and
  explicit animation, input, observer and GPU teardown. Register gallery
  resources with a shared example lifetime; stop camera streams, MIDI ports
  and custom input subscriptions when their example ends.
- Migrate rendering fixtures and smoke helpers to supported public imports,
  preserving dedicated legacy compatibility tests. Release fixture GPU
  resources explicitly and cover example teardown, shared resource ownership
  and cancellation, including cleanup errors.
- Preserve all seven rendering references across the JavaScript and Wasm
  fixture migration. The intentional color-regression self-check still detects
  mismatches and produces comparison images; no reference updates are needed.

### Breaking changes

- Rename functions, methods, fields, constants, parameters, and named
  constructors to lowerCamelCase. The previous names have been removed.
- Replace the core `dart:web_gl` bindings with `package:web` types. The `Gl*`
  aliases now refer to those types, and `getExtension` returns `JSObject?`.
- Return `package:web` elements from image, video, camera, and canvas helpers.
  Update explicitly typed variables and callbacks in consuming applications.
- Require Dart 3.14.0 or later within Dart 3, with `vector_math: ^2.4.4` and
  `web: ^1.1.2`.
- Replace mutable palette vectors with immutable `Color` values. Convert with
  `toVector3()` at vector API boundaries. Make texture, blend and stencil
  settings immutable; replace field assignments and texture setter cascades
  with constructors, `copyWith()`, `withFilterNearest()` or `withMipmapLinear()`.
- Move demo particle/star factories and demo shaders to `example/shared/` and
  remove the shared `emptyMaterial`. Replace shadow map visualization methods
  with a separate `ShadowMapVisualizer`.
- Curate supported exports through public modules. Import diagnostics from
  `debug.dart` separately; remove unfinished `MidiInput`, `findBridge` and
  `extractWireframe` from supported exports, together with internal helpers.
- Protect shader interface collections, uniform maps, animation track structure,
  GPU attribute snapshots and the easing registry from external changes that
  bypass their owners. Use explicit mutation methods where provided.
- Replace assertion-only public contracts with runtime checks and string shader
  failures with `ShaderCompilationException`. Invalid arguments, invalid state
  and unsupported operations use distinct typed errors in all build modes.

### Supported public API

- Add `animation.dart`, `importers.dart`, `shaders.dart`, `webgl.dart`,
  `render.dart`, `scene.dart` and `web.dart`. Animation, importer and shader
  descriptions join transforms, cameras and geometry as VM-compatible modules.
- Add explicit `ShaderStage.vertex`/`fragment`, `ShaderObject.create`, `.vertex`
  and `.fragment`; retain deprecated stage inference only for the legacy
  constructor. Built-in shader descriptions use explicit stages.
- Add `UniformKey<T>`, built-in `UniformKeys`, and typed `set`, `force` and `get`
  alongside existing canonical string names and setter calls.
- Add named constructors for programs, scene passes/batches, textures, lights,
  animation and browser integration, with documented units. Add typed browser
  constructors for contexts, input, texture sources and diagnostic panels;
  preserve deprecated Object-based JavaScript compatibility boundaries.
- Add a public module contract and migration table, plus focused VM export,
  runtime contract and browser scene/diagnostic integration coverage.
- Add explicit diagnostic imports to affected examples so removing diagnostics
  from the aggregate preserves example compilation. Deprecate the legacy
  Object-based `OrbitCamera` constructor in favor of a mathematical camera and
  `OrbitControls.forCamera`.
- Reject `GpuMesh.changeFaces` before an index buffer exists, including after
  `clearData()`, with `StateError` before changing mesh data or WebGL bindings.

### Helpers, shadows and diagnostics

- Add documented `mesh.dart` GPU factories and forward all geometry options,
  including the previously ignored `shapeCube.computeNormals`. Keep CPU
  geometry imports independent of browser modules.
- Add `FullscreenPass` with an owned quad, independent default material,
  optional program ownership, failure cleanup and idempotent disposal.
  Keep `unitNode` as a deprecated helper with independent materials.
- Add `shadows.dart` for shadow computation and `debug.dart` for optional
  diagnostics. `ShadowMap` owns and disposes its framebuffer, attachments and
  compute program without creating debug assets.
- Create shadow, light and skeleton visualizer assets lazily and dispose their
  owned meshes, programs and samplers. Shadow visualization uses a separate
  sampler and restores texture bindings on errors; subsequent shadow computes
  clear depth correctly after a fullscreen draw.
- Add `StatsPanel` and `FpsPanel`, retaining `Stats` and `StatsFps` aliases.
  Panels dispose their own DOM wrapper; FPS uses the actual sampling interval.
- Move legacy resize adapters into browser integration and add `dispose()`
  to stop their owned window subscriptions.

### Scene graph and geometry boundaries

- Split the common `Node` contract into `GroupNode` containers and `MeshNode`
  drawables with required, borrowed `mesh` and `material`. Keep the legacy node
  constructors as factories; access drawable resources through `MeshNode`.
- Introduce `RenderBatch` and `RenderPass`, retaining `Scene` and `RenderPhase`
  as aliases. Preserve insertion order and compute world transforms per DAG
  path; detect cycles and recover traversal state after exceptions.
- Copy supplied batch uniform lists and preserve caller lists, groups and
  transform matrices while drawing. Clear selected framebuffer buffers once
  per nonempty enabled pass. Disabled passes and empty viewports skip
  framebuffer work.
- Add browser-independent `geometry.dart` for CPU builders, shape generators,
  and polygon algorithms, with explicit `GeometryBuilder.validate()` checks.
- Omit the normal attribute from `wedgeGeometry(computeNormals: false)` so
  the no-normal result validates and uploads correctly.
- Introduce `GpuMesh`, immutable attribute layouts, `makeGpuMesh`,
  `uploadGeometry`, and `uploadWireframeGeometry`. Preserve `MeshData` and the
  existing upload helpers. Reject context/layout mismatches before drawing;
  validate CPU data before allocation and release partial failed uploads.
- Bind integer vertex attributes with integer pointers and preserve typed
  integer uploads in both JavaScript and Wasm.

### GPU resource lifetimes

- Add repeat-safe disposal for GPU meshes, programs, textures and
  framebuffers. Clean up owned handles when creation fails.
- Track ownership of framebuffer attachments and external mesh attribute
  buffers. Newly supplied external resources are borrowed by default, and
  ownership can be transferred explicitly.
- Add `Framebuffer.replaceAttachments` to validate and install a complete
  attachment configuration. Replacing attachments or mesh buffers releases
  displaced owned resources after the new configuration is installed.

### Cameras, projections and transforms

- Add browser-independent `Transform` through `core.dart` and `chronosgl.dart`,
  with local-to-parent TRS semantics, explicit movement/rotation spaces,
  position-preserving `lookAt`, copied state, and lossless affine matrix import.
- Add browser-independent `Camera`, `PerspectiveCamera`, and `OrthographicCamera`
  through `camera.dart` and `chronosgl.dart`. Both camera types store a world
  position and normalized orientation, derive the view as the inverse world
  matrix, and preserve the eye position when aiming.
- Add immutable, browser-independent `Projection`, `PerspectiveProjection`, and
  `OrthographicProjection` with matrix snapshots and `fromProjection`
  constructors for sharing projection values between cameras.
- Validate named projection parameters and Float32 matrices before updating a
  camera. Orthographic bounds support signed depth distances.
- Reuse the same projection math for directional and spot-light shadows.
  Invalid shadow projection parameters now throw `ArgumentError`.
- Fix legacy `Spatial.lookAt` overwriting the world position with view
  translation. Derive the view from the pose and supply world-space
  `uEyePosition` from both legacy projection adapters. Use pose columns for
  movement and local axes for look and roll.
- Return independent matrix snapshots with current values from cameras,
  transforms and projections.
- Add `Camera.copyWorldMatrixInto`, `copyViewMatrixInto`,
  `copyProjectionMatrixInto`, and `copyViewProjectionMatrixInto` for reusable
  caller-owned outputs. Calculation failures leave the destination unchanged.
- Reject overlapping storage in legacy `Spatial.getViewMatrix`, including
  distinct matrix objects and typed-data views that alias the camera pose.
- Add `CameraUniforms(camera, [name])` for `RenderProgram.draw` and
  `RenderBatch`. It returns the current projection-times-view matrix and
  world-space eye position in independent snapshots.
- Cover camera invariants, projection round trips and standalone mathematical
  imports on the VM. Verify camera uniform uploads for both camera types
  in JavaScript and Wasm, including alternating adapters on one program.

### Browser controls and compatibility

- Add `OrbitControls` for a supplied mathematical camera and explicit browser
  event target, with frame-independent `update(deltaSeconds)`, accumulated drag
  and wheel input, enable/disable, and idempotent disposal.
- Add `CanvasViewport` to coordinate element content size, pixel density,
  drawing buffer, viewport and perspective aspect. Support partial viewports,
  hidden-element recovery and observer cleanup while preserving orthographic
  bounds.
- Test equal-time movement across different frame rates. Legacy orbit and
  resize helpers remain available as deprecated adapters.
- Add `dispose()` to keyboard and mouse helpers to cancel their subscriptions.
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
  Remove Git-aware development orchestration. Make's `presubmit` still runs
  `tests` and `buildall`.
- Add deterministic WebGL rendering goldens, failure images, and a regression
  self-check using Chrome with SwiftShader.
- Run analysis, VM and JavaScript tests, Wasm browser tests, and the golden
  self-check in CI. Build the full example gallery for release.
- Configure Windows sandbox access to the downloaded CI browser.
- Enable strict analysis and recommended Dart lints.
- Maintain the public module and ownership guide alongside the API reference
  generated by `dart doc`. Document camera pose, matrix snapshots and legacy DOM
  compatibility in the migration guide.
