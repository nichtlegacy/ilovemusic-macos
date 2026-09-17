import AppKit
import SwiftUI

struct GeneralPane: View {
  @Environment(\.locale) private var locale
  @Bindable var appModel: AppModel
  @State private var relaunchFailed = false

  var body: some View {
    Form {
      Section {
        SettingsToggle(
          LocalizedStringResource("Launch at login", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Automatically opens ILoveMusic when you start your Mac.", bundle: #bundle, comment: "Launch at login explanation"),
          isOn: $appModel.launchAtLogin
        )
        if let message = appModel.launchAtLoginStatus.messageResource {
          Label {
            Text(message.resolved(in: locale))
          } icon: {
            Image(systemName: "exclamationmark.triangle")
          }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        SettingsToggle(
          LocalizedStringResource("Resume last station on launch", bundle: #bundle, comment: "Settings toggle"),
          subtitle: LocalizedStringResource("Reopens the station that was active before quitting.", bundle: #bundle, comment: "Resume playback explanation"),
          isOn: $appModel.resumeLastStationOnLaunch
        )
        Picker(selection: $appModel.appLanguage) {
          Text("System Default", bundle: #bundle).tag(AppLanguage.system)
          Text("Deutsch", bundle: #bundle).tag(AppLanguage.german)
          Text("English", bundle: #bundle).tag(AppLanguage.english)
        } label: {
          Text("Language", bundle: #bundle)
        }
        .pickerStyle(.menu)

        if appModel.requiresLanguageRestart {
          VStack(alignment: .leading, spacing: 8) {
            Label {
              Text("The language changes after you restart ILoveMusic.", bundle: #bundle)
            } icon: {
              Image(systemName: "arrow.clockwise")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            HStack {
              Spacer()
              Button {
                do {
                  try AppRelauncher.restart()
                } catch {
                  relaunchFailed = true
                }
              } label: {
                Text("Restart ILoveMusic", bundle: #bundle)
              }
            }
          }
        }
      } header: {
        Text("System", bundle: #bundle)
      }

      Section {
        Picker(selection: $appModel.stationSort) {
          ForEach(StationSortPreference.allCases) { Text($0.titleResource.resolved(in: locale)).tag($0) }
        } label: {
          Text("Channel order", bundle: #bundle)
        }
        .pickerStyle(.menu)
      } header: {
        Text("Library", bundle: #bundle)
      } footer: {
        Text("Popularity sorts by current listener count; Alphabetical sorts by name.", bundle: #bundle)
      }
    }
    .settingsFormStyle()
    .alert(
      Text("ILoveMusic couldn’t restart.", bundle: #bundle),
      isPresented: $relaunchFailed
    ) {
      Button(role: .cancel) {
      } label: {
        Text("Cancel", bundle: #bundle)
      }
    } message: {
      Text("Quit and reopen ILoveMusic to apply the language.", bundle: #bundle)
    }
  }
}
