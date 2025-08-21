import SwiftUI

enum VisualTheme: String, CaseIterable, Identifiable {
    case classic, neon, minimal
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var metro = MetronomeEngine()
    @State private var theme: VisualTheme = .classic
    
    var body: some View {
        VStack(spacing: 32) {
            
            // MARK: Tempo Display + +/- Buttons
            HStack {
                Button {
                    metro.bpm = max(20, metro.bpm - 1)
                    metro.resetPhase()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                VStack {
                    Text("\(Int(metro.bpm))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 24).fill(.thinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.quaternary, lineWidth: 1))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let delta = -value.translation.height / 3
                            metro.bpm = min(300, max(20, metro.bpm + delta))
                        }
                )
                .onChange(of: metro.bpm) {
                    metro.resetPhase()
                }
                
                Button {
                    metro.bpm = min(300, metro.bpm + 1)
                    metro.resetPhase()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // MARK: Beat Visualizer
            ZStack {
                switch theme {
                case .classic:
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 12)
                    Circle()
                        .fill(metro.pulse ? Color.accentColor : .secondary.opacity(0.4))
                        .scaleEffect(metro.pulse ? 1.0 : 0.8)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: metro.pulse)
                    
                case .neon:
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 8)
                        .shadow(color: Color.accentColor, radius: metro.pulse ? 20 : 5)
                        .scaleEffect(metro.pulse ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 0.25), value: metro.pulse)
                    
                case .minimal:
                    Circle()
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 2)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 3)
                                .scaleEffect(metro.pulse ? 1.2 : 0.8)
                                .opacity(metro.pulse ? 0.8 : 0.2)
                                .animation(.easeOut(duration: 0.3), value: metro.pulse)
                        )
                }
            }
            .frame(width: 200, height: 200)
            
            // MARK: Theme Picker
            Picker("Theme", selection: $theme) {
                ForEach(VisualTheme.allCases) { t in
                    Text(t.rawValue.capitalized).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // MARK: Controls
            VStack(spacing: 16) {
                Picker("Sound", selection: $metro.sound) {
                    ForEach(ClickSound.allCases, id: \.self) { s in
                        Text(s.rawValue.capitalized).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                Stepper("Beats per bar: \(metro.beatsPerBar)", value: $metro.beatsPerBar, in: 1...12)
                    .onChange(of: metro.beatsPerBar) {
                        metro.resetPhase()
                    }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
            
            // MARK: Toggles
            HStack(spacing: 20) {
                Toggle(isOn: $metro.soundEnabled) {
                    Label("Sound", systemImage: "speaker.wave.2.fill")
                }
                Toggle(isOn: $metro.hapticsEnabled) {
                    Label("Vibrate", systemImage: "iphone.radiowaves.left.and.right")
                }
            }
            .labelsHidden()
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            
            Spacer()
            
            // MARK: Bottom Buttons
            HStack(spacing: 24) {
                Button {
                    metro.isRunning ? metro.stop() : metro.start()
                } label: {
                    Label(metro.isRunning ? "Stop" : "Start",
                          systemImage: metro.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    metro.tapTempo()
                } label: {
                    Label("Tap", systemImage: "hand.tap.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear { metro.prepare() }
    }
}


#Preview {
    ContentView()
}
