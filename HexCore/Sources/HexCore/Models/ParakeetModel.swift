import Foundation

/// Which FluidAudio engine backs a given model.
///
/// This is the source of truth for transcription routing: `.tdtBatch` models
/// record first and transcribe a finished file, while `.nemotronStreaming`
/// models decode live while audio is captured.
public enum FluidEngine: Sendable {
	case tdtBatch
	case nemotronStreaming
}

/// Known FluidAudio Core ML bundles that Hex supports.
public enum ParakeetModel: String, CaseIterable, Sendable {
	case englishV2 = "parakeet-tdt-0.6b-v2-coreml"
	case multilingualV3 = "parakeet-tdt-0.6b-v3-coreml"
	case nemotronStreamingMultilingual = "nemotron-3.5-asr-streaming-0.6b-coreml"

	/// The logical identifier used throughout the app (settings key, curated-list
	/// id, routing).
	///
	/// For the batch Parakeet models this also matches FluidAudio's on-disk
	/// folder name. The Nemotron streaming model does not: FluidAudio lays it out
	/// under `<repo>/<langDir>/<chunkMs>ms`, so for that case this value is purely
	/// Hex's logical key and availability/delete must use the streaming client's
	/// repo path rather than a folder-name match.
	public var identifier: String { rawValue }

	/// Which FluidAudio engine drives this model.
	public var engine: FluidEngine {
		switch self {
		case .englishV2, .multilingualV3:
			return .tdtBatch
		case .nemotronStreamingMultilingual:
			return .nemotronStreaming
		}
	}

	/// Whether this model decodes live during recording (vs. record-then-transcribe).
	public var isStreaming: Bool {
		engine == .nemotronStreaming
	}

	/// Whether the model only supports English transcription.
	public var isEnglishOnly: Bool {
		self == .englishV2
	}

	/// Short capability label for UI copy.
	public var capabilityLabel: String {
		switch self {
		case .englishV2:
			return "English"
		case .multilingualV3:
			return "Multilingual"
		case .nemotronStreamingMultilingual:
			return "Streaming · Multilingual"
		}
	}

	/// Convenience text for recommendation badges.
	public var recommendationLabel: String {
		switch self {
		case .englishV2:
			return "Recommended (English)"
		case .multilingualV3:
			return "Recommended (Multilingual)"
		case .nemotronStreamingMultilingual:
			return "Recommended (Streaming)"
		}
	}
}
