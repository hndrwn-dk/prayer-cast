import AVFoundation
import Flutter
import UIKit

/// iOS AVAudioSession silent keepalive (spec §5.5).
///
/// Plays near-silent audio on a loop so the app can remain eligible for
/// background execution while recently opened / charging. Not a substitute
/// for exact alarms — the UI must not overpromise reliability.
public class AudioKeepalivePlugin: NSObject, FlutterPlugin {
  private var player: AVAudioPlayer?
  private var active = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "prayer_cast/audio_keepalive",
      binaryMessenger: registrar.messenger()
    )
    let instance = AudioKeepalivePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      do {
        try start()
        result(nil)
      } catch {
        result(FlutterError(
          code: "keepalive_start_failed",
          message: error.localizedDescription,
          details: nil
        ))
      }
    case "stop":
      stop()
      result(nil)
    case "isActive":
      result(active && (player?.isPlaying ?? false))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start() throws {
    if active, player?.isPlaying == true { return }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playback,
      mode: .default,
      options: [.mixWithOthers]
    )
    try session.setActive(true)

    let data = Self.silentWavData()
    player = try AVAudioPlayer(data: data)
    player?.numberOfLoops = -1
    player?.volume = 0.01
    guard player?.play() == true else {
      throw NSError(
        domain: "AudioKeepalive",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer.play() returned false"]
      )
    }
    active = true
  }

  private func stop() {
    player?.stop()
    player = nil
    active = false
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
  }

  /// Minimal mono 8 kHz 16-bit PCM WAV with a few zero samples.
  private static func silentWavData() -> Data {
    let sampleRate: UInt32 = 8000
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let numSamples: UInt32 = 800 // 100 ms of silence
    let dataSize = numSamples * UInt32(channels) * UInt32(bitsPerSample / 8)
    var data = Data()

    func appendU32(_ v: UInt32) {
      var le = v.littleEndian
      data.append(Data(bytes: &le, count: 4))
    }
    func appendU16(_ v: UInt16) {
      var le = v.littleEndian
      data.append(Data(bytes: &le, count: 2))
    }

    data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
    appendU32(36 + dataSize)
    data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
    data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
    appendU32(16)
    appendU16(1) // PCM
    appendU16(channels)
    appendU32(sampleRate)
    appendU32(sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8))
    appendU16(channels * bitsPerSample / 8)
    appendU16(bitsPerSample)
    data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
    appendU32(dataSize)
    data.append(Data(count: Int(dataSize)))
    return data
  }
}
