#!/usr/bin/env python3
"""Check Sources build phase anchor format."""
with open("ILSApp/ILSApp.xcodeproj/project.pbxproj", "r") as f:
    content = f.read()

anchor = "A154E5D4BF2B0E80683778B9"
positions = []
start = 0
while True:
    pos = content.find(anchor, start)
    if pos < 0:
        break
    positions.append(pos)
    start = pos + 1

for pos in positions:
    ctx = content[pos:pos+120]
    print(f"pos {pos}: {repr(ctx)}")
    print()
