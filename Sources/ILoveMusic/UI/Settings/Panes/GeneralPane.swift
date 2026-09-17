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
              restartText(Self.languageRestartNoticeResource)
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
                restartText(Self.restartButtonResource)
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
      restartText(Self.restartFailedResource),
      isPresented: $relaunchFailed
    ) {
      Button(role: .cancel) {
      } label: {
        restartText(Self.cancelResource)
      }
    } message: {
      restartText(Self.restartFailureHelpResource)
    }
  }

  /// The pending-restart controls use the newly selected language so the user
  /// can understand the action that applies that choice.
  private func restartText(_ resource: LocalizedStringResource) -> Text {
    Text(verbatim: AppLocalization.string(resource, language: appModel.appLanguage))
  }

  static let languageRestartNoticeResource = LocalizedStringResource(
    "The language changes after you restart ILoveMusic.",
    bundle: #bundle,
    comment: "Explanation shown after selecting a different app language."
  )

  static let restartButtonResource = LocalizedStringResource(
    "Restart ILoveMusic",
    bundle: #bundle,
    comment: "Button that relaunches the app to apply a language change."
  )

  static let restartFailedResource = LocalizedStringResource(
    "ILoveMusic couldn’t restart.",
    bundle: #bundle,
    comment: "Alert title shown when relaunching after a language change fails."
  )

  static let cancelResource = LocalizedStringResource(
    "Cancel",
    bundle: #bundle,
    comment: "Button that dismisses the language relaunch failure alert."
  )

  static let restartFailureHelpResource = LocalizedStringResource(
    "Quit and reopen ILoveMusic to apply the language.",
    bundle: #bundle,
    comment: "Recovery instruction after relaunching for a language change fails."
  )
}
