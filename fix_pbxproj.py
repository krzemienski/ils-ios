#!/usr/bin/env python3
import re

proj = 'ILSApp/ILSApp.xcodeproj/project.pbxproj'

with open(proj, 'r') as f:
    content = f.read()

lkt = 'lastKnownFileType'
vm_ref_line = '\t\tAA00000000000001AABBCC08 /* ErrorPatternsViewModel.swift */ = {isa = PBXFileReference; %s = sourcecode.swift; path = ErrorPatternsViewModel.swift; sourceTree = "<group>"; };' % lkt

# 1. Add PBXFileReference for ErrorPatternsViewModel after AnalyticsViewModel ref
marker = 'BAEB0566A2007404F394E113 /* AnalyticsViewModel.swift */'
idx = content.find(marker)
end = content.find('\n', idx)
content = content[:end] + '\n' + vm_ref_line + content[end:]
print('FileRef ViewModel:', 'SUCCESS' if 'AA00000000000001AABBCC08' in content else 'FAILED')

# 2. Add to ViewModels group (after AnalyticsViewModel group entry)
old_g = 'BAEB0566A2007404F394E113 /* AnalyticsViewModel.swift */,'
new_g = old_g + '\n\t\t\t\tAA00000000000001AABBCC08 /* ErrorPatternsViewModel.swift */,'
content = content.replace(old_g, new_g, 1)
print('Group ViewModel:', 'SUCCESS' if '/* ErrorPatternsViewModel.swift */,' in content else 'FAILED')

# 3. Add PBXBuildFile entries (after existing AnalyticsViewModel build file entry)
old_bf = '6DF28BE36CAAF75AD420F46F /* AnalyticsViewModel.swift in Sources */'
idx2 = content.find(old_bf)
end2 = content.find('\n', idx2)
extra = (
    '\n\t\tAA00000000000001AABBCC09 /* ErrorPatternsViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA00000000000001AABBCC08 /* ErrorPatternsViewModel.swift */; };'
    '\n\t\tAA00000000000001AABBCC0B /* ErrorPatternsViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA00000000000001AABBCC08 /* ErrorPatternsViewModel.swift */; };'
)
content = content[:end2] + extra + content[end2:]
print('BuildFile ViewModel:', 'SUCCESS' if 'AA00000000000001AABBCC09' in content else 'FAILED')

# 4. macOS build phase - add after AnalyticsViewModel
old_mac = '7FD27DD9DC11923A20664506 /* AnalyticsViewModel.swift in Sources */,'
new_mac = old_mac + '\n\t\t\t\tAA00000000000001AABBCC0B /* ErrorPatternsViewModel.swift in Sources */,'
content = content.replace(old_mac, new_mac, 1)
print('macOS VM sources:', 'SUCCESS' if 'AA00000000000001AABBCC0B /* ErrorPatternsViewModel' in content else 'FAILED')

# 5. iOS build phase - add after AnalyticsViewModel
old_ios = '6DF28BE36CAAF75AD420F46F /* AnalyticsViewModel.swift in Sources */,'
new_ios = old_ios + '\n\t\t\t\tAA00000000000001AABBCC09 /* ErrorPatternsViewModel.swift in Sources */,'
content = content.replace(old_ios, new_ios, 1)
print('iOS VM sources:', 'SUCCESS' if 'AA00000000000001AABBCC09 /* ErrorPatternsViewModel' in content else 'FAILED')

with open(proj, 'w') as f:
    f.write(content)
print('Done.')
