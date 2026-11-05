# Installation and platform support

Specifications checked 2026-11-01. Skill instructions, plugin distribution,
MCP connectors, and project permissions are separate. MCP is optional; install
the skill without it for code review, repository edits, design, or offline help.
Connect Studio/ROTEX separately through the host's supported setup. No connector,
credentials, endpoint, or Studio plugin is bundled here.

## Standalone folder: Claude Code and Codex

Requirements: a host supporting filesystem skills, and access to the target
directory. Extract `ro-engineer-skill-v1.0.1.zip`; copy the inner `ro-engineer`
folder intact to one destination:

| Host | This project | This user |
|---|---|---|
| Claude Code | `<project>/.claude/skills/ro-engineer/` | `~/.claude/skills/ro-engineer/` |
| Codex | `<project>/.agents/skills/ro-engineer/` | `~/.agents/skills/ro-engineer/` |

`~` means your home directory, also on Windows. Create missing parent folders.
Confirm `SKILL.md`, `references/`, `workflows/`, `templates/`, `agents/`, and
`LICENSE` are together. No full repository clone is required.

Verify discovery in the host's skills/menu list and ask it to use a specific
reference. Claude standalone invocation: `/ro-engineer`; Codex: `$ro-engineer`
or its skills picker. Codex detects changes automatically; restart if missing.
For Claude, check the current session's menu and restart if needed.

To update, back up local customizations, replace the installed folder with the
new extracted version, and verify recognition again. To uninstall, remove only
that installed skill folder. Project installs can be committed for the team;
each developer still needs their own tool permissions and connections.

Source installation also works: clone this repository to one of those exact
skill destinations. Use `git pull --ff-only` there to update after reviewing
local changes. This includes repository documentation; the ZIP is leaner.

### Codex skill-installer option

If `$skill-installer` is available, ask it: "Install the ro-engineer skill from
https://github.com/excaldev/ro-engineer with repository path `.` and name
`ro-engineer`." The bundled helper supports `--repo`, `--path`, `--name`, and
`--dest`; the default legacy destination may be `~/.codex/skills`, distinct
from the native paths above. Specify your intended destination if needed.
Verify the installed resources; do not assume every host includes this helper.

Sources: [Claude skill locations](https://code.claude.com/docs/en/skills),
[Codex locations](https://learn.chatgpt.com/docs/customization/overview),
[skill discovery/metadata](https://learn.chatgpt.com/docs/build-skills),
[OpenAI skill-installer](https://github.com/openai/skills/tree/main/skills/.system/skill-installer).

## Claude Code plugin

Use a current Claude Code release with plugin support. In a local interactive
session:

```text
/plugin marketplace add excaldev/ro-engineer
/plugin install ro-engineer@ro-engineer
```

Choose user/project/local scope in the plugin UI as needed. Verify the Installed
tab and `/ro-engineer:ro-engineer` in the slash menu. The namespaced plugin
invocation differs from standalone `/ro-engineer`.

Update through the Installed tab or run `claude plugin update ro-engineer@ro-engineer`
in your shell; uninstall through the Installed tab or
`claude plugin uninstall ro-engineer@ro-engineer` (select the installed scope).
Apply any reload
the client requests. For local source testing use `claude --plugin-dir .`
from this repository; `skills: "./"` explicitly points at the canonical skill.

Source: [official plugin installation and management](https://code.claude.com/docs/en/discover-plugins),
[manifest paths](https://code.claude.com/docs/en/plugins-reference).

## Claude chat / Cowork

Where custom skill upload is available, upload the standalone skill ZIP through
the account's Skills settings and enable it. Confirm it is listed, then ask
Claude to use ro-engineer. Update/reupload or disable/remove it in those settings.
Availability and sync depend on account and client version; do not assume chat
has no tools or that skills never sync. Recent Claude Code supports account-skill
sync in documented signed-in environments. Tool mode follows actual capabilities.

Source: [Claude skills and account sync](https://code.claude.com/docs/en/skills).

## ChatGPT desktop standalone skills

Official documentation supports standalone skills in the ChatGPT desktop app,
and its Skills sidebar exposes available workflows. For an existing supported
Claude setup, install the complete standalone skill as above, then open
Settings > Import, select the source agent, choose Skills among the supported
items, and review the import. Verify ro-engineer in Skills and select with `@`.
This documents the supported setup-import route; it does not promise a generic
standalone ZIP-upload button. Do not treat copying files to a Codex directory
as a universal ChatGPT installation method.

Update or remove through the mechanism that installed it. Imported auto-updates
are available only when that import feature is enabled. If your account/client
does not expose an applicable import flow, use a supported plugin path below or
provide code/references in chat; an attachment alone is not persistent installation.

Sources: [Build skills](https://learn.chatgpt.com/docs/build-skills),
[import supported setup](https://learn.chatgpt.com/docs/import).

## ChatGPT / OpenAI plugin package

`ro-engineer-openai-plugin-v1.0.1.zip` contains portable root `plugin.json` and
`skills/ro-engineer/` with the same canonical skill bytes. It has no MCP server
or hooks. Its manifest is generated from `packaging/openai-plugin.json`; it does
not reuse Claude's manifest or pretend those formats are interchangeable.

Where custom plugin ZIP upload is enabled, use that host/workspace upload flow,
review the package, and verify ro-engineer appears in Plugins. Select with `@`
and test a reference-dependent request in a fresh chat. Use the plugin's management
controls to update/upload a new version or uninstall. Exact UI and permission
availability vary; workspace permissions may restrict upload/use/sharing.

For local desktop testing, extract the plugin and use the documented local
marketplace/Plugin Creator authoring flow to register its folder. This repository
does not supply an OpenAI marketplace catalog or a one-click install command.
Package validation is not a live import, public directory approval, or proof the
account can install it. No public listing is claimed. Browser/mobile use requires
a supported installed plugin distribution, not local filesystem skill copying.

Sources: [OpenAI packaging specification](https://developers.openai.com/plugins/build/plugins),
[workspace plugin controls](https://learn.chatgpt.com/docs/enterprise/apps-and-connectors),
[ChatGPT creation/use](https://learn.chatgpt.com/docs/build-plugins),
[separate skill distribution controls](https://learn.chatgpt.com/docs/enterprise/skills).
