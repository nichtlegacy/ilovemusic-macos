import Foundation

func formatShortListeningDuration(_ seconds: Double, locale: Locale = .current) -> String {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : (seconds >= 60 ? [.minute] : [.second])
  formatter.unitsStyle = .short
  formatter.maximumUnitCount = 2
  var calendar = Calendar.current
  calendar.locale = locale
  formatter.calendar = calendar
  return formatter.string(from: seconds) ?? formatter.string(from: 0) ?? "0"
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

func formatAxisListeningDuration(_ seconds: Double, locale: Locale = .current) -> String {
  if seconds >= 3600 {
    let hours = Int((seconds / 3600).rounded())
    return "\(hours.formatted(.number.locale(locale))) h"
  }
  let minutes = Int((seconds / 60).rounded())
  return "\(max(minutes, 0).formatted(.number.locale(locale))) min"
}

func localizedSongCount(_ count: Int, locale: Locale = .current) -> String {
  String(
    localized: LocalizedStringResource(
      "\(count) songs",
      locale: locale,
      bundle: #bundle,
      comment: "Number of songs shown in listening history."
    )
  )
}

func localizedPlayCount(_ count: Int, locale: Locale = .current) -> String {
  String(
    localized: LocalizedStringResource(
      "\(count) plays",
      locale: locale,
      bundle: #bundle,
      comment: "Number of times a song, artist, or station was played."
    )
  )
}

func localizedDayCount(_ count: Int, locale: Locale = .current) -> String {
  String(
    localized: LocalizedStringResource(
      "\(count) days",
      locale: locale,
      bundle: #bundle,
      comment: "Number of consecutive listening days in a streak."
    )
  )
}

func localizedMondayFirstWeekdaySymbols(locale: Locale = .current) -> [String] {
  let formatter = DateFormatter()
  formatter.locale = locale
  let sundayFirst = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
  guard sundayFirst.count == 7 else { return [] }
  return Array(sundayFirst.dropFirst()) + [sundayFirst[0]]
}
