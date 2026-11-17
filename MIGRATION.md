# Migrating to ChronosGL 5.0.0

Version 5.0.0 changes API names and browser types. Use Dart 3.14.0 or later
within Dart 3, then update the dependencies in your application:

```yaml
dependencies:
  chronosgl: ^5.0.0
  vector_math: ^2.4.4
  web: ^1.1.2
```

Declare `vector_math` and `web` directly when your application imports them.
Run `dart pub get` and `dart analyze` after updating names and imports. For Wasm,
replace all legacy SDK browser imports in your application as well as upgrading
ChronosGL; legacy DOM compatibility is available only for JavaScript builds.

## Projection parameters (refactoring step 3.8)

Mathematical perspective cameras and projections use named `fovYRadians`,
`aspectRatio`, `near`, and `far`. The full vertical angle is in radians (default
`50 * pi / 180`); aspect is width / height (default `1`). Near and far are
required. All values must be finite, with `0 < fovYRadians < pi`,
`aspectRatio > 0`, and `0 < near < far`. Orthographic types require all six
ordered bounds and permit zero or negative near/far distances.

The API introduced in steps 3.2–3.3 is unchanged. `setProjection` requires all
named parameters, including unchanged values obtained from getters. Invalid
ranges and nonfinite/singular Float32 matrices throw `ArgumentError` while
preserving the previous projection object, parameters, matrices, and pose.
Legacy `Perspective.updateFov` still takes degrees. See the
[parameter contract and update example](docs/3.8_PROJECTION_PARAMETERS.md).

## Matrix access and updates (refactoring step 3.7)

Mathematical `Camera`, `Transform`, and `Projection` getters return independent
snapshots, including their typed storage. Setters take effect on the next read
without `update()`. Existing snapshots do not refresh automatically. Use camera
setters to edit the pose/projection, and `Transform.setMatrix(editedSnapshot)`
to commit a matrix edit; mutating a getter result only changes that snapshot.

To reuse output storage, cameras now provide `copyWorldMatrixInto(out)`,
`copyViewMatrixInto(out)`, `copyProjectionMatrixInto(out)`, and
`copyViewProjectionMatrixInto(out)`. They never retain the destination;
calculation failures leave it unchanged. The existing `copyMatrixInto(out)`
methods on transforms and projections follow the same ownership convention.

Legacy `Spatial.transform` remains live mutable state. Its `getViewMatrix(out)`
now rejects any output storage overlapping that pose, including a different
`Matrix4` wrapping the same list or buffer. Use a separate matrix for the view.
Legacy scratch vectors and uniform maps remain borrowed working values; copy
them explicitly when retaining them. See [the matrix access contract](docs/3.7_MATRIX_ACCESS.md).

## Transform component (refactoring step 3.1)

`package:chronosgl/core.dart` now exports the browser-independent `Transform`.
It is also available through `chronosgl.dart`. Its matrix always maps local
coordinates to parent coordinates, composed as translation * rotation * scale.
Inputs are copied and getters return snapshots; use setters or `setMatrix`
to change state. `lookAt` preserves position and scale and points local -Z
toward a target in parent space.

For a legacy object node, keep a `Transform` and call
`pose.copyMatrixInto(node.transform)` after changes and before drawing.
Do not copy a view matrix as an object pose. Since step 3.6, legacy
`Spatial.transform` also stores a pose; see the camera-position migration below.
See [the Transform contract and migration table](docs/3.1_TRANSFORM.md), including
explicit movement spaces and preservation of imported shear.

## Camera contract (refactoring step 3.2)

`package:chronosgl/camera.dart` exports the browser-independent `Camera`,
`PerspectiveCamera`, and `OrthographicCamera`; the same types are available
through `chronosgl.dart`. Both cameras own a world-space position and rotation.
`lookAt` preserves position, `viewMatrix` is the inverse world matrix, and
`viewProjectionMatrix` is `projectionMatrix * viewMatrix`. Getters return copies.

```dart
import 'package:chronosgl/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;

final camera = PerspectiveCamera(near: 0.1, far: 1000, aspectRatio: 16 / 9)
  ..setPosition(0, 0, 10);
camera.lookAt(vm.Vector3.zero()); // World position remains (0, 0, 10).
```

