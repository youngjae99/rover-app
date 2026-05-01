import Foundation
import AppKit

enum RoverState: String, CaseIterable {
    case idle, idleFidget, sleep, speak, startSpeak, endSpeak
    case eat, reading, getAttention, ashamed, haf, lick, exit
}

struct AnimationClip {
    let frames: [NSImage]
    let fps: Double
    let loops: Bool
}

@MainActor
final class AnimationCatalog {
    static let shared = AnimationCatalog()

    private let folderForState: [RoverState: [String]] = [
        .idle: ["_1Idle"],
        .idleFidget: ["_2Idle", "_3Idle", "_4Idle", "_5Idle",
                      "_6Idle", "_7Idle", "_8Idle", "_9Idle", "_10Idle"],
        .sleep: ["Sleep"],
        .speak: ["Speak"],
        .startSpeak: ["Start_Speak"],
        .endSpeak: ["End_Speak"],
        .eat: ["Eat"],
        .reading: ["Reading"],
        .getAttention: ["GetAttention"],
        .ashamed: ["Ashamed"],
        .haf: ["Haf"],
        .lick: ["Lick"],
        .exit: ["Exit"]
    ]

    private let fpsForState: [RoverState: Double] = [
        .idle: 10, .idleFidget: 10, .sleep: 6, .speak: 14, .startSpeak: 14, .endSpeak: 14,
        .eat: 12, .reading: 8, .getAttention: 12, .ashamed: 10,
        .haf: 12, .lick: 10, .exit: 12
    ]

    private let loopingStates: Set<RoverState> = [.idle, .sleep, .speak, .reading]

    private var cache: [String: [NSImage]] = [:]
    private var resourceRoots: [URL] = []

    private init() {
        resourceRoots = computeResourceRoots()
        NSLog("Rover: resource roots = \(resourceRoots.map(\.path))")
        // Warm a single idle clip up front so first frame appears immediately.
        _ = loadFrames(folder: "_1Idle")
    }

    func clip(for state: RoverState) -> AnimationClip {
        let folders = folderForState[state] ?? ["_1Idle"]
        let folder = folders.randomElement() ?? folders[0]
        let frames = loadFrames(folder: folder)
        return AnimationClip(
            frames: frames.isEmpty ? [placeholderFrame(label: state.rawValue)] : frames,
            fps: fpsForState[state] ?? 10,
            loops: loopingStates.contains(state)
        )
    }

    private func computeResourceRoots() -> [URL] {
        var roots: [URL] = []
        let module = Bundle.module
        if let r = module.resourceURL { roots.append(r) }
        roots.append(module.bundleURL)
        // Some SPM bundles place the synced "Resources" subdir at the bundle root,
        // others promote it to be the resource root itself. We try both.
        let candidates = roots.flatMap { [$0, $0.appendingPathComponent("Resources")] }
        return candidates.filter { url in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
    }

    private func loadFrames(folder: String) -> [NSImage] {
        if let cached = cache[folder] { return cached }
        var pngURLs: [URL] = []

        // Strategy 1: Bundle.module direct subdirectory lookup.
        if let urls = Bundle.module.urls(
            forResourcesWithExtension: "png",
            subdirectory: "Resources/\(folder)"
        ), !urls.isEmpty {
            pngURLs = urls
        } else if let urls = Bundle.module.urls(
            forResourcesWithExtension: "png",
            subdirectory: folder
        ), !urls.isEmpty {
            pngURLs = urls
        } else {
            // Strategy 2: walk the candidate roots ourselves.
            for root in resourceRoots {
                let dir = root.appendingPathComponent(folder)
                if let entries = try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil
                ), !entries.isEmpty {
                    pngURLs = entries.filter { $0.pathExtension.lowercased() == "png" }
                    break
                }
            }
        }

        let frames = pngURLs
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { NSImage(contentsOf: $0) }
        cache[folder] = frames
        if frames.isEmpty {
            NSLog("⚠️ Rover: no frames for folder '\(folder)'. Searched: \(resourceRoots.map(\.path))")
        }
        return frames
    }

    func soundURL(named name: String) -> URL? {
        if let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Resources"
        ) { return url }
        if let url = Bundle.module.url(
            forResource: name,
            withExtension: nil
        ) { return url }
        for root in resourceRoots {
            let candidate = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func placeholderFrame(label: String) -> NSImage {
        let size = NSSize(width: 160, height: 160)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemOrange.withAlphaComponent(0.8).setFill()
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        path.fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let textSize = str.size()
        str.draw(at: NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        ))
        img.unlockFocus()
        return img
    }
}
