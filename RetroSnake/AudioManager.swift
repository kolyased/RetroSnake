//
//  AudioManager.swift
//  RetroSnake
//
//  Created by Николай Чернобоков on 29.06.2026.
//

import AVFoundation

final class AudioManager {
    static let shared = AudioManager()

    private let soundEnabledKey = "SoundEnabled"
    private let volumeLevelKey = "VolumeLevel"

    private var backgroundPlayer: AVAudioPlayer?
    private var eatPlayer: AVAudioPlayer?
    private var gameOverPlayer: AVAudioPlayer?

    private(set) var soundEnabled = true
    private(set) var volumeLevel = 5

    private init() {
        configureAudioSession()
        loadSettings()
        preparePlayers()
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: soundEnabledKey) == nil {
            soundEnabled = true
        } else {
            soundEnabled = defaults.bool(forKey: soundEnabledKey)
        }

        if defaults.object(forKey: volumeLevelKey) == nil {
            volumeLevel = 5
        } else {
            let savedVolume = defaults.integer(forKey: volumeLevelKey)
            volumeLevel = min(max(savedVolume, 1), 10)
        }

        print("Audio settings loaded: soundEnabled=\(soundEnabled), volumeLevel=\(volumeLevel)")
    }

    func saveSettings() {
        UserDefaults.standard.set(soundEnabled, forKey: soundEnabledKey)
        UserDefaults.standard.set(volumeLevel, forKey: volumeLevelKey)
    }

    func playBackgroundMusic() {
        guard soundEnabled else {
            print("Background music not started: sound disabled")
            stopBackgroundMusic()
            return
        }

        if backgroundPlayer == nil {
            backgroundPlayer = makePlayer(fileName: "background", fileExtension: "mp3")
            backgroundPlayer?.numberOfLoops = -1
            backgroundPlayer?.prepareToPlay()
        }

        guard let backgroundPlayer else { return }

        updateBackgroundVolume()
        if !backgroundPlayer.isPlaying {
            backgroundPlayer.play()
            print("Background music started: background.mp3")
        }
    }

    func stopBackgroundMusic() {
        backgroundPlayer?.pause()
    }

    func updateBackgroundVolume() {
        backgroundPlayer?.volume = Float(volumeLevel) / 10.0 * 0.35
    }

    func playEatSound() {
        print("Play eat sound requested")
        playEffect(&eatPlayer, fileName: "eat", fileExtension: "wav")
    }

    func playGameOverSound() {
        print("Play gameover sound requested")
        playEffect(&gameOverPlayer, fileName: "gameover", fileExtension: "wav")
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        saveSettings()

        if enabled {
            updateBackgroundVolume()
        } else {
            stopBackgroundMusic()
        }
    }

    func setVolumeLevel(_ level: Int) {
        volumeLevel = min(10, max(1, level))
        saveSettings()
        updateBackgroundVolume()
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func preparePlayers() {
        backgroundPlayer = makePlayer(fileName: "background", fileExtension: "mp3")
        backgroundPlayer?.numberOfLoops = -1
        backgroundPlayer?.prepareToPlay()

        eatPlayer = makePlayer(fileName: "eat", fileExtension: "wav")
        eatPlayer?.prepareToPlay()

        gameOverPlayer = makePlayer(fileName: "gameover", fileExtension: "wav")
        gameOverPlayer?.prepareToPlay()
    }

    private func playEffect(_ player: inout AVAudioPlayer?, fileName: String, fileExtension: String) {
        guard soundEnabled else {
            print("Effect not played: sound disabled")
            return
        }

        if player == nil {
            player = makePlayer(fileName: fileName, fileExtension: fileExtension)
            player?.prepareToPlay()
        }

        guard let player else { return }

        player.volume = Float(volumeLevel) / 10.0
        player.currentTime = 0
        player.play()
        print("Audio effect played: \(fileName).\(fileExtension)")
    }

    private func makePlayer(fileName: String, fileExtension: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("Audio file not found: \(fileName).\(fileExtension)")
            return nil
        }

        do {
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            print("Audio file could not be loaded: \(fileName).\(fileExtension)")
            return nil
        }
    }
}
