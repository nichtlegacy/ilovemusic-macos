import Foundation

func formatShortListeningDuration(_ seconds: Double) -> String {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : (seconds >= 60 ? [.minute] : [.second])
  formatter.unitsStyle = .short
  formatter.maximumUnitCount = 2
  return formatter.string(from: seconds) ?? "0 sec"
}

func formatClockListeningDuration(_ seconds: Double) -> String {
  let totalSeconds = Int(seconds.rounded())
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let remainder = totalSeconds % 60

  if hours > 0 {
    return "\(hours):" + String(format: "%02d:%02d", minutes, remainder)
  }
  return "\(minutes):" + String(format: "%02d", remainder)
}

func formatAxisListeningDuration(_ seconds: Double) -> String {
  if seconds >= 3600 {
    let hours = Int((seconds / 3600).rounded())
    return "\(hours) h"
  }
  let minutes = Int((seconds / 60).rounded())
  return "\(max(minutes, 0)) min"
}
