import ComposableArchitecture
import HexCore
import Inject
import SwiftUI

/// Settings for live streaming transcription models (e.g. Nemotron). Shown only
/// when a streaming model is selected.
struct StreamingSectionView: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<SettingsFeature>

	private var chunkMs: Binding<Int> {
		Binding(
			get: { store.hexSettings.nemotronChunkMs },
			set: { store.send(.setNemotronChunkMs($0)) }
		)
	}

	private var showLivePartials: Binding<Bool> {
		Binding(
			get: { store.hexSettings.showLivePartials },
			set: { store.send(.setShowLivePartials($0)) }
		)
	}

	private func chunkLabel(_ ms: Int) -> String {
		String(format: "%.2fs", Double(ms) / 1000.0)
	}

	/// The curated entry for the selected streaming model. Its `isDownloaded`
	/// reflects the *currently selected chunk size* (refreshed when the chunk
	/// picker changes), so it tracks whether this exact variant is on disk.
	private var streamingModel: CuratedModelInfo? {
		store.modelDownload.curatedModels.first { $0.parakeetModel?.isStreaming == true }
	}

	/// True while the selected streaming model's chunk variant is downloading.
	private var isDownloadingThisModel: Bool {
		guard let streamingModel else { return false }
		return store.modelDownload.isDownloading
			&& store.modelDownload.downloadingModelName == streamingModel.internalName
	}

	var body: some View {
		Section("Streaming") {
			Label {
				Picker("Chunk size", selection: chunkMs) {
					ForEach(HexSettings.allowedNemotronChunkMs, id: \.self) { ms in
						Text(chunkLabel(ms)).tag(ms)
					}
				}
				Text("Larger chunks improve accuracy and punctuation; smaller chunks lower latency. 0.56s can drop punctuation on long sessions (FluidAudio #687).")
					.settingsCaption()
				chunkDownloadStatus
			} icon: {
				Image(systemName: "waveform")
			}

			Label {
				Toggle("Show live transcript", isOn: showLivePartials)
				Text("Display the running transcript in the recording indicator while you speak.")
					.settingsCaption()
			} icon: {
				Image(systemName: "text.bubble")
			}
		}
		.enableInjection()
	}

	/// Inline download state for the selected chunk variant, shown right under
	/// the picker so a chunk change that needs a new ~600 MB download is visible
	/// here instead of failing silently at record time.
	@ViewBuilder
	private var chunkDownloadStatus: some View {
		if let streamingModel {
			if isDownloadingThisModel {
				VStack(alignment: .leading, spacing: 4) {
					HStack(spacing: 6) {
						ProgressView().controlSize(.small)
						Text("Downloading \(chunkLabel(store.hexSettings.nemotronChunkMs)) model… \(Int(store.modelDownload.downloadProgress * 100))%")
							.font(.caption)
						Spacer()
						Button("Cancel") { store.send(.modelDownload(.cancelDownload)) }
							.buttonStyle(.borderless)
							.controlSize(.small)
					}
					ProgressView(value: store.modelDownload.downloadProgress)
						.tint(.blue)
				}
				.padding(.top, 4)
			} else if !streamingModel.isDownloaded {
				HStack(spacing: 8) {
					Image(systemName: "arrow.down.circle")
						.foregroundStyle(.orange)
					VStack(alignment: .leading, spacing: 1) {
						Text("This chunk size isn't downloaded yet")
							.font(.caption)
						Text(streamingModel.storageSize)
							.settingsCaption()
					}
					Spacer()
					Button("Download") { store.send(.modelDownload(.downloadSelectedModel)) }
						.controlSize(.small)
				}
				.padding(.top, 4)
			} else {
				HStack(spacing: 6) {
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(.green)
					Text("\(chunkLabel(store.hexSettings.nemotronChunkMs)) model ready")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.top, 4)
			}
		}
	}
}
