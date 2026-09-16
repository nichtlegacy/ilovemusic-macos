import SwiftUI

/// Capsule status pill used in the Discord and Stream Deck pane headers.
///
/// Color contract (matches `design.md` §5.5):
///   - connected/active → `.green`
///   - busy / connecting → `.yellow`
///   - error → `.red`
///   - idle / disconnected → `.secondary`
@MainActor
struct StatusBadge: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
      Text(label)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.quaternary, in: Capsule())
  }
}
