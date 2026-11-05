# Implement or fix Roblox code

1. Read affected scripts, dependencies, callers, and relevant project conventions.
   With ROTEX, retrieve the interfaces/versions needed for integration.
2. Reuse suitable code. For a small fix, act directly. For substantial changes,
   settle ownership, interfaces, migration, and verification first; use
   [system design](design-system.md) if needed. Continue work already authorized.
3. Make a targeted change that preserves surrounding contracts. Correct routine
   implementation details; ask about material requirement conflicts or scope
   changes. The [module template](../templates/module-template.md) is optional.
4. Load only applicable references: [Luau](../references/luau-modern.md) for a
   language/API issue, [security](../references/client-server-boundaries.md) for
   trust boundaries, and the relevant pattern/lifecycle reference as needed.
5. Validate according to [testing](../references/testing.md). Use configured
   static checks and applicable runtime tests; examine console output and
   integration behavior. ROTEX validation is evidence only for its actual scope.
6. Report files/instances changed, behavior, checks run/results, and unverified
   work. Offline outputs include path/service, script type, dependencies, and
   concrete manual checks. Do not call generated code tested.