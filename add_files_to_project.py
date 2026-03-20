#!/usr/bin/env python3
"""Add missing Swift files to the Xcode project properly."""
import re
import hashlib

PBXPROJ = "ILSApp/ILSApp.xcodeproj/project.pbxproj"

with open(PBXPROJ, "r") as f:
    content = f.read()

def gen_id(seed):
    h = hashlib.md5(seed.encode()).hexdigest().upper()
    return h[:24]

# Anchor entries that appear only in each target's Sources build phase
# (the `,` suffix distinguishes them from the PBXBuildFile definition which ends with `= {`)
ANCHOR_ILS_ENTRY  = "A154E5D4BF2B0E80683778B9 /* SessionCheckpointsView.swift in Sources */,"
ANCHOR_MAC_ENTRY  = "1FCDA853824C5CC0896B74E1 /* SessionCheckpointsView.swift in Sources */,"
ANCHOR_NAME       = "SessionCheckpointsView.swift"

SESSIONS_GROUP   = "6F49257F38D17C70764B897D"
VIEWMODELS_GROUP = "CF667032F0641715AC1D846F"
SERVICES_GROUP   = "BA480E94C563D561E67BEEF5"

FILES = [
    ("SessionRecoveryService.swift",
     SERVICES_GROUP,   "srvc",
     "SessionMonitorService.swift", "FBC4C0F2BDC4C6D703AA925D"),
    ("SessionRecoveryViewModel.swift",
     VIEWMODELS_GROUP, "vmvm",
     "SessionCheckpointsViewModel.swift", "448A55AEFBD34AD89EA6C69C"),
    ("SessionRecoveryBannerView.swift",
     SESSIONS_GROUP,   "bnvw",
     ANCHOR_NAME, "AB21906489F9396858EEBC0E"),
    ("RecoveryTimelineView.swift",
     SESSIONS_GROUP,   "tlvw",
     ANCHOR_NAME, "AB21906489F9396858EEBC0E"),
]

new_content = content

for filename, group_id, seed, group_anchor, group_anchor_ref_id in FILES:
    already = re.search(r'isa = PBXFileReference[^;]+path = ' + re.escape(filename), new_content)
    if already:
        print(f"SKIP: {filename} already a PBXFileReference")
        continue

    file_ref_id  = gen_id(f"{seed}_ref_{filename}")
    build_id_app = gen_id(f"{seed}_buildapp_{filename}")
    build_id_mac = gen_id(f"{seed}_buildmac_{filename}")
    print(f"Adding: {filename}")

    # 1. Add PBXFileReference
    new_fileref = (
        f'\t\t{file_ref_id} /* {filename} */ = '
        f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
        f'path = {filename}; sourceTree = "<group>"; }};\n'
    )
    pos = new_content.find("/* End PBXFileReference section */")
    new_content = new_content[:pos] + new_fileref + new_content[pos:]

    # 2. Add to group children
    anchor_in_group = f"{group_anchor_ref_id} /* {group_anchor} */"
    if anchor_in_group in new_content:
        new_content = new_content.replace(
            anchor_in_group + ",",
            anchor_in_group + f",\n\t\t\t\t{file_ref_id} /* {filename} */,",
            1
        )
        print(f"  Added to group")
    else:
        print(f"  WARNING: group anchor not found")

    # 3. Add PBXBuildFile entries
    for build_id in [build_id_app, build_id_mac]:
        new_bf = (
            f'\t\t{build_id} /* {filename} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n'
        )
        pos2 = new_content.find("/* End PBXBuildFile section */")
        new_content = new_content[:pos2] + new_bf + new_content[pos2:]

    # 4. Add to ILSApp Sources build phase
    # Use the comma-terminated entry which appears only in the Sources build phase list
    app_insert = f"\n\t\t\t\t{build_id_app} /* {filename} in Sources */,"
    new_content = new_content.replace(
        ANCHOR_ILS_ENTRY,
        ANCHOR_ILS_ENTRY + app_insert,
        1
    )
    print(f"  Added to ILSApp Sources phase")

    # 5. Add to ILSMacApp Sources build phase
    mac_insert = f"\n\t\t\t\t{build_id_mac} /* {filename} in Sources */,"
    new_content = new_content.replace(
        ANCHOR_MAC_ENTRY,
        ANCHOR_MAC_ENTRY + mac_insert,
        1
    )
    print(f"  Added to ILSMacApp Sources phase")

with open(PBXPROJ, "w") as f:
    f.write(new_content)

print("Done!")
