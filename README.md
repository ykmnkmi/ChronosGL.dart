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
* [Simple example HTML part (simple.html)](example/simple/simple.html)
* [Simple example Dart part (simple.dart)](example/simple/simple.dart)


## Usage

Constants, functions, methods, and variables use lowerCamelCase, for example
`glArrayBuffer`, `geometryBuilderToMeshData`, and `Keyboard.pageUp`.
See [MIGRATION.md](MIGRATION.md) for the previous names.

Mathematics and CPU geometry are available on the Dart VM through these imports:

- `package:chronosgl/core.dart` exports `Transform`, immutable `Color`, and the
  color palette.
- `package:chronosgl/camera.dart` exports `Camera`, `PerspectiveCamera`,
  `OrthographicCamera`, `Projection`, `PerspectiveProjection`, and
  `OrthographicProjection`.
- `package:chronosgl/geometry.dart` exports `GeometryBuilder`, shape factories,
  polygon algorithms, and vertex attribute names. Call `geometry.validate()`
  before using or uploading edited CPU data.

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

`fovYRadians` is the full vertical angle, with a default of 50 degrees in
radians; `aspectRatio` defaults to `1`. All parameters must be finite, with
`0 < fovYRadians < pi`, `aspectRatio > 0`, and `0 < near < far`.
Orthographic cameras require explicit ordered bounds and allow signed near/far
distances. Invalid ranges or a nonfinite/singular Float32 projection throw
`ArgumentError`. Camera `setProjection` requires all named parameters and
preserves the entire camera state on failure. See the
[projection parameter contract](docs/3.8_PROJECTION_PARAMETERS.md).

Use the same imports in command-line tools and VM tests. The aggregate
`package:chronosgl/chronosgl.dart` includes browser dependencies; use it in
browser code. See the [VM import contract](docs/3.10_VM_MATH_IMPORTS.md) for a
standalone example and the import regression test.

For browser rendering, import `package:chronosgl/chronosgl.dart` and wrap either
camera in `CameraUniforms`:

```dart
final cameraUniforms = CameraUniforms(camera);
program.draw(mesh, [cameraUniforms, material, transforms]);
// Or pass [cameraUniforms] as the RenderBatch constructor's uniform list.
```

Each draw reads the current `uPerspectiveViewMatrix = projection * view` and
world-space `uEyePosition`. Reads return independent camera snapshots; no
explicit adapter update is needed after changing pose or projection. Object
transforms remain separate. See the [adapter contract](docs/3.9_CAMERA_UNIFORMS.md).

Create a `GroupNode` for a container and a `MeshNode` for a drawable object.
Only mesh nodes expose `mesh` and `material`; both resources are required and
borrowed. `RenderBatch` draws ordered roots with one program. `RenderPass`
draws ordered batches into its framebuffer, clearing selected buffers once
before drawing. Set its viewport dimensions before drawing; an empty viewport
or disabled pass performs no framebuffer work.

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
after upload. `Node(...)`, `Node.container(...)`, `Scene`, `RenderPhase`,
`MeshData`, and the previous upload helpers remain migration entry points;
resource access on a statically typed `Node` must move to `MeshNode`.
See the [scene contract](docs/5.1_SCENE_GRAPH.md),
[CPU geometry boundary](docs/5.7_CPU_GEOMETRY.md), and
[GPU layout contract](docs/5.8_MESH_LAYOUT.md).

