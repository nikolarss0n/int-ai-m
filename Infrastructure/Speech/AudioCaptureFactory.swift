import Foundation
import AVFoundation
import CoreGraphics

enum AudioCapturePermissionError: LocalizedError {
    case denied(CaptureDevice)
    var errorDescription: String? {
        switch self {
        case .denied(.microphone): return "Microphone permission is required. Enable Interview Master in Privacy & Security → Microphone."
        case .denied(.systemAudio): return "Screen Recording permission is required to capture system audio. Enable Interview Master in Privacy & Security → Screen Recording."
        }
    }
}

@available(macOS 13.0, *)
enum AudioCaptureFactory {
    static func hasPermission(_ device: CaptureDevice) -> Bool {
        switch device {
        case .microphone: return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .systemAudio: return CGPreflightScreenCaptureAccess()
        }
    }

    static func preflight(_ device: CaptureDevice, allowPrompt: Bool = true) async throws {
        if hasPermission(device) { return }
        guard allowPrompt else { throw AudioCapturePermissionError.denied(device) }
        switch device {
        case .microphone:
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined,
                  await AVCaptureDevice.requestAccess(for: .audio) else {
                throw AudioCapturePermissionError.denied(device)
            }
        case .systemAudio:
            let allowed = await MainActor.run { CGRequestScreenCaptureAccess() }
            guard allowed || CGPreflightScreenCaptureAccess() else {
                throw AudioCapturePermissionError.denied(device)
            }
        }
    }

    static func make(_ device: CaptureDevice) -> any AudioSourceCapture {
        switch device {
        case .microphone: return MicrophoneCapture()
        case .systemAudio: return SystemAudioCapture()
        }
    }
}
