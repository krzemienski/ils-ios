#!/usr/bin/env python3
"""Fix ILSApp.xcodeproj/project.pbxproj by adding all missing Swift files."""

import hashlib
import os
import re
import sys

PBXPROJ = "ILSApp/ILSApp.xcodeproj/project.pbxproj"
SOURCE_ROOT = "ILSApp/ILSApp"

def generate_id(seed: str, salt: str) -> str:
    """Generate a deterministic 24-char hex ID from a seed string."""
    h = hashlib.md5((seed + salt).encode()).hexdigest().upper()
    return h[:24]

def find_swift_files_on_disk():
    """Find all .swift files under SOURCE_ROOT."""
    files = []
    for root, dirs, filenames in os.walk(SOURCE_ROOT):
        # Skip hidden dirs and test dirs
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for f in filenames:
            if f.endswith('.swift'):
                full = os.path.join(root, f)
                rel = os.path.relpath(full, SOURCE_ROOT)
                files.append(rel)
    return sorted(files)

def find_referenced_files(content):
    """Find all Swift files already referenced in pbxproj."""
    # Match PBXFileReference lines like: XXXX /* Foo.swift */ = {isa = PBXFileReference; ...path = Foo.swift; ...
    refs = set()
    for m in re.finditer(r'/\*\s+(\S+\.swift)\s+\*/', content):
        refs.add(m.group(1))
    return refs

def find_sources_build_phase_id(content):
    """Find the PBXSourcesBuildPhase section's files list."""
    # Find the build phase that has isa = PBXSourcesBuildPhase
    m = re.search(r'(\w{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{[^}]*isa\s*=\s*PBXSourcesBuildPhase', content)
    if m:
        return m.group(1)
    return None

def find_main_group(content):
    """Find the main PBXGroup that contains ILSApp sources."""
    # Look for the ILSApp group
    pattern = r'(\w{24})\s*/\*\s*ILSApp\s*\*/\s*=\s*\{[^}]*isa\s*=\s*PBXGroup[^}]*children\s*=\s*\('
    m = re.search(pattern, content)
    if m:
        return m.group(1)
    return None

