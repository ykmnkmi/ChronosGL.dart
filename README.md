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

* [Github](https://github.com/ChronosTeam/ChronosGL)
* [Classes/Basic Concepts](https://github.com/ChronosTeam/ChronosGL/tree/master/class_glossary.md)

## Examples

Build and serve the examples from the package root:

```sh
dart pub get --enforce-lockfile
dart run build_runner serve example:8080
```

Open `http://localhost:8080/` to browse the examples. For a release build:

```sh
dart run build_runner build --release --output=example:build/example
```

* [Live Examples](http://chronosteam.github.io/ChronosGL/Examples/)
* [Simple example HTML part (simple.html)](https://github.com/ChronosTeam/ChronosGL/tree/master/example/simple/simple.html)
* [Simple example Dart part (simple.dart)](https://github.com/ChronosTeam/ChronosGL/tree/master/example/simple/simple.dart)


## Usage

Constants, functions, methods, and variables use lowerCamelCase, for example
`glArrayBuffer`, `geometryBuilderToMeshData`, and `Keyboard.pageUp`.
See [MIGRATION.md](MIGRATION.md) for the previous names.


Create a new Dart webapp project, add this as a `pubspec.yaml` dependency:
```yaml
dependencies:
  chronosgl: any
  vector_math: ^2.4.3
  web: ^1.1.1
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

Run the existing unit/browser tests and the rendering goldens with:

```sh
dart pub get --enforce-lockfile
dart test -P all
```

```sh
dart analyze
```

Golden tests use Dart and Chrome with SwiftShader; no Node.js packages,
Playwright, or Docker are required. To compare or explicitly update the PNGs:

```sh
dart run tool/goldens.dart
dart run tool/goldens.dart --update
```

Review changed PNGs before committing updates. See
[the golden test guide](test/goldens/README.md) for scenes, failure images,
environment details, and the regression self-check.
