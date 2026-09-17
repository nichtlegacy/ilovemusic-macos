import SwiftUI

struct AdvancedPane: View {
  @Environment(\.locale) private var locale
  @Bindable var appModel: AppModel
  @State private var maintenanceStatus: LocalizedStringResource?

  var body: some View {
    Form {
      Section {
        LabeledContent {
          Button {
            Task {
              await appModel.refreshAll()
              maintenanceStatus = LocalizedStringResource("Refresh complete", bundle: #bundle, comment: "Maintenance operation result")
            }
          } label: {
            Text("Refresh Now", bundle: #bundle)
          }
        } label: {
          Text("Station data", bundle: #bundle)
        }
        LabeledContent {
          Button {
            Task {
              await appModel.clearCachedCatalog()
              maintenanceStatus = LocalizedStringResource("Catalog cache cleared", bundle: #bundle, comment: "Maintenance operation result")
            }
          } label: {
            Text("Clear Cache", bundle: #bundle)
          }
        } label: {
          Text("Catalog cache", bundle: #bundle)
        }
        LabeledContent {
          Button {
            appModel.clearCachedArtwork()
            maintenanceStatus = LocalizedStringResource("Artwork cache cleared", bundle: #bundle, comment: "Maintenance operation result")
          } label: {
            Text("Clear Cache", bundle: #bundle)
          }
        } label: {
          Text("Artwork cache", bundle: #bundle)
        }
        if let maintenanceStatus {
          Label {
            Text(maintenanceStatus.resolved(in: locale))
          } icon: {
            Image(systemName: "checkmark.circle.fill")
          }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Maintenance", bundle: #bundle)
      } footer: {
        Text("Catalog refreshes every 15 minutes, listeners every 2 minutes, and now-playing data every 30 seconds.", bundle: #bundle)
      }

      Section {
        LabeledContent { Text(appModel.diagnostics.source.titleResource.resolved(in: locale)) } label: { Text("Catalog source", bundle: #bundle) }
        LabeledContent { Text(verbatim: "\(appModel.diagnostics.rawStationCount)") } label: { Text("Raw stations", bundle: #bundle) }
        LabeledContent { Text(verbatim: "\(appModel.diagnostics.visibleStationCount)") } label: { Text("Visible stations", bundle: #bundle) }
        LabeledContent { Text(verbatim: "\(appModel.diagnostics.filteredOutCount)") } label: { Text("Filtered out", bundle: #bundle) }
        LabeledContent {
          if let name = appModel.diagnostics.activeStationName { Text(verbatim: name) } else { Text("None", bundle: #bundle) }
        } label: { Text("Active station", bundle: #bundle) }
        LabeledContent {
          if let date = appModel.diagnostics.lastMetadataRefreshAt { Text(verbatim: date.shortTimeOrDateTime(locale: locale)) } else { Text("Never", bundle: #bundle) }
        } label: { Text("Last metadata", bundle: #bundle) }
        LabeledContent {
          if let date = appModel.diagnostics.lastArtworkCacheClearAt { Text(verbatim: date.shortTimeOrDateTime(locale: locale)) } else { Text("Never", bundle: #bundle) }
        } label: { Text("Artwork cleared", bundle: #bundle) }
      } header: {
        Text("Catalog diagnostics", bundle: #bundle)
      }

      Section {
        LogPanel(
          entries: appModel.discordConnectionLog,
          persistedCap: 80,
          onClear: { appModel.clearDiscordConnectionLog() }
        )
      } header: { Text("Discord log", bundle: #bundle) }

      Section {
        LogPanel(
          entries: appModel.controlConnectionLog,
          persistedCap: 80,
          onClear: { appModel.clearControlConnectionLog() }
        )
      } header: { Text("Stream Deck log", bundle: #bundle) }
    }
    .settingsFormStyle()
  }
}
