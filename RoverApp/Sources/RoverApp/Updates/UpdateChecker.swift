import Foundation
import AppKit

/// Lightweight "is there a newer release?" probe against the project's
/// GitHub Releases API. We deliberately don't ship Sparkle yet — that
/// chains in a dynamic framework, code signing, and an EdDSA key
/// pipeline, which is too much weight for an unsigned dev build.
/// Instead this checker:
///
///   1. GETs https://api.github.com/repos/<owner>/<repo>/releases/latest
///   2. Parses the `tag_name` (expected `vX.Y.Z`) and the DMG asset URL.
///   3. Compares to the running bundle's `CFBundleShortVersionString`.
///   4. Surfaces an `availableUpdate` describing what's newer.
///
/// The user clicks the link in Settings → Advanced and downloads the
/// DMG manually. Worse UX than Sparkle but zero infra; Sparkle can
/// supersede this once we have a signed release pipeline.
@MainActor
final class UpdateChecker: ObservableObject {
    struct AvailableUpdate: Equatable {
        let version: String
        let downloadURL: URL
        let releaseURL: URL
        let publishedAt: Date?
    }

    enum Status: Equatable {
        case idle
        case checking
        case upToDate(currentVersion: String)
        case available(AvailableUpdate)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    /// `owner/repo` slug. Hardcoded for the canonical project; future
    /// forks can override at construction time if needed.
    let repo: String

    init(repo: String = "youngjae99/rover-app") {
        self.repo = repo
    }

    /// Current `CFBundleShortVersionString`, or "0.0.0" if absent.
    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// Hit the GitHub API and update `status`. Network errors and
    /// rate-limit responses both land in `.failed`. Idempotent — calling
    /// while a check is in flight is a no-op.
    func check() {
        if case .checking = status { return }
        status = .checking
        Task {
            await runCheck()
        }
    }

    private func runCheck() async {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Rover.app", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                status = .failed("no http response")
                return
            }
            if http.statusCode == 404 {
                // No releases yet — treat as up-to-date.
                status = .upToDate(currentVersion: currentVersion)
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                status = .failed("HTTP \(http.statusCode)")
                return
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = (json["tag_name"] as? String)?.trimmingCharacters(in: .whitespaces),
                  !tag.isEmpty else {
                status = .failed("malformed release JSON")
                return
            }
            let releaseURL = (json["html_url"] as? String).flatMap(URL.init(string:))
                ?? URL(string: "https://github.com/\(repo)/releases/latest")!
            let assetURL = (json["assets"] as? [[String: Any]])?
                .compactMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
                .first(where: { $0.lastPathComponent.lowercased().hasSuffix(".dmg") })
                ?? releaseURL
            let publishedAt = (json["published_at"] as? String)
                .flatMap(ISO8601DateFormatter().date(from:))

            if Self.isNewer(latest: tag, than: currentVersion) {
                status = .available(AvailableUpdate(
                    version: Self.normalize(tag),
                    downloadURL: assetURL,
                    releaseURL: releaseURL,
                    publishedAt: publishedAt
                ))
            } else {
                status = .upToDate(currentVersion: currentVersion)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Strip a leading "v" from a tag and compare component-wise as
    /// integers. Anything non-numeric (`v0.3.0-rc1`) is conservatively
    /// treated as not-newer so we don't push pre-releases at the user.
    static func isNewer(latest: String, than current: String) -> Bool {
        let l = parts(of: latest), c = parts(of: current)
        guard let l, let c else { return false }
        for i in 0..<max(l.count, c.count) {
            let li = i < l.count ? l[i] : 0
            let ci = i < c.count ? c[i] : 0
            if li > ci { return true }
            if li < ci { return false }
        }
        return false
    }

    private static func parts(of v: String) -> [Int]? {
        let trimmed = v.hasPrefix("v") ? String(v.dropFirst()) : v
        let comps = trimmed.split(separator: ".")
        var out: [Int] = []
        for c in comps {
            // Reject components like "0-rc1".
            if let n = Int(c) { out.append(n) } else { return nil }
        }
        return out.isEmpty ? nil : out
    }

    static func normalize(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }
}
