import SwiftUI

struct FileTranscriptionJobRow: View {
  let job: FileTranscriptionJob
  let copy: () -> Void
  let remove: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content

      Divider()

      HStack {
        HStack(spacing: 6) {
          Image(systemName: job.status.systemImage)
            .foregroundStyle(job.status.tint)
          Text(job.fileName)
            .lineLimit(1)
          Text("•")
          Text(job.status.title)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        Spacer()

        HStack(spacing: 10) {
          if job.status == .completed {
            Button {
              copy()
              showCopyAnimation()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc.fill")
                if showCopied {
                  Text("Copied").font(.caption)
                }
              }
            }
            .buttonStyle(.plain)
            .foregroundStyle(showCopied ? .green : .secondary)
            .help("Copy to clipboard")
          }

          Button(action: remove) {
            Image(systemName: "xmark")
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .help("Remove from this list")
        }
        .font(.subheadline)
      }
      .frame(height: 20)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
    }
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.windowBackgroundColor).opacity(0.5))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    )
    .onDisappear {
      copyTask?.cancel()
    }
  }

  @ViewBuilder
  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      if job.status == .transcribing || job.status == .saving {
        progressSection
      }

      if let error = job.errorMessage {
        Text(error)
          .font(.callout)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let transcript = job.transcriptText {
        Text(transcript)
          .font(.body)
          .foregroundStyle(.primary)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.trailing, 40)
    .padding(12)
  }

  @ViewBuilder
  private var progressSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(job.status == .saving ? "Saving transcript..." : "Transcribing audio...")
          .foregroundStyle(.secondary)
        Spacer()
        // Live elapsed timer; ticks every second while transcribing.
        TimelineView(.periodic(from: .now, by: 1)) { context in
          if let elapsed = job.elapsed(now: context.date) {
            Text(Self.formatElapsed(elapsed))
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
        }
        if let progress = job.progress {
          Text("\(Int(progress * 100))%")
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
      }
      .font(.callout)

      // Determinate where the engine reports progress (Nemotron file path),
      // indeterminate otherwise (Whisper / Parakeet batch).
      if let progress = job.progress, job.status == .transcribing {
        ProgressView(value: progress)
      } else {
        ProgressView().progressViewStyle(.linear)
      }
    }
  }

  private static func formatElapsed(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  @State private var showCopied = false
  @State private var copyTask: Task<Void, Error>?

  private func showCopyAnimation() {
    copyTask?.cancel()

    copyTask = Task {
      withAnimation {
        showCopied = true
      }

      try await Task.sleep(for: .seconds(1.5))

      withAnimation {
        showCopied = false
      }
    }
  }
}
