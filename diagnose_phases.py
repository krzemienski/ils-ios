#!/usr/bin/env python3
"""Find and diagnose PBXSourcesBuildPhase definitions."""
import re

with open("ILSApp/ILSApp.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

# Find the actual PBXSourcesBuildPhase definitions
phases = list(re.finditer(
    r'([0-9A-F]{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase',
    content
))
print(f"Found {len(phases)} PBXSourcesBuildPhase definitions:")
for p in phases:
    print(f"  ID: {p.group(1)}")
    # Find the files list
    pos = p.start()
    end = content.find("};", pos + 100)
    block = content[pos:end+2]
    has_ckpts = "SessionCheckpointsView" in block
    has_anchor_ils = "A154E5D4BF2B0E80683778B9" in block
    has_anchor_mac = "1FCDA853824C5CC0896B74E1" in block
    print(f"  has SessionCheckpointsView: {has_ckpts}")
    print(f"  has ILSApp anchor ({has_anchor_ils}), ILSMacApp anchor ({has_anchor_mac})")
    print(f"  block length: {len(block)}")
    print()
