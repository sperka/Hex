//
//  HexCapsuleView.swift
//  Hex
//
//  Created by Kit Langton on 1/25/25.

import AppKit
import Inject
import Pow
import SwiftUI

struct TranscriptionIndicatorView: View {
  @ObserveInjection var inject
  
  enum Status {
    case hidden
    case optionKeyPressed
    case recording
    case transcribing
    case prewarming
  }

  var status: Status
  var meter: Meter
  /// Live streaming transcript shown beneath the indicator while recording.
  /// Empty hides it.
  var partialText: String = ""

  let transcribeBaseColor: Color = .blue
  private var backgroundColor: Color {
    switch status {
    case .hidden: return Color.clear
    case .optionKeyPressed: return Color.black
    case .recording:
      return mixedColor(mixedNSColor(.red, with: .black, by: 0.5), with: .red, by: meter.averagePower * 3)
    case .transcribing: return mixedColor(.blue, with: .black, by: 0.5)
    case .prewarming: return mixedColor(.blue, with: .black, by: 0.5)
    }
  }

  private var strokeColor: Color {
    switch status {
    case .hidden: return Color.clear
    case .optionKeyPressed: return Color.black
    case .recording: return mixedColor(.red, with: .white, by: 0.1).opacity(0.6)
    case .transcribing: return mixedColor(.blue, with: .white, by: 0.1).opacity(0.6)
    case .prewarming: return mixedColor(.blue, with: .white, by: 0.1).opacity(0.6)
    }
  }

  private func mixedColor(_ color: NSColor, with otherColor: NSColor, by fraction: Double) -> Color {
    Color(nsColor: mixedNSColor(color, with: otherColor, by: fraction))
  }

  private func mixedNSColor(_ color: NSColor, with otherColor: NSColor, by fraction: Double) -> NSColor {
    let clampedFraction = min(max(fraction, 0), 1)
    return color.blended(withFraction: clampedFraction, of: otherColor) ?? color
  }

  private var innerShadowColor: Color {
    switch status {
    case .hidden: return Color.clear
    case .optionKeyPressed: return Color.clear
    case .recording: return Color.red
    case .transcribing: return transcribeBaseColor
    case .prewarming: return transcribeBaseColor
    }
  }

  private let cornerRadius: CGFloat = 8
  private let baseWidth: CGFloat = 16
  private let expandedWidth: CGFloat = 56

  // Live-transcript bubble: grows horizontally until it hits `maxPartialFraction`
  // of the screen width, then wraps downward up to `maxPartialLines` lines.
  private let maxPartialFraction: CGFloat = 0.35
  private let maxPartialLines: Int = 10
  private let minPartialWidth: CGFloat = 40
  private let partialFont: Font = .system(size: 12, weight: .medium)

  /// Natural single-line width of the current partial text (measured offscreen).
  @State private var measuredPartialWidth: CGFloat = 0

  /// Max width for the live-transcript bubble before it wraps to new lines.
  private var maxPartialWidth: CGFloat {
    let screenWidth = NSScreen.main?.frame.width ?? 1440
    return screenWidth * maxPartialFraction
  }

  var isHidden: Bool {
    status == .hidden
  }

  @State var transcribeEffect = 0

  var body: some View {
    VStack(spacing: 6) {
      indicator
      // Live streaming transcript below the indicator (away from the notch).
      if !partialText.isEmpty {
        partialBubble
      }
    }
    .animation(.easeInOut(duration: 0.15), value: partialText)
    .enableInjection()
  }

