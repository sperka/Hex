import Foundation
import HexCore

#if canImport(FluidAudio)
import AVFoundation
import FluidAudio

/// Wraps FluidAudio's `StreamingNemotronMultilingualAsrManager` for live,
/// during-recording transcription.
///
/// Unlike `ParakeetClient` (batch: record a file, then transcribe it), this
/// model decodes incrementally: feed 16 kHz mono Float32 samples via `feed`
/// while recording, observe partial hypotheses through the callback set in
/// `startUtterance`, and collect the final text from `finishUtterance`.
///
/// The underlying manager is itself an actor and serializes its own work, but
/// frame *order* still matters — callers must funnel audio through a single
/// serial consumer so `feed` calls arrive in capture order.
actor NemotronStreamingClient {
  private var manager: StreamingNemotronMultilingualAsrManager?
  private var loadedChunkMs: Int?
  private var loadedLanguageCode: String?
  private let logger = HexLog.parakeet

  /// FluidAudio's on-disk layout for this model:
  /// `<Application Support>/FluidAudio/Models/<repoFolder>/<langDir>/<chunkMs>ms/`.
  /// `langDir` collapses to "latin" for en/es/fr/it/pt/de and "multilingual"
  /// otherwise (mirrors `languageDirectory(for:)`); `repoFolder` is FluidAudio's
  /// `Repo.nemotronMultilingual.folderName` ("nemotron-multilingual").
  private static let repoFolder = "nemotron-multilingual"

  /// Whether the requested variant's models are already cached on disk.
  func isModelAvailable(chunkMs: Int, languageCode: String) -> Bool {
    if manager != nil, loadedChunkMs == chunkMs, loadedLanguageCode == languageCode {
      return true
    }
    let metadata = variantDirectory(chunkMs: chunkMs, languageCode: languageCode)
      .appendingPathComponent("metadata.json")
    return FileManager.default.fileExists(atPath: metadata.path)
  }

  /// Downloads (if needed) and loads the requested variant into memory.
  /// Reuses the loaded manager when the chunk size and language are unchanged.
  func ensureLoaded(
    chunkMs: Int,
    languageCode: String,
    progress: @escaping (Progress) -> Void
  ) async throws {
    if manager != nil, loadedChunkMs == chunkMs, loadedLanguageCode == languageCode {
      return
    }
    // A different variant invalidates the loaded model.
    if loadedChunkMs != chunkMs || loadedLanguageCode != languageCode {
      manager = nil
      loadedChunkMs = nil
      loadedLanguageCode = nil
    }

    let t0 = Date()
    logger.notice("Starting Nemotron load chunkMs=\(chunkMs) lang=\(languageCode, privacy: .public)")
    let p = Progress(totalUnitCount: 100)
    p.completedUnitCount = 1
    progress(p)

    let variantDir = try await StreamingNemotronMultilingualAsrManager.downloadVariant(
      languageCode: languageCode,
      chunkMs: chunkMs,
      progressHandler: { downloadProgress in
        // Map FluidAudio's 0...1 download fraction onto 0...90; loading takes
        // the rest. Clamp because phases can report slightly out of range.
        let frac = max(0.0, min(1.0, downloadProgress.fractionCompleted))
        p.completedUnitCount = Int64(1 + frac * 89)
        progress(p)
      }
    )

    let manager = StreamingNemotronMultilingualAsrManager()
    try await manager.loadModels(from: variantDir)
    self.manager = manager
    self.loadedChunkMs = chunkMs
    self.loadedLanguageCode = languageCode
    p.completedUnitCount = 100
    progress(p)
    logger.notice("Nemotron ensureLoaded completed in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
  }

  /// Begins a fresh utterance: clears decoder state and installs the partial
  /// hypothesis callback.
  ///
  /// The callback fires with the **cumulative** running transcript (the full
  /// text decoded so far, not a delta) each time new tokens are emitted during
  /// `feed`. Consumers should replace their displayed text with each value, not
  /// append.
  func startUtterance(partial: @escaping @Sendable (String) -> Void) async throws {
    guard let manager else {
      throw NSError(
        domain: "Nemotron",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Nemotron not initialized"]
      )
    }
    await manager.reset()
    await manager.setPartialCallback(partial)
  }

  /// Feeds one chunk of 16 kHz mono Float32 samples.
  ///
  /// Partial hypotheses surface through the callback installed in
  /// `startUtterance`, not here — the underlying `process` always returns an
  /// empty string (it buffers and decodes internally), so there is no value to
  /// return.
  func feed(samples: [Float]) async throws {
    guard let manager else {
      throw NSError(
        domain: "Nemotron",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Nemotron not initialized"]
      )
    }
    _ = try await manager.process(samples: samples)
  }

  /// Flushes any buffered audio and returns the final transcript.
  func finishUtterance() async throws -> String {
    guard let manager else {
      throw NSError(
        domain: "Nemotron",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Nemotron not initialized"]
      )
    }
    return try await manager.finish()
  }

  /// Deletes cached model files for the given variant and resets live state if
  /// the deleted variant was the one loaded.
  func deleteCaches(chunkMs: Int, languageCode: String) async throws {
    let dir = variantDirectory(chunkMs: chunkMs, languageCode: languageCode)
    let fm = FileManager.default
    if fm.fileExists(atPath: dir.path) {
      try fm.removeItem(at: dir)
    }
    if loadedChunkMs == chunkMs, loadedLanguageCode == languageCode {
      manager = nil
      loadedChunkMs = nil
      loadedLanguageCode = nil
    }
  }

  // MARK: - Paths

  private func variantDirectory(chunkMs: Int, languageCode: String) -> URL {
    let root = (try? URL.hexParakeetModelsDirectory)
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FluidAudio/Models", isDirectory: true)
    return root
      .appendingPathComponent(Self.repoFolder, isDirectory: true)
      .appendingPathComponent(Self.languageDirectory(for: languageCode), isDirectory: true)
      .appendingPathComponent("\(chunkMs)ms", isDirectory: true)
  }

  /// Mirrors FluidAudio's `languageDirectory(for:)`: Latin-script European
  /// languages share the "latin" vocab-pruned ship; everything else uses the
  /// full "multilingual" ship.
  private static func languageDirectory(for languageCode: String) -> String {
    let c = languageCode.lowercased()
    let latinPrefixes = ["en", "es", "fr", "it", "pt", "de"]
    return latinPrefixes.contains(where: { c.hasPrefix($0) }) ? "latin" : "multilingual"
  }
}

#else

actor NemotronStreamingClient {
  func isModelAvailable(chunkMs: Int, languageCode: String) -> Bool { false }
  func ensureLoaded(chunkMs: Int, languageCode: String, progress: @escaping (Progress) -> Void) async throws {
    throw NSError(
      domain: "Nemotron",
      code: -2,
      userInfo: [NSLocalizedDescriptionKey: "Nemotron streaming support not linked. Add Swift Package: https://github.com/FluidInference/FluidAudio.git and link FluidAudio to Hex."]
    )
  }
  func startUtterance(partial: @escaping @Sendable (String) -> Void) async throws {
    throw NSError(domain: "Nemotron", code: -3, userInfo: [NSLocalizedDescriptionKey: "Nemotron not available"])
  }
  func feed(samples: [Float]) async throws {
    throw NSError(domain: "Nemotron", code: -3, userInfo: [NSLocalizedDescriptionKey: "Nemotron not available"])
  }
  func finishUtterance() async throws -> String {
    throw NSError(domain: "Nemotron", code: -3, userInfo: [NSLocalizedDescriptionKey: "Nemotron not available"])
  }
  func deleteCaches(chunkMs: Int, languageCode: String) async throws {}
}

#endif