GPU convenience factories are available from `package:chronosgl/mesh.dart` and
the aggregate import. `shapeCube`, `shapeWedge`, `shapeCylinder`,
`shapeIcosahedron`, `shapeTorusKnot`, `shapeQuad`, and `shapeGrid` each return a
new mesh owned by the caller. All supplied geometry options are forwarded,
including `shapeCube(computeNormals: false)`; use a program that does not require
normals when disabling them.

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
Applications can copy or replace that example code; the engine does not import
it. See the [Phase 6 migration guide](MIGRATION.md#helpers-and-settings-refactoring-phase-6)
for replaced helpers and ownership details.

Browser camera input and sizing use separate components from the same aggregate
import:

```dart
final camera = PerspectiveCamera(near: 0.1, far: 1000);
canvas.tabIndex = 0;
canvas.focus(); // Receive keyboard input on this explicit target.
final controls = OrbitControls(camera, canvas, radius: 15);
final phase = RenderPhase('main', cgl);
final viewport = CanvasViewport(cgl, canvas, camera, renderPhase: phase);
// Add scenes with CameraUniforms(camera) to phase.

// In requestAnimationFrame, convert timestamp differences from ms to seconds.
controls.update(deltaSeconds);
if (viewport.update()) phase.draw();
```

`OrbitControls` listens on the supplied event target. Keyboard movement uses
seconds; mouse drag and wheel events accumulate until the next update and are
consumed once. `disable()` detaches input and clears pending state; `enable()`
attaches fresh listeners. Call `await controls.dispose()` when finished.

`CanvasViewport` observes the canvas content size and device pixel ratio,
updates the drawing buffer, viewport and perspective aspect together, and keeps
explicit orthographic bounds. Give the canvas a CSS width and height. Its
`update()` returns false while disabled or hidden, preserving the last valid
projection; call `dispose()` to disconnect observers. Partial viewports use
physical buffer pixels through `setViewport`. See the
[controls contract](docs/4.1_ORBIT_CONTROLS.md) and
[viewport contract](docs/4.5_CANVAS_VIEWPORT.md).

The [orbit camera example](example/orbit_camera/orbit_camera.dart) combines
these components. The [torus-knot example](example/torusknot_camera/torusknot_camera.dart)
keeps its trajectory in an example controller that drives a supplied camera.
Legacy `OrbitCamera` and resize helpers remain available during migration;
their existing frame-based input and resize behavior is unchanged.


Create a new Dart webapp project, add this as a `pubspec.yaml` dependency:
```yaml
dependencies:
  chronosgl: ^5.0.0
  vector_math: ^2.4.4
  web: ^1.1.2
```
The examples use `vector_math` for vectors and matrices and `package:web` for
browser APIs. Declare packages you import directly in your own dependencies.

As a test copy `simple.html` and `simple.dart` from above into
your project.

It should look like this:
<img src="http://i.imgur.com/Zb1XyCG.png" style="width: 600px;"/>

Use `package:web` with a prefix to avoid a naming conflict with ChronosGL's `Node`:

```dart
import 'package:chronosgl/chronosgl.dart';
import 'package:web/web.dart' as web;

void main() {
  final canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final cgl = ChronosGL(canvas);
  cgl.clear(glClearAll);
  // Create shaders, geometry, and a camera as in example/simple/simple.dart.
}
```

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
projection types. The focused `test/camera_math_test.dart` suite adds equivalent
quaternion signs and world/NDC round trips after projection changes. See the
[VM camera coverage map](docs/3.11_VM_CAMERA_TESTS.md) for the selected suites
and their run command.

Format only edited Dart files with `dart format <files>`. Install dependencies
with `dart pub get --enforce-lockfile` only when setup is needed.

For browser changes, select the relevant browser suite:

```sh
dart test -p golden_chrome test/webhelper_interop_test.dart
```

Camera uniform upload coverage is in `test/camera_uniforms_webgl_test.dart`.
It reads the uploaded matrix and world eye back from WebGL after camera edits,
scene draws, and adapter switches. See the
[browser uniform checks](docs/3.12_CAMERA_UNIFORMS_WEBGL.md) for the selected
JavaScript and Wasm commands.

Phase 4 checks are selected in the
[controls and viewport coverage map](docs/4.10_CONTROLS_AND_VIEWPORT_TESTS.md),
including equal-time keyboard movement, input detachment, element resize,
pixel density, hidden-canvas recovery and a combined WebGL scene.

Add `-c dart2wasm` when the changes affect Wasm. Set `CHROME_EXECUTABLE` if Dart
cannot discover Chrome/Chromium. Local development does not require full test
runs, building all examples, or checking Git state. CI runs the configured
VM/JavaScript and VM/Wasm suites directly through Dart.

The Makefile contains project-specific tasks: `make documentation` regenerates
`class_glossary.md`. It does not select tests or inspect development phases.

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
