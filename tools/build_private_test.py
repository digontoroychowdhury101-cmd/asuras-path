#!/usr/bin/env python3
"""Prepare a private integration/device build; never publishes anything."""
from pathlib import Path
import argparse
import json
import re
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--universe-id',type=int,default=0)
parser.add_argument('--products',type=Path,default=ROOT/'outputs/Phase12-Private-Products.json')
parser.add_argument('--run-cloud-on-start',action='store_true',help='Opt in to isolated fixtures once per real private server job')
parser.add_argument('--cross-job-chain',action='store_true',help='Arm an isolated A-closing/B-running lease and recovery fixture')
args=parser.parse_args()
assert args.universe_id>=0
xml=ET.parse(ROOT/'outputs/Cagebound-Phase12-iPhone-Test.rbxlx')
def name(i): return i.findtext("Properties/string[@name='Name']")
if args.universe_id and args.products.exists():
 mapping=json.loads(args.products.read_text())
 assert mapping['universeId']==args.universe_id and mapping['saleEnabled'] is False
 catalog=next(i for i in xml.getroot().iter('Item') if name(i)=='ShopCatalog')
 source=catalog.find("Properties/string[@name='Source']")
 assert source is not None
 for key,entry in mapping['products'].items():
  assert entry['offsale'] and isinstance(entry['productId'],int) and entry['productId']>10006
  source.text,count=re.subn(r'('+re.escape(key)+r'\s*=\s*\{.*?productId\s*=\s*)\d+',lambda m:m[1]+str(entry['productId']),source.text,count=1,flags=re.S)
  assert count==1,key
 print('Mapped six off-sale products in the private artifact only')
server=next(i for i in xml.getroot().iter('Item') if name(i)=='Bootstrap')
parent=next(i for i in xml.getroot().iter('Item') if server in list(i))
item=ET.SubElement(parent,'Item',{'class':'ModuleScript','referent':'PRIVATE_BACKEND_VALIDATION'})
props=ET.SubElement(item,'Properties')
ET.SubElement(props,'string',name='Name').text='PrivateBackendValidation'
ET.SubElement(props,'ProtectedString',name='Source').text=(ROOT/'tools/qa/PrivateBackendValidation.luau').read_text()
# A separate server-only config makes the allowlist reviewable. Validation never auto-runs.
item=ET.SubElement(parent,'Item',{'class':'ModuleScript','referent':'PRIVATE_VALIDATION_ALLOWLIST'})
props=ET.SubElement(item,'Properties')
ET.SubElement(props,'string',name='Name').text='PrivateValidationUniverse'
ET.SubElement(props,'ProtectedString',name='Source').text=f'return {args.universe_id}\n'
if args.run_cloud_on_start:
 assert args.universe_id==10770990655,'Only the explicitly authorized isolated universe may run on startup'
 item=ET.SubElement(parent,'Item',{'class':'Script','referent':'PRIVATE_CLOUD_RUN'})
 props=ET.SubElement(item,'Properties')
 ET.SubElement(props,'string',name='Name').text='PrivateCloudRun'
 ET.SubElement(props,'ProtectedString',name='Source').text=(ROOT/'tools/qa/PrivateCloudRun.server.luau').read_text()
if args.cross_job_chain:
 assert args.run_cloud_on_start and args.universe_id==10770990655
 item=ET.SubElement(parent,'Item',{'class':'Script','referent':'PRIVATE_CROSS_JOB'})
 props=ET.SubElement(item,'Properties')
 ET.SubElement(props,'string',name='Name').text='PrivateCrossJob'
 ET.SubElement(props,'ProtectedString',name='Source').text=(ROOT/'tools/qa/PrivateCrossJob.server.luau').read_text()
path=ROOT/'outputs/Cagebound-Phase12-Private-Test.rbxlx'
xml.write(path,encoding='utf-8',xml_declaration=True)
print(f'Prepared private test build; universe allowlist={args.universe_id}; isolated startup fixtures={args.run_cloud_on_start}; ranked/purchases disabled')
