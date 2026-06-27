import ComposableArchitecture
import Darwin
import Inject
import SwiftUI

struct CuratedRow: View {
	@ObserveInjection var inject
	@Bindable var store: StoreOf<ModelDownloadFeature>
	let model: CuratedModelInfo
	@State private var showStreamingInfo = false

	var isSelected: Bool {
		let selected = store.hexSettings.selectedModel
		if model.internalName.contains("*") || model.internalName.contains("?") {
			return fnmatch(model.internalName, selected, 0) == 0
		}
		// Also consider the inverse: selected may be a concrete name while the curated item is a prefix-like value
		if selected.contains("*") || selected.contains("?") {
			return fnmatch(selected, model.internalName, 0) == 0
		}
		return model.internalName == selected
	}

	var body: some View {
		Button(action: { store.send(.selectModel(model.internalName)) }) {
			HStack(alignment: .center, spacing: 12) {
				// Radio selector
				Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
					.foregroundStyle(isSelected ? .blue : .secondary)

				// Title and ratings
				VStack(alignment: .leading, spacing: 6) {
					HStack(spacing: 6) {
						Text(model.displayName)
							.font(.headline)
						if let badge = model.badge {
							Text(badge)
								.font(.caption2)
								.fontWeight(.semibold)
								.foregroundStyle(.white)
								.padding(.horizontal, 6)
								.padding(.vertical, 2)
								.background(Color.accentColor)
								.clipShape(RoundedRectangle(cornerRadius: 4))
						}
						if model.parakeetModel?.isStreaming == true {
							streamingInfoButton
						}
					}
					HStack(spacing: 16) {
						HStack(spacing: 6) {
							StarRatingView(model.accuracyStars)
							Text("Accuracy").font(.caption2).foregroundStyle(.secondary)
						}
						HStack(spacing: 6) {
							StarRatingView(model.speedStars)
							Text("Speed").font(.caption2).foregroundStyle(.secondary)
						}
					}
				}

				Spacer(minLength: 12)

				// Trailing size and action/progress icons, aligned to the right
				HStack(spacing: 12) {
					// Size with an adjacent reveal-in-Finder button (only when the
					// model has files on disk).
					HStack(spacing: 4) {
						if model.isDownloaded {
							Button {
								store.send(.revealModel(model.internalName))
							} label: {
								Image(systemName: "folder")
							}
							.buttonStyle(.borderless)
							.foregroundStyle(.secondary)
							.help("Reveal in Finder")
						}

						Text(model.storageSize)
							.foregroundStyle(.secondary)
							.font(.subheadline)
					}
					.frame(width: 96, alignment: .trailing)

					// Download/Progress/Downloaded at far right
					ZStack {
						if store.isDownloading, store.downloadingModelName == model.internalName {
							ProgressView(value: store.downloadProgress)
								.progressViewStyle(.circular)
								.controlSize(.small)
								.tint(.blue)
								.frame(width: 24, height: 24)
								.help("Downloading… \(Int(store.downloadProgress * 100))%")
						} else if model.isDownloaded {
							Image(systemName: "checkmark.circle.fill")
								.foregroundStyle(.green)
								.frame(width: 24, height: 24)
								.help("Downloaded")
						} else {
							Button {
								store.send(.selectModel(model.internalName))
								store.send(.downloadSelectedModel)
							} label: {
								Image(systemName: "arrow.down.circle")
							}
							.buttonStyle(.borderless)
							.help("Download")
							.frame(width: 24, height: 24)
						}
					}
				}
			}
			.padding(10)
			.background(
				RoundedRectangle(cornerRadius: 10)
					.fill(isSelected ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 10)
					.stroke(isSelected ? Color.blue.opacity(0.35) : Color.gray.opacity(0.18))
			)
			.contentShape(.rect)
		}
		.buttonStyle(.plain)
		// Keep context menu as an alternative path
		.contextMenu {
			if store.isDownloading, store.downloadingModelName == model.internalName {
				Button("Cancel Download", role: .destructive) { store.send(.cancelDownload) }
			}
			if model.isDownloaded || (store.isDownloading && store.downloadingModelName == model.internalName) {
				Button("Show in Finder") { store.send(.openModelLocation) }
			}
			if model.isDownloaded {
				Divider()
				Button("Delete", role: .destructive) {
					store.send(.selectModel(model.internalName))
					store.send(.deleteSelectedModel)
				}
			}
		}
		.enableInjection()
	}

	/// Info affordance for streaming models, explaining the per-chunk download.
	private var streamingInfoButton: some View {
		Button {
			showStreamingInfo = true
		} label: {
			Image(systemName: "info.circle")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.buttonStyle(.plain)
		.help("About chunk-size downloads")
		.popover(isPresented: $showStreamingInfo, arrowEdge: .bottom) {
			VStack(alignment: .leading, spacing: 8) {
				Text("Streaming model")
					.font(.headline)
				Text("This model transcribes live as you speak. Each chunk size (set in the Streaming section) is a separate ~600 MB download.")
					.font(.callout)
				Text("Switching to a chunk size you haven't downloaded yet will need to download it before you can record at that size.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			.padding(14)
			.frame(width: 300)
		}
	}
}
