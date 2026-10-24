# Rendering golden tests

These PNGs capture ChronosGL's current rendering before further package updates.
The test harness uses the existing Dart `test` runner and Chrome. PNG encoding
and decoding use `package:web` browser canvas APIs. A small VM isolate reads and
writes files through `package:test`'s hybrid-test channel. `stream_channel` is
declared as a direct dev dependency; it was already a transitive dependency of
the test runner.
No Node.js packages, Playwright, Docker, or external image tools are needed.

## Run

From the package root, with Dart 3.13.5 and Chrome installed:

```sh
dart pub get --enforce-lockfile
dart run tool/goldens.dart
```

To run the existing checks, golden comparisons, and importer/GPU data regression
tests:

```sh
dart test -P all
```

The `all` preset lists the older test files explicitly because their filenames do
not follow the default `*_test.dart` discovery pattern. The extension diagnostic
now runs in Chrome and checks renderer information when the browser exposes it.
The interactive contour demo remains a manual check.
The `goldens` preset is also available directly as `dart test -P goldens`.

To run the migrated browser suites with Wasm, including the same rendering goldens:

```sh
dart test -P all -p golden_chrome -c dart2wasm
```

The polygon tests retain their normal VM compiler. The JavaScript-only
`test/legacy_dom_compatibility_test.dart` is excluded by its compiler selector.
That file intentionally keeps the legacy `dart:html` and `dart:web_gl` imports
to verify existing canvas, texture, and helper callers.
All other browser tests and golden helpers use `package:web` and
`dart:js_interop`.

## Update and review

```sh
dart run tool/goldens.dart --update
```

This deliberately overwrites the references and records the rendering environment
in `environment.json`. Inspect the changed PNGs, then commit them together with
the relevant code change. Ordinary runs never create or update reference PNGs;
a missing reference is a test failure. Updates are refused in GitHub Actions.

On a mismatch, `build/golden_failures/<scene>/` contains:

- `expected.png`: the reference image;
- `actual.png`: the newly rendered image;
- `diff.png`: changed pixels in magenta over a darkened current image;
- `result.json`: dimensions, mismatch counts, and rendering environment details.

A missing reference produces `actual.png` and `result.json`. Passing tests clear
their own previous failure files. The entire `build/` directory is gitignored.

To verify that a real rendering regression is detected:

```sh
dart run tool/goldens.dart --self-check
```

The self-check changes the geometry scene's red cube to green in memory, expects
the golden test to fail, and verifies that all three diagnostic PNGs were written.
The command succeeds only when that intentional mismatch is detected. It never
changes the reference image or source files. A later normal run clears its images.

## Scenes and comparison

| Reference | Coverage |
| --- | --- |
| `geometry.png` | Cube, wedge, subdivided icosahedron, parent/child transforms |
| `perspective.png` | Perspective projection, view matrix, different object depths |
| `orthographic.png` | The same objects with orthographic projection |
| `texture.png` | Asymmetric generated texture, UV orientation, nearest filtering |
| `depth.png` | Overlapping surfaces submitted out of depth order |
| `blending.png` | Overlapping half-transparent materials and an opaque background |
| `lighting.png` | Blinn-Phong shader, normals, directional lights, specular highlight |

Each scene is 256 x 256, has a fixed camera, and uses no animation, random values,
input listeners, fonts, or network assets. Rendering goes into an RGBA8 framebuffer
with antialiasing and dithering disabled. Readback flips WebGL's bottom-up rows to
PNG's top-down order. Before clearing each frame, the fixture restores depth
writes because transparent materials leave that mask disabled.

Each scene must produce foreground and background pixels, render identically
across three repeated frames, and match an independently created WebGL context
byte for byte. Reference comparison decodes the PNG and compares all RGBA pixels:
up to 2/255 difference per channel is allowed for rounding; zero pixels may exceed
that bound. Image dimensions must match. Separate tests check PNG orientation,
color preservation, tolerance boundaries, and dimension changes.

## Reproducible environment and CI

The initial references were captured on Windows with Dart 3.13.5 and
Chrome 155.0.8059.80. `dart_test.yaml` defines `golden_chrome`, which forces ANGLE
SwiftShader, and the rendering tests verify that SwiftShader is actually active.
The test annotations use the built-in `chrome` selector so that `build_test` can
generate bootstraps while building or serving examples. The presets select the
custom `golden_chrome` runtime, which inherits `chrome` and adds SwiftShader flags.
`environment.json` records the browser user agent (which reports a reduced Chrome
version), renderer, WebGL version, host OS, and Dart version for diagnosis.

Chrome can be selected with the standard `CHROME_EXECUTABLE` environment variable.
Use the same Chrome version and rendering configuration when updating references.
Other operating systems and browser versions have not been validated against
these references. When changing the reference environment, review the images
explicitly rather than automatically accepting differences.

The GitHub Actions workflow uses Windows and pins Dart 3.13.5 and
[Chrome for Testing 155.0.8059.84](https://googlechromelabs.github.io/chrome-for-testing/155.0.8059.84.json).
The original desktop Chrome version, 155.0.8059.80, is not available from
Chrome for Testing. The workflow compares against the original reference PNGs;
changing the browser pin does not regenerate or accept new references.

A setup step grants AppContainer and LPAC read/execute access to the downloaded
Chrome directory so its Windows sandbox processes can start. See
[Chromium's sandbox filesystem requirements](https://chromium.googlesource.com/chromium/src/+/main/docs/design/sandbox.md#lpac-file-system-permissions).
The permissions apply only to the CI browser installation.

CI runs the browser suites with JavaScript and Wasm, runs the VM tests and
regression self-check, and uploads genuine failure images as an artifact. The
workflow must run on GitHub to validate the hosted runner environment; local
checks cannot verify that environment.
