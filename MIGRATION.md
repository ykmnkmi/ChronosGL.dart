# API naming changes

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
| `HTML` | `html` |
| `WEBGL` | `webgl` |
| `VM` | `vm` |
| `Math`, `MATH` | `math` |
| `JS` | `js` |
| `DATA` | `data` |

For example, `HTML.CanvasElement` becomes `html.CanvasElement` after changing
the import to `import 'dart:html' as html;`. Names supplied by the imported
library, such as `CanvasElement`, remain the same.

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
and the existing SDK browser libraries. Web helpers and examples can migrate
separately. For new core callers:

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

The core-only interop tests also run with Wasm:

```sh
dart test -p golden_chrome -c dart2wasm test/core_web_interop_test.dart
```
