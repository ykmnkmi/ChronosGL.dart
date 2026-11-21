# ChronosGL


<img src="http://i.imgur.com/JkaU6LF.png" style="width: 600px;"/>

A simple WebGL2 engine written in Dart
--------------------------------------

## Features:

* MIT licensed
* straight-forward API
* lightweight (close to "baremetal")
* fully based on WebGL2 and GLSL 3.00es
* keyboard and mouse event capture
* support for canvas based textures including skybox
* focus on procedural content generation
* optional basic scenegraph
* importer for several file formats
* bone animations
* few dependencies

## Code

* [Github](https://github.com/ykmnkmi/ChronosGL.dart)
* [Classes/Basic Concepts](class_glossary.md)

## Upgrading to 5.0.0

Version 5.0.0 requires Dart 3.14.0 or later within Dart 3 and includes breaking
API naming and browser type changes. Read [MIGRATION.md](MIGRATION.md) when
upgrading from 4.x, and see [CHANGELOG.md](CHANGELOG.md) for the release notes.

## Examples

To browse the examples manually, start the server from the package root:

```sh
dart pub get --enforce-lockfile
dart run build_runner serve example:8080
```

Open `http://localhost:8080/` to browse the examples.

* [Upstream Live Examples](http://chronosteam.github.io/ChronosGL/Examples/)
* [Minimal scene HTML](example/minimal/minimal.html)
* [Minimal scene Dart](example/minimal/minimal.dart), including animation and teardown
* [Textured scene with particles](example/simple/simple.dart)

Build the complete example gallery for deployment with:

```sh
dart run build_runner build --release --output=example:build/example
```


## Usage

### Public imports

Constants, functions, methods, and variables use lowerCamelCase, for example
`glArrayBuffer`, `uploadGeometry`, and `Keyboard.pageUp`.
See [MIGRATION.md](MIGRATION.md) for the previous names.

Import these public modules from `package:chronosgl/`.

| Import | Contents |
| --- | --- |
| `core.dart`, `camera.dart` | Transforms, colors, cameras and projections |
| `geometry.dart`, `animation.dart`, `importers.dart`, `shaders.dart` | CPU geometry, skeletal animation, model parsing and shader descriptions |
| `webgl.dart`, `render.dart` | WebGL2 bindings, GPU resources, uniforms and materials |
| `mesh.dart` | GPU meshes, geometry uploads and shape factories |
| `scene.dart`, `shadows.dart`, `web.dart` | Scene traversal, shadow computation and browser integration |
| `debug.dart` | Optional panels and visualizers, imported separately |

The first two rows work on the Dart VM. `chronosgl.dart` combines the supported
engine modules for browser applications. Import `debug.dart` for diagnostics.
For module boundaries and ownership, see [Class and architecture](class_glossary.md).
For changes from 4.x, see [Public API migration](MIGRATION.md#supported-public-api).

### Cameras and CPU geometry on the VM

Use these imports for command-line tools and VM tests.

- `package:chronosgl/core.dart` exports `Transform`, immutable `Color`, and the
  color palette.
- `package:chronosgl/camera.dart` exports `Camera`, `PerspectiveCamera`,
  `OrthographicCamera`, `Projection`, `PerspectiveProjection`, and
  `OrthographicProjection`.
- `package:chronosgl/geometry.dart` exports `GeometryBuilder`, shape factories,
  polygon algorithms, and vertex attribute names. Call `geometry.validate()`
  before using or uploading edited CPU data.
- `package:chronosgl/animation.dart` exports skeletal animation. Each bone
  track holds its final keyframe from its timestamp onward.

These imports can be used together without DOM, WebGL, or rendering adapters.
For example:

```dart
import 'dart:math' as math;
import 'package:chronosgl/camera.dart';

final camera = PerspectiveCamera(
  fovYRadians: 60 * math.pi / 180,
  aspectRatio: 16 / 9,
  near: 0.1,
  far: 1000,
);
```

`fovYRadians` is the full vertical angle and defaults to 50 degrees in radians.
`aspectRatio` defaults to `1`. All parameters must be finite, with
`0 < fovYRadians < pi`, `aspectRatio > 0`, and `0 < near < far`.
Orthographic cameras require explicit ordered bounds and allow signed near/far
distances. Invalid ranges or a nonfinite/singular Float32 projection throw
`ArgumentError`. Camera `setProjection` requires all named parameters and
preserves the entire camera state on failure. [Projection parameters](MIGRATION.md#projection-parameters)

See the [standalone VM example](test/support/math_imports.dart).

### Shaders and uniforms

New shader descriptions declare their stage explicitly with
`ShaderObject.create(name: ..., stage: ShaderStage.vertex)`,
`ShaderObject.vertex(name)` or `ShaderObject.fragment(name)`. Set interface
variables before generating the body. For uniforms, use typed keys:

```dart
final material = Material('surface')
  ..set(UniformKeys.color, colorWhite.toVector3());
material.force(UniformKeys.color, colorBlue.toVector3());
final tint = material.get(UniformKeys.color);
```

Canonical strings remain available for GLSL and existing `setUniform` calls.
Stored uniform groups expose a read-only `getUniforms()` snapshot; use
`addUniforms`, `removeUniform` and `clearUniforms` to edit a group.
`CameraUniforms` returns a fresh mutable map with independent camera snapshots.
Invalid arguments throw `ArgumentError`, invalid object state throws
`StateError`, and unavailable operations throw
`UnsupportedError`. Shader compiler and linker failures throw
`ShaderCompilationException`, including the driver message and stage details.
These contracts apply with assertions enabled or disabled.

For browser rendering, import `package:chronosgl/chronosgl.dart` and wrap either
camera in `CameraUniforms`:

```dart
final cameraUniforms = CameraUniforms(camera);
program.draw(mesh, [cameraUniforms, material, transforms]);
// Or pass [cameraUniforms] as the RenderBatch constructor's uniform list.
```

Each draw reads the current `uPerspectiveViewMatrix = projection * view` and
world-space `uEyePosition`. Reads return independent camera snapshots, and
pose and projection edits take effect on the next draw. Supply object transforms
separately. [Camera uniforms](MIGRATION.md#camera-uniforms)

### Scene graph and GPU meshes

Create a `GroupNode` for a container and a `MeshNode` for a drawable object.
Only mesh nodes expose `mesh` and `material`; both resources are required and
borrowed. `RenderBatch` draws ordered roots with one program. `RenderPass`
draws ordered batches into its framebuffer, clearing selected buffers once
before drawing. If depth writes are disabled, a depth clear temporarily enables
them and restores the mask before drawing. Set the viewport dimensions before
drawing. An empty viewport or disabled pass performs no framebuffer work.

`uploadGeometry` accepts empty triangle builders and attribute lists whose
elements pass `GeometryBuilder.validate()`.

```dart
final geometry = cubeGeometry()..validate();
final mesh = uploadGeometry('cube', program, geometry);
final root = GroupNode('root', MeshNode('cube', mesh, material));
final batch = RenderBatch('objects', program, [CameraUniforms(camera)])
  ..add(root);
final pass = RenderPass('main', cgl)
  ..viewPortW = canvas.width
  ..viewPortH = canvas.height
  ..add(batch);
pass.draw();
// Dispose mesh when every consumer has finished using it.
mesh.dispose();
```

Traversal uses `parentWorld * local`, in parent-before-child insertion order.
A node shared by several branches draws with each branch's world transform;
cycles throw `StateError`. Drawing preserves supplied uniform lists and groups,
including after an exception. A batch copies its input list while borrowing
the contained groups.

`GpuMesh` owns uploaded GPU buffers and a VAO. Its immutable `attributeLayout`
records attribute names, locations, types, widths, and instancing divisors.
`mesh.isCompatibleWith(program)` checks the context and required bindings;
drawing with an incompatible program throws `ArgumentError` before GPU state
changes. Compatible programs can share a mesh. CPU builders remain independent
after upload. The migration guide maps the previous aliases and upload
helpers to the current API. [Scene graph and geometry migration](MIGRATION.md#scene-graph-and-geometry)

GPU convenience factories are available from `package:chronosgl/mesh.dart` and
the aggregate import. `shapeCube`, `shapeWedge`, `shapeCylinder`,
`shapeIcosahedron`, `shapeTorusKnot`, `shapeQuad`, and `shapeGrid` each return a
new mesh owned by the caller. All supplied geometry options are forwarded,
including `shapeCube(computeNormals: false)`; use a program that does not require
normals when disabling them.

### Render helpers and settings

Use `FullscreenPass(program)` for a reusable clip-space quad. It owns its mesh
and creates an independent material with depth testing and writes disabled.
Set the framebuffer and viewport before `draw()`, or add `fullscreen.node` to a
batch. Call `fullscreen.dispose()` after its last consumer. A supplied material
and its textures are borrowed; the program is borrowed unless
`ownsProgram: true` is specified. The shared `emptyMaterial` has been removed.

Colors are immutable RGB values exported by `core.dart`. Convert them explicitly
when an API requires a mutable vector:

```dart
material.setUniform(uColor, colorWhite.toVector3());
final tint = colorBlue.copyWith(r: 0.25);
final settings = texturePropertiesFramebuffer.copyWith(
  minFilter: glLinear,
  magFilter: glLinear,
);
```

Texture, blend and stencil settings are immutable and can safely share presets.
Create variants using constructors or `copyWith()`; texture filtering helpers
are `withFilterNearest()` and `withMipmapLinear()`.

`package:chronosgl/shadows.dart` provides `ShadowMap` without diagnostic
resources. `package:chronosgl/debug.dart` provides `ShadowMapVisualizer`,
`LightVisualizer`, `BoneVisualizer`, `StatsPanel` and `FpsPanel`.
Visualizers allocate GPU assets on first use and release them with `dispose()`;
they borrow their input programs, materials and scene data. A shadow visualizer
creates and owns its own program, quad and sampler, and leaves the shadow
texture's comparison settings intact. Dispose visualizers before their borrowed
shadow map, then dispose the map to release its framebuffer, attachments and
compute program. Panels own their DOM wrapper and preserve their supplied root.

Demo particles, stars and fixed demo shaders live in `example/shared/`.
Applications can copy that example code.
[Helpers and settings migration](MIGRATION.md#helpers-and-settings)

### Browser controls and canvas sizing

Browser camera input and sizing use separate components from the same aggregate
import:

```dart
final camera = PerspectiveCamera(near: 0.1, far: 1000);
canvas.tabIndex = 0;
canvas.focus(); // Receive keyboard input on this explicit target.
final controls = OrbitControls.forCamera(
  camera: camera,
  eventTarget: canvas,
  radius: 15,
);
final pass = RenderPass.named(name: 'main', context: cgl);
final viewport = CanvasViewport.forCanvas(
  cgl: cgl,
  canvas: canvas,
  camera: camera,
  renderPass: pass,
);
// Add render batches with CameraUniforms(camera) to the pass.

// In requestAnimationFrame, convert timestamp differences from ms to seconds.
controls.update(deltaSeconds);
if (viewport.update()) pass.draw();
```

`OrbitControls` listens on the supplied event target. Set `canvas.tabIndex = 0`
so a primary click can focus the canvas for keyboard input. Keyboard movement
uses seconds. Mouse drag and wheel events accumulate until the next update and
are consumed once. `disable()` detaches input and clears pending state.
`enable()` attaches fresh listeners. Call `await controls.dispose()` when finished.

`CanvasViewport` observes the canvas content size and device pixel ratio,
updates the drawing buffer, viewport and perspective aspect together, and keeps
explicit orthographic bounds. Give the canvas a CSS width and height. Its
`update()` returns false while disabled or hidden and preserves the last valid
projection. Call `dispose()` to disconnect observers. Partial viewports use
physical buffer pixels through `setViewport`.
[Controls and canvas sizing migration](MIGRATION.md#camera-controls-and-canvas-sizing)

The [minimal scene](example/minimal/minimal.dart) and
[orbit camera example](example/orbit_camera/orbit_camera.dart) combine
these components. The [torus-knot example](example/torusknot_camera/torusknot_camera.dart)
keeps its trajectory in an example controller that drives a supplied camera.
The examples use supported cameras, controls and viewport components. Legacy
`OrbitCamera` and resize helpers remain available as deprecated compatibility
adapters with their previous frame-based input and resize behavior.

Camera pose describes camera-local to world coordinates. `viewMatrix` is its
inverse; `lookAt()` changes orientation while preserving the eye position.
`CameraUniforms` uploads that world position as `uEyePosition`. The legacy
`Spatial.lookAt()` now also preserves world pose; code that treated its matrix
as a view matrix must migrate explicitly. See the
[camera migration](MIGRATION.md#camera-semantics-and-resource-lifetimes).

Every example owns its programs, meshes, textures, offscreen targets and input
subscriptions. The gallery's [shared lifetime helper](example/shared/lifetime.dart)
stops pending animation frames and releases registered resources on page
teardown. Its `ownPass`/`ownBatch` methods explicitly take ownership of reachable
resources; ordinary engine passes, batches, nodes and materials still borrow
their inputs. Check for teardown before allocating in asynchronous load callbacks.
The standalone minimal scene implements cleanup directly and can be copied into
an application without the shared gallery helpers.

Use `ChronosGL.fromCanvas` and `ImageTexture.fromCanvas/fromImage/fromVideo`
with `package:web` elements, and `Keyboard.forTarget`/`Mouse.forTarget` with a
typed event target. Diagnostics provide `StatsPanel.attach` and
`FpsPanel.attach`. The previous Object-based constructors remain deprecated
compatibility boundaries; legacy SDK DOM objects work only in JavaScript.

`GpuMesh.changeFaces` updates an existing index buffer. Call `addFaces` first,
including after `clearData()`. Otherwise it throws `StateError` before changing
mesh data or WebGL bindings.
`changeVertexData` updates positions with the existing vertex count. Use
`addVertices` to replace storage when that count changes, and update associated
attributes and indices to match the new topology.

### Minimal rendering setup

Create a new Dart webapp project, add this as a `pubspec.yaml` dependency:
```yaml
dependencies:
  chronosgl: ^5.0.0
  vector_math: ^2.4.4
  web: ^1.1.2
```
The examples use `vector_math` for vectors and matrices and `package:web` for
browser APIs. Declare packages you import directly in your own dependencies.

Copy `minimal.html` and `minimal.dart` into your project's web directory, using
the CSS dimensions from `example/style.css` or your own layout. The complete
example draws an interactive cube and releases its resources when finished.
This smaller, single-frame version shows the rendering setup and ownership:

```dart
import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

void main() {
  final canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final cgl = ChronosGL.fromCanvas(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 100)
    ..setPosition(3, 2, 5)
    ..lookAt(vm.Vector3.zero());
  final program = RenderProgram.create(
    name: 'cube',
    context: cgl,
    vertexShader: solidColorVertexShader,
    fragmentShader: solidColorFragmentShader,
  );
  final mesh = shapeCube(program);
  final material = Material('blue')
    ..set(UniformKeys.color, colorLiteBlue.toVector3());
  final batch = RenderBatch('objects', program, [CameraUniforms(camera)])
    ..add(MeshNode('cube', mesh, material));
  final pass = RenderPass('screen', cgl)..add(batch);
  final viewport = CanvasViewport.forCanvas(
    cgl: cgl, canvas: canvas, camera: camera, renderPass: pass,
  );
  try {
    if (viewport.update()) pass.draw();
  } finally {
    viewport.dispose();
    mesh.dispose();
    program.dispose();
  }
}
```

Use a canvas with a nonzero CSS size, for example
`<canvas id="webgl-canvas" style="width: 640px; height: 480px"></canvas>`.
For animation, keep resources alive until the loop stops, cancel its pending
frame, and then dispose controls, the viewport and GPU resources as demonstrated
in `minimal.dart`. Materials, camera adapters and graph links have no GPU handles
to release. Textures remain the responsibility of their explicit owners.

Browser callbacks and promises use `dart:js_interop`: convert callbacks with
`.toJS` and await promises with `.toDart`. The examples use
`window.requestAnimationFrame` with a cached JavaScript callback and support
both JavaScript and Wasm compilation. Camera examples request camera access;
the MIDI example connects when you select **Connect MIDI**.

## Tests and rendering goldens

Use the Dart CLI directly and select tests that verify the changes. For a
mathematical camera change, for example:

```sh
dart analyze lib/src/camera/camera.dart
dart test -p vm test/camera_test.dart
```

The camera VM tests cover position, orientation, matrix inverses, and both
projection types. The camera math suite adds equivalent quaternion signs and
world/NDC round trips after projection changes. The import test compiles and
runs a standalone VM consumer. [Camera math tests](test/camera_math_test.dart)
· [VM import test](test/math_imports_test.dart)

Format only edited Dart files with `dart format <files>`. Install dependencies
with `dart pub get --enforce-lockfile` only when setup is needed.

For browser changes, select the relevant browser suite:

```sh
dart test -p golden_chrome test/webhelper_interop_test.dart
```

The browser camera uniform suite reads the matrix and world eye back from
WebGL after camera edits, scene draws and adapter switches.
[Camera uniform tests](test/camera_uniforms_webgl_test.dart)

The browser controls and viewport suites cover input detachment, equal-time
keyboard movement, canvas resizing, pixel density, hidden-canvas recovery
and camera-to-rendering integration. [Orbit controls](test/orbit_controls_test.dart)
· [Frame rate](test/orbit_frame_rate_reproduction_test.dart)
· [Canvas viewport](test/canvas_viewport_test.dart)
· [Camera integration](test/camera_controls_integration_test.dart)

Add `-c dart2wasm` when the changes affect Wasm. Set `CHROME_EXECUTABLE` if Dart
cannot discover Chrome/Chromium. CI runs analysis, VM and JavaScript tests, the
browser-only `wasm` preset, the golden regression self-check and a release build
of the gallery. CI uploads golden failure images from the JavaScript and Wasm
suites. [CI workflow](.github/workflows/tests.yml)

Generate the API reference from source with `dart doc --output=build/api`.
For the supported API and architecture, see the [class glossary](class_glossary.md).

The legacy DOM compatibility test runs only with JavaScript. The polygon tests
use the VM compiler.

Golden tests use Dart and Chrome with SwiftShader; no Node.js packages,
Playwright, or Docker are required. For rendering changes, select the affected
scene:

```sh
dart test -p golden_chrome test/render_golden_test.dart --name '^golden geometry$'
```

Reference updates are a separate, explicit task using
`dart run tool/goldens.dart --update`. Review the generated PNGs before accepting
updates. See
[the golden test guide](test/goldens/README.md) for scenes, failure images,
environment details, and the regression self-check.
