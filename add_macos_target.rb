#!/usr/bin/env ruby
require 'xcodeproj'

# Open the existing Xcode project
project_path = '/Users/nick/Desktop/ils-ios/ILSApp/ILSApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "📦 Opening project: #{project_path}"
puts "📋 Existing targets: #{project.targets.map(&:name).join(', ')}"

# Check if ILSMacApp target already exists
if project.targets.find { |t| t.name == 'ILSMacApp' }
  puts "⚠️  ILSMacApp target already exists!"
  exit 0
end

# Create macOS app target
puts "\n🎯 Creating ILSMacApp target..."
target = project.new_target(:application, 'ILSMacApp', :osx, '14.0')

# Configure build settings
puts "⚙️  Configuring build settings..."
target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'ILSMacApp'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ils.mac'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SDKROOT'] = 'macosx'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['INFOPLIST_FILE'] = 'ILSMacApp/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ILSMacApp/ILSMacApp.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

# Find the ILSMacApp group in the project
puts "📁 Finding ILSMacApp group..."
mac_app_group = project.main_group.find_subpath('ILSMacApp', true)

# Add source files to target
puts "📝 Adding source files to target..."

# Main app file
app_file = mac_app_group.find_file_by_path('ILSMacApp.swift')
if app_file
  target.add_file_references([app_file])
  puts "  ✓ ILSMacApp.swift"
end

# AppDelegate
delegate_file = mac_app_group.find_file_by_path('AppDelegate.swift')
if delegate_file
  target.add_file_references([delegate_file])
  puts "  ✓ AppDelegate.swift"
end

# Add Views
views_group = mac_app_group.find_subpath('Views', false)
if views_group
  views_group.files.each do |file|
    target.add_file_references([file]) if file.path.end_with?('.swift')
    puts "  ✓ #{file.path}"
  end
end

# Add Managers
managers_group = mac_app_group.find_subpath('Managers', false)
if managers_group
  managers_group.files.each do |file|
    target.add_file_references([file]) if file.path.end_with?('.swift')
    puts "  ✓ #{file.path}"
  end
end

# Add TouchBar
touchbar_group = mac_app_group.find_subpath('TouchBar', false)
if touchbar_group
  touchbar_group.files.each do |file|
    target.add_file_references([file]) if file.path.end_with?('.swift')
    puts "  ✓ #{file.path}"
  end
end

# Add Assets.xcassets to resources
assets = mac_app_group.find_file_by_path('Assets.xcassets')
if assets
  resources_phase = target.resources_build_phase
  resources_phase.add_file_reference(assets)
  puts "  ✓ Assets.xcassets (resources)"
end

# Add Credits.rtf to resources
credits = mac_app_group.find_file_by_path('Credits.rtf')
if credits
  resources_phase = target.resources_build_phase
  resources_phase.add_file_reference(credits)
  puts "  ✓ Credits.rtf (resources)"
end

# Link ILSShared package
puts "\n📦 Linking ILSShared package..."
shared_package = project.root_object.package_references.find { |p| p.name == 'ILSShared' }
if shared_package
  # Add package product dependency
  ils_shared_product = target.package_product_dependencies.find { |d| d.product_name == 'ILSShared' }
  unless ils_shared_product
    package_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    package_product.product_name = 'ILSShared'
    package_product.package = shared_package
    target.package_product_dependencies << package_product

    # Add to frameworks build phase
    frameworks_phase = target.frameworks_build_phase
    build_file = frameworks_phase.add_file_reference(package_product)
    puts "  ✓ ILSShared linked"
  end
else
  puts "  ⚠️  ILSShared package reference not found"
end

# Link shared ViewModels and Services from iOS target
puts "\n🔗 Linking shared files from iOS target..."
ios_target = project.targets.find { |t| t.name == 'ILSApp' }
if ios_target
  # Get files from iOS target that should be shared
  shared_paths = [
    'ViewModels',
    'Services',
    'Models',
    'Views/Shared',
    'Views/Components'
  ]

  ios_target.source_build_phase.files.each do |build_file|
    file_ref = build_file.file_ref
    next unless file_ref && file_ref.path

    # Check if file is in a shared directory
    if shared_paths.any? { |path| file_ref.path.include?(path) }
      # Check if already added
      unless target.source_build_phase.files.find { |f| f.file_ref == file_ref }
        target.add_file_references([file_ref])
        puts "  ✓ #{file_ref.path}"
      end
    end
  end
end

# Create scheme
puts "\n📋 Creating ILSMacApp scheme..."
scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target)
scheme.save_as(project_path, 'ILSMacApp')
puts "  ✓ ILSMacApp scheme created"

# Save project
puts "\n💾 Saving project..."
project.save

puts "\n✅ Successfully added ILSMacApp target!"
puts "\n📊 Summary:"
puts "  • Target: ILSMacApp"
puts "  • Platform: macOS 14.0+"
puts "  • Bundle ID: com.ils.mac"
puts "  • Files: #{target.source_build_phase.files.count} source files"
puts "  • Resources: #{target.resources_build_phase.files.count} resource files"
puts "  • Frameworks: #{target.frameworks_build_phase.files.count} frameworks"
puts "\n🔨 Next steps:"
puts "  1. Create Info.plist at ILSMacApp/Info.plist"
puts "  2. Create ILSMacApp.entitlements at ILSMacApp/ILSMacApp.entitlements"
puts "  3. Run: xcodebuild -project ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' build"
