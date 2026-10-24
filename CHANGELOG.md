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
- Require Dart 3.13.5 or later within Dart 3, with `vector_math: ^2.4.3` and
  `web: ^1.1.1`.

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

- Add deterministic WebGL rendering goldens, failure images, and a regression
  self-check using Chrome with SwiftShader.
- Run the VM and JavaScript tests, Wasm browser tests, and regression self-check
  in the Windows CI workflow, using an available Chrome for Testing build.
- Configure Windows sandbox access to the downloaded CI browser.
- Enable strict analysis and recommended Dart lints, and update the example
  build and migration instructions.
