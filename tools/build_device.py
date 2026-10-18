#!/usr/bin/env python3
"""Build a physical-device instrumentation variant; does not publish or enable paid/ranked features."""
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
xml=ET.parse(root/'outputs/Cagebound-Phase12.rbxlx')
def named(item,name): return item.findtext("Properties/string[@name='Name']")==name
server=next(i for i in xml.getroot().iter('Item') if named(i,'Bootstrap'))
source=server.find("Properties/string[@name='Source']");source.text='workspace:SetAttribute("CageboundDiagnostics",true)\n'+source.text
client=next(i for i in xml.getroot().iter('Item') if named(i,'CageboundClient'))
source=client.find("Properties/string[@name='Source']");source.text+='\n_G.CageboundDiagnostics=diagnostics\n'
parent=next(i for i in xml.getroot().iter('Item') if client in list(i))
item=ET.SubElement(parent,'Item',{'class':'LocalScript','referent':'DEVICE_DIAGNOSTICS'})
props=ET.SubElement(item,'Properties')
ET.SubElement(props,'string',name='Name').text='DeviceDiagnostics'
ET.SubElement(props,'ProtectedString',name='Source').text=(root/'tools/qa/DeviceDiagnostics.client.luau').read_text()
xml.write(root/'outputs/Cagebound-Phase12-iPhone-Test.rbxlx',encoding='utf-8',xml_declaration=True)
print('Built instrumented device place; paid purchases and ranked queue remain disabled')
