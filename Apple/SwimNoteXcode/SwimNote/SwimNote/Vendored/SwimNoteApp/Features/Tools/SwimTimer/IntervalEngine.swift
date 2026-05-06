import SwiftUI
import AVFAudio

/// Observable interval timer engine for interval training
/// Supports work/rest intervals with countdown and repetitions
@Observable
class IntervalEngine: NSObject {
    // MARK: - Configuration

    var workDuration: TimeInterval = 30  // seconds
    var restDuration: TimeInterval = 10  // seconds
    var repetitions: Int = 8
    var countdownSeconds: Int = 3

    // MARK: - State

    var isRunning: Bool = false
    var isPaused: Bool = false
    var currentPhase: Phase = .idle
    var currentRound: Int = 0
    var timeRemaining: TimeInterval = 0
    var totalElapsedTime: TimeInterval = 0
    var isCountingDown: Bool = false
    var countdownRemaining: Int = 0

    // MARK: - Computed Properties

    var displayTime: String {
        if isCountingDown {
            return String(countdownRemaining)
        }
        return formatIntervalTime(timeRemaining)
    }

    var displayPhase: String {
        if isCountingDown {
            return "GET READY"
        }
        switch currentPhase {
        case .idle: return "READY"
        case .work: return "WORK"
        case .rest: return "REST"
        case .complete: return "COMPLETE"
        }
    }

    var phaseColor: Color {
        if isCountingDown {
            return .orange
        }
        switch currentPhase {
        case .idle: return .gray
        case .work: return .red
        case .rest: return .green
        case .complete: return .blue
        }
    }

    var progress: Double {
        guard !isCountingDown else { return 0 }
        let totalInterval = currentPhase == .work ? workDuration : restDuration
        guard totalInterval > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalInterval)
    }

    var totalRounds: Int {
        repetitions
    }

    var totalDuration: TimeInterval {
        Double(repetitions) * (workDuration + restDuration)
    }

    var displayTotalTime: String {
        formatIntervalTime(totalElapsedTime)
    }

    // MARK: - Private

    private var timer: Timer?
    private var startTime: Date?

    // MARK: - Enum

    nonisolated enum Phase: Sendable {
        case idle
        case work
        case rest
        case complete
    }

    // MARK: - Actions

    /// Start the interval timer with countdown
    func start() {
        guard !isRunning else { return }

        currentRound = 0
        currentPhase = .idle
        totalElapsedTime = 0
        isRunning = true
        isPaused = false

        // Start countdown
        startCountdown()
    }

    /// Start countdown sequence
    func startCountdown() {
        isCountingDown = true
        countdownRemaining = countdownSeconds

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.playBeep()
            self.countdownRemaining -= 1

            if self.countdownRemaining <= 0 {
                self.isCountingDown = false
                self.timer?.invalidate()
                self.timer = nil
                self.playDoubleBeep()
                self.startWorkInterval()
            }
        }
    }

    /// Start work interval
    func startWorkInterval() {
        currentRound += 1
        currentPhase = .work
        timeRemaining = workDuration
        startTime = Date()

        playBeep()

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(self.startTime!)
            self.timeRemaining = self.workDuration - elapsed
            self.totalElapsedTime += 0.01

            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.timeRemaining = 0

                if self.currentRound >= self.repetitions {
                    self.completeSession()
                } else {
                    self.playDoubleBeep()
                    self.startRestInterval()
                }
            }
        }
    }

    /// Start rest interval
    func startRestInterval() {
        currentPhase = .rest
        timeRemaining = restDuration
        startTime = Date()

        playBeep()

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(self.startTime!)
            self.timeRemaining = self.restDuration - elapsed
            self.totalElapsedTime += 0.01

            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.timeRemaining = 0
                self.playDoubleBeep()
                self.startWorkInterval()
            }
        }
    }

    /// Pause the timer
    func pause() {
        guard isRunning && !isPaused else { return }
        isPaused = true
        timer?.invalidate()
        timer = nil
        playBeep()
    }

    /// Resume from pause
    func resume() {
        guard isRunning && isPaused else { return }
        isPaused = false

        // Resume current interval
        startTime = Date().addingTimeInterval(-timeRemaining)

        let interval = currentPhase == .work ? workDuration : restDuration

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(self.startTime!)
            self.timeRemaining = interval - elapsed
            self.totalElapsedTime += 0.01

            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.timeRemaining = 0

                if self.currentPhase == .work {
                    if self.currentRound >= self.repetitions {
                        self.completeSession()
                    } else {
                        self.playDoubleBeep()
                        self.startRestInterval()
                    }
                } else {
                    self.playDoubleBeep()
                    self.startWorkInterval()
                }
            }
        }
    }

    /// Stop and reset
    func stop() {
        isRunning = false
        isPaused = false
        isCountingDown = false
        currentPhase = .idle
        currentRound = 0
        timeRemaining = 0
        totalElapsedTime = 0
        countdownRemaining = 0

        timer?.invalidate()
        timer = nil

        playBeep()
    }

    /// Complete the session
    func completeSession() {
        currentPhase = .complete
        isRunning = false

        // Play completion sound (3 beeps)
        playBeep()
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            self.playBeep()
            try? await Task.sleep(for: .milliseconds(200))
            self.playBeep()
        }
    }

    // MARK: - Formatting

    func formatIntervalTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            return String(format: "%02d", seconds)
        }
    }

    // MARK: - Audio

    func playBeep() {
        AudioServicesPlaySystemSound(1057)
    }

    func playDoubleBeep() {
        AudioServicesPlaySystemSound(1057)
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            AudioServicesPlaySystemSound(1057)
        }
    }
}