  private var indicator: some View {
    let averagePower = min(1, meter.averagePower * 3)
    let peakPower = min(1, meter.peakPower * 3)
    return ZStack {
      Capsule()
        .fill(backgroundColor.shadow(.inner(color: innerShadowColor, radius: 4)))
        .overlay {
          Capsule()
            .stroke(strokeColor, lineWidth: 1)
            .blendMode(.screen)
        }
        .overlay(alignment: .center) {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.red.opacity(status == .recording ? (averagePower < 0.1 ? averagePower / 0.1 : 1) : 0))
            .blur(radius: 2)
            .blendMode(.screen)
            .padding(6)
        }
        .overlay(alignment: .center) {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(status == .recording ? (averagePower < 0.1 ? averagePower / 0.1 : 0.5) : 0))
            .blur(radius: 1)
            .blendMode(.screen)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(7)
        }
        .overlay(alignment: .center) {
          GeometryReader { proxy in
            RoundedRectangle(cornerRadius: cornerRadius)
              .fill(Color.red.opacity(status == .recording ? (peakPower < 0.1 ? (peakPower / 0.1) * 0.5 : 0.5) : 0))
              .frame(width: max(proxy.size.width * (peakPower + 0.6), 0), height: proxy.size.height, alignment: .center)
              .frame(maxWidth: .infinity, alignment: .center)
              .blur(radius: 4)
              .blendMode(.screen)
          }.padding(6)
        }
        .cornerRadius(cornerRadius)
        .shadow(
          color: status == .recording ? .red.opacity(averagePower) : .red.opacity(0),
          radius: 4
        )
        .shadow(
          color: status == .recording ? .red.opacity(averagePower * 0.5) : .red.opacity(0),
          radius: 8
        )
        .animation(.interactiveSpring(), value: meter)
        .frame(
          width: status == .recording ? expandedWidth : baseWidth,
          height: baseWidth
        )
        .opacity(status == .hidden ? 0 : 1)
        .scaleEffect(status == .hidden ? 0.0 : 1)
        .blur(radius: status == .hidden ? 4 : 0)
        .animation(.bouncy(duration: 0.3), value: status)
        .changeEffect(.glow(color: .red.opacity(0.5), radius: 8), value: status)
        .changeEffect(.shine(angle: .degrees(0), duration: 0.6), value: transcribeEffect)
        .compositingGroup()
        .task(id: status == .transcribing) {
          while status == .transcribing, !Task.isCancelled {
            transcribeEffect += 1
            try? await Task.sleep(for: .seconds(0.25))
          }
        }
      
      // Show tooltip when prewarming
      if status == .prewarming {
        VStack(spacing: 4) {
          Text("Model prewarming...")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.8))
            )
        }
        .offset(y: -24)
        .transition(.opacity)
        .zIndex(2)
      }
    }
  }

  /// Live transcript bubble shown below the indicator. Starts compact and grows
  /// with the text horizontally up to `maxPartialWidth`, then wraps downward
  /// (head-truncated) up to `maxPartialLines` so the newest words stay visible.
  ///
  /// SwiftUI's `Text` can't natively "hug content but wrap at a cap": a
  /// `.frame(maxWidth:)` just fills the cap. So a hidden single-line copy
  /// measures the text's natural width, and the real bubble is sized to
  /// `min(naturalWidth, cap)` (clamped to a small minimum).
  private var partialBubble: some View {
    let width = max(minPartialWidth, min(measuredPartialWidth, maxPartialWidth))
    return Text(partialText)
      .font(partialFont)
      .foregroundColor(.white)
      .lineLimit(maxPartialLines)
      .truncationMode(.head)
      .multilineTextAlignment(.leading)
      .frame(width: width, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.black.opacity(0.85))
      )
      .background(partialWidthMeasurer)
      .transition(.opacity)
  }

  /// Hidden single-line copy that reports the text's natural (unwrapped) width.
  private var partialWidthMeasurer: some View {
    Text(partialText)
      .font(partialFont)
      .lineLimit(1)
      .fixedSize()
      .hidden()
      .background(
        GeometryReader { proxy in
          Color.clear.preference(key: PartialWidthKey.self, value: proxy.size.width)
        }
      )
      .onPreferenceChange(PartialWidthKey.self) { measuredPartialWidth = $0 }
  }
}

private struct PartialWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

#Preview("HEX") {
  VStack(spacing: 8) {
    TranscriptionIndicatorView(status: .hidden, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .optionKeyPressed, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .recording, meter: .init(averagePower: 0.5, peakPower: 0.5))
    TranscriptionIndicatorView(status: .recording, meter: .init(averagePower: 0.5, peakPower: 0.5), partialText: "Short partial")
    TranscriptionIndicatorView(
      status: .recording,
      meter: .init(averagePower: 0.5, peakPower: 0.5),
      partialText: "This is a much longer live transcript that should grow horizontally and then wrap downward across several lines once it reaches about a third of the screen width."
    )
    TranscriptionIndicatorView(status: .transcribing, meter: .init(averagePower: 0, peakPower: 0))
    TranscriptionIndicatorView(status: .prewarming, meter: .init(averagePower: 0, peakPower: 0))
  }
  .padding(40)
}
