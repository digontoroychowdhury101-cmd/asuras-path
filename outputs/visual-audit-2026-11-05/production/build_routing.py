from pathlib import Path
import json,csv
P=Path(__file__).parent
C=json.loads((P/'agent-prompts.json').read_text());A=json.loads((P/'arena-prompts.json').read_text())
r={}
def row(ids,method,human,assets,agents):
 for id in ids.split():r[id]=dict(method=method,human_input=human,assets=assets,agent_prompts=[C.get(x,A.get(x)) for x in agents.split()])
row('AP-01','Existing models; verify integration only','None for model creation: creator says all boss models are constructed. Locate them; in-game status remains to be rechecked.',[],'C00')
row('AP-02','Human/Rodin character design, then agent rig/integration','Approve Lin/Gao/Hermit concepts using C00-exported actual-rig references; supply chosen models/maps.',['H06','H07','H08'],'C06')
row('AP-03 AP-04 AP-05 SN-01','Agent builds/reuses geometry and implements','No new Rodin model required. Review one close/gameplay sample per family.',['B03','B04'],'C02')
row('AP-06','Agent kit + code; preserve PvP footprints','No new Rodin model required; human normal-input/two-client acceptance follows.',['B01','B07'],'C03 C07')
row('DM-01','Agent Blender modular construction + code','No new Rodin model required.',['B01'],'C03')
row('DM-02','Agent Blender damage/grounding kit + code','No new Rodin model required.',['B01','B09'],'C03')
row('DM-03','Human/Rodin hero sculpture + agent kit/integration','Approve and supply H01; agent can finish the daises/ruins while waiting.',['H01','B01'],'C03 C06')
row('DM-04 DM-05','Reuse supplied Foundry_Bell/HanCauldron; agent derives variants','No new Rodin model required.',['B04'],'C03')
row('DM-06','Agent modular architecture + code','No new Rodin model required.',['B01','B09'],'C03')
row('DM-07','Agent small prop kit + code','No new Rodin model required.',['B10'],'C03')
row('DM-08','Human/Rodin relief, agent exact facade/door frame','Supply H04 carving; agent handles the entire precise structure and route.',['H04','B01'],'C03 C06')
row('DM-09','Agent terrain/water/VFX and fitting','No Rodin waterfall or whole alcove model required.',['B06','B09'],'C03 C05')
row('DM-10','Arena redesign: agent layout/architecture; human taste review','No new boss model. Hero sculpture optional, existing statue assets can be reused.',['B01','B07','B09'],'AR00 AR02')
row('BP-01','Arena redesign: agent layout/terrain/foliage','No new boss model. H03 root module is optional and reusable from Titan.',['B06','B09','H03 optional'],'AR00 AR03')
row('LT-01','Direct code/fixture placement and real-view calibration','Compare normal-profile captures; no new 3D model needed. No need to approve routine numeric fixes before they are made reviewable.',[],'C01 C07')
row('AC-01','Agent architecture kit; coordinate with larger Shen arena','No new Rodin model required.',['B01','B07'],'C03 AR00 AR01')
row('AC-02','Reuse matching existing statue source; agent small prop variants','No new statue commission required if standing statue source is available.',['B09','B10'],'C03')
row('AC-03','Arena redesign: agent terrain/arcades/seating/landmark','Approve the rendered scene composition; no whole-scene Rodin asset.',['B01','B07','B09'],'AR00 AR01')
row('SD-01','Agent crypt kit + human hero root module; enlarged Titan chamber','Supply H03 after the measured room prototype. Optional H04 is reusable.',['H03','B01','B02'],'C04 C06 AR00 AR04')
row('SD-02','Agent skull/niche kit first; optional Rodin fallback','No human model required if the agent sample reads well. H09 is a complete optional image/Rodin prompt if it does not.',['B02','H09 optional'],'C04')
row('SD-03','Agent coffin/lid modules; preserve or explicitly migrate crossing','No new Rodin model required.',['B02'],'C04')
row('SD-04','Agent open-link restraints + code placement','No new Rodin model required; fit to supplied Titan scale.',['B05'],'C04')
row('SD-05','Agent water/terrain/grounding','No new Rodin model required.',['B06','B09'],'C04 AR04')
row('SD-06','Agent small candle/FX kit','No new Rodin model required.',['B10'],'C04')
row('CP-01','Human/Rodin throne + agent loft/frame integration','Approve H02 and supply its chosen export/maps.',['H02','B01'],'C05 C06')
row('CP-02','Reuse Foundry_Bell; agent suspension/frame','No new Rodin model required.',['B04'],'C05')
row('CP-03','Agent small foliage mesh + water/terrain','No new Rodin model required.',['B06','B09'],'C05')
row('CP-04','Agent precise timber/stone construction','No new Rodin model required.',['B01'],'C05')
row('CP-05','Arena redesign: agent mirror court/lighting/bounds; supplied throne','H02 is the only recommended human focal prop here; whole lake/sky built in engine.',['H02','B06','B07','B08'],'AR00 AR05')
row('SC-01','Direct code placement; agent simple chain geometry','No human/Rodin work required.',['B05'],'C01')
row('SC-02','Agent chain/scale reuse; optional human organic crown','Reuse the supplied Wyrm model/materials; H05 is optional only if the chosen landmark needs it.',['B05','B07','H05 optional'],'C05 AR06')
row('SC-03','Agent masonry kit; enlarged Wyrm scene','No new Rodin model required; H05 optional.',['B01','B07'],'C05 AR00 AR06')
# The creator has supplied every H source; retain actual integration/visual gates.
completed_h={'AP-02':'H06/H07/H08','DM-03':'H01','DM-08':'H04','SD-01':'H03/H04','SD-02':'H09','CP-01':'H02'}
for finding, entry in r.items():
 entry['asset_workflow']='ASSET_WORKFLOW.md'
 if finding in completed_h:
  entry['method']='Supplied approved '+completed_h[finding]+'; ForgeGUI/project lookup and Blender preparation/integration'
  entry['human_input']='Sources already created. Locate approved exports; creator judges actual in-game appearance/rig fit after a concrete comparison. No automatic regeneration.'
 elif entry['method'].startswith('Agent '):
  entry['method']='ForgeGUI/project reuse where suitable; '+entry['method']
 entry['human_input']=entry['human_input'].replace('H05 optional.','H05 already created; place only if useful.').replace('H05 is optional only if','H05 is already created; place only if')
