import Foundation

public enum PoseLandmarkIndex: Int, CaseIterable, Sendable {
    case nose = 0
    case leftEye = 1
    case rightEye = 2
    case leftEar = 7
    case rightEar = 8
    case leftShoulder = 11
    case rightShoulder = 12
    case leftElbow = 13
    case rightElbow = 14
    case leftWrist = 15
    case rightWrist = 16
    case leftHip = 23
    case rightHip = 24
    case leftKnee = 25
    case rightKnee = 26
    case leftAnkle = 27
    case rightAnkle = 28

    public static let count = 33
}

public struct PoseLandmark: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var visibility: Double

    public init(x: Double, y: Double, z: Double, visibility: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.visibility = visibility
    }
}

public struct PoseFrame: Codable, Hashable, Sendable {
    public var timestamp: Double
    public var landmarks: [PoseLandmark]

    public init(timestamp: Double, landmarks: [PoseLandmark]) {
        self.timestamp = timestamp
        self.landmarks = landmarks
    }
}

public struct PoseAnalysisMetrics: Codable, Hashable, Sendable {
    public var strokeRatePerMinute: Double
    public var strokeRateHz: Double
    public var kickRatePerMinute: Double
    public var kickRateHz: Double
    public var kickRateConfidence: Double
    public var bodyAngleAverage: Double
    public var bodyAngleMin: Double
    public var bodyAngleMax: Double
    public var armEntryAngleAverage: Double
    public var elbowHeightAverage: Double

    public static let empty = PoseAnalysisMetrics(
        strokeRatePerMinute: 0,
        strokeRateHz: 0,
        kickRatePerMinute: 0,
        kickRateHz: 0,
        kickRateConfidence: 0,
        bodyAngleAverage: 0,
        bodyAngleMin: 0,
        bodyAngleMax: 0,
        armEntryAngleAverage: 0,
        elbowHeightAverage: 0
    )
}

public struct VideoAnalysisRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var videoFilename: String
    public var strokeId: StrokeID
    public var createdAt: String
    public var metrics: PoseAnalysisMetrics
    public var frames: [PoseFrame]
}

public struct PoseMetricsAnalyzer: Sendable {
    public init() {}

    public func analyze(frames: [PoseFrame]) -> PoseAnalysisMetrics {
        guard !frames.isEmpty else { return .empty }
        let bodyAngles = frames.map { calculateBodyAngle(landmarks: $0.landmarks) }.filter(\.isFinite)
        let elbowHeights = frames.map { calculateElbowHeight(landmarks: $0.landmarks) }.filter(\.isFinite)
        let armEntryAngles = frames.map { calculateArmEntryAngle(landmarks: $0.landmarks) }.filter(\.isFinite)
        let kickRate = estimateRate(frames: frames, primary: .leftAnkle, secondary: .rightAnkle)
        let strokeRate = estimateRate(frames: frames, primary: .leftWrist, secondary: .rightWrist)

        return PoseAnalysisMetrics(
            strokeRatePerMinute: strokeRate * 60,
            strokeRateHz: strokeRate,
            kickRatePerMinute: kickRate * 60,
            kickRateHz: kickRate,
            kickRateConfidence: kickRate > 0 ? 0.75 : 0,
            bodyAngleAverage: average(bodyAngles),
            bodyAngleMin: bodyAngles.min() ?? 0,
            bodyAngleMax: bodyAngles.max() ?? 0,
            armEntryAngleAverage: average(armEntryAngles),
            elbowHeightAverage: average(elbowHeights)
        )
    }

