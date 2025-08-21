# MetronomeApp – Program Documentation

## Overview
MetronomeApp is a SwiftUI application implementing a professional-grade metronome with:
- **Sample-accurate audio clicks** (via `AVAudioEngine`)
- **Multiple sound options** (`beep`, `wood`, `noise`, `square`)
- **Haptic feedback** (via `CoreHaptics`)
- **UI beat visualization**
- **Configurable tempo** (BPM, beats per bar, tap tempo)

The core design ensures **timing accuracy** by separating:
- **Audio clock (master)** → drives click scheduling  
- **Haptics/UI (slaves)** → mirror audio events  

---

## Architecture

### High-Level Flow
ContentView (UI)
↓ user input
MetronomeEngine (scheduler/state)
├─ AudioClickEngine (sound synthesis/playback)
├─ HapticsEngine (vibration events)
└─ AudioTime (timebase conversion)

markdown
Copy
Edit

- **UI (ContentView.swift)**
  - Displays controls (slider, stepper, toggles, buttons)
  - Subscribes to `MetronomeEngine` via `@StateObject`
  - Reflects current tempo and beat pulse

- **MetronomeEngine.swift**
  - Central controller
  - Publishes state (`bpm`, `beatsPerBar`, `isRunning`, etc.)
  - Runs a `DispatchSourceTimer` scheduler at ~50 Hz
  - Schedules audio/haptic events ahead of time (~250 ms lookahead)
  - Provides tap-tempo detection (median of recent taps)

- **AudioClickEngine.swift**
  - Wraps `AVAudioEngine` + `AVAudioPlayerNode`
  - Precomputes click buffers (short waveforms per sound type)
  - Schedules clicks precisely at host time (`AVAudioTime(hostTime:)`)

- **ClickSynth.swift** (inside AudioClickEngine)
  - Procedural sound synthesis (beep = sine, wood = sine+noise, noise burst, square wave)
  - Short exponential decay envelope
  - Different accent vs normal beat

- **HapticsEngine.swift**
  - Wraps `CHHapticEngine`
  - Schedules transient vibrations aligned to audio events
  - Converts host time → wall-clock delay for dispatch

- **AudioTime.swift**
  - Helper utilities for converting between:
    - Seconds ↔ Host time (`mach_absolute_time`)
    - Adds offsets
  - Ensures audio/haptics sync correctly

---

## Key Classes and Responsibilities

### `ContentView`
- View layer: slider (BPM), stepper (beats/bar), sound picker, toggles
- Start/stop and tap-tempo buttons
- Visual beat pulse (`Circle` animation)

### `MetronomeEngine`
- Holds published state
- Controls start/stop
- Runs scheduling loop
- Calls into Audio/Haptics engines
- Calculates accent beats

### `AudioClickEngine`
- Manages `AVAudioEngine`
- Generates PCM buffers for clicks
- Handles play/stop
- Ensures clicks are pre-scheduled (low jitter)

### `ClickSynth`
- DSP helper
- Generates waveforms per sound type
- Applies amplitude envelope + accent variations

### `HapticsEngine`
- Handles haptic playback
- Ensures compatibility check (hardware supports haptics)
- Schedules haptic transients at correct delays

### `AudioTime`
- Provides conversions between mach timebase and seconds
- Prevents drift between audio clock and UI clock

---

## Timing Strategy
- **Lookahead scheduling**: Events are scheduled 0.25 s into the future.
- **Scheduler interval**: ~20 ms (50 Hz), runs on background queue.
- **UI pulse**: updated via `DispatchQueue.main.asyncAfter` with calculated delay, so it lines up visually.
- **Tap tempo**: Uses median filter across last 6 taps to smooth jitter.

---

## Limitations
- Haptics cannot be truly sample-accurate; uses wall-clock approximation.
- UI pulse may drift slightly, but audio is always the master clock.
- Background/lock-screen stability depends on iOS audio session category (`.playback`).

---

## Dependencies
- **SwiftUI** (UI)
- **AVFoundation** (audio)
- **CoreHaptics** (haptics)
- **Dispatch** (`DispatchSourceTimer` for scheduling)
- **mach_absolute_time** (high-precision clock)

---

## Extension Points
- **Add new click sounds** → implement in `ClickSynth.makeClick`
- **Support subdivisions/polyrhythms** → extend scheduler in `MetronomeEngine`
- **Preset management** → add persistence layer (UserDefaults/JSON)
- **Background audio refinements** → handle audio route changes and session interruptions

---

## Example Sequence (1 bar, 4/4, 120 BPM)
1. User presses **Start** → `MetronomeEngine.start()`
2. Engine sets `nextBeatHostTime`
3. Scheduler loop runs every 20 ms:
   - Checks if next beat fits in lookahead window
   - Schedules:
     - Audio buffer at `hostTime`
     - Haptic event delayed to match
     - UI pulse animation scheduled on main thread
   - Increments beat counter
4. At runtime → Audio click is precise; vibration/UI follow
