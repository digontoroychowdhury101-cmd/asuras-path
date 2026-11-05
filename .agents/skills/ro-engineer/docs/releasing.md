# Release checks

Shared skill content lives at the repository root. Update versions together in
`.claude-plugin/plugin.json` and `packaging/openai-plugin.json`, and add a
changelog entry. Python 3.10+ is required for the standard-library checks/build.

```sh
python scripts/validate.py
python -m unittest discover -s tests -v
claude plugin validate --strict .claude-plugin/plugin.json
claude plugin validate --strict .claude-plugin/marketplace.json
python scripts/package.py
```

Claude commands require a current installed CLI. Structural validation is not
live skill discovery: locally test `claude --plugin-dir .` and a standalone
Codex installation when preparing a release. Test the OpenAI plugin import in a
permitted account; record client/version and result. Do not claim unrun tests.

The builder checks local references and metadata, emits deterministic ZIPs with
forward-slash paths, verifies entries/bytes, and writes SHA256SUMS.txt. Artifacts:

- `dist/ro-engineer-skill-v1.0.1.zip`: one `ro-engineer/` directory containing
  the skill, supporting files, metadata, and license.
- `dist/ro-engineer-openai-plugin-v1.0.1.zip`: root portable `plugin.json`,
  README/license, and `skills/ro-engineer/` generated from that same content.

Explicit allowlists exclude `.git`, promo, old archives, unrelated scripts,
and Claude manifests from the standalone skill and OpenAI plugin. Assets remain
repository presentation, not required runtime content. Old v1 ZIPs are not used.

The generated OpenAI wrapper follows the
[official packaging guide](https://developers.openai.com/plugins/build/plugins)
and [Agent Plugins schema](https://agent-plugins.org/schemas/1.0.0/plugin.schema.json).
Recheck those sources if platform specifications change. No connector configuration
is fabricated; adding ROTEX later requires a real endpoint/transport/auth contract
and a separate authorized integration test.

Review diffs and validation results before creating a commit/tag. Pushing,
uploading a release, and public/plugin-directory submission require explicit
authorization; building the packages does not perform any of those actions.
