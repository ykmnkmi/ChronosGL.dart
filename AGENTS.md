# Repository guidance

ChronosGL is a Dart WebGL2 engine targeting JavaScript and Wasm. Mathematical
and camera APIs in `lib/core.dart` and `lib/camera.dart` must remain usable on
the Dart VM without browser dependencies; `lib/chronosgl.dart` is the
browser-facing aggregate export.

## Task scope

- Do not use Git unless the user explicitly requests Git work. This includes
  read-only commands such as status, diff, and log, as well as staging, commits,
  branches, and other repository operations. Routine development does not
  require inspecting Git state. Preserve existing user edits.
- Use `rg` and targeted file excerpts to find task context. Avoid dumping
  `pubspec.lock`, generated files, or unrelated documentation into context.
- Update `CHANGELOG.md` and `README.md` when public APIs or user-facing
  behavior change, preserving each document's language.

## Development and validation

- Use the Dart CLI directly. If dependency setup is necessary, run
  `dart pub get --enforce-lockfile`; do not upgrade unrelated dependencies.
- Follow `analysis_options.yaml`. Format only Dart files edited for the task
  with `dart format <files>`. When analysis is useful, limit
  `dart analyze <path>` to the relevant file or directory.
- Run only explicitly selected tests that verify the requested changes:
  `dart test -p vm test/relevant_test.dart` for VM code, or
  `dart test -p golden_chrome test/relevant_test.dart` for browser code.
  Use `-c dart2wasm` only when the changes require Wasm coverage. Select test
  cases with `--name` when only part of a suite is relevant.
- Do not start long-running processes (including servers and watchers), build
  all examples, or run full checks, `-P all`, the golden self-check, or a full
  platform matrix unless the user explicitly requests that work. Historical
  validation results in documentation are reference material, not instructions
  to repeat those runs.
- Compare goldens with committed reference images. Updating references
  (`dart run tool/goldens.dart --update`) requires an explicit user request.
- Documentation-only changes need a review of the edited text, not runtime tests.
  After a relevant check passes, repeat it only for subsequent relevant changes
  or an unresolved failure.

## Keep tool output compact

- Prefer concise command output. Keep verbose logs on disk and read relevant
  excerpts when diagnosing failures; do not hide failures to shorten output.
- Report failures with the exact targeted rerun command.
- Finish with the outcome, files worth reviewing, targeted checks performed,
  and any remaining limitation. Do not repeat the command transcript.
