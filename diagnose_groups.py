#!/usr/bin/env python3
"""Diagnose which groups contain our anchor files."""
import re

with open("ILSApp/ILSApp.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

targets = {
    "SessionCheckpointsViewModel.swift": "448A55AEFBD34AD89EA6C69C",
    "SessionMonitorService.swift": None,
    "SessionCheckpointsView.swift": "AB21906489F9396858EEBC0E",
}

for name, ref_id in targets.items():
    if ref_id is None:
        m = re.search(r'([0-9A-F]{24}) /\* ' + re.escape(name) + r' \*/ = \{isa = PBXFileReference', content)
        if m:
            ref_id = m.group(1)
        else:
            print(f"{name}: NOT FOUND as PBXFileReference")
            continue

    positions = [i for i in range(len(content)) if content[i:i+24] == ref_id]
    print(f"\n{name} (ref={ref_id}) appears at {len(positions)} positions:")
    for pos in positions:
        ctx = content[pos:pos+80]
        print(f"  {ctx}")

    # Find which group contains this file ref
    group_pattern = re.compile(r'([0-9A-F]{24}) /\* ([^*]+) \*/ = \{\s*isa = PBXGroup')
    groups = list(group_pattern.finditer(content))
    for i, gm in enumerate(groups):
        gstart = gm.start()
        gend = groups[i+1].start() if i+1 < len(groups) else len(content)
        segment = content[gstart:gend]
        if ref_id in segment and "children" in segment[:segment.find(ref_id)]:
            print(f"  -> In group: {gm.group(2).strip()} ({gm.group(1)})")
