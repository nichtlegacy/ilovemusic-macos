import SwiftUI

struct AdvancedPane: View {
  @Bindable var appModel: AppModel
  @State private var maintenanceStatus: String?

  var body: some View {
    Form {
      Section {
        LabeledContent("Station data") {
          Button("Refresh Now") {
            Task {
              await appModel.refreshAll()
              maintenanceStatus = "Refresh complete"
            }
          }
        }
        LabeledContent("Catalog cache") {
          Button("Clear Cache") {
            Task {
              await appModel.clearCachedCatalog()
              maintenanceStatus = "Catalog cache cleared"
            }
          }
        }
        LabeledContent("Artwork cache") {
          Button("Clear Cache") {
            appModel.clearCachedArtwork()
            maintenanceStatus = "Artwork cache cleared"
          }
        }
        if let maintenanceStatus {
          Label(maintenanceStatus, systemImage: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Maintenance")
      } footer: {
        Text("Catalog refreshes every 15 minutes, listeners every 2 minutes, and now-playing data every 30 seconds.")
      }

      Section("Catalog diagnostics") {
        LabeledContent("Catalog source", value: appModel.diagnostics.source.title)
        LabeledContent("Raw stations", value: "\(appModel.diagnostics.rawStationCount)")
        LabeledContent("Visible stations", value: "\(appModel.diagnostics.visibleStationCount)")
        LabeledContent("Filtered out", value: "\(appModel.diagnostics.filteredOutCount)")
        LabeledContent("Active station", value: appModel.diagnostics.activeStationName ?? "None")
        LabeledContent("Last metadata", value: appModel.diagnostics.lastMetadataRefreshAt?.shortTimeOrDateTime ?? "Never")
        LabeledContent("Artwork cleared", value: appModel.diagnostics.lastArtworkCacheClearAt?.shortTimeOrDateTime ?? "Never")
      }

      Section("Discord log") {
        LogPanel(
          entries: appModel.discordConnectionLog,
          persistedCap: 80,
          onClear: { appModel.clearDiscordConnectionLog() }
        )
      }

      Section("Stream Deck log") {
        LogPanel(
          entries: appModel.controlConnectionLog,
          persistedCap: 80,
          onClear: { appModel.clearControlConnectionLog() }
        )
      }
    }
    .settingsFormStyle()
  }
}
