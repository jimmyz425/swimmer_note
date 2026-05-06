import SwiftUI
import AVFAudio

/// Observable timer engine for stopwatch functionality
/// Supports start/stop, split recording, stroke counting, and reset
@Observable
class TimerEngine: NSObject {
    // MARK: - State

    var isRunning: Bool = false
    var elapsedTime: TimeInterval = 0
    var splits: [TimerSplit] = []
    var startTime: Date?
    var currentStrokeCount: Int = 0  // Strokes for current lap

    // MARK: - Computed Properties

    /// Current lap time (time since last split)
    var currentLapTime: TimeInterval {
        guard let lastSplit = splits.last else { return elapsedTime }
        return elapsedTime - lastSplit.cumulativeTime
    }

    /// Current stroke rate (strokes per minute)
    var currentStrokeRate: Double {
        guard currentLapTime > 0 else { return 0 }
        return Double(currentStrokeCount) / (currentLapTime / 60.0)
    }

    /// Total strokes across all splits
    var totalStrokes: Int {
        splits.reduce(0) { $0 + $1.strokeCount } + currentStrokeCount
    }

    /// Average stroke rate across all completed splits
    var averageStrokeRate: Double {
        guard !splits.isEmpty else { return 0 }
        let totalTime = splits.reduce(0.0) { $0 + $1.lapTime }
        let totalStrokes = splits.reduce(0) { $0 + $1.strokeCount }
        guard totalTime > 0 else { return 0 }
        return Double(totalStrokes) / (totalTime / 60.0)
    }

    /// Formatted total elapsed time
    var displayTime: String {
        formatTime(elapsedTime)
    }

    /// Formatted current lap time
    var displayLapTime: String {
        formatTime(currentLapTime)
    }

    /// Number of splits recorded
    var splitCount: Int {
        splits.count
    }

    // MARK: - Private

    private var timer: Timer?
    private var accumulatedTime: TimeInterval = 0  // Time before current run

    // MARK: - Actions

    /// Start the timer
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()

        // Resume from accumulated time if paused
        let baseTime = accumulatedTime

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            self.elapsedTime = baseTime + Date().timeIntervalSince(self.startTime!)
        }

        // Keep timer running in background
        timer?.tolerance = 0
    }

    /// Stop/pause the timer
    func stop() {
        guard isRunning else { return }
        isRunning = false

        // Save elapsed time for resume
        accumulatedTime = elapsedTime

        timer?.invalidate()
        timer = nil

        playBeep()
    }

    /// Reset everything
    func reset() {
        stop()
        elapsedTime = 0
        accumulatedTime = 0
        splits = []
        startTime = nil
        currentStrokeCount = 0
    }

    /// Record a stroke (tap during swim)
    func recordStroke() {
        guard isRunning else { return }
        currentStrokeCount += 1
        playBeep()
    }

    /// Record a split/lap
    func recordSplit() {
        guard isRunning else { return }

        let lapTime = splits.isEmpty ? elapsedTime : elapsedTime - splits.last!.cumulativeTime
        let split = TimerSplit(
            splitNumber: splits.count + 1,
            cumulativeTime: elapsedTime,
            lapTime: lapTime,
            strokeCount: currentStrokeCount,
            timestamp: Date()
        )
        splits.append(split)

        // Reset stroke count for next lap
        currentStrokeCount = 0

        playBeep()
    }

    // MARK: - Formatting

    /// Format time as MM:SS.HH or SS.HH
    func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hundredths = Int((time * 100).truncatingRemainder(dividingBy: 100))

        if minutes > 0 {
            return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
        } else {
            return String(format: "%02d.%02d", seconds, hundredths)
        }
    }

    /// Format stroke rate as whole number
    func formatStrokeRate(_ rate: Double) -> String {
        String(format: "%.0f", rate)
    }

    /// Format stroke length in meters
    func formatStrokeLength(_ length: Double) -> String {
        String(format: "%.2f", length)
    }

    // MARK: - Audio

    /// Play a short beep sound
    func playBeep() {
        // System sound: short beep (1057)
        AudioServicesPlaySystemSound(1057)
    }

    /// Play start countdown beep sequence (3-2-1-GO)
    func playStartSequence() async {
        for _ in [3, 2, 1] {
            playBeep()
            try? await Task.sleep(for: .seconds(1))
        }
        // Double beep for GO
        AudioServicesPlaySystemSound(1057)
        try? await Task.sleep(for: .milliseconds(100))
        AudioServicesPlaySystemSound(1057)
    }
}
