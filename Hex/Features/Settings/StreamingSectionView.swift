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
			set: { newValue in store.$hexSettings.withLock { $0.nemotronChunkMs = newValue } }
		)
	}

	private var showLivePartials: Binding<Bool> {
		Binding(
			get: { store.hexSettings.showLivePartials },
			set: { newValue in store.$hexSettings.withLock { $0.showLivePartials = newValue } }
		)
	}

	private func chunkLabel(_ ms: Int) -> String {
		String(format: "%.2fs", Double(ms) / 1000.0)
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
}
