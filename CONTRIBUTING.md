# Contributing to flutter_ai

Thanks for your interest! This is a [pub workspace](https://dart.dev/tools/pub/workspaces)
(Dart ≥ 3.6) of small, focused packages. Contributions of all kinds are welcome.

## Setup

```bash
git clone https://github.com/ananmouaz/flutter_ai
cd flutter_ai
flutter pub get          # resolves the whole workspace at once
```

## Before you push

CI runs these on every PR; run them locally first:

```bash
dart format .                                  # must produce no changes
dart analyze                                   # must be clean (strict lints)
# run each package's tests, e.g.:
cd packages/flutter_ai_core && dart test       # pure-Dart packages
cd packages/flutter_ai_elements && flutter test  # Flutter packages
```

- **`dart format` is authoritative** — the format check fails CI on any diff.
- The shared `analysis_options.yaml` is strict (public-API docs required, etc.).
- Add or update tests for any behavior change. Provider live tests
  (`test/live_test.dart`) are skipped unless the relevant API key env var is set.

## Conventions

- Match the surrounding code's style, naming, and comment density.
- Keep `flutter_ai_core` **dependency-free**; put transport/UI/engine code in the
  appropriate package (see the architecture diagram in the README).
- Each public member needs a concise dartdoc comment.
- Commits: a clear imperative summary line; explain the "why" in the body.

## Pull requests

1. Branch off `main` (`feat/…`, `fix/…`, `chore/…`).
2. Keep PRs focused; update CHANGELOGs for user-facing changes.
3. Ensure format + analyze + tests pass.
4. Fill in the PR template.

## Reporting issues

Use the issue templates (bug report / feature request). Include your Flutter
version (`flutter --version`), the package(s) involved, and a minimal repro.

By contributing you agree your contributions are licensed under the project's
[BSD-3-Clause](LICENSE) license.
