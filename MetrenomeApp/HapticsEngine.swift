// MARK: HapticsEngine.swift
import CoreHaptics
import AVFoundation

final class HapticsEngine {
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    func prepare() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptics init error: \(error)")
        }
    }

    func scheduleTransient(atHostTime hostTime: UInt64, intensity: Float, sharpness: Float) {
        guard supportsHaptics, let engine = engine else { return }
        // Convert audio host time to wall-clock seconds from now
        let nowHost = AudioTime.hostTimeNow()
        let delta = AudioTime.hostTimeToSeconds(hostTime) - AudioTime.hostTimeToSeconds(nowHost)
        let delay = max(0, delta)

        let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, sharpParam], relativeTime: 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                // if the engine stopped (e.g., app went background), try restart once
                try? self.engine?.start()
            }
        }
    }
}