    public func calculateBodyAngle(landmarks: [PoseLandmark]) -> Double {
        guard
            let leftShoulder = landmarks[safe: PoseLandmarkIndex.leftShoulder.rawValue],
            let rightShoulder = landmarks[safe: PoseLandmarkIndex.rightShoulder.rawValue],
            let leftHip = landmarks[safe: PoseLandmarkIndex.leftHip.rawValue],
            let rightHip = landmarks[safe: PoseLandmarkIndex.rightHip.rawValue]
        else {
            return 0
        }

        let shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2
        let shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2
        let hipMidX = (leftHip.x + rightHip.x) / 2
        let hipMidY = (leftHip.y + rightHip.y) / 2
        let dx = shoulderMidX - hipMidX
        let dy = shoulderMidY - hipMidY
        return atan2(dy, dx) * 180 / .pi
    }

    public func calculateElbowHeight(landmarks: [PoseLandmark]) -> Double {
        let left = relativeElbowHeight(landmarks: landmarks, elbow: .leftElbow, wrist: .leftWrist)
        let right = relativeElbowHeight(landmarks: landmarks, elbow: .rightElbow, wrist: .rightWrist)

        if let left, let right {
            return max(left, right)
        }
        return left ?? right ?? 0
    }

    public func calculateArmEntryAngle(landmarks: [PoseLandmark]) -> Double {
        guard
            let shoulder = landmarks[safe: PoseLandmarkIndex.leftShoulder.rawValue],
            let wrist = landmarks[safe: PoseLandmarkIndex.leftWrist.rawValue]
        else {
            return 0
        }

        let dx = wrist.x - shoulder.x
        let dy = wrist.y - shoulder.y
        return atan2(dy, dx) * 180 / .pi
    }

    private func relativeElbowHeight(
        landmarks: [PoseLandmark],
        elbow: PoseLandmarkIndex,
        wrist: PoseLandmarkIndex
    ) -> Double? {
        guard
            let elbowLandmark = landmarks[safe: elbow.rawValue],
            let wristLandmark = landmarks[safe: wrist.rawValue],
            elbowLandmark.visibility > 0.2,
            wristLandmark.visibility > 0.2
        else {
            return nil
        }

        return wristLandmark.y - elbowLandmark.y
    }

    private func estimateRate(frames: [PoseFrame], primary: PoseLandmarkIndex, secondary: PoseLandmarkIndex) -> Double {
        guard frames.count >= 10 else { return 0 }
        let signal = frames.map { frame -> Double in
            let first = frame.landmarks[safe: primary.rawValue]?.y ?? 0.5
            let second = frame.landmarks[safe: secondary.rawValue]?.y ?? 0.5
            return (first + second) / 2
        }
        let centered = center(signal)
        let peaks = findPeaks(centered)
        guard peaks.count >= 2 else { return 0 }
        let firstTime = frames[peaks.first ?? 0].timestamp
        let lastTime = frames[peaks.last ?? 0].timestamp
        let seconds = max((lastTime - firstTime) / 1000, 0.001)
        return Double(peaks.count - 1) / seconds
    }

    private func findPeaks(_ signal: [Double]) -> [Int] {
        guard signal.count > 2 else { return [] }
        var peaks: [Int] = []
        for index in 1..<(signal.count - 1) {
            if signal[index] > signal[index - 1], signal[index] > signal[index + 1] {
                if peaks.last.map({ index - $0 >= 3 }) ?? true {
                    peaks.append(index)
                }
            }
        }
        return peaks
    }

    private func center(_ signal: [Double]) -> [Double] {
        let mean = average(signal)
        return signal.map { $0 - mean }
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

public final class NativeVideoAnalysisService: @unchecked Sendable {
    private let metricsAnalyzer: PoseMetricsAnalyzer

    public init(metricsAnalyzer: PoseMetricsAnalyzer = PoseMetricsAnalyzer()) {
        self.metricsAnalyzer = metricsAnalyzer
    }

    public func makeRecord(videoURL: URL, strokeId: StrokeID, frames: [PoseFrame]) -> VideoAnalysisRecord {
        VideoAnalysisRecord(
            id: UUID().uuidString,
            videoFilename: videoURL.lastPathComponent,
            strokeId: strokeId,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            metrics: metricsAnalyzer.analyze(frames: frames),
            frames: frames
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
