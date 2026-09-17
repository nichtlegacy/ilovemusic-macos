import Foundation

/// Bindable accessors for user preferences.
///
/// Pane views use `@Bindable var appModel: AppModel` and write
/// `$appModel.launchAtLogin` instead of the verbose
/// `Binding(get: { appModel.preferences.launchAtLogin },
///          set: { appModel.updateLaunchAtLogin($0) })`.
///
/// Each getter reads `preferences.X` (so SwiftUI Observation tracks the
/// underlying value), and each setter routes through the matching
/// `update*` method on `AppModel` so persistence and side-effect
/// application stay in one place.
///
/// Optional preference fields are exposed with the same default values
/// the panes used before (e.g. `recordHistoryEnabled ?? true`).
extension AppModel {

  // MARK: - General

  var launchAtLogin: Bool {
    get { preferences.launchAtLogin }
    set { updateLaunchAtLogin(newValue) }
  }

  var resumeLastStationOnLaunch: Bool {
    get { preferences.resumeLastStationOnLaunch }
    set { updateResumeLastStation(newValue) }
  }

  var appLanguage: AppLanguage {
    get { preferences.effectiveAppLanguage }
    set { updateAppLanguage(newValue) }
  }

  // MARK: - Playback

  var globalHotkeysEnabled: Bool {
    get { preferences.globalHotkeysEnabled }
    set { updateGlobalHotkeysEnabled(newValue) }
  }

  var volumePercentBinding: Int {
    get { activeVolumePercent }
    set { updateVolumePercent(newValue) }
  }

  var unlockMaxVolume: Bool {
    get { preferences.unlockMaxVolume ?? false }
    set { updateUnlockMaxVolume(newValue) }
  }

  // MARK: - Library

  var stationSort: StationSortPreference {
    get { preferences.stationSort }
    set { updateStationSort(newValue) }
  }

  // MARK: - Data / History

  var recordHistoryEnabled: Bool {
    get { preferences.recordHistoryEnabled ?? true }
    set { updateRecordHistoryEnabled(newValue) }
  }

  // MARK: - Discord

  var discordEnabled: Bool {
    get { preferences.discordEnabled ?? false }
    set { updateDiscordEnabled(newValue) }
  }

  var discordShowArtwork: Bool {
    get { preferences.discordShowArtwork ?? true }
    set { updateDiscordShowArtwork(newValue) }
  }

  var discordShowButton: Bool {
    get { preferences.discordShowButton ?? true }
    set { updateDiscordShowButton(newValue) }
  }

  var discordShowListeners: Bool {
    get { preferences.discordShowListeners ?? true }
    set { updateDiscordShowListeners(newValue) }
  }

  var discordShowStationLogo: Bool {
    get { preferences.discordShowStationLogo ?? true }
    set { updateDiscordShowStationLogo(newValue) }
  }

  var discordClientID: String {
    get { preferences.discordClientID ?? "" }
    set { updateDiscordClientID(newValue) }
  }
}
