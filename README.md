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

Mathematics is available on the Dart VM through two public imports:

- `package:chronosgl/core.dart` exports `Transform`.
- `package:chronosgl/camera.dart` exports `Camera`, `PerspectiveCamera`,
  `OrthographicCamera`, `Projection`, `PerspectiveProjection`, and
  `OrthographicProjection`.

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
// Or pass [cameraUniforms] as the Scene constructor's uniform list.
```

Each draw reads the current `uPerspectiveViewMatrix = projection * view` and
world-space `uEyePosition`. Reads return independent camera snapshots; no
explicit adapter update is needed after changing pose or projection. Object
transforms remain separate. See the [adapter contract](docs/3.9_CAMERA_UNIFORMS.md).


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
