# System design

Adapt module ownership and data flow to the existing project. Inspect startup,
callers, persistence, remotes, and installed frameworks before changing structure.
The layout and lifecycle below are examples, not migration requirements.

## Module boundaries

- One system per responsibility: `CurrencyService`, `InventoryService`,
  `RoundController`, `ShopUI`.
- A system owns its state and exposes functions and signals. Nobody else
  writes its state.
- Split by what changes together, not by object type. If two modules always
  change in the same commit, they may be one module.
- Keep shared code in `ReplicatedStorage/Shared` (types, config, pure
  functions). Server-only code in `ServerScriptService`/`ServerStorage`.
  Client-only code in `StarterPlayerScripts`/`ReplicatedStorage/Client`.

## Typical layout

```
ReplicatedStorage/
  Shared/         types, config (frozen), pure utils, remote definitions
  Client/         client controllers, UI
  Packages/       Wally or vendored libraries
ServerScriptService/
  Main.server.luau        bootstraps services
ServerStorage/
  Services/       server systems
StarterPlayer/StarterPlayerScripts/
  Main.client.luau        bootstraps controllers
```

For new multi-service designs, a bootstrap with explicit ordering can help.
Preserve the existing framework/startup model when extending a project.

## Lifecycle

```
init()   -- create state, no cross-system calls
start()  -- connect events, call other systems
```

Two phases can separate dependency wiring from activation; they do not by
themselves prevent require cycles or asynchronous startup races. Use the
project's lifecycle contract and handle failures explicitly.

## Ownership map

For each piece of state, write down:

| State | Owner | Lives on | Replicated how | Persisted |
|---|---|---|---|---|
| Coins | CurrencyService | Server | Attribute on player / remote | DataStore |
| Round phase | RoundService | Server | Attribute on workspace | No |
| Shop open | ShopUI | Client | n/a | No |

If two systems claim the same state, redesign.

## Interfaces first

Define each system's public surface before internals:

```lua
export type CurrencyService = {
	getBalance: (player: Player) -> number,
	add: (player: Player, amount: number, reason: string) -> (),
	trySpend: (player: Player, amount: number, reason: string) -> boolean,
	balanceChanged: Signal<Player, number>,
}
```

- Functions for commands and queries, signals for "something happened".
- Pass ids and plain data across boundaries, not internal objects.
- Include a `reason` on economy mutations for logging and analytics.

## Dependencies

- Dependencies point one way. Draw the graph; break cycles by introducing a
  signal or moving shared logic down into a lower module.
- High-level systems (Round) depend on low-level ones (Currency), not the
  reverse. Low-level systems announce via signals.
- Avoid a global "GameManager" that knows everything.

## Data flow

Typical flow for a player action:

```
Client input -> Client controller -> Remote (request)
  -> Server handler: validate -> System command -> State change
  -> Signal -> Replication -> Client UI update
```

The client may predict for feel, but the server result wins.

## Persistence

- One data module owns load/save per player, with session locking (e.g.
  ProfileStore-style libraries; **[verify]** current recommendation).
- Use the persistence owner's periodic, leave, and shutdown save paths; avoid
  duplicate competing saves. Handle failed requests and shutdown time limits.
- Version the saved schema and migrate on load.
- Respect DataStore request budgets; never save per change.

## Config and tuning

Put designer-adjustable values in the existing config system. Typed/frozen
tables are useful when compatible; ordinary constants do not need a new module.
