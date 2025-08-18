import AVFoundation
import Foundation

/// Manages loading and playback of key click sounds.
/// 사운드 테마별 폴더(Resources/<Theme>)의 *.caf / *.wav 파일을 모두 로드하여
/// 키 입력마다 랜덤으로 하나씩 재생합니다.
final class KeySoundManager {
    // Currently selected theme name
    private(set) var currentTheme: String = "typewriter"
    // URLs of all sound files for current theme
    private var soundURLs: [URL] = []
    private var keyCodeToURL: [Int: URL] = [:]
    private var nonUniqueCount: Int = 0

    // Active audio players to prevent ARC from stopping playback prematurely
    private var players: [AVAudioPlayer] = []
    var volume: Float = 1.0

    // MARK: - Init

    init(theme: String = "typewriter") {
        self.currentTheme = theme
        loadSounds(theme: theme)
    }

    // MARK: - Public

    /// 재생 가능한 사운드를 다시 로드합니다(테마 변경 시 호출).
    func loadSounds(theme: String) {
        currentTheme = theme
        soundURLs = []
        keyCodeToURL = [:]
        nonUniqueCount = 0

        guard let scheme = Self.loadSchemes().first(where: { $0.name == theme }) else {
            print("Ticklings: scheme not found for theme=\(theme)")
            return
        }

        // Build URLs in the exact order from schemes.json
        var urls: [URL] = []
        for fileName in scheme.files {
            if let url = Self.locateResource(fileName: fileName, theme: theme) {
                urls.append(url)
            } else {
                print("Ticklings: missing file \(fileName) for theme=\(theme)")
            }
        }
        soundURLs = urls

        // Map key codes
        for (keyCode, fileIndex) in scheme.keyAudioMap {
            if fileIndex >= 0, fileIndex < soundURLs.count {
                keyCodeToURL[keyCode] = soundURLs[fileIndex]
            }
        }
        nonUniqueCount = max(0, min(scheme.nonUniqueCount ?? soundURLs.count, soundURLs.count))

        #if DEBUG
        let modPath = Bundle.module.resourceURL?.path ?? "nil"
        let mainPath = Bundle.main.resourceURL?.path ?? "nil"
        print("Ticklings DEBUG - loadSounds theme=\(theme) module=\(modPath) main=\(mainPath) files=\(soundURLs.count) nonUnique=\(nonUniqueCount)")
        #endif
    }

    /// 지정된 키코드에 맞는 사운드 재생. 매핑이 없으면 일반 키 사운드 범위 내 랜덤.
    func play(forKeyCode keyCode: Int) {
        print("Ticklings DEBUG - soundURLs.count =", soundURLs.count, "volume =", volume, "key=", keyCode)
        guard volume > 0 else { return }

        let url: URL?
        if let mapped = keyCodeToURL[keyCode] {
            url = mapped
        } else if !soundURLs.isEmpty {
            let upper = nonUniqueCount > 0 ? nonUniqueCount : soundURLs.count
            url = soundURLs[0..<upper].randomElement()
        } else {
            url = nil
        }

        guard let playURL = url else {
            print("no sound files")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: playURL)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            players.append(player)
            cleanupPlayers()
        } catch {
            print("Ticklings: Failed to play sound - \(error)")
        }
    }

    /// 번들에 포함된 테마 목록을 반환합니다.
    static func availableThemes() -> [String] {
        // Prefer schemes.json
        let schemes = loadSchemes()
        if !schemes.isEmpty {
            return schemes.map { $0.name }.sorted()
        }
        // Fallback: scan several candidate roots for directories that contain audio files
        let audioExts = ["wav", "caf", "mp3"]
        let fm = FileManager.default
        let baseCandidates: [URL] = [
            Bundle.module.resourceURL?.appendingPathComponent("Resources"),
            Bundle.module.resourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("Resources"),
            Bundle.main.resourceURL
        ].compactMap { $0 }

        for base in baseCandidates {
            if let items = try? fm.contentsOfDirectory(
                at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            {
                let themes = items.filter { url in
                    guard let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory, isDir else { return false }
                    if let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        return files.contains { audioExts.contains($0.pathExtension.lowercased()) }
                    }
                    return false
                }.map { $0.lastPathComponent }
                if !themes.isEmpty { return themes.sorted() }
            }
        }

        return []
    }

    // MARK: - Schemes helpers
    private struct Scheme: Decodable {
        let name: String
        let files: [String]
        let nonUniqueCount: Int?
        let keyAudioMap: [Int: Int]

        enum CodingKeys: String, CodingKey {
            case name
            case files
            case nonUniqueCount = "non_unique_count"
            case keyAudioMap = "key_audio_map"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            files = try c.decode([String].self, forKey: .files)
            nonUniqueCount = try c.decodeIfPresent(Int.self, forKey: .nonUniqueCount)
            let raw = try c.decodeIfPresent([String: Int].self, forKey: .keyAudioMap) ?? [:]
            var dict: [Int: Int] = [:]
            for (k, v) in raw { if let kk = Int(k) { dict[kk] = v } }
            keyAudioMap = dict
        }
    }

    private static func loadSchemes() -> [Scheme] {
        let candidates: [URL?] = [
            Bundle.module.url(forResource: "schemes", withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: "schemes", withExtension: "json", subdirectory: "Resources")
        ]
        for urlOpt in candidates {
            if let url = urlOpt, let data = try? Data(contentsOf: url) {
                if let arr = try? JSONDecoder().decode([Scheme].self, from: data) {
                    return arr
                }
            }
        }
        return []
    }

    private static func locateResource(fileName: String, theme: String) -> URL? {
        let subdir = "Resources/\(theme)"
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let candidates: [URL?] = [
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdir),
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir)
        ]
        for u in candidates { if let url = u { return url } }
        // Fallback: manual path join
        let bases: [URL?] = [Bundle.module.resourceURL, Bundle.main.resourceURL]
        for b in bases {
            if let base = b {
                let url = base.appendingPathComponent(subdir).appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        return nil
    }

    // MARK: - Private

    private func cleanupPlayers() {
        players.removeAll { !$0.isPlaying }
        // limit array size
        if players.count > 10 {
            players.removeFirst(players.count - 10)
        }
    }
}
