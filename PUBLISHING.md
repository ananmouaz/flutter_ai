# Publishing to pub.dev

The packages use hosted version constraints between each other, so they publish
as normal pub packages. Because each depends on the one(s) below it, **publish in
dependency order** — a package can't be published until its dependencies are
already on pub.dev.

## Order

```
1. flutter_ai_core          (no deps)
2. flutter_ai_tools         → core
   flutter_ai_voice         → (none beyond SDK)
3. flutter_ai_client        → core
4. flutter_ai_provider_openai      → core
   flutter_ai_provider_anthropic   → core
   flutter_ai_provider_gemini      → core
5. flutter_ai_elements      → client, core
```

## Steps

```bash
# one-time
dart pub login

# from the repo root, for each package in the order above:
cd packages/flutter_ai_core
dart pub publish --dry-run     # validate (0 warnings expected)
dart pub publish               # publish for real

# then the next tier, and so on…
```

After publishing a new version, bump the dependents' constraints if you made a
breaking change, update each `CHANGELOG.md`, and tag the release
(`git tag vX.Y.Z && git push --tags`).

## README images

Package READMEs use **relative** image paths (`../../demo/screenshots/…`), which
render on GitHub (including this private repo). **pub.dev does not render relative
images** — it needs absolute URLs to a public host. Before publishing, either
make the repo public and rewrite the image links to
`https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/…`,
or copy the few hero images into each package and reference them locally. A quick
rewrite:

```bash
sed -i '' 's#../../demo/screenshots/#https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/#g' packages/*/README.md
```

## Notes

- `flutter_ai_core` already passes `dart pub publish --dry-run` with 0 warnings.
- The workspace root `pubspec.yaml` and `demo/` are `publish_to: none` and are
  never published.
- Keep versions in sync across a coordinated release, or bump independently with
  semver — see each package's `CHANGELOG.md`.
