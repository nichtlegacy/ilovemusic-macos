import SwiftUI

struct PlaybackPane: View {
  @Bindable var appModel: AppModel

  /// IDs of slots whose recorder rows are actively listening. While any slot
  /// is recording we suspend the Carbon hotkey listener so the user's combo
  /// reaches the `NSEvent` monitor instead of firing the global shortcut.
  @State private var recordingSlots: Set<HotkeyID> = []

  var body: some View {
    PrefsScrollPane {
      SettingsBlock("Default Volume") {
        VStack(alignment: .leading, spacing: 4) {
          Text("Default volume").font(.body)
          Text("The slider in the menu uses a perceptual curve — 50% sounds quieter than half power.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
          HStack {
            Button {
              appModel.toggleMute()
            } label: {
              Image(systemName: appModel.isVolumeMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .foregroundStyle(appModel.isVolumeMuted ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(appModel.isVolumeMuted ? "Unmute" : "Mute")
            Slider(value: Binding(
              get: { Double(appModel.activeVolumePercent) },
              set: { appModel.updateVolumePercent(Int($0.rounded())) }
            ), in: 0...100)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            Text("\(appModel.activeVolumePercent)%")
              .font(.callout.monospacedDigit())
              .frame(width: 44, alignment: .trailing)
          }

          PreferenceToggleRow(
            title: "Unlock maximum volume",
            subtitle: "Off: output is capped below full power so low slider positions are easier to fine-tune. On: the slider reaches full volume.",
            isOn: $appModel.unlockMaxVolume
          )
        }
      }

      Divider()

      SettingsBlock("Hotkeys") {
        PreferenceToggleRow(
          title: "Enable global hotkeys",
          subtitle: "Hotkeys work from anywhere on the system, not just when the menu is open.",
          isOn: $appModel.globalHotkeysEnabled
        )

        VStack(alignment: .leading, spacing: 8) {
          ForEach(HotkeyID.allCases, id: \.self) { id in
            HotkeyRecorderRow(
              id: id,
              binding: appModel.preferences.hotkeyBinding(for: id),
              conflictForCandidate: { candidate in
                conflictingActionTitle(for: candidate, excluding: id)
              },
              onSave: { newBinding in
                appModel.updateHotkey(id, binding: newBinding)
              },
              onRecordingChanged: { recording in
                handleRecordingChange(id: id, recording: recording)
              }
            )
            .opacity(appModel.globalHotkeysEnabled ? 1 : 0.5)
            .disabled(!appModel.globalHotkeysEnabled)
          }

          if !appModel.hotkeyConflicts.isEmpty {
            Label(
              "macOS or another app already uses \(conflictingHotkeyNames). Pick a different combination.",
              systemImage: "exclamationmark.triangle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          }

          Text("Tap a shortcut to record. Press Esc to clear, or use the trash icon.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .onDisappear {
      // If the pane is torn down mid-recording (tab switch / window close),
      // the recorder rows never report `recording = false`, so the Carbon
      // hotkey listener would stay suspended indefinitely. Restore it here.
      if !recordingSlots.isEmpty {
        recordingSlots.removeAll()
        appModel.resumeGlobalHotkeys()
      }
    }
  }

  // MARK: - Conflict + recording lifecycle

  /// Titles of the slots the system refused, in the stable `HotkeyID` order.
  private var conflictingHotkeyNames: String {
    HotkeyID.allCases
      .filter { appModel.hotkeyConflicts.contains($0) }
      .map(\.title)
      .joined(separator: ", ")
  }

  private func conflictingActionTitle(for candidate: HotkeyBinding, excluding id: HotkeyID) -> String? {
    for other in HotkeyID.allCases where other != id {
      if let existing = appModel.preferences.hotkeyBinding(for: other),
         existing.keyCode == candidate.keyCode,
         existing.modifiers == candidate.modifiers {
        return other.title
      }
    }
    return nil
  }

  private func handleRecordingChange(id: HotkeyID, recording: Bool) {
    if recording {
      if recordingSlots.isEmpty {
        appModel.suspendGlobalHotkeysForRecording()
      }
      recordingSlots.insert(id)
    } else {
      recordingSlots.remove(id)
      if recordingSlots.isEmpty {
        appModel.resumeGlobalHotkeys()
      }
    }
  }
}
