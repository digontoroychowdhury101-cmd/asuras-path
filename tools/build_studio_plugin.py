#!/usr/bin/env python3
"""Build a temporary local-only Studio launcher plugin; never installs or publishes."""
from pathlib import Path
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
launcher=(root/'tools/qa/LaunchStudioTests.luau').read_text()
launcher=launcher.replace(' if not ok then warn(err) end',' button.Enabled=true\n if not ok then warn(err) end')
source='''-- Temporary local plugin. Remove after validation. Never publish this model.
local toolbar=plugin:CreateToolbar("Cagebound QA")
local button=toolbar:CreateButton("RunPhase12","Run local two-client normal and latency tests","")
button.ClickableWhenViewportHidden=true
button.Click:Connect(function()
 if game.PlaceId~=0 or game:GetService("RunService"):IsRunning()
  or not game.ServerScriptService:FindFirstChild("Phase12ServerQA",true) then
  warn("[Cagebound QA12 Plugin] Open the unpublished QA place in edit mode first")
  return
 end
 button.Enabled=false
'''+launcher+'''\nend)
print("[Cagebound QA12 Plugin] Ready; unpublished QA only; no automatic test or publication")
'''
path=root/'work/ui-continuation/CageboundStudioLauncher.luau'
path.write_text(source)
xml=ET.Element('roblox',{'version':'4'})
item=ET.SubElement(xml,'Item',{'class':'Script','referent':'CAGEBOUND_QA_LAUNCHER'})
props=ET.SubElement(item,'Properties')
ET.SubElement(props,'string',name='Name').text='CageboundStudioLauncher'
ET.SubElement(props,'ProtectedString',name='Source').text=source
ET.ElementTree(xml).write(path.with_suffix('.rbxmx'),encoding='utf-8',xml_declaration=True)
print('Built temporary local QA plugin in work/ui-continuation; installation is a separate Studio action')
