//
//  TripLiveActivity.swift
//  TripLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

private let appGroupId = "group.com.etrikeph.etrikePhDriver"
private var sharedDefault: UserDefaults? { UserDefaults(suiteName: appGroupId) }

private let ecoGreen = Color(red: 0.31, green: 0.64, blue: 0.29)
private let ecoGreenLight = Color(red: 0.37, green: 0.72, blue: 0.35)
private let forestDark = Color(red: 0.04, green: 0.13, blue: 0.08)

@main
struct TripLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 16.1, *) {
      TripLiveActivityWidget()
    }
  }
}

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {
    var appGroupId: String
  }

  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

@available(iOSApplicationExtension 16.1, *)
struct TripLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    let configuration = ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      TripActivityContentView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          TripPhaseIcon(phase: tripPhase(context), size: 28)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 4) {
            Text(tripTitle(context))
              .font(.headline)
              .fontWeight(.semibold)
              .lineLimit(1)
            Text(tripSubtitle(context))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .multilineTextAlignment(.center)
            TripProgressDots(progress: tripProgress(context))
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(spacing: 2) {
            Text("ETA")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text(tripEta(context))
              .font(.title3)
              .fontWeight(.bold)
              .foregroundStyle(ecoGreenLight)
          }
        }
      } compactLeading: {
        TripPhaseIcon(phase: tripPhase(context), size: 18)
      } compactTrailing: {
        Text(tripEta(context))
          .font(.caption)
          .fontWeight(.bold)
          .foregroundStyle(ecoGreenLight)
      } minimal: {
        Circle()
          .fill(ecoGreen)
          .frame(width: 12, height: 12)
      }
    }

    if #available(iOSApplicationExtension 18.0, *) {
      return configuration.supplementalActivityFamilies([.small])
    }
    return configuration
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TripActivityContentView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    if #available(iOSApplicationExtension 18.0, *) {
      TripActivityContentViewIOS18(context: context)
    } else {
      TripLockScreenView(context: context)
    }
  }
}

@available(iOSApplicationExtension 18.0, *)
private struct TripActivityContentViewIOS18: View {
  @Environment(\.activityFamily) private var activityFamily
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    if activityFamily == .small {
      TripWatchSmartStackView(context: context)
    } else {
      TripLockScreenView(context: context)
    }
  }
}

@available(iOSApplicationExtension 18.0, *)
private struct TripWatchSmartStackView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    HStack(spacing: 8) {
      TripPhaseIcon(phase: tripPhase(context), size: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(tripTitle(context))
          .font(.caption)
          .fontWeight(.semibold)
          .lineLimit(1)
        TripProgressDots(progress: tripProgress(context))
      }
      Spacer(minLength: 4)
      Text(tripEta(context))
        .font(.caption)
        .fontWeight(.bold)
        .foregroundStyle(ecoGreenLight)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(forestDark)
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TripLockScreenView: View {
  let context: ActivityViewContext<LiveActivitiesAppAttributes>

  var body: some View {
    HStack(spacing: 14) {
      TripPhaseIcon(phase: tripPhase(context), size: 36)
      VStack(alignment: .leading, spacing: 4) {
        Text(tripTitle(context))
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundStyle(.white)
        Text(tripSubtitle(context))
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.75))
          .lineLimit(2)
        TripProgressDots(progress: tripProgress(context))
      }
      Spacer()
      VStack(spacing: 2) {
        Text("ETA")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.6))
        Text(tripEta(context))
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(ecoGreenLight)
      }
    }
    .padding(16)
    .background(
      LinearGradient(
        colors: [forestDark, forestDark.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TripPhaseIcon: View {
  let phase: String
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(ecoGreen.opacity(0.25))
        .frame(width: size + 10, height: size + 10)
      Image(systemName: iconName)
        .font(.system(size: size * 0.55, weight: .semibold))
        .foregroundStyle(ecoGreenLight)
    }
  }

  private var iconName: String {
    switch phase {
    case "assigned": return "checkmark.circle.fill"
    case "arrived": return "mappin.circle.fill"
    case "enroute": return "arrow.triangle.turn.up.right.circle.fill"
    default: return "dot.radiowaves.left.and.right"
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TripProgressDots: View {
  let progress: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<3, id: \.self) { index in
        Capsule()
          .fill(index <= progress ? ecoGreenLight : Color.white.opacity(0.25))
          .frame(width: index == progress ? 18 : 8, height: 4)
      }
    }
    .padding(.top, 2)
  }
}

@available(iOSApplicationExtension 16.1, *)
private func tripTitle(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
  sharedDefault?.string(forKey: context.attributes.prefixedKey("title")) ?? "Sulong Driver"
}

@available(iOSApplicationExtension 16.1, *)
private func tripSubtitle(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
  sharedDefault?.string(forKey: context.attributes.prefixedKey("subtitle")) ?? "Updating your trip…"
}

@available(iOSApplicationExtension 16.1, *)
private func tripEta(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
  sharedDefault?.string(forKey: context.attributes.prefixedKey("eta")) ?? "—"
}

@available(iOSApplicationExtension 16.1, *)
private func tripPhase(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
  sharedDefault?.string(forKey: context.attributes.prefixedKey("phase")) ?? "searching"
}

@available(iOSApplicationExtension 16.1, *)
private func tripProgress(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> Int {
  sharedDefault?.integer(forKey: context.attributes.prefixedKey("progress")) ?? 0
}
