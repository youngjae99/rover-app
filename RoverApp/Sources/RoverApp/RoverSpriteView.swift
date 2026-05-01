import SwiftUI
import AppKit

@MainActor
final class SpriteAnimator: ObservableObject {
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var state: RoverState = .idle

    private var clip: AnimationClip?
    private var frameIndex = 0
    private var timer: Timer?
    private var queuedNextState: RoverState?
    private var idleSwitchTimer: Timer?

    init() {
        applyState(.idle)
    }

    func setState(_ next: RoverState) {
        if next == state, clip != nil { return }
        applyState(next)
    }

    private func applyState(_ next: RoverState) {
        timer?.invalidate()
        state = next
        let newClip = AnimationCatalog.shared.clip(for: next)
        clip = newClip
        frameIndex = 0
        currentImage = newClip.frames.first
        guard newClip.frames.count > 1 else { return }
        if next == .idle {
            scheduleIdleVariety()
            holdIdleEyesOpen()
        } else {
            idleSwitchTimer?.invalidate()
            idleSwitchTimer = nil
            startTickingTimer(fps: newClip.fps)
        }
    }

    private func startTickingTimer(fps: Double) {
        let interval = 1.0 / max(fps, 1)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func holdIdleEyesOpen() {
        guard let clip else { return }
        timer?.invalidate()
        frameIndex = 0
        currentImage = clip.frames.first
        let hold = Double.random(in: 1.5...3.0)
        timer = Timer.scheduledTimer(withTimeInterval: hold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .idle, let clip = self.clip else { return }
                self.startTickingTimer(fps: clip.fps)
            }
        }
    }

    private func tick() {
        guard let clip else { return }
        frameIndex += 1
        if frameIndex >= clip.frames.count {
            if clip.loops {
                if state == .idle {
                    holdIdleEyesOpen()
                    return
                }
                frameIndex = 0
            } else {
                timer?.invalidate()
                if let queued = queuedNextState {
                    queuedNextState = nil
                    applyState(queued)
                } else {
                    applyState(.idle)
                }
                return
            }
        }
        currentImage = clip.frames[frameIndex]
    }

    private func scheduleIdleVariety() {
        idleSwitchTimer?.invalidate()
        let delay = Double.random(in: 15.0...30.0)
        idleSwitchTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .idle else { return }
                self.applyState(.idleFidget)
            }
        }
    }
}

struct RoverSpriteView: View {
    @StateObject private var animator = SpriteAnimator()
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            if let img = animator.currentImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
            } else {
                Circle()
                    .fill(Color.orange.opacity(0.5))
                    .overlay(Text("rover").font(.caption).foregroundStyle(.white))
            }
        }
        .onReceive(viewModel.$roverState) { newState in
            animator.setState(newState)
        }
    }
}
