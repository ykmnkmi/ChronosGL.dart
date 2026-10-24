# Migrating to ChronosGL 5.0.0

Version 5.0.0 changes API names and browser types. Use Dart 3.13.5 or later
within Dart 3, then update the dependencies in your application:

```yaml
dependencies:
  chronosgl: ^5.0.0
  vector_math: ^2.4.3
  web: ^1.1.1
```

Declare `vector_math` and `web` directly when your application imports them.
Run `dart pub get` and `dart analyze` after updating names and imports. For Wasm,
replace all legacy SDK browser imports in your application as well as upgrading
ChronosGL; legacy DOM compatibility is available only for JavaScript builds.

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
