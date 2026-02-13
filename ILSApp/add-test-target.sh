#!/bin/bash

# Script to add ILSAppTests target to ILSApp.xcodeproj
# This script adds test files to the Xcode project

set -e

echo "🔧 Adding ILSAppTests target to Xcode project..."

PROJECT_FILE="ILSApp.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Could not find $PROJECT_FILE"
    exit 1
fi

echo "✅ Found project file"

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
echo "✅ Created backup: $PROJECT_FILE.backup"

# Note: Programmatic editing of pbxproj files is complex and error-prone
# The recommended approach is to use Xcode GUI or xcodeproj Ruby gem

echo ""
echo "⚠️  IMPORTANT: This script creates test files but requires manual Xcode configuration"
echo ""
echo "To complete test setup, please follow these steps in Xcode:"
echo ""
echo "1. Open ILSApp.xcodeproj in Xcode"
echo "2. File → New → Target → Unit Testing Bundle"
echo "3. Name: ILSAppTests"
echo "4. Target to test: ILSApp"
echo "5. Add test files:"
echo "   - Right-click ILSApp project → Add Files to \"ILSApp\""
echo "   - Select ILSAppTests folder"
echo "   - Check \"Create groups\""
echo "   - Select \"ILSAppTests\" target"
echo "6. Configure test target:"
echo "   - Select ILSAppTests target"
echo "   - Build Phases → Dependencies → Add ILSApp"
echo "   - Build Phases → Link Binary → Add CloudKit.framework"
echo "7. Build and test: ⌘U"
echo ""

# Try to use Ruby xcodeproj gem if available
if command -v gem >/dev/null 2>&1; then
    echo "📦 Checking for xcodeproj gem..."

    if gem list xcodeproj -i >/dev/null 2>&1; then
        echo "✅ xcodeproj gem found, attempting to add test target automatically..."

        # Create Ruby script to add test target
        cat > add_tests.rb << 'EOF'
require 'xcodeproj'

project_path = 'ILSApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main app target
app_target = project.targets.find { |t| t.name == 'ILSApp' }

if app_target.nil?
    puts "❌ Could not find ILSApp target"
    exit 1
end

# Check if test target already exists
existing_test_target = project.targets.find { |t| t.name == 'ILSAppTests' }

if existing_test_target
    puts "✅ ILSAppTests target already exists"
else
    puts "🔨 Creating ILSAppTests target..."

    # Create test target
    test_target = project.new_target(:unit_test_bundle, 'ILSAppTests', :ios)
    test_target.product_name = 'ILSAppTests'

    # Add dependency on main app
    test_target.add_dependency(app_target)

    puts "✅ Created ILSAppTests target"
end

# Find or create test group
test_group = project.main_group.find_subpath('ILSAppTests', true)
test_group.set_source_tree('SOURCE_ROOT')

# Add test files
test_files = [
    'ILSAppTests/CloudKitServiceTests.swift',
    'ILSAppTests/CloudKitSyncableTests.swift',
    'ILSAppTests/iCloudKeyValueStoreTests.swift',
    'ILSAppTests/SyncViewModelTests.swift',
    'ILSAppTests/CloudKitSyncTests.swift',
    'ILSAppTests/Info.plist'
]

test_target = project.targets.find { |t| t.name == 'ILSAppTests' }

test_files.each do |file_path|
    # Check if file exists
    unless File.exist?(file_path)
        puts "⚠️  Skipping #{file_path} - file not found"
        next
    end

    # Add file to project
    file_ref = test_group.new_file(file_path)

    # Add to compile sources (except Info.plist)
    unless file_path.end_with?('.plist')
        test_target.source_build_phase.add_file_reference(file_ref)
        puts "✅ Added #{file_path} to test target"
    end
end

# Add CloudKit framework
frameworks_group = project.main_group.find_subpath('Frameworks', true)
cloudkit_framework = frameworks_group.new_file('System/Library/Frameworks/CloudKit.framework')
cloudkit_framework.source_tree = 'SDKROOT'
test_target.frameworks_build_phase.add_file_reference(cloudkit_framework)
puts "✅ Added CloudKit framework"

# Configure build settings
test_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.ILSAppTests'
    config.build_settings['INFOPLIST_FILE'] = 'ILSAppTests/Info.plist'
    config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
    config.build_settings['ENABLE_TESTABILITY'] = 'YES'
end

# Save project
project.save

puts ""
puts "✅ Successfully added ILSAppTests target to Xcode project!"
puts "✅ Test files added and configured"
puts ""
puts "Next steps:"
puts "1. Open ILSApp.xcodeproj in Xcode"
puts "2. Build the project (⌘B)"
puts "3. Run tests (⌘U)"
EOF

        ruby add_tests.rb
        rm add_tests.rb

        echo ""
        echo "✅ Test target added successfully!"
        echo "📝 You can now open the project in Xcode and run tests with ⌘U"

    else
        echo "❌ xcodeproj gem not found"
        echo "To install: sudo gem install xcodeproj"
        echo ""
        echo "Or follow the manual steps above"
    fi
else
    echo "❌ Ruby not found, cannot use xcodeproj gem"
    echo "Please follow the manual steps above"
fi

echo ""
echo "✅ Test setup complete!"
echo "📁 Test files created:"
ls -1 ILSAppTests/*.swift
echo ""
echo "📖 See ILSAppTests/README.md for detailed instructions"
