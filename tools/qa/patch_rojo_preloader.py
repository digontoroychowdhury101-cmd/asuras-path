"""Patch Rojo 7.7.1 typed audio preloading in an XML copy; never installs or edits other modules.
Usage: python3 tools/qa/patch_rojo_preloader.py SOURCE.rbxmx DEST.rbxmx
Based on rojo-rbx/rojo issue #1342 and upstream PR #1344 (typed Sound preloading).
"""
from pathlib import Path
import sys,xml.etree.ElementTree as E,hashlib,json
source,target=map(Path,sys.argv[1:3]);doc=E.parse(source);matches=[]
for item in doc.iter('Item'):
 props=item.find('Properties')
 if props is not None and props.findtext('string[@name="Name"]')=='preloadAssets':
  matches.append(next(p for p in props if p.get('name')=='Source'))
assert len(matches)==1,'Expected exactly one Rojo preloadAssets module'
node=matches[0];old=node.text
assert 'ContentProvider:PreloadAsync(contentUrls)' in old and 'gatherAssetUrlsRecursive(Assets)' in old
node.text='''-- Typed preloading fixes rojo-rbx/rojo#1342. Images remain strings; audio is a Sound.
local ContentProvider = game:GetService("ContentProvider")
local Packages = script.Parent.Parent.Packages
local Log = require(Packages.Log)
local Assets = require(script.Parent.Assets)
local function preloadAssets()
 local content, sounds = {}, {}
 local function gather(t, audio)
  for key, value in t do
   if typeof(value) == "table" then gather(value, audio or key == "Sounds")
   elseif typeof(value) == "string" then
    if audio then
     local sound = Instance.new("Sound")
     sound.SoundId = value
     table.insert(sounds, sound)
     table.insert(content, sound)
    else table.insert(content, value) end
   end
  end
 end
 gather(Assets, false)
 Log.trace("Preloading typed assets: {:?}", content)
 task.spawn(function()
  local ok, err = pcall(function() ContentProvider:PreloadAsync(content) end)
  for _, sound in sounds do sound:Destroy() end
  if not ok then warn("[Rojo] Asset preload failed: " .. tostring(err)) end
 end)
end
return preloadAssets
'''
doc.write(target,encoding='utf-8',xml_declaration=True)
print(json.dumps({'changedModule':'preloadAssets','originalSourceSha256':hashlib.sha256(old.encode()).hexdigest(),'patchedSourceSha256':hashlib.sha256(node.text.encode()).hexdigest(),'source':str(source),'target':str(target)}))
