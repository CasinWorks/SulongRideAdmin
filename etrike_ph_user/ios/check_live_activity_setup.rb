#!/usr/bin/env ruby
# Verifies Live Activity / App Group setup for Sulong Ride.
require 'xcodeproj'

APP_GROUP = 'group.com.etrikeph.etrikePhUser'
IOS_DIR = File.dirname(__FILE__)

puts "\n=== Sulong Ride — Live Activity setup check ===\n"

project = Xcodeproj::Project.open(File.join(IOS_DIR, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' }
ext = project.targets.find { |t| t.name == 'TripLiveActivityExtension' }

unless ext
  puts '❌ TripLiveActivityExtension target missing. Run: ruby configure_live_activity.rb'
  exit 1
end

def entitlements_groups(path)
  return [] unless File.exist?(path)
  content = File.read(path)
  return [] unless content.include?('com.apple.security.application-groups')
  content.scan(/<string>(group\.[^<]+)<\/string>/).flatten
end

runner_groups = entitlements_groups(File.join(IOS_DIR, 'Runner/Runner.entitlements'))
ext_groups = entitlements_groups(File.join(IOS_DIR, 'TripLiveActivityExtension.entitlements'))

puts "Runner App Groups: #{runner_groups.empty? ? '❌ none' : runner_groups.join(', ')}"
puts "Extension App Groups: #{ext_groups.empty? ? '❌ none' : ext_groups.join(', ')}"

if runner_groups.include?(APP_GROUP) && ext_groups.include?(APP_GROUP)
  puts "✅ Both targets include #{APP_GROUP}"
else
  puts "❌ Add #{APP_GROUP} to Runner and TripLiveActivityExtension entitlements"
end

plugin = File.join(IOS_DIR, '.symlinks/plugins/live_activities/ios/live_activities/Sources/live_activities/LiveActivitiesPlugin.swift')
if File.exist?(plugin)
  content = File.read(plugin)
  if content.include?('pushType: nil')
    puts '✅ live_activities patched (pushType: nil)'
  else
    puts '⚠️  Run pod install to patch live_activities pushType'
  end
end

puts <<~STEPS

--- Required in Apple Developer portal (developer.apple.com) ---

1. Identifiers → App Groups → "+" → #{APP_GROUP}
2. Identifiers → com.etrikeph.etrikePhUser → enable App Groups → check #{APP_GROUP}
3. Identifiers → com.etrikeph.etrikePhUser.TripLiveActivityExtension → same App Group
4. Optional: enable Push Notifications on com.etrikeph.etrikePhUser

Then in Xcode (Runner.xcworkspace):
- Runner target → Signing & Capabilities → + App Groups → #{APP_GROUP}
- TripLiveActivityExtension → same
- Product → Clean Build Folder → Run on device

STEPS