F=json.loads((P.parent/'findings.json').read_text())
assert set(r)=={x['id'] for x in F},(set(r)^{x['id'] for x in F})
(P/'routing.json').write_text(json.dumps(r,indent=2)+'\n')
with (P/'OWNERSHIP_MATRIX.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=['finding','title','method','human_input','assets','agent_prompts'],lineterminator='\n');w.writeheader()
 for a in F:
  b=r[a['id']];w.writerow(dict(finding=a['id'],title=a['title'],method=b['method'],human_input=b['human_input'],assets='; '.join(b['assets']),agent_prompts='; '.join(b['agent_prompts'])))
md=['# Start here — production plan and complete prompts',
 '',
 'Updated 7 November 2026. Extends the [5 November visual audit](../README.md). This packet specifies work; it does '
 'not claim the environments or larger arenas are already implemented. All nine H-assets and all boss designs are '
 'already created. Reconcile current integration against the latest journal.',
 '',
 '## ForgeGUI and Blender',
 '',
 'Read [ASSET_WORKFLOW.md](ASSET_WORKFLOW.md) before executing any batch. Inspect project/imported/supplied assets and '
 'search the connected ForgeGUI account library, public catalog and past MCP jobs before creating an asset. Reuse a suitable existing '
 'model rather than generating a duplicate. ForgeGUI supplies genuinely missing decorative/sculptural components; '
 'Blender handles exact architecture, modular joins, optimization, UVs, baking, collision proxies and rig adaptation. '
 'Roblox code assembles the playable world, terrain, lighting, VFX and encounter systems.',
 '',
 'Preserve the approved H01-H09 and boss designs. Missing local files require a handoff, not regeneration. The '
 'raw-model transfer is AsurasPath_Asset_Handoff_2026-11-07.zip; it does not replace current rigged Shen templates. '
 'Most inspected source exports contain one million triangles. Prepare measured game copies and profile actual scenes.',
 '',
 '## Open these files',
 '',
 '- [ASSET_WORKFLOW.md](ASSET_WORKFLOW.md): ForgeGUI search/reuse, actual capabilities, Blender responsibilities, '
 'credits, source preservation, game preparation and parallel work.',
 '- [WINDOWS_START_HERE.md](WINDOWS_START_HERE.md): current Windows C00 → AR00 → AR01 assignment while Mac debugs '
 'Shen.',
 '- [RELAY_UPDATE.md](RELAY_UPDATE.md): historical relay note; newer PROJECT_STATE and Shen handoffs supersede its old '
 'integration status.',
 '- [ART_DIRECTION.md](ART_DIRECTION.md): all nine scene references and their composition/material lessons.',
 '- [ASSET_PROMPTS.md](ASSET_PROMPTS.md): the nine already-created H-assets and B-kit reuse/construction briefs. '
 'Legacy IMAGE_TO_RODIN filenames remain stable; their workflow is updated.',
 '- [ARENAS.md](ARENAS.md): six larger scenes, measured-plan requirements, dependencies and full prompts.',
 '- [OWNERSHIP_MATRIX.csv](OWNERSHIP_MATRIX.csv): all 36 original finding families, asset routes and prompt files.',
 '',
 '## Run order and current parallel work',
 '',
 '1. C00 reconciles the latest source, existing project and ForgeGUI assets, supplied model intake and '
 'rig/scale/camera measurements. Skip completed work and refresh only stale measurements.',
 '2. AR00 creates a coherent six-arena coordinate manifest and two reversible larger prototypes per arena. Record '
 'provisional clearances where the final boss implementation is unavailable.',
 '3. C01 fixes the traced chain placement and route readability. AR01 is the first finished arena pilot; inspect its '
 'normal-camera composition before extending shared architectural/material treatment across all scenes.',
 '4. C02 → C03 → C04 → C05 builds/reuses the required kits. C06 prepares the nine supplied H-assets, including '
 'H05/H09, and stages arena-specific models until their final anchors exist. Reuse existing ForgeGUI/project results '
 'throughout.',
 '5. AR02 → AR03 → AR04 → AR05 → AR06 finishes the remaining scenes sequentially using AR00 and the validated kits.',
 '6. C07 provides final integrated Windows, normal-input, genuine multiplayer and profiling evidence, plus declared '
 'Mac/device comparison. It cannot replace outstanding combat verification stages.',
 '',
 'Currently Mac owns Shen integration; Windows may complete C00 → AR00 → AR01 on codex/windows-arenas in an isolated '
 'checkout/Studio build. Boss debugging need not finish before independent environment construction. Combine completed '
 'boss/arena pairs at deliberate checkpoints and refresh affected measurements; keep combined fight acceptance pending '
 'until checked. This overrides older blanket instructions to push every task directly to ux/onboarding-overhaul.',
 '',
 'Commit/push only owned files, with task-specific handoffs and required checks. One integration owner combines shared '
 'mappings, bounds, spawns and camera changes. Avoid automatic rebase/autostash, broad staging and force-push during '
 'parallel editing. Git does not transfer ignored raw models or .blend files.',
 '',
 '## Reading an ID such as AR03',
 '',
 'Claude needs the repository on its current computer and filesystem permission. Prompt IDs are labels, not remote '
 'file access. Start Claude Code in the correct clone/worktree, read the repository-root ENVIRONMENT_PROMPTS.md index, '
 'then open the full mapped file. Regular chat without file access needs the prompt attached or pasted; implementation '
 'also needs repository and Studio/tool access. ForgeGUI must be connected on that computer separately.',
 '',
 'For AR03, read outputs/visual-audit-2026-11-05/production/prompts/AR03_VENERABLEBAIZE_ARENA.md in full, plus '
 'ASSET_WORKFLOW.md and the current C00/AR00 results. Do not infer the detailed task from its ID.',
 '',
 '## Direct agent prompts',
 '',
 '| ID | Task | Full copy-paste file |',
 '|---|---|---|']
titles={'C00':'Current-state/asset/scale intake','C01':'Floating chains + route readability','C02':'Altars, coffers, ladders, smith kit','C03':'Monastery ruins + two PvP ring finishes','C04':'Crypt architecture/funerary/water/chain kit','C05':'Pagoda/Citadel joinery, bell, garden/foliage','C06':'Supplied hero/cast mesh cleanup, rigging and integration','C07':'Integrated Windows/normal-input/multiplayer/profile acceptance'}
for id,path in C.items():md.append(f'| {id} | {titles[id]} | [{path.split("/")[-1]}]({path}) |')
for id,path in A.items():md.append(f'| {id} | '+('Spatial plan + larger prototypes' if id=='AR00' else next(x['name'] for x in json.loads((P/'arenas.json').read_text()) if x['id']==id))+f' | [{path.split("/")[-1]}]({path}) |')
md+=['', 'Each agent file is standalone: copy the full fenced text. It includes project context, scope, exact source/evidence to read, implementation expectations, tests and handoff. Do not paste all 15 implementation prompts into one unbounded job. Finish and inspect each coherent batch before starting the next.','', '## Every audited finding: ownership and prompt','', '| Finding | Production route | Human input | Assets | Agent files |','|---|---|---|---|---|']
for a in F:
 b=r[a['id']];md.append(f'| {a["id"]} · {a["title"]} | {b["method"]} | {b["human_input"]} | '+', '.join(b['assets'])+' | '+', '.join(f'[{Path(x).stem}]({x})' for x in b['agent_prompts'])+' |')
md+=['', '## Current evidence status','', 'The existing tour covers seven regions and 53 named campaign layout zones with settled actor and/or scripted-camera samples, 135 scripted captures and seven short normal-camera keyboard samples. This remains an assisted visual audit, not an earned all-secrets playthrough. The temporary helper/cheats were restored and both owned Play sessions stopped; the post-tour script digest and canonical place bytes match the pre-tour state. See [restoration.json](../restoration.json).','', 'This production extension adds prompts and references only. Boss assets are creator-reported constructed; their new in-game integration has not been reverified by this document. Proposed arena dimensions are not tested facts. No paid model/image generation or production game change was performed to prepare the packet.','']
(P/'README.md').write_text('\n'.join(md))
print('Mapped all',len(r),'findings to explicit ownership/assets/complete agent prompts')

# Discoverable root index and standalone current Windows assignment.
index=["# Asura's Path environment prompt index", '',
       'Updated 7 November 2026. Read this file from the current repository checkout. Prompt IDs do not grant access to another computer or transfer model files.', '',
       'Read [asset workflow](outputs/visual-audit-2026-11-05/production/ASSET_WORKFLOW.md) and [production run order](outputs/visual-audit-2026-11-05/production/README.md). Current Windows assignment: [C00 → AR00 → AR01](outputs/visual-audit-2026-11-05/production/WINDOWS_START_HERE.md), while Mac owns Shen integration.', '',
       '| ID | Full prompt |', '|---|---|']
for key,path in {**C,**A}.items():
 index.append(f'| {key} | [{Path(path).name}](outputs/visual-audit-2026-11-05/production/{path}) |')
index += ['', 'H01-H09 already exist. Their historical IMAGE_TO_RODIN files now contain reuse-first ForgeGUI/Blender instructions; see [asset briefs](outputs/visual-audit-2026-11-05/production/ASSET_PROMPTS.md).', '',
          'Example: "Read ENVIRONMENT_PROMPTS.md, open the full AR03 file and ASSET_WORKFLOW.md, inspect the latest C00/AR00 results, and execute only AR03 on the assigned task branch. Preserve the active Mac Shen work."', '',
          'The current 7 November update is documentation only. Read the latest PROJECT_STATE and task results for actual implementation status. No generation, upload or gameplay acceptance is implied by these prompts.', '']
(P.parents[2]/'ENVIRONMENT_PROMPTS.md').write_text('\n'.join(index),encoding='utf-8')
c00=(P/C['C00']).read_text()
c00_body=c00.split('```text\n',1)[1].rsplit('```',1)[0].strip()
windows_prefix="""Mac is currently debugging Grandmaster Shen. Windows owns the environment C00 → AR00 → AR01 run on codex/windows-arenas in an isolated checkout/Studio build.
Read ENVIRONMENT_PROMPTS.md and the full ASSET_WORKFLOW.md. Complete missing/stale C00 work below, then read and execute the complete AR00 and AR01 files mapped by the index, one coherent batch at a time. Do not redo completed work or infer a task from its short ID.
Use ForgeGUI/project asset reuse first, ForgeGUI for missing in-scope decorative/sculptural components, and Blender for precision construction and game preparation. All nine H-assets and boss source designs already exist. The approved raw export handoff is AsurasPath_Asset_Handoff_2026-11-07.zip; locate registered copies or record missing files, never regenerate the queue.
A ForgeGUI connection on Mac does not establish one on Windows. Discover actual tools; continue independent work if a connection/source is missing. C00/AR00 do not launch paid generation.

C00 DETAILED TASK
"""
windows_end="""
FINAL OVERRIDES FOR THIS WINDOWS RUN
1. Work only on the assigned isolated arena branch/build. Commit/push only owned changes; do not overwrite Mac's active place or merge into the shared relay branch during its debugging session.
2. After completing/checkpointing C00, execute the complete AR00 prompt, then AR01. C01 and AR02-AR06 are outside this run.
3. Use actual approved models at intended scale where available. Label estimated movement/phase clearance and proxies provisional. Mac's uncommitted rig work may be absent; do not interpret that as deleted implementation.
4. Finish independent environment construction and available checks. Keep boss-dependent fight/phase/flight/telegraph/camera acceptance pending where the stable implementation is unavailable.
5. Provide owned changed files, asset source/artifact/version manifest, before/after evidence, checks and exact integration steps. Combine stable Shen/AR01 work at a deliberate integration checkpoint. Do not publish the game.
"""
(P/'WINDOWS_START_HERE.md').write_text('# Windows — C00, AR00 and AR01 while Mac integrates Shen\n\n```text\n'+windows_prefix+'\n'+c00_body+'\n'+windows_end+'```\n',encoding='utf-8')
