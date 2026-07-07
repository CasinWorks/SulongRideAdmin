#!/usr/bin/env ruby
# Adds TripLiveActivity widget extension to Runner.xcodeproj for Live Activities.

require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner

if project.targets.any? { |t| t.name == 'TripLiveActivityExtension' }
  puts 'TripLiveActivityExtension target already exists'
  exit 0
end

extension = project.new_target(
  :app_extension,
  'TripLiveActivityExtension',
  :ios,
  '16.1'
)

extension.build_configurations.each do |config|
  config.base_configuration_reference = project.files.find { |f| f.path == 'Flutter/Extension.xcconfig' } ||
    project.new_file('Flutter/Extension.xcconfig')
  config.build_settings['INFOPLIST_FILE'] = 'TripLiveActivity/Info.plist'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Sulong Trip'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'TripLiveActivityExtension.entitlements'
  config.build_settings['DEVELOPMENT_TEAM'] = 'DQVYSH4ADS'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.etrikeph.etrikePhUser.TripLiveActivityExtension'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.1'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  config.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks'
  ]
end

swift_file = extension.new_file('TripLiveActivity/TripLiveActivity.swift')
extension.source_build_phase.add_file_reference(swift_file) unless extension.source_build_phase.files_references.include?(swift_file)

assets = extension.new_file('TripLiveActivity/Assets.xcassets')
extension.resources_build_phase.add_file_reference(assets) unless extension.resources_build_phase.files_references.include?(assets)

embed_phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed Foundation Extensions'
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  thin_binary = runner.build_phases.find { |p| p.display_name == 'Thin Binary' }
  if thin_binary
    runner.build_phases.insert(runner.build_phases.index(thin_binary), embed_phase)
  else
    runner.build_phases << embed_phase
  end
end

build_file = embed_phase.add_file_reference(extension.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

dep = project.new(Xcodeproj::Project::Object::PBXTargetDependency)
dep.target = extension
runner.dependencies << dep

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
puts 'TripLiveActivityExtension target added successfully'
