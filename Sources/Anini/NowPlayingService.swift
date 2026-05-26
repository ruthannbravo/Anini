import AppKit
import Combine

enum NowPlayingSource { case music, spotify }

struct NowPlayingTrack {
    let title: String
    let artist: String
    let isPlaying: Bool
    let source: NowPlayingSource
    var artwork: NSImage?
}

final class NowPlayingService: ObservableObject, @unchecked Sendable {
    @Published var track: NowPlayingTrack? = nil
    @Published var lastTrack: NowPlayingTrack? = nil

    private let musicNotif   = "com.apple.Music.playerInfo"
    private let spotifyNotif = "com.spotify.client.PlaybackStateChanged"

    init() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(handleMusic(_:)),
                           name: NSNotification.Name(musicNotif), object: nil)
        center.addObserver(self, selector: #selector(handleSpotify(_:)),
                           name: NSNotification.Name(spotifyNotif), object: nil)
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: – Notification handlers

    @objc private func handleMusic(_ n: Notification) {
        guard let info = n.userInfo else { return }
        let state  = info["Player State"] as? String ?? ""
        let title  = info["Name"]         as? String ?? ""
        let artist = info["Artist"]       as? String ?? ""
        DispatchQueue.main.async {
            if state == "Stopped" || title.isEmpty {
                if let current = self.track {
                    self.lastTrack = NowPlayingTrack(title: current.title, artist: current.artist,
                                                     isPlaying: false, source: .music,
                                                     artwork: current.artwork)
                }
                self.track = nil
            } else {
                self.track = NowPlayingTrack(title: title, artist: artist,
                                             isPlaying: state == "Playing", source: .music)
                Task {
                    guard let img = await self.fetchMusicArtwork(title: title, artist: artist) else { return }
                    DispatchQueue.main.async {
                        guard self.track?.title == title else { return }
                        self.track = NowPlayingTrack(title: title, artist: artist,
                                                      isPlaying: state == "Playing",
                                                      source: .music, artwork: img)
                    }
                }
            }
        }
    }

    @objc private func handleSpotify(_ n: Notification) {
        guard let info = n.userInfo else { return }
        let playing   = (info["Player State"] as? String) == "Playing"
        let title     = info["Name"]           as? String ?? ""
        let artist    = info["Artist"]         as? String ?? ""
        let artURLStr = info["artworkURL"]      as? String
        DispatchQueue.main.async {
            if title.isEmpty {
                if let current = self.track {
                    self.lastTrack = NowPlayingTrack(title: current.title, artist: current.artist,
                                                     isPlaying: false, source: .spotify,
                                                     artwork: current.artwork)
                }
                self.track = nil
            } else {
                self.track = NowPlayingTrack(title: title, artist: artist,
                                             isPlaying: playing, source: .spotify)
                if let urlStr = artURLStr, let url = URL(string: urlStr) {
                    Task {
                        guard let img = await self.fetchArtwork(from: url) else { return }
                        DispatchQueue.main.async {
                            guard self.track?.title == title else { return }
                            self.track = NowPlayingTrack(title: title, artist: artist,
                                                          isPlaying: playing,
                                                          source: .spotify, artwork: img)
                        }
                    }
                }
            }
        }
    }

    // MARK: – Playback controls

    func playPause() {
        let app = activeSource() == .spotify ? "Spotify" : "Music"
        runScript("tell application \"\(app)\" to playpause")
    }

    func nextTrack() {
        let app = activeSource() == .spotify ? "Spotify" : "Music"
        runScript("tell application \"\(app)\" to next track")
    }

    func previousTrack() {
        let app = activeSource() == .spotify ? "Spotify" : "Music"
        runScript("tell application \"\(app)\" to previous track")
    }

    // MARK: – Helpers

    private func activeSource() -> NowPlayingSource {
        (track ?? lastTrack)?.source ?? .music
    }

    private func runScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            NSAppleScript(source: source)?.executeAndReturnError(nil)
        }
    }

    private func fetchMusicArtwork(title: String, artist: String) async -> NSImage? {
        // Short delay so Music.app has time to push the new track into MediaRemote
        try? await Task.sleep(nanoseconds: 600_000_000)
        if let img = await fetchArtworkViaMediaRemote() { return img }
        if let img = await fetchArtworkViaAppleScript() { return img }
        // iTunes Search API — works for any Apple Music / streaming track by title+artist
        return await fetchArtworkViaiTunesSearch(title: title, artist: artist)
    }

    private func fetchArtworkViaMediaRemote() async -> NSImage? {
        guard
            let bundle = CFBundleCreate(kCFAllocatorDefault,
                NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
            let fnPtr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString)
        else { return nil }

        typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        let getInfo = unsafeBitCast(fnPtr, to: GetInfoFn.self)

        return await withCheckedContinuation { cont in
            getInfo(DispatchQueue.global(qos: .utility)) { info in
                if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
                   let img = NSImage(data: data) {
                    cont.resume(returning: img)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func fetchArtworkViaAppleScript() async -> NSImage? {
        let src = """
        tell application "Music"
            try
                set theTrack to current track
                if (count of artworks of theTrack) is 0 then return ""
                set art to artwork 1 of theTrack
                try
                    set artData to data of art
                    if length of artData > 0 then return artData
                end try
                return raw data of art
            on error
                return ""
            end try
        end tell
        """
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                var err: NSDictionary?
                guard let desc = NSAppleScript(source: src)?.executeAndReturnError(&err) else {
                    cont.resume(returning: nil); return
                }
                let data = desc.data
                cont.resume(returning: data.isEmpty ? nil : NSImage(data: data))
            }
        }
    }

    private func fetchArtworkViaiTunesSearch(title: String, artist: String) async -> NSImage? {
        let term = "\(artist) \(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "https://itunes.apple.com/search?term=\(term)&entity=song&limit=5&media=music"),
              let (data, _) = try? await URLSession.shared.data(from: searchURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let thumb = first["artworkUrl100"] as? String
        else { return nil }

        let hiRes = thumb.replacingOccurrences(of: "100x100bb", with: "600x600bb")
        guard let artURL = URL(string: hiRes) else { return nil }
        return await fetchArtwork(from: artURL)
    }

    private func fetchArtwork(from url: URL) async -> NSImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }
}
