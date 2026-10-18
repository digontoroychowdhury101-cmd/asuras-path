#!/usr/bin/env python3
"""Generate a local-only native rendering benchmark. Never publish this artifact."""
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
xml=ET.parse(root/'outputs/Cagebound-Phase12-iPhone-Test.rbxlx')
name=lambda i:i.findtext("Properties/string[@name='Name']")
parent=next(i for i in xml.getroot().iter('Item') if name(i)=='StarterPlayerScripts')
i=ET.SubElement(parent,'Item',{'class':'LocalScript','referent':'LOCAL_NATIVE_BENCHMARK'})
p=ET.SubElement(i,'Properties')
ET.SubElement(p,'string',name='Name').text='ForegroundBenchmark'
ET.SubElement(p,'ProtectedString',name='Source').text=(root/'tools/qa/ForegroundBenchmark.client.luau').read_text()
out=root/'work/Cagebound-Phase12-Foreground-Benchmark.rbxlx';xml.write(out,encoding='utf-8',xml_declaration=True)
print('Built local-only normal RenderStep benchmark:',out)
