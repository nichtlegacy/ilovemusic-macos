import Foundation
import Testing
@testable import ILoveMusic

@Test
func socketDiscoveryFindsHigherIndexedSocketInPreferredBasePath() throws {
  let fileManager = FileManager.default
  let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let xdg = root.appendingPathComponent("xdg", isDirectory: true)
  let tmpdir = root.appendingPathComponent("tmpdir", isDirectory: true)

  try fileManager.createDirectory(at: xdg, withIntermediateDirectories: true)
  try fileManager.createDirectory(at: tmpdir, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: root) }

  let preferredSocket = xdg.appendingPathComponent("discord-ipc-3")
  let laterSocket = tmpdir.appendingPathComponent("discord-ipc-0")
  fileManager.createFile(atPath: preferredSocket.path, contents: Data())
  fileManager.createFile(atPath: laterSocket.path, contents: Data())

  let resolved = DiscordIPCClient.findSocketPath(
    fileManager: fileManager,
    environment: [
      "XDG_RUNTIME_DIR": xdg.path,
      "TMPDIR": tmpdir.path
    ]
  )

  #expect(resolved == preferredSocket.path)
}

@Test
func socketDiscoveryFindsNestedDiscordAppSocket() throws {
  let fileManager = FileManager.default
  let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  let runtime = root.appendingPathComponent("runtime", isDirectory: true)
  let nestedDirectory = runtime.appendingPathComponent("app.com.discordapp.Discord", isDirectory: true)

  try fileManager.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
  defer { try? fileManager.removeItem(at: root) }

  let nestedSocket = nestedDirectory.appendingPathComponent("discord-ipc-7")
  fileManager.createFile(atPath: nestedSocket.path, contents: Data())

  let resolved = DiscordIPCClient.findSocketPath(
    fileManager: fileManager,
    environment: ["TMPDIR": runtime.path]
  )

  #expect(resolved == nestedSocket.path)
}
