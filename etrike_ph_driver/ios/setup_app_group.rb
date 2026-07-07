#!/usr/bin/env ruby
# Registers App Groups capability in Xcode and triggers automatic provisioning
# (requires you to be signed into Xcode with team DQVYSH4ADS).

require 'xcodeproj'

APP_GROUP = 'group.com.etrikeph.etrikePhDriver'
TEAM_ID = 'DQVYSH4ADS'
IOS_DIR = File.dirname(__FILE__)
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' }
extension = project.targets.find { |t| t.name == 'TripLiveActivityExtension' }

abort('Runner target not found') unless runner
abort('TripLiveActivityExtension target not found') unless extension

def enable_capability(target_attributes, capability_key)
  target_attributes['SystemCapabilities'] ||= {}
  target_attributes['SystemCapabilities'][capability_key] = { 'enabled' => '1' }
end

project.root_object.attributes['TargetAttributes'] ||= {}

[runner, extension].each do |target|
  attrs = project.root_object.attributes['TargetAttributes'][target.uuid] ||= {}
  enable_capability(attrs, 'com.apple.ApplicationGroups.iOS')
  attrs['DevelopmentTeam'] = TEAM_ID
  attrs['ProvisioningStyle'] = 'Automatic'
end

[runner, extension].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['DEVELOPMENT_TEAM'] = TEAM_ID
  end
end

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

extension.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'TripLiveActivityExtension.entitlements'
end

project.save
puts "✅ Xcode project updated with App Groups capability"
puts "   App Group: #{APP_GROUP}"
puts "   Team: #{TEAM_ID}"
