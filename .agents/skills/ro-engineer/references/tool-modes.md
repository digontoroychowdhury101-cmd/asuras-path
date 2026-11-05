# Tool capabilities and evidence

Select capabilities, not product labels. Studio bridges may expose search,
read/edit, Luau execution, play controls, logs, and place selection under
different names. ROTEX may expose library context, system search, dependencies,
call sites, or validation. Inspect actual tools and permissions first.

1. Identify repository/place and whether execution acts in edit, server, or
   client context. Read-only access can still support diagnosis.
2. Read implementation, callers, remotes, data schemas, package versions,
   and resource ownership. Retrieve only needed ROTEX interfaces; documentation
   is not proof a module is installed in the current place.
3. Use the authorized writer: local files with existing sync, or the Studio
   bridge. Avoid competing writers; verify resulting script content. Execution
   tools can also mutate the place.
4. Determine whether validation checks syntax, types, library usage, or runtime
   behavior. Inspect test results and new relevant logs. Silence is not a pass.

If a connection fails, continue supported repository/offline work and state
the gap. Do not fabricate playtests. Offline code includes placement and
dependencies; local-file edits still need engine integration tests when relevant.

Do not bundle credentials, invent a ROTEX endpoint, or change MCP configuration
as a side effect. Connect through host-supported setup when requested. The
skill supplies guidance, a plugin distributes it, an MCP connector supplies
tools, and granted capabilities determine possible project actions.