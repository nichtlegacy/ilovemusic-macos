import AppKit
import SwiftUI

struct SettingsSidebar: View {
  @Binding var selection: SettingsTab

  private var versionString: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "0.1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
  }

  var body: some View {
    ZStack {
      SettingsVisualEffectView(material: .sidebar)

      VStack(spacing: 0) {
        List(selection: $selection) {
          ForEach(SettingsTab.allCases) { tab in
            HStack(spacing: 9) {
              SettingsIconChip(tab: tab)
              Text(tab.title)
            }
            .tag(tab)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
          }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .scrollEdgeEffectSoftIfAvailable()

        Divider()

        HStack(spacing: 10) {
          appIcon
          VStack(alignment: .leading, spacing: 1) {
            Text(AppIdentity.displayName)
              .font(.callout.weight(.semibold))
            Text(versionString)
              .font(.caption)
              .foregroundStyle(.tertiary)
              .monospacedDigit()
          }
          Spacer(minLength: 0)
        }
        .padding(12)
      }
    }
  }

  @ViewBuilder
  private var appIcon: some View {
    if let image = Bundle.module.image(forResource: "AppLogo") {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(.pink.gradient)
        .frame(width: 36, height: 36)
        .overlay {
          Text("I♥")
            .font(.system(size: 16, weight: .black))
            .foregroundStyle(.white)
        }
    }
  }
}
