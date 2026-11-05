# Bamboo arena and shrine handoff

Computers B and C can pull `ux/onboarding-overhaul` and open `places/AsurasPath.rbxlx`.
The checked-in binary mirror and output copy were refreshed in the same build.

- Canonical XML SHA-256: `6114dc3c57f52af9b3d4b21a5a09ba70cb86fdf57cf7ec9d49f2fdadbad2040c`
- Binary mirror SHA-256: `c3a505a7b36993e581db5f520f690572782fe5bacee9f7bf27664d7a181cf953`
- Open Studio and canonical source: 281 scripts, 2,243,876 bytes, digest `1802037792`

The arena boundary has 50 timber bays divided by stone sills and piers. Three existing Lobby Kit
meshes supply the geometry. Engine wood plank material replaces the previous dark albedo, while the
stone pieces keep their PBR maps. The five walls have 255 decorative mesh parts and 21,600 triangles.
Six soil pockets at the shrine add six ferns and twelve litter patches around the existing approach.

The Play audit checked the five original wall transforms and sizes, a query against the west wall,
both gate openings, and the decorative collision flags. It read the real uploaded mesh triangle
counts. The first audit hit Studio's capability restriction on requiring the layout module. The
successful audit compared the live geometry directly against the five authored wall definitions.
Studio returned to Edit. All 14 local verification stages passed.

`stone-cedar-final` contains four matched arena views, a matched shrine view, a ground detail and
the runtime audit. The five pairs match camera, 1271×685 viewport, FOV, Bamboo lighting, Automatic
FRM1, Detailed tier and HUD state. These static observer captures document the material and placement
changes. Normal camera traversal, sustained desktop timing, physical mobile and the other regions
remain open for the larger environment goal.