Use `fovYRadians` for the full vertical angle; the default is 50 degrees expressed
in radians. Orthographic cameras require all six bounds explicitly and allow
zero or negative `near`. Use `setProjection` with all named parameters to change
the projection atomically. Neither camera observes canvas size or handles input.

These mathematical types are separate from legacy `Perspective(Spatial, ...)`
and `Orthographic(Spatial, ...)`. Use `CameraUniforms(camera)` from
`chronosgl.dart` to pass either new camera to rendering uniform lists. See
[the camera contract](docs/3.2_CAMERAS.md) for parameters and ownership, and
the adapter example below for rendering.

## Reusable projections (refactoring step 3.3)

`camera.dart` and `chronosgl.dart` now export `Projection`,
`PerspectiveProjection`, and `OrthographicProjection`. These immutable values
calculate view-to-clip matrices without a camera, uniforms, DOM, or GPU resources.
`matrix` returns a snapshot; `copyMatrixInto(out)` writes into caller-owned storage.
The parameters and validation match the corresponding cameras.

Existing camera constructors and `setProjection(...)` calls continue to work.
Use `PerspectiveCamera.fromProjection(projection, ...)` or
`OrthographicCamera.fromProjection(projection, ...)` to reuse an existing value.
The camera's `projection` getter returns that immutable value; `setProjection`
replaces it atomically without changing other cameras that share the old value.

For shadows, compose `projection.matrix..multiply(lightViewMatrix)` and pass
the result to `ShadowMap.compute`. Directional and spot lights now use these
projection classes internally, preserving their valid shadow matrices and cone
padding. Invalid shadow bounds, FOV, or clipping distances now throw
`ArgumentError` when `extractShadowProjViewMatrix()` is called. Legacy uniform
adapters and resize helpers keep their APIs. See [the projection contract and
shadow example](docs/3.3_PROJECTIONS.md).

## Camera pose storage (refactoring step 3.4)

The new cameras now store world position and normalized orientation directly.
World and view matrices are derived snapshots; reading them never changes the
pose. No calling-code changes are required. `lookAt` sets orientation once and
does not retain a target: moving afterwards preserves that orientation until
another orientation update.

Invalid pose edits leave both components intact. A view calculation that throws
`StateError` for Float32 overflow also leaves the pose readable and editable.
The legacy camera-position correction is described in step 3.6 below. See
[the pose storage contract](docs/3.4_CAMERA_POSE.md) for details and tests.

## Camera view matrix (refactoring step 3.5)

No calling-code changes are needed: the existing new-camera implementation
already computes `viewMatrix = inverse(worldMatrix)`. For `C = T(eye) * R`,
the view is `R^-1 * T(-eye)`, so a world point becomes `R^-1 * (point - eye)`.
View translation is `-R^-1 * eye`; use `worldPosition` to read the eye position.
Directions (homogeneous `w = 0`) receive only the inverse rotation.

Both camera types use the same calculation, independently of their projections.
The phase adds dedicated inverse-matrix regression coverage without changing
legacy cameras or uniforms. See [the view matrix contract](docs/3.5_VIEW_MATRIX.md).

## Preserved camera position (refactoring step 3.6)

`Spatial.lookAt(target, [up])` now preserves position and stores a local-to-parent
pose, or camera-to-world pose for an unparented camera. `getViewMatrix(out)`
computes its inverse into separate storage. `getPos()` and `getEyePosition()`
therefore return `(0, 0, 10)` after `setPos(0, 0, 10)` and `lookAt(Vector3.zero())`.
Repeated aiming and subsequent movement use the preserved position.

Both `Perspective` and `Orthographic` supply world-space `uEyePosition` alongside
`uPerspectiveViewMatrix = P * V`. Custom `Spatial` subclasses overriding
`getViewMatrix` and `getEyePosition` remain supported. The new mathematical
cameras keep their existing API and use `CameraUniforms` for rendering (3.9).

This corrects legacy behavior and may change existing scenes:

- Read the view through `getViewMatrix(out)`, not `transform`. When importing a
  precomputed view matrix, invert it before copying into `transform`.
- Direction getters and movement now use pose columns. `lookUp/Down`,
  `lookLeft/Right`, and `rollLeft/Right` rotate around local X, Y, and Z;
  up/left rotations use positive angles. Orbit roll preserves its target.
- A node's `lookAt` takes its target and up in parent space and preserves its
  local position. As before, this legacy operation discards scale/shear;
  use `Transform` to retain supported scale.
