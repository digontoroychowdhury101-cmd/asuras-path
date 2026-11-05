# Design a system that fits the project

Inspect existing interfaces, callers, startup, state/persistence, remotes,
lifecycle, installed packages, and available tests before proposing structure.
Reuse or extend a suitable implementation. State assumptions when inaccessible.

For a significant design:
- Map state owners, client/server placement, replication, persistence, and
  migrations. Consult [system design](../references/system-design.md).
- Compare approaches using [pattern selection](../references/pattern-selection.md).
  Explain fit/trade-offs and plausible alternatives briefly. Do not load all
  pattern references; read the selected one when its details are needed.
- Define changed interfaces, dependencies, compatibility, and rollback.
- For networked work, apply [security](../references/client-server-boundaries.md);
  read [transport](../references/networking-remotes.md) if selecting remotes.
- Define expected scale/update rate, device budget, resource ownership,
  failure handling, and observable validation.

The [design template](../templates/design-doc-template.md) is optional. Link a
game loop only if the task changes player behavior. Continue authorized
implementation; seek input for material unresolved requirements or actions
outside scope, not routine design details.