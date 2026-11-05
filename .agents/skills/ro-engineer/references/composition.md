# Composition and Roblox lifecycles

Use composition to vary independent behavior without duplicating classes or
building an entity framework. Functions and injected dependencies may suffice.
Preserve existing component APIs.

Define who creates, starts, updates, and destroys components. Wire behavior
through explicit interfaces/signals; retain and end subscriptions. Destroy in
dependency order and guard late callbacks. Caller-owned Models remain so unless
the contract transfers ownership.

## CollectionService and streaming

- Connect tag-added/removed handlers, then process `GetTagged(tag)`. Make
  creation idempotent so overlap cannot attach duplicate components.
- Removal can mean tag removal, leaving the DataModel, destruction, or client
  stream-out. Explicitly release the component and external subscriptions:
  the signal does not clean them up. Handle later stream-in.
- A tagged instance does not guarantee ready descendants. Narrow optional
  values or wait with a timeout and a missing-content path.
- Client tag changes can be overwritten by server replication. Keep
  authoritative behavior on the appropriate side.

## OOP / ECS boundary

For hybrid projects, assign one writer per state field. ECS may own projectile
position/lifetime while a sync step updates render Instances; a boss can expose
a damage interface. Avoid bidirectional mirrors that drift.

Migration is not automatically mechanical: audit ordering, identity, callbacks,
persistence, replication, and cleanup. Read [ECS](ecs.md) only when relevant.

Sources: [CollectionService](https://create.roblox.com/docs/reference/engine/classes/CollectionService),
[streaming signals](https://create.roblox.com/docs/workspace/streaming/techniques).