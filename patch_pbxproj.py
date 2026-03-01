#!/usr/bin/env python3
import sys

# Read the file
with open('ILSApp/ILSApp.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# UUIDs
EXT_TARGET_ID = '3435419D5BFA49ABA9F419B7'
EXT_PRODUCT_REF = '008D6CFCE3484D699EAA9570'
EXT_SOURCES_PHASE = '421A2B8529664FE886969756'
EXT_RESOURCES_PHASE = 'D50AE4127D1F426B9165C794'
EXT_FRAMEWORKS_PHASE = '5198ED1D9F29431AA71D8E61'
EXT_CONFIG_LIST = '383793FBB1C04C8EB364728C'
EXT_DEBUG_CONFIG = '5062E1D2237C408FAC8C2C18'
EXT_RELEASE_CONFIG = 'A17060280FA94E34A3083C88'
EXT_GROUP = 'B9F884987E9A450CA33CF1FA'
EXT_MAIN_FILE_REF = 'E2E2C1C6E7FB42388D3D9AB2'
EXT_MAIN_BUILD_FILE = 'F32607212950409E8D46D771'
EXT_WIDGET_FILE_REF = 'F2297E1250734C8DB70B3BEE'
EXT_WIDGET_BUILD_FILE = '92E591F5CA844681988B83CA'
EXT_ENTITLEMENTS_REF = 'C75A150808274509B078FE58'
EXT_EMBED_PHASE = '38B3AB360F854D04BEC0DFB9'
EXT_EMBED_BUILD_FILE = '5A5BF3D97F974184BD191CD0'
PROXY_ID = '3090569AC77F43AA91FACE79'
DEPENDENCY_ID = 'C729ACC64C0E4E659ABAE029'
SHARED_ILSLIVE_BUILD = 'A483A9BE219541B3B8174443'
SHARED_SESSION_BUILD = 'F1ABF28092C84AE991282EF7'
SHARED_SERVER_BUILD = 'AE756846F5D94603918543CD'
SHARED_PROVIDER_BUILD = 'A5AFE0DED9174953AD475D75'
SHARED_THEME_BUILD = '68E9CAA6E2DD4A9492E2592D'
SHARED_CONST_BUILD = '9300985EA8DF4323BAA1C791'
SHARED_DATE_BUILD = 'DD6C6E72BAAD4D3F9569B497'

errors = []

def replace_once(c, old, new, desc):
    count = c.count(old)
    if count == 0:
        errors.append(f"NOT FOUND: {desc}")
        return c
    if count > 1:
        print(f"WARNING: '{desc}' found {count} times, replacing first only")
    return c.replace(old, new, 1)

T = '\t'

# 1. PBXBuildFile entries (insert before End PBXBuildFile section)
old = '/* End PBXBuildFile section */'
new = (
    T+T+EXT_MAIN_BUILD_FILE+' /* ILSLiveActivityExtension.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = '+EXT_MAIN_FILE_REF+' /* ILSLiveActivityExtension.swift */; };\n'
    + T+T+EXT_WIDGET_BUILD_FILE+' /* ChatStreamingLiveActivityWidget.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = '+EXT_WIDGET_FILE_REF+' /* ChatStreamingLiveActivityWidget.swift */; };\n'
    + T+T+EXT_EMBED_BUILD_FILE+' /* ILSLiveActivityExtension.appex in Embed App Extensions */ = {isa = PBXBuildFile; '
    + 'fileRef = '+EXT_PRODUCT_REF+' /* ILSLiveActivityExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n'
    + T+T+SHARED_ILSLIVE_BUILD+' /* ILSLiveActivity.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 98FD0B430247AE5A4C83D990 /* ILSLiveActivity.swift */; };\n'
    + T+T+SHARED_SESSION_BUILD+' /* SessionWidget.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 634B53732914E58E3AAD3092 /* SessionWidget.swift */; };\n'
    + T+T+SHARED_SERVER_BUILD+' /* ServerStatusWidget.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 59590E5FFF289E598D2F6A1C /* ServerStatusWidget.swift */; };\n'
    + T+T+SHARED_PROVIDER_BUILD+' /* WidgetDataProvider.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 2AE94C5ECFA39B3E883FDE23 /* WidgetDataProvider.swift */; };\n'
    + T+T+SHARED_THEME_BUILD+' /* AppTheme.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 402B977AA6C4850AA23BDB0E /* AppTheme.swift */; };\n'
    + T+T+SHARED_CONST_BUILD+' /* AppConstants.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 4DEE8624B9BCC400474F4F46 /* AppConstants.swift */; };\n'
    + T+T+SHARED_DATE_BUILD+' /* DateFormatters.swift in Sources */ = {isa = PBXBuildFile; '
    + 'fileRef = 17EC5845473E98DEC4C5FA84 /* DateFormatters.swift */; };\n'
    + '/* End PBXBuildFile section */'
)
content = replace_once(content, old, new, 'PBXBuildFile section end')

# 2. PBXContainerItemProxy entry
old = '/* End PBXContainerItemProxy section */'
new = (
    T+T+PROXY_ID+' /* PBXContainerItemProxy */ = {\n'
    + T+T+T+'isa = PBXContainerItemProxy;\n'
    + T+T+T+'containerPortal = EF21AB5EEE4667421D71D6B8 /* Project object */;\n'
    + T+T+T+'proxyType = 1;\n'
    + T+T+T+'remoteGlobalIDString = '+EXT_TARGET_ID+';\n'
    + T+T+T+'remoteInfo = ILSLiveActivityExtension;\n'
    + T+T+'};\n'
    + '/* End PBXContainerItemProxy section */'
)
content = replace_once(content, old, new, 'PBXContainerItemProxy section end')

# 3. PBXCopyFilesBuildPhase section (insert before PBXFileReference)
old = '/* Begin PBXFileReference section */'
new = (
    '/* Begin PBXCopyFilesBuildPhase section */\n'
    + T+T+EXT_EMBED_PHASE+' /* Embed App Extensions */ = {\n'
    + T+T+T+'isa = PBXCopyFilesBuildPhase;\n'
    + T+T+T+'buildActionMask = 2147483647;\n'
    + T+T+T+'dstPath = "";\n'
    + T+T+T+'dstSubfolderSpec = 13;\n'
    + T+T+T+'files = (\n'
    + T+T+T+T+EXT_EMBED_BUILD_FILE+' /* ILSLiveActivityExtension.appex in Embed App Extensions */,\n'
    + T+T+T+');\n'
    + T+T+T+'name = "Embed App Extensions";\n'
    + T+T+T+'runOnlyForDeploymentPostprocessing = 0;\n'
    + T+T+'};\n'
    + '/* End PBXCopyFilesBuildPhase section */\n\n'
    + '/* Begin PBXFileReference section */'
)
content = replace_once(content, old, new, 'PBXFileReference section begin')

# 4. PBXFileReference entries
old = '/* End PBXFileReference section */'
new = (
    T+T+EXT_PRODUCT_REF+' /* ILSLiveActivityExtension.appex */ = {isa = PBXFileReference; '
    + 'explicitFileType = "wrapper.app-extension"; includeInIndex = 0; '
    + 'path = ILSLiveActivityExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };\n'
    + T+T+EXT_MAIN_FILE_REF+' /* ILSLiveActivityExtension.swift */ = {isa = PBXFileReference; '
    + 'lastKnownFileType = sourcecode.swift; path = ILSLiveActivityExtension.swift; sourceTree = "<group>"; };\n'
    + T+T+EXT_WIDGET_FILE_REF+' /* ChatStreamingLiveActivityWidget.swift */ = {isa = PBXFileReference; '
    + 'lastKnownFileType = sourcecode.swift; path = ChatStreamingLiveActivityWidget.swift; sourceTree = "<group>"; };\n'
    + T+T+EXT_ENTITLEMENTS_REF+' /* ILSLiveActivityExtension.entitlements */ = {isa = PBXFileReference; '
    + 'lastKnownFileType = text.plist.entitlements; path = ILSLiveActivityExtension.entitlements; sourceTree = "<group>"; };\n'
    + '/* End PBXFileReference section */'
)
content = replace_once(content, old, new, 'PBXFileReference section end')

# 5. PBXFrameworksBuildPhase - add extension phase
old = '/* End PBXFrameworksBuildPhase section */'
new = (
    T+T+EXT_FRAMEWORKS_PHASE+' /* Frameworks */ = {\n'
    + T+T+T+'isa = PBXFrameworksBuildPhase;\n'
    + T+T+T+'buildActionMask = 2147483647;\n'
    + T+T+T+'files = (\n'
    + T+T+T+');\n'
    + T+T+T+'runOnlyForDeploymentPostprocessing = 0;\n'
    + T+T+'};\n'
    + '/* End PBXFrameworksBuildPhase section */'
)
content = replace_once(content, old, new, 'PBXFrameworksBuildPhase section end')

# 6. PBXGroup: Add EXT_GROUP to main group children
old = T+T+T+T+'60C21CF81EEA9386849DC0A8 /* ILSMacApp */,\n'+T+T+T+T+'074A6B4F495721F2E83C93C4 /* Packages */,'
new = (T+T+T+T+'60C21CF81EEA9386849DC0A8 /* ILSMacApp */,\n'
       + T+T+T+T+EXT_GROUP+' /* ILSLiveActivityExtension */,\n'
       + T+T+T+T+'074A6B4F495721F2E83C93C4 /* Packages */,')
content = replace_once(content, old, new, 'main group ILSMacApp/Packages')

# 7. PBXGroup: Add EXT_PRODUCT_REF to Products group
old = T+T+T+T+'5403907FD9017776F9FA89AC /* ILSMacApp.app */,\n'+T+T+T+');\n'+T+T+T+'name = Products;'
new = (T+T+T+T+'5403907FD9017776F9FA89AC /* ILSMacApp.app */,\n'
       + T+T+T+T+EXT_PRODUCT_REF+' /* ILSLiveActivityExtension.appex */,\n'
       + T+T+T+');\n'+T+T+T+'name = Products;')
content = replace_once(content, old, new, 'Products group')

# 8. PBXGroup: Add EXT_GROUP definition
old = '/* End PBXGroup section */'
new = (
    T+T+EXT_GROUP+' /* ILSLiveActivityExtension */ = {\n'
    + T+T+T+'isa = PBXGroup;\n'
    + T+T+T+'children = (\n'
    + T+T+T+T+EXT_MAIN_FILE_REF+' /* ILSLiveActivityExtension.swift */,\n'
    + T+T+T+T+EXT_WIDGET_FILE_REF+' /* ChatStreamingLiveActivityWidget.swift */,\n'
    + T+T+T+T+EXT_ENTITLEMENTS_REF+' /* ILSLiveActivityExtension.entitlements */,\n'
    + T+T+T+');\n'
    + T+T+T+'path = ILSLiveActivityExtension;\n'
    + T+T+T+'sourceTree = "<group>";\n'
    + T+T+'};\n'
    + '/* End PBXGroup section */'
)
content = replace_once(content, old, new, 'PBXGroup section end')

# 9. PBXNativeTarget: Add Widget Extension target
old = '/* End PBXNativeTarget section */'
new = (
    T+T+EXT_TARGET_ID+' /* ILSLiveActivityExtension */ = {\n'
    + T+T+T+'isa = PBXNativeTarget;\n'
    + T+T+T+'buildConfigurationList = '+EXT_CONFIG_LIST+' /* Build configuration list for PBXNativeTarget "ILSLiveActivityExtension" */;\n'
    + T+T+T+'buildPhases = (\n'
    + T+T+T+T+EXT_SOURCES_PHASE+' /* Sources */,\n'
    + T+T+T+T+EXT_RESOURCES_PHASE+' /* Resources */,\n'
    + T+T+T+T+EXT_FRAMEWORKS_PHASE+' /* Frameworks */,\n'
    + T+T+T+');\n'
    + T+T+T+'buildRules = (\n'
    + T+T+T+');\n'
    + T+T+T+'dependencies = (\n'
    + T+T+T+');\n'
    + T+T+T+'name = ILSLiveActivityExtension;\n'
    + T+T+T+'packageProductDependencies = (\n'
    + T+T+T+');\n'
    + T+T+T+'productName = ILSLiveActivityExtension;\n'
    + T+T+T+'productReference = '+EXT_PRODUCT_REF+' /* ILSLiveActivityExtension.appex */;\n'
    + T+T+T+'productType = "com.apple.product-type.app-extension";\n'
    + T+T+'};\n'
    + '/* End PBXNativeTarget section */'
)
content = replace_once(content, old, new, 'PBXNativeTarget section end')

# 10. ILSApp target: add EXT_EMBED_PHASE to buildPhases and DEPENDENCY_ID to dependencies
old = (T+T+T+T+'A4A7DF60096F1CE481CCEC80 /* Sources */,\n'
       + T+T+T+T+'CEC272911F8C0CFE9F9B02C8 /* Resources */,\n'
       + T+T+T+T+'39DB7C44291CD2B8BA315AF1 /* Frameworks */,\n'
       + T+T+T+');\n'
       + T+T+T+'buildRules = (\n'
       + T+T+T+');\n'
       + T+T+T+'dependencies = (\n'
       + T+T+T+');\n'
       + T+T+T+'name = ILSApp;')
new = (T+T+T+T+'A4A7DF60096F1CE481CCEC80 /* Sources */,\n'
       + T+T+T+T+'CEC272911F8C0CFE9F9B02C8 /* Resources */,\n'
       + T+T+T+T+'39DB7C44291CD2B8BA315AF1 /* Frameworks */,\n'
       + T+T+T+T+EXT_EMBED_PHASE+' /* Embed App Extensions */,\n'
       + T+T+T+');\n'
       + T+T+T+'buildRules = (\n'
       + T+T+T+');\n'
       + T+T+T+'dependencies = (\n'
       + T+T+T+T+DEPENDENCY_ID+' /* PBXTargetDependency */,\n'
       + T+T+T+');\n'
       + T+T+T+'name = ILSApp;')
content = replace_once(content, old, new, 'ILSApp target buildPhases/dependencies')

# 11. PBXProject targets: add EXT_TARGET_ID
old = (T+T+T+T+'AB6F4F861DC7592BED6D0F4B /* ILSMacApp */,\n'
       + T+T+T+');\n'
       + T+T+'};\n'
       + '/* End PBXProject section */')
new = (T+T+T+T+'AB6F4F861DC7592BED6D0F4B /* ILSMacApp */,\n'
       + T+T+T+T+EXT_TARGET_ID+' /* ILSLiveActivityExtension */,\n'
       + T+T+T+');\n'
       + T+T+'};\n'
       + '/* End PBXProject section */')
content = replace_once(content, old, new, 'PBXProject targets')

# 12. PBXProject TargetAttributes: add EXT_TARGET_ID
old = (T+T+T+T+T+'D645525C5887D056718B993A = {\n'
       + T+T+T+T+T+T+'DevelopmentTeam = HC36V7B67Z;\n'
       + T+T+T+T+T+'};\n'
       + T+T+T+T+'};\n'
       + T+T+T+'};\n'
       + T+T+T+'buildConfigurationList = DFCE3D86ED7093B74666BA73')
new = (T+T+T+T+T+'D645525C5887D056718B993A = {\n'
       + T+T+T+T+T+T+'DevelopmentTeam = HC36V7B67Z;\n'
       + T+T+T+T+T+'};\n'
       + T+T+T+T+T+EXT_TARGET_ID+' = {\n'
       + T+T+T+T+T+T+'DevelopmentTeam = HC36V7B67Z;\n'
       + T+T+T+T+T+'};\n'
       + T+T+T+T+'};\n'
       + T+T+T+'};\n'
       + T+T+T+'buildConfigurationList = DFCE3D86ED7093B74666BA73')
content = replace_once(content, old, new, 'PBXProject TargetAttributes')

# 13. PBXResourcesBuildPhase: add extension resources phase
old = '/* End PBXResourcesBuildPhase section */'
new = (
    T+T+EXT_RESOURCES_PHASE+' /* Resources */ = {\n'
    + T+T+T+'isa = PBXResourcesBuildPhase;\n'
    + T+T+T+'buildActionMask = 2147483647;\n'
    + T+T+T+'files = (\n'
    + T+T+T+');\n'
    + T+T+T+'runOnlyForDeploymentPostprocessing = 0;\n'
    + T+T+'};\n'
    + '/* End PBXResourcesBuildPhase section */'
)
content = replace_once(content, old, new, 'PBXResourcesBuildPhase section end')

# 14. PBXSourcesBuildPhase: add extension sources phase
old = '/* End PBXSourcesBuildPhase section */'
new = (
    T+T+EXT_SOURCES_PHASE+' /* Sources */ = {\n'
    + T+T+T+'isa = PBXSourcesBuildPhase;\n'
    + T+T+T+'buildActionMask = 2147483647;\n'
    + T+T+T+'files = (\n'
    + T+T+T+T+EXT_MAIN_BUILD_FILE+' /* ILSLiveActivityExtension.swift in Sources */,\n'
    + T+T+T+T+EXT_WIDGET_BUILD_FILE+' /* ChatStreamingLiveActivityWidget.swift in Sources */,\n'
    + T+T+T+T+SHARED_ILSLIVE_BUILD+' /* ILSLiveActivity.swift in Sources */,\n'
    + T+T+T+T+SHARED_SESSION_BUILD+' /* SessionWidget.swift in Sources */,\n'
    + T+T+T+T+SHARED_SERVER_BUILD+' /* ServerStatusWidget.swift in Sources */,\n'
    + T+T+T+T+SHARED_PROVIDER_BUILD+' /* WidgetDataProvider.swift in Sources */,\n'
    + T+T+T+T+SHARED_THEME_BUILD+' /* AppTheme.swift in Sources */,\n'
    + T+T+T+T+SHARED_CONST_BUILD+' /* AppConstants.swift in Sources */,\n'
    + T+T+T+T+SHARED_DATE_BUILD+' /* DateFormatters.swift in Sources */,\n'
    + T+T+T+');\n'
    + T+T+T+'runOnlyForDeploymentPostprocessing = 0;\n'
    + T+T+'};\n'
    + '/* End PBXSourcesBuildPhase section */'
)
content = replace_once(content, old, new, 'PBXSourcesBuildPhase section end')

# 15. PBXTargetDependency: add DEPENDENCY_ID
old = '/* End PBXTargetDependency section */'
new = (
    T+T+DEPENDENCY_ID+' /* PBXTargetDependency */ = {\n'
    + T+T+T+'isa = PBXTargetDependency;\n'
    + T+T+T+'target = '+EXT_TARGET_ID+' /* ILSLiveActivityExtension */;\n'
    + T+T+T+'targetProxy = '+PROXY_ID+' /* PBXContainerItemProxy */;\n'
    + T+T+'};\n'
    + '/* End PBXTargetDependency section */'
)
content = replace_once(content, old, new, 'PBXTargetDependency section end')

# 16. XCBuildConfiguration: add extension build configs
old = '/* End XCBuildConfiguration section */'
new = (
    T+T+EXT_DEBUG_CONFIG+' /* Debug */ = {\n'
    + T+T+T+'isa = XCBuildConfiguration;\n'
    + T+T+T+'buildSettings = {\n'
    + T+T+T+T+'CODE_SIGN_ENTITLEMENTS = ILSLiveActivityExtension/ILSLiveActivityExtension.entitlements;\n'
    + T+T+T+T+'CODE_SIGN_STYLE = Automatic;\n'
    + T+T+T+T+'DEVELOPMENT_TEAM = HC36V7B67Z;\n'
    + T+T+T+T+'GENERATE_INFOPLIST_FILE = YES;\n'
    + T+T+T+T+'INFOPLIST_KEY_NSExtensionPointIdentifier = "com.apple.widgetkit-extension";\n'
    + T+T+T+T+'IPHONEOS_DEPLOYMENT_TARGET = 17.0;\n'
    + T+T+T+T+'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../../Frameworks @executable_path/../Frameworks";\n'
    + T+T+T+T+'ONLY_ACTIVE_ARCH = YES;\n'
    + T+T+T+T+'PRODUCT_BUNDLE_IDENTIFIER = "com.ils.app.liveactivity";\n'
    + T+T+T+T+'PRODUCT_NAME = ILSLiveActivityExtension;\n'
    + T+T+T+T+'SDKROOT = iphoneos;\n'
    + T+T+T+T+'SKIP_INSTALL = YES;\n'
    + T+T+T+T+'SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n'
    + T+T+T+T+'SWIFT_OPTIMIZATION_LEVEL = "-Onone";\n'
    + T+T+T+T+'SWIFT_STRICT_CONCURRENCY = targeted;\n'
    + T+T+T+T+'SWIFT_VERSION = 5.0;\n'
    + T+T+T+T+'TARGETED_DEVICE_FAMILY = 1;\n'
    + T+T+T+'};\n'
    + T+T+T+'name = Debug;\n'
    + T+T+'};\n'
    + T+T+EXT_RELEASE_CONFIG+' /* Release */ = {\n'
    + T+T+T+'isa = XCBuildConfiguration;\n'
    + T+T+T+'buildSettings = {\n'
    + T+T+T+T+'CODE_SIGN_ENTITLEMENTS = ILSLiveActivityExtension/ILSLiveActivityExtension.entitlements;\n'
    + T+T+T+T+'CODE_SIGN_STYLE = Automatic;\n'
    + T+T+T+T+'DEVELOPMENT_TEAM = HC36V7B67Z;\n'
    + T+T+T+T+'GENERATE_INFOPLIST_FILE = YES;\n'
    + T+T+T+T+'INFOPLIST_KEY_NSExtensionPointIdentifier = "com.apple.widgetkit-extension";\n'
    + T+T+T+T+'IPHONEOS_DEPLOYMENT_TARGET = 17.0;\n'
    + T+T+T+T+'LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../../Frameworks @executable_path/../Frameworks";\n'
    + T+T+T+T+'PRODUCT_BUNDLE_IDENTIFIER = "com.ils.app.liveactivity";\n'
    + T+T+T+T+'PRODUCT_NAME = ILSLiveActivityExtension;\n'
    + T+T+T+T+'SDKROOT = iphoneos;\n'
    + T+T+T+T+'SKIP_INSTALL = YES;\n'
    + T+T+T+T+'SWIFT_OPTIMIZATION_LEVEL = "-O";\n'
    + T+T+T+T+'SWIFT_STRICT_CONCURRENCY = targeted;\n'
    + T+T+T+T+'SWIFT_VERSION = 5.0;\n'
    + T+T+T+T+'TARGETED_DEVICE_FAMILY = 1;\n'
    + T+T+T+'};\n'
    + T+T+T+'name = Release;\n'
    + T+T+'};\n'
    + '/* End XCBuildConfiguration section */'
)
content = replace_once(content, old, new, 'XCBuildConfiguration section end')

# 17. XCConfigurationList: add extension config list
old = '/* End XCConfigurationList section */'
new = (
    T+T+EXT_CONFIG_LIST+' /* Build configuration list for PBXNativeTarget "ILSLiveActivityExtension" */ = {\n'
    + T+T+T+'isa = XCConfigurationList;\n'
    + T+T+T+'buildConfigurations = (\n'
    + T+T+T+T+EXT_DEBUG_CONFIG+' /* Debug */,\n'
    + T+T+T+T+EXT_RELEASE_CONFIG+' /* Release */,\n'
    + T+T+T+');\n'
    + T+T+T+'defaultConfigurationIsVisible = 0;\n'
    + T+T+T+'defaultConfigurationName = Debug;\n'
    + T+T+'};\n'
    + '/* End XCConfigurationList section */'
)
content = replace_once(content, old, new, 'XCConfigurationList section end')

if errors:
    print("ERRORS:")
    for e in errors:
        print(" ", e)
    sys.exit(1)

# Write the file
with open('ILSApp/ILSApp.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print(f"Done! Lines: {content.count(chr(10))}")
