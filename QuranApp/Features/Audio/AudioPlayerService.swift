//
//  AudioPlayerService.swift
//  QuranApp
//
//  Professional audio playback engine for Quranic recitation.
//  Streams Sheikh Khalifa Al Tunaiji from EveryAyah CDN.
//  Integrates AVFoundation, AVAudioSession (.playback), MPNowPlayingInfoCenter,
//  MPRemoteCommandCenter, auto-advance, and Hifdh repeat loops.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Observation

@Observable
@MainActor
public final class AudioPlayerService: NSObject {
    // MARK: - Playback State
    public enum PlaybackState: Sendable {
        case stopped
        case buffering
        case playing
        case paused
    }

    public enum RepeatMode: Equatable, Sendable {
        case none
        case repeatVerse(target: Int, current: Int)
        case repeatSurah
    }

    public var state: PlaybackState = .stopped
    public var currentSurahId: Int = 1
    public var currentVerseNumber: Int = 1
    public var currentSurahName: String = "Al-Fatihah"
    public var currentAyahText: String = ""
    public var elapsedSeconds: Double = 0.0
    public var durationSeconds: Double = 0.0
    public var repeatMode: RepeatMode = .none
    public var autoAdvance: Bool = true
    public var reciterName: String = "Sheikh Khalifa Al Tunaiji"

    // Callback when verse changes (so reader can highlight and auto-turn page)
    public var onVerseChanged: ((Int, Int) -> Void)?

    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var isInterrupted: Bool = false
    private let repository: QuranRepositoryProtocol

    public init(repository: QuranRepositoryProtocol) {
        self.repository = repository
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        setupInterruptionNotifications()
    }

    deinit {
        // Clean up time observer
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Setup (.playback)
    private func setupAudioSession() {
        #if canImport(AVFAudio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Playback Controls
    public func play(surahId: Int, verseNumber: Int, surahName: String = "") {
        self.currentSurahId = surahId
        self.currentVerseNumber = verseNumber
        if !surahName.isEmpty {
            self.currentSurahName = surahName
        }

        let urlString = String(
            format: "https://everyayah.com/data/khalefa_al_tunaiji_64kbps/%03d%03d.mp3",
            surahId,
            verseNumber
        )

        guard let url = URL(string: urlString) else { return }

        // Notify reader to update highlight and page viewport
        onVerseChanged?(surahId, verseNumber)

        self.state = .buffering
        teardownPlayer()

        let playerItem = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: playerItem)

        // Observe Item Completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        // Observe Time Progress
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        self.timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.elapsedSeconds = time.seconds
            if let duration = self.player?.currentItem?.duration.seconds, !duration.isNaN {
                self.durationSeconds = duration
            }
            self.updateNowPlayingInfo()
        }

        player?.play()
        self.state = .playing
        updateNowPlayingInfo()
    }

    public func togglePlayPause() {
        if state == .playing {
            pause()
        } else if state == .paused {
            resume()
        } else {
            play(surahId: currentSurahId, verseNumber: currentVerseNumber)
        }
    }

    public func pause() {
        player?.pause()
        self.state = .paused
        updateNowPlayingInfo()
    }

    public func resume() {
        player?.play()
        self.state = .playing
        updateNowPlayingInfo()
    }

    public func stop() {
        teardownPlayer()
        self.state = .stopped
        self.elapsedSeconds = 0.0
        self.durationSeconds = 0.0
        clearNowPlayingInfo()
    }

    public func nextVerse() {
        Task {
            if let nextAyah = try? await repository.fetchAyah(surah: currentSurahId, verse: currentVerseNumber + 1) {
                play(surahId: nextAyah.surahId, verseNumber: nextAyah.verseNumber)
            } else if let nextSurah = try? await repository.fetchSurah(id: currentSurahId + 1) {
                // Advance to first ayah of next surah
                play(surahId: nextSurah.id, verseNumber: 1, surahName: nextSurah.englishName)
            } else {
                stop()
            }
        }
    }

    public func previousVerse() {
        if currentVerseNumber > 1 {
            play(surahId: currentSurahId, verseNumber: currentVerseNumber - 1)
        } else if currentSurahId > 1 {
            Task {
                if let prevSurah = try? await repository.fetchSurah(id: currentSurahId - 1) {
                    play(surahId: prevSurah.id, verseNumber: prevSurah.totalVerses, surahName: prevSurah.englishName)
                }
            }
        }
    }

    public func setRepeatCount(_ count: Int) {
        if count <= 1 {
            self.repeatMode = .none
        } else {
            self.repeatMode = .repeatVerse(target: count, current: 1)
        }
    }

    // MARK: - Auto-Advance & Loop Handling
    @objc private func playerItemDidReachEnd() {
        switch repeatMode {
        case .repeatVerse(let target, let current):
            if current < target {
                self.repeatMode = .repeatVerse(target: target, current: current + 1)
                // Replay same verse
                player?.seek(to: .zero)
                player?.play()
                self.state = .playing
                return
            } else {
                // Loop finished, reset mode
                self.repeatMode = .none
            }

        case .repeatSurah:
            // Handled when reaching end of surah
            break

        case .none:
            break
        }

        if autoAdvance {
            nextVerse()
        } else {
            self.state = .stopped
        }
    }

    private func teardownPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            self.timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player?.pause()
        self.player = nil
    }

    // MARK: - Lock Screen Media Center (MPNowPlayingInfoCenter)
    private func updateNowPlayingInfo() {
        #if canImport(MediaPlayer)
        var nowPlayingInfo: [String: Any] = [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Surah \(currentSurahName) - Ayah \(currentVerseNumber)"
        nowPlayingInfo[MPMediaItemPropertyArtist] = reciterName
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "The Holy Quran (13-Line)"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = state == .playing ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }

    private func clearNowPlayingInfo() {
        #if canImport(MediaPlayer)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #endif
    }

    // MARK: - Remote Command Center
    private func setupRemoteCommands() {
        #if canImport(MediaPlayer)
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.resume() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.nextVerse() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.previousVerse() }
            return .success
        }
        #endif
    }

    // MARK: - Interruptions & Route Changes
    private func setupInterruptionNotifications() {
        #if canImport(AVFAudio)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        #if canImport(AVFAudio)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            isInterrupted = (state == .playing)
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) && isInterrupted {
                resume()
            }
            isInterrupted = false
        @unknown default:
            break
        }
        #endif
    }

    @objc private func handleRouteChange(notification: Notification) {
        #if canImport(AVFAudio)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        // When headphones or AirPods are unplugged/disconnected, pause audio
        if reason == .oldDeviceUnavailable {
            pause()
        }
        #endif
    }
}