- Invalid `lookAt` arguments throw `ArgumentError` before changing the pose.
  A singular or nonfinite view inverse throws `StateError` without changing the
  output. Passing `transform` itself as view output throws `ArgumentError`.

Legacy matrices and scratch vectors remain mutable. Use copies when retaining
them; new cameras return snapshots. Camera parenting is not supported by this
legacy view API. See [the correction and regression tests](docs/3.6_CAMERA_POSITION.md).

## Camera uniforms (refactoring step 3.9)

Import `package:chronosgl/chronosgl.dart` in browser rendering code and wrap
either mathematical camera in `CameraUniforms(camera, [name])`:

```dart
final camera = PerspectiveCamera(near: 0.1, far: 1000)
  ..setPosition(0, 0, 10);
camera.lookAt(vm.Vector3.zero());
final uniforms = CameraUniforms(camera);
program.draw(mesh, [uniforms, material, transforms]);
// The same adapter can be passed to Scene('scene', program, [uniforms]).
```

The adapter borrows the camera and reads it on every draw; changing its pose or
projection needs no adapter update. `getUniforms()` returns a fresh map with
independent `uPerspectiveViewMatrix = P * V` and world-space `uEyePosition`
snapshots. The matrix name also applies to orthographic cameras. Supply object
transforms separately as before. Camera values override inherited uniform
setters; additional uniforms retain existing `UniformGroup` semantics.

`CameraUniforms` belongs to rendering and is not exported by `camera.dart` or
`core.dart`. Those mathematical entry points remain usable on the Dart VM.
Existing `Perspective`/`Orthographic` integrations can keep their APIs.
See [the adapter contract and tests](docs/3.9_CAMERA_UNIFORMS.md).

## Mathematical imports on the VM (refactoring step 3.10)

For command-line tools and VM tests, import the mathematical entry points:

```dart
import 'package:chronosgl/core.dart';
import 'package:chronosgl/camera.dart';
```

`core.dart` exports `Transform`; `camera.dart` exports the camera and projection
contracts and both perspective/orthographic implementations. Their transitive
dependencies contain no DOM, WebGL, or rendering adapters. The existing exports
and mathematical behavior are unchanged.

Replace the aggregate `chronosgl.dart` import in mathematical VM code with these
imports. The aggregate remains the browser entry point and includes
`CameraUniforms`, WebGL resources, scenes, and browser helpers. The internal
`src/core/lib.dart` is also browser-dependent; its name does not make it the
public mathematical core. Other CPU modules are separated in later phases.

A standalone kernel compilation and execution check now protects this boundary.
See [the import contract and VM example](docs/3.10_VM_MATH_IMPORTS.md).

## API naming changes

Functions, methods, fields, parameters, variables, and named constructors now
use lowerCamelCase. Import prefixes use lowercase names. Classes and typedefs
retain UpperCamelCase. These are source-breaking API changes; update references
in consuming projects. The previous names have been removed.

## Functions, methods, and constructors

| Previous name | Current name |
| --- | --- |
| `LogInfo` | `logInfo` |
| `CubeGeometry` | `cubeGeometry` |
| `GeometryBuilderToMeshData` | `geometryBuilderToMeshData` |
| `ImportGeometryFromWavefront` | `importGeometryFromWavefront` |
| `LoadJson` | `loadJson` |
| `GeometryBuilder.AddVertices` | `GeometryBuilder.addVertices` |
| `GeometryBuilder.GenerateFaceIndices` | `GeometryBuilder.generateFaceIndices` |
| `UniformGroup.SetUniform` | `UniformGroup.setUniform` |
| `UniformGroup.GetUniforms` | `UniformGroup.getUniforms` |
| `RenderProgram.Draw` | `RenderProgram.draw` |
| `RenderPhase.Draw` | `RenderPhase.draw` |
| `Node.UpdateModelMatrix` | `Node.updateModelMatrix` |
| `Node.Container` | `Node.container` |
| `Material.Transparent` | `Material.transparent` |
| `Material.Empty` | `Material.empty` |
| `Framebuffer.Screen` | `Framebuffer.screen` |
| `Framebuffer.Effect` | `Framebuffer.effect` |
| `Framebuffer.Default` | `Framebuffer.defaultFramebuffer` |
| `TypedTextureMutable.UpdateContent` | `TypedTextureMutable.updateContent` |
| `TextureProperties.SetFilterNearest` | `TextureProperties.setFilterNearest` |
| `Utils.MakeStarMesh` | `Utils.makeStarMesh` |
| `Keyboard.AfterFrameCleanup` | `Keyboard.afterFrameCleanup` |

