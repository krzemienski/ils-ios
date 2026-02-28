#!/usr/bin/env python3
"""Add analytics Swift files to ILSApp.xcodeproj/project.pbxproj."""

import hashlib
import re
import sys

PBXPROJ = "ILSApp/ILSApp.xcodeproj/project.pbxproj"

# IOS Views group ID (B385414DDDDE6CDD82D4141C)
IOS_VIEWS_GROUP_ID = "B385414DDDDE6CDD82D4141C"
# ViewModels group ID
VIEWMODELS_GROUP_ID = "CF667032F0641715AC1D846F"
# iOS sources build phase ID
IOS_SOURCES_ID = "A4A7DF60096F1CE481CCEC80"
# macOS sources build phase ID
MAC_SOURCES_ID = "FDA1036F55730F8285233415"


def gen_id(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest().upper()[:24]


def unique_id(seed: str, existing: set) -> str:
    candidate = gen_id(seed)
    while candidate in existing:
        candidate = gen_id(candidate + "_col")
    existing.add(candidate)
    return candidate


def main():
    with open(PBXPROJ, "r") as f:
        content = f.read()

    existing_ids = set(re.findall(r"\b([0-9A-F]{24})\b", content))

    # Files to add: (basename, relative_path_from_ILSApp_dir, add_to_mac_target)
    FILES = [
        ("AnalyticsViewModel.swift", "ViewModels/AnalyticsViewModel.swift", True),
        ("ActivityTimelineView.swift", "Views/Analytics/ActivityTimelineView.swift", True),
        ("AnalyticsView.swift", "Views/Analytics/AnalyticsView.swift", True),
        ("SessionMetricsView.swift", "Views/Analytics/SessionMetricsView.swift", True),
        ("SkillUsageView.swift", "Views/Analytics/SkillUsageView.swift", True),
    ]

    # Check which are already referenced
    file_refs_in_proj = set()
    for m in re.finditer(r"/\*\s+(\S+\.swift)\s+\*/", content):
        file_refs_in_proj.add(m.group(1))

    missing = [(b, r, mac) for b, r, mac in FILES if b not in file_refs_in_proj]
    if not missing:
        print("All analytics files already referenced in project. Nothing to do.")
        return

    print(f"Adding {len(missing)} missing file(s):")
    for b, r, _ in missing:
        print(f"  + {r}")

    # Generate IDs for each missing file
    file_data = []
    for basename, rel_path, add_to_mac in missing:
        fref_id = unique_id(f"{rel_path}::fileref", existing_ids)
        build_ios_id = unique_id(f"{rel_path}::build::ios", existing_ids)
        build_mac_id = unique_id(f"{rel_path}::build::mac", existing_ids) if add_to_mac else None
        file_data.append((basename, rel_path, fref_id, build_ios_id, build_mac_id, add_to_mac))

    # Generate ID for Analytics group
    analytics_group_id = unique_id("Views/Analytics::group", existing_ids)

    # -----------------------------------------------------------------------
    # 1. Add PBXFileReference entries
    # -----------------------------------------------------------------------
    fref_entries = []
    for basename, _, fref_id, _, _, _ in file_data:
        fref_entries.append(
            f'\t\t{fref_id} /* {basename} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; path = {basename}; '
            f'sourceTree = "<group>"; }};'
        )
    fref_block = "\n".join(fref_entries) + "\n"
    marker = "/* End PBXFileReference section */"
    if marker not in content:
        print("ERROR: PBXFileReference section end marker not found")
        sys.exit(1)
    content = content.replace(marker, fref_block + marker)
    print("✓ Added PBXFileReference entries")

    # -----------------------------------------------------------------------
    # 2. Add PBXBuildFile entries
    # -----------------------------------------------------------------------
    build_entries = []
    for basename, _, fref_id, build_ios_id, build_mac_id, add_to_mac in file_data:
        build_entries.append(
            f"\t\t{build_ios_id} /* {basename} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {fref_id} /* {basename} */; }};"
        )
        if add_to_mac and build_mac_id:
            build_entries.append(
                f"\t\t{build_mac_id} /* {basename} in Sources */ = "
                f"{{isa = PBXBuildFile; fileRef = {fref_id} /* {basename} */; }};"
            )
    build_block = "\n".join(build_entries) + "\n"
    marker = "/* End PBXBuildFile section */"
    if marker not in content:
        print("ERROR: PBXBuildFile section end marker not found")
        sys.exit(1)
    content = content.replace(marker, build_block + marker)
    print("✓ Added PBXBuildFile entries")

    # -----------------------------------------------------------------------
    # 3. Create Analytics PBXGroup
    # -----------------------------------------------------------------------
    analytics_view_files = [(b, fref) for b, r, fref, _, _, _ in file_data if "Views/Analytics" in r]
    analytics_children = "\n".join(
        [f"\t\t\t\t{fref} /* {b} */," for b, fref in analytics_view_files]
    )
    analytics_group_entry = (
        f"\t\t{analytics_group_id} /* Analytics */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"{analytics_children}\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = Analytics;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    end_group = "/* End PBXGroup section */"
    if end_group not in content:
        print("ERROR: PBXGroup section end marker not found")
        sys.exit(1)
    content = content.replace(end_group, analytics_group_entry + end_group)
    print("✓ Created Analytics PBXGroup")

    # -----------------------------------------------------------------------
    # 4. Add Analytics group to iOS Views group children
    # -----------------------------------------------------------------------
    # Find the Views group by ID and insert the Analytics group into its children
    views_pattern = (
        rf"({re.escape(IOS_VIEWS_GROUP_ID)}\s*/\*\s*Views\s*\*/\s*=\s*\{{[^}}]*isa\s*=\s*PBXGroup;"
        rf"[^}}]*children\s*=\s*\()"
    )
    m = re.search(views_pattern, content, re.DOTALL)
    if m:
        insert_pos = m.end()
        content = (
            content[:insert_pos]
            + f"\n\t\t\t\t{analytics_group_id} /* Analytics */,"
            + content[insert_pos:]
        )
        print("✓ Added Analytics group to iOS Views group")
    else:
        print(f"WARNING: Could not find iOS Views group ({IOS_VIEWS_GROUP_ID})")

    # -----------------------------------------------------------------------
    # 5. Add AnalyticsViewModel.swift to ViewModels group
    # -----------------------------------------------------------------------
    vm_data = [(b, fref) for b, r, fref, _, _, _ in file_data if b == "AnalyticsViewModel.swift"]
    if vm_data:
        vm_basename, vm_fref_id = vm_data[0]
        viewmodels_pattern = (
            rf"({re.escape(VIEWMODELS_GROUP_ID)}\s*/\*\s*ViewModels\s*\*/\s*=\s*\{{[^}}]*isa\s*=\s*PBXGroup;"
            rf"[^}}]*children\s*=\s*\()"
        )
        m = re.search(viewmodels_pattern, content, re.DOTALL)
        if m:
            insert_pos = m.end()
            content = (
                content[:insert_pos]
                + f"\n\t\t\t\t{vm_fref_id} /* {vm_basename} */,"
                + content[insert_pos:]
            )
            print("✓ Added AnalyticsViewModel.swift to ViewModels group")
        else:
            print(f"WARNING: Could not find ViewModels group ({VIEWMODELS_GROUP_ID})")

    # -----------------------------------------------------------------------
    # 6. Add files to iOS Sources build phase
    # -----------------------------------------------------------------------
    # The PBXSourcesBuildPhase section has the pattern:
    #   <ID> /* Sources */ = { isa = PBXSourcesBuildPhase; ... files = (
    ios_sources_pattern = (
        rf"({re.escape(IOS_SOURCES_ID)}\s*/\*\s*Sources\s*\*/\s*=\s*\{{[^}}]*isa\s*=\s*PBXSourcesBuildPhase;"
        rf"[^}}]*files\s*=\s*\()"
    )
    m = re.search(ios_sources_pattern, content, re.DOTALL)
    if m:
        insert_pos = m.end()
        ios_entries = "\n".join(
            [f"\t\t\t\t{build_ios_id} /* {b} in Sources */," for b, _, _, build_ios_id, _, _ in file_data]
        )
        content = content[:insert_pos] + "\n" + ios_entries + content[insert_pos:]
        print("✓ Added files to iOS Sources build phase")
    else:
        print(f"WARNING: Could not find iOS Sources build phase ({IOS_SOURCES_ID})")

    # -----------------------------------------------------------------------
    # 7. Add files to macOS Sources build phase
    # -----------------------------------------------------------------------
    mac_sources_pattern = (
        rf"({re.escape(MAC_SOURCES_ID)}\s*/\*\s*Sources\s*\*/\s*=\s*\{{[^}}]*isa\s*=\s*PBXSourcesBuildPhase;"
        rf"[^}}]*files\s*=\s*\()"
    )
    m = re.search(mac_sources_pattern, content, re.DOTALL)
    if m:
        insert_pos = m.end()
        mac_entries = "\n".join(
            [
                f"\t\t\t\t{build_mac_id} /* {b} in Sources */,"
                for b, _, _, _, build_mac_id, add_mac in file_data
                if add_mac and build_mac_id
            ]
        )
        content = content[:insert_pos] + "\n" + mac_entries + content[insert_pos:]
        print("✓ Added files to macOS Sources build phase")
    else:
        print(f"WARNING: Could not find macOS Sources build phase ({MAC_SOURCES_ID})")

    # -----------------------------------------------------------------------
    # Write updated project file
    # -----------------------------------------------------------------------
    with open(PBXPROJ, "w") as f:
        f.write(content)

    print("\nDone! Project file updated successfully.")


if __name__ == "__main__":
    main()
