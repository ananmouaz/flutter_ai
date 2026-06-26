# flutter_ai

A family of Flutter/Dart packages for building AI chat and agent experiences —
the Flutter answer to Vercel AI Elements + AI SDK. It adopts Elements' proven
component vocabulary while rendering through a mobile-first, 2026-era design
system, on top of un-opinionated, provider-neutral logic packages.

> Design stance: copy Vercel Elements' **component contract and behavior**, not
> its shadcn web skin. Render through a `ThemeExtension`-driven mobile design
> system. State-manager- and provider-agnostic throughout.

See [`docs/`](docs/) for the full specs (overview, architecture, per-package
specs, roadmap).

## Packages

| Package | Status | Description |
|---|---|---|
| [`flutter_ai_core`](packages/flutter_ai_core) | ✅ 0.1.0 | Dependency-free models, streaming `MessageProcessor`, provider/renderer contracts |
| [`flutter_ai_client`](packages/flutter_ai_client) | ✅ 0.1.0 | Provider abstraction + `UseChatController` (Listenable) |
| [`flutter_ai_elements`](packages/flutter_ai_elements) | ✅ 0.1.0 | UI components + `AiThemeExtension` (`AiChat`, `AiPromptInput`, `AiMessageBubble`, …) |
| `flutter_ai_tools` | ⏳ planned | Tool calling, web search, structured actions |
| `flutter_ai_voice` | ⏳ planned | Speech-to-text / voice input (optional) |
| `flutter_ai_provider_local` | ⏳ planned | On-device inference (optional, FFI) |

## Repository layout

This is a [pub workspace](https://dart.dev/tools/pub/workspaces) (Dart ≥ 3.6):
one shared dependency resolution and one strict, shared `analysis_options.yaml`
across all packages.

```
flutter_ai/
├── analysis_options.yaml   # shared strict lints for every package
├── pubspec.yaml            # workspace root
├── docs/                   # specs & roadmap
└── packages/
    ├── flutter_ai_core/      # the foundation (pure Dart)
    ├── flutter_ai_client/    # UseChatController
    └── flutter_ai_elements/  # UI + AiThemeExtension
```

## Development

```bash
dart pub get                              # resolve the whole workspace
dart analyze .                            # lint every package
dart format .                             # format every package
cd packages/flutter_ai_core && dart test  # run a package's tests
```

## License

BSD-3-Clause. See [LICENSE](LICENSE).
