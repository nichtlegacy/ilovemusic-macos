import Foundation
import Testing
@testable import ILoveMusic

@Test
func supportDirectoryUsesCanonicalFolderName() throws {
  let fileManager = FileManager.default
  let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: root) }

  let resolved = AppSupportPaths.supportDirectory(
    fileManager: fileManager,
    applicationSupportURL: root
  )

  #expect(resolved == root.appendingPathComponent("ILoveMusic", isDirectory: true))
  #expect(fileManager.fileExists(atPath: resolved.path))
}

@Test
func supportDirectoryKeepsExistingPreferredFolder() throws {
  let fileManager = FileManager.default
  let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: root) }

  let preferredDirectory = root.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
  try fileManager.createDirectory(at: preferredDirectory, withIntermediateDirectories: true)

  let resolved = AppSupportPaths.supportDirectory(
    fileManager: fileManager,
    applicationSupportURL: root
  )

  #expect(resolved == preferredDirectory)
}
