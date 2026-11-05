# Object pooling

Consider pooling when representative profiles show repeated creation/destruction
or allocation causes material spikes. Rare, long-lived, or costly-to-reset
objects may be cheaper to create normally. Reuse a suitable project pool.

## Lifecycle contract

- Acquire transfers temporary ownership; release accepts active leases only.
  Detect double release, foreign objects, and stale callbacks.
- End the active lifetime on release: disconnect hit handlers, cancel tweens
  and delayed work, stop/clear effects, and remove external references.
- Before reuse, restore transform, velocity, collision/query/touch flags,
  transparency, attributes, sounds, emitters, and children as applicable.
  Reset can be split across release/acquire, but idle objects must be inert.
  Generation ids can prevent old callbacks mutating a new lease.
- Define pool teardown, including active leases and retained objects. Generic
  pools need a disposal callback, not only Instance cleanup.

## Capacity and placement

Measure active peak and burst demand. Distinguish idle retention cap from
active limit; define whether exhaustion grows, rejects, or degrades cosmetic
work. Prewarm within loading/memory budgets and reclaim overflow.

Parking in Workspace can retain replication/physics cost; unparenting has
reparenting costs. Compare strategies. For parked parts, account for anchoring,
`CanCollide`, `CanTouch`, and `CanQuery`.

Local VFX can use client pools; gameplay authority stays on the server even
when clients render compact state. Cover hit, timeout, respawn, owner departure,
and shutdown. Compare peak frame time and retained memory/Instance counts;
remove complexity if it yields no useful benefit.