def main():
    with open(PBXPROJ, 'r') as f:
        content = f.read()

    disk_files = find_swift_files_on_disk()
    referenced = find_referenced_files(content)

    print(f"Files on disk: {len(disk_files)}")
    print(f"Files referenced: {len(referenced)}")

    # Find missing files
    missing = []
    for rel in disk_files:
        basename = os.path.basename(rel)
        if basename not in referenced:
            missing.append(rel)

    print(f"Missing files: {len(missing)}")

    if not missing:
        print("Nothing to do!")
        return

    for f in missing:
        print(f"  + {f}")

    # Generate IDs for each missing file
    file_refs = []  # (file_ref_id, build_file_id, basename, relative_path)
    for rel in missing:
        basename = os.path.basename(rel)
        fref_id = generate_id(rel, "fileref")
        build_id = generate_id(rel, "buildfile")
        file_refs.append((fref_id, build_id, basename, rel))

    # Check for ID collisions with existing content
    existing_ids = set(re.findall(r'\b([0-9A-F]{24})\b', content))
    for fref_id, build_id, basename, rel in file_refs:
        while fref_id in existing_ids:
            fref_id = generate_id(rel + "_collision", "fileref" + fref_id)
        while build_id in existing_ids:
            build_id = generate_id(rel + "_collision", "buildfile" + build_id)
        existing_ids.add(fref_id)
        existing_ids.add(build_id)

    # 1. Add PBXBuildFile entries
    # Find the end of PBXBuildFile section
    build_file_marker = "/* End PBXBuildFile section */"
    build_file_entries = []
    for fref_id, build_id, basename, rel in file_refs:
        entry = f"\t\t{build_id} /* {basename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref_id} /* {basename} */; }};"
        build_file_entries.append(entry)

    build_file_block = "\n".join(build_file_entries) + "\n"
    content = content.replace(build_file_marker, build_file_block + build_file_marker)

    # 2. Add PBXFileReference entries
    # Find the end of PBXFileReference section
    file_ref_marker = "/* End PBXFileReference section */"
    file_ref_entries = []
    for fref_id, build_id, basename, rel in file_refs:
        # Path relative to the group (ILSApp/)
        entry = f'\t\t{fref_id} /* {basename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {basename}; sourceTree = "<group>"; }};'
        file_ref_entries.append(entry)

    file_ref_block = "\n".join(file_ref_entries) + "\n"
    content = content.replace(file_ref_marker, file_ref_block + file_ref_marker)

    # 3. Add to PBXSourcesBuildPhase
    # Find the sources build phase files list
    sources_pattern = r'(isa\s*=\s*PBXSourcesBuildPhase;[^}]*files\s*=\s*\()'
    m = re.search(sources_pattern, content, re.DOTALL)
    if m:
        insert_pos = m.end()
        source_entries = []
        for fref_id, build_id, basename, rel in file_refs:
            source_entries.append(f"\n\t\t\t\t{build_id} /* {basename} in Sources */,")
        source_block = "".join(source_entries)
        content = content[:insert_pos] + source_block + content[insert_pos:]
    else:
        print("WARNING: Could not find PBXSourcesBuildPhase!")

    # 4. Add file references to appropriate PBXGroup children
    # We need to find or create groups for each directory
    # First, let's organize files by directory
    dirs_to_files = {}
    for fref_id, build_id, basename, rel in file_refs:
        dirname = os.path.dirname(rel)
        if dirname not in dirs_to_files:
            dirs_to_files[dirname] = []
        dirs_to_files[dirname].append((fref_id, basename))

    # For each directory, find the matching PBXGroup and add children
    # The pbxproj has groups like:
    #   XXXXX /* ViewModels */ = { isa = PBXGroup; children = ( ... ); path = ViewModels; ...

    for dirname, files in dirs_to_files.items():
        if dirname == '':
            # Root-level files go in the main ILSApp group
            group_name = "ILSApp"
        else:
            # Use the last component of the path as group name
            group_name = os.path.basename(dirname)

        # Find the group by name AND path
        # Try exact path match first
        if dirname:
            group_pattern = rf'(\w{{24}})\s*/\*\s*{re.escape(group_name)}\s*\*/\s*=\s*\{{[^}}]*isa\s*=\s*PBXGroup;[^}}]*path\s*=\s*{re.escape(group_name)};[^}}]*children\s*=\s*\('
            m = re.search(group_pattern, content, re.DOTALL)

            if not m:
                # Try alternative pattern where children comes before path
                group_pattern2 = rf'(\w{{24}})\s*/\*\s*{re.escape(group_name)}\s*\*/\s*=\s*\{{[^}}]*isa\s*=\s*PBXGroup;[^}}]*children\s*=\s*\('
                m = re.search(group_pattern2, content, re.DOTALL)
        else:
            # Root ILSApp group
            group_pattern = r'(\w{24})\s*/\*\s*ILSApp\s*\*/\s*=\s*\{[^}]*isa\s*=\s*PBXGroup;[^}]*children\s*=\s*\('
            m = re.search(group_pattern, content, re.DOTALL)

        if m:
            insert_pos = m.end()
            child_entries = []
            for fref_id, basename in files:
                child_entries.append(f"\n\t\t\t\t{fref_id} /* {basename} */,")
            child_block = "".join(child_entries)
            content = content[:insert_pos] + child_block + content[insert_pos:]
            print(f"  Added {len(files)} files to group '{group_name}'")
        else:
            print(f"  WARNING: No group found for '{dirname}' (group_name='{group_name}'), creating new group")
            # Create a new group
            group_id = generate_id(dirname, "group")
            while group_id in existing_ids:
                group_id = generate_id(dirname + "_g", "group" + group_id)
            existing_ids.add(group_id)

            children_str = ",\n".join([f"\t\t\t\t{fref_id} /* {basename} */" for fref_id, basename in files])

            group_entry = f"""\t\t{group_id} /* {group_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_str},
\t\t\t);
\t\t\tpath = {group_name};
\t\t\tsourceTree = "<group>";
\t\t}};"""

            # Add group to PBXGroup section
            group_section_marker = "/* End PBXGroup section */"
            content = content.replace(group_section_marker, group_entry + "\n" + group_section_marker)

            # Now add this new group to its parent group
            parent_dir = os.path.dirname(dirname)
            if parent_dir:
                parent_name = os.path.basename(parent_dir)
            else:
                parent_name = "ILSApp"

            parent_pattern = rf'(/\*\s*{re.escape(parent_name)}\s*\*/\s*=\s*\{{[^}}]*children\s*=\s*\()'
            pm = re.search(parent_pattern, content, re.DOTALL)
            if pm:
                insert_pos = pm.end()
                content = content[:insert_pos] + f"\n\t\t\t\t{group_id} /* {group_name} */," + content[insert_pos:]
                print(f"    Added group '{group_name}' to parent '{parent_name}'")
            else:
                print(f"    WARNING: Could not find parent group '{parent_name}' for new group '{group_name}'")

    # Write the modified content
    with open(PBXPROJ, 'w') as f:
        f.write(content)

    print(f"\nDone! Added {len(missing)} files to {PBXPROJ}")

if __name__ == '__main__':
    main()