Leading underscores on private declarations remain in place, for example
`_JsonDouble` becomes `_jsonDouble`. Parameters such as `num_points` become
`numPoints`; update named arguments as well as references in function bodies.
Named constructors retain their class name, as in `Node.container`.

`Framebuffer.Default` uses `defaultFramebuffer` because `default` is a Dart
keyword. The game example's `Sprite.Break` is now `Sprite.brake`, since `break`
is also a keyword.

## Variables and import prefixes

| Previous name | Current name |
| --- | --- |
| `ColorWhite` | `colorWhite` |
| `BlendEquationMix` | `blendEquationMix` |
| `TexturePropertiesFramebuffer` | `texturePropertiesFramebuffer` |
| `ColorFunctions` | `colorFunctions` |
| `RIGHTX`, `UPY`, `POSZ` | `rightX`, `upY`, `posZ` |
| `VM` | `vm` |
| `Math`, `MATH` | `math` |
| `DATA` | `data` |

Replace `dart:html` and `dart:web_gl` imports with
`import 'package:web/web.dart' as web;`. For example, `HTML.CanvasElement`
becomes `web.HTMLCanvasElement`. The `web` prefix also avoids a naming conflict
with ChronosGL's `Node`. Import `dart:js_interop` for callback and promise
conversions instead of using the old `dart:js` or `dart:js_util` APIs.

## Constants

Constants now use lowerCamelCase throughout the library, examples, and tests.

| Previous name | Current name |
| --- | --- |
| `GL_ARRAY_BUFFER` | `glArrayBuffer` |
| `GL_COLOR_BUFFER_BIT` | `glColorBufferBit` |
| `GL_CLEAR_ALL` | `glClearAll` |
| `GL_RGBA8` | `glRgba8` |
| `GL_TEXTURE_2D` | `glTexture2D` |
| `GL_UNSIGNED_SHORT_5_6_5` | `glUnsignedShort565` |
| `GL_UNMASKED_RENDERER_WEBGL` | `glUnmaskedRendererWebgl` |
| `VarTypeFloat` | `varTypeFloat` |
| `VarTypeSampler2D` | `varTypeSampler2D` |
| `StdVertexBody` | `stdVertexBody` |
| `StdLibShader` | `stdLibShader` |
| `PackedRGBALib` | `packedRgbaLib` |
| `PerlinNoiseFunctions` | `perlinNoiseFunctions` |
| `SimplexNoiseHelpers` | `simplexNoiseHelpers` |
| `ShadowMapShaderLib` | `shadowMapShaderLib` |
| `NO_WEBGL_MESSAGE` | `noWebglMessage` |
| `Keyboard.PAGEUP` | `Keyboard.pageUp` |
| `Keyboard.PAGEDOWN` | `Keyboard.pageDown` |
| `Keyboard.SPACE` | `Keyboard.space` |
| `Keyboard.A` … `Keyboard.Z` | `Keyboard.a` … `Keyboard.z` |
| `Keyboard.F1` … `Keyboard.F12` | `Keyboard.f1` … `Keyboard.f12` |
| `Mouse.LEFT` | `Mouse.left` |
| `Mouse.MIDDLE` | `Mouse.middle` |
| `Mouse.RIGHT` | `Mouse.right` |

The `GL_*` constants use a `gl` prefix followed by capitalized words. Acronyms
become words, such as `RGBA` → `Rgba`; dimensional suffixes retain `2D` and `3D`.
Numeric components are joined, as in `GL_UNSIGNED_SHORT_5_6_5` above.
The MIDI example also uses names such as `midiNoteOn` instead of `MIDI_NOTE_ON`.
Private constants retain their leading underscore, for example
`_SAMPLE_RATE_MS` → `_sampleRateMs`.

Constant values, GLSL text, attribute/uniform names, and rendering reference
images are unchanged. Diagnostic strings such as `"GL_RGBA"` still use the
standard WebGL spelling. This rename applies to ChronosGL's declarations;
constant names supplied by the Dart SDK or other dependencies are unchanged.

