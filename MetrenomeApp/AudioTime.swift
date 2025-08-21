// MARK: AudioTime.swift
import AVFoundation

enum AudioTime {
    static func hostTimeNow() -> UInt64 { mach_absolute_time() }

    static func toHostTime(seconds: Double) -> UInt64 {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let nanos = seconds * 1_000_000_000
        let hostTicks = nanos * Double(timebase.denom) / Double(timebase.numer)
        return UInt64(hostTicks)
    }

    static func hostTimeToSeconds(_ host: UInt64) -> Double {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let nanos = Double(host) * Double(timebase.numer) / Double(timebase.denom)
        return nanos / 1_000_000_000.0
    }

    static func addSeconds(hostTime: UInt64, seconds: Double) -> UInt64 {
        hostTime &+ toHostTime(seconds: seconds)
    }
}