## Core WebGL bindings

The core wrapper now uses `package:web` and `dart:js_interop` instead of
`dart:web_gl`. The `GlBuffer`, `GlTexture`, `GlProgram`, and other `Gl*` aliases
refer to the corresponding `package:web` WebGL types. Buffer, texture, uniform,
and pixel APIs still accept Dart typed data, including views with byte offsets.

`ChronosGL` and image textures accept browser objects from both `package:web`
and the existing SDK browser libraries. For new core callers:

```dart
import 'package:chronosgl/chronosgl.dart';
import 'package:web/web.dart' as web;

final canvas = web.HTMLCanvasElement()
  ..width = 640
  ..height = 480;
final cgl = ChronosGL(canvas);
```

`getParameter` returns Dart scalars and lists, preserving opaque WebGL handles.
`getExtension` returns a nullable `JSObject`; use a `package:web` extension type
to access extension methods:

```dart
final extension = cgl.getExtension('WEBGL_lose_context');
if (extension != null) {
  (extension as web.WEBGL_lose_context).loseContext();
}
```

See Dart's [package:web migration guide](https://dart.dev/interop/js-interop/package-web)
for the browser API naming and interop differences.

The core interop tests also run with Wasm:

```sh
dart test -p golden_chrome -c dart2wasm test/core_web_interop_test.dart
```

## Web and miscellaneous helpers

The web helpers and miscellaneous helpers now use `package:web` and
`dart:js_interop`. No library under `lib/` imports the legacy SDK browser
libraries. Existing DOM elements can still be passed to `Keyboard`, `Mouse`,
`OrbitCamera`, `Stats`, `StatsFps`, `RenderPhaseResizeAware`, and
`PerspectiveResizeAware` while applications migrate. `Keyboard(null)` and
`Mouse(null)` continue to listen on the document.

Helpers that create elements now return the corresponding `package:web` types:

| Helper | Return type |
| --- | --- |
| `loadImage` | `Future<web.HTMLImageElement>` |
| `loadCubeImages` | `List<Future<web.HTMLImageElement>>` |
| `loadVideo` | `Future<web.HTMLVideoElement>` |
| `makeVideoElementFromCamera` | `Future<web.HTMLVideoElement?>` |
| `makeSolidColorCanvas`, `Utils.createParticleCanvas` | `web.HTMLCanvasElement` |

Update explicitly typed callbacks and variables to these types, or let Dart
infer the callback parameter type. `ImageTexture` and `CubeTexture` accept these
elements directly. Cube faces retain the order `nx`, `px`, `ny`, `py`, `nz`, `pz`.

`loadRaw` and `loadJson` now report HTTP and network failures through their
returned futures. Invalid JSON also completes with an error. Failed image and
video loads complete with an error instead of leaving the future pending.
Video helpers still wait for `playing` before returning. Camera capture uses
`navigator.mediaDevices.getUserMedia`, returns a muted inline video, and keeps
the nullable failure result. A stream is stopped if video initialization fails.

The helper tests import the public package entry point and can run with either
JavaScript or Wasm:

```sh
dart test -p golden_chrome test/webhelper_interop_test.dart
dart test -p golden_chrome -c dart2wasm test/webhelper_interop_test.dart
```

## Examples and browser callbacks

The examples use `package:web` and `dart:js_interop`. Convert Dart callbacks
with `.toJS` and browser promises with `.toDart`. Cache a JavaScript callback
when reusing it, as in an animation loop:

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void main() {
  late final JSFunction onFrame;
  void animate(double timeMs) {
    // Update and draw the scene.
    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;
  web.window.requestAnimationFrame(onFrame);
}
```

See [example/simple/simple.dart](example/simple/simple.dart) for a complete
scene. Camera examples request camera access, and the MIDI example connects
after the user selects **Connect MIDI**.

## Validate the migration

From a checkout of this repository, run the VM and JavaScript suites, then the
Wasm browser suites with the same rendering references:

```sh
dart pub get --enforce-lockfile
dart analyze
dart test -P all
dart test -P all -p golden_chrome -c dart2wasm
dart run tool/goldens.dart --self-check
```

The legacy DOM compatibility test intentionally retains SDK browser imports
and runs only with JavaScript. See [the golden test guide](test/goldens/README.md)
for Chrome setup, the reference environment, and failure diagnostics.
