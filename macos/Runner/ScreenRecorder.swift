import Cocoa
import ScreenCaptureKit
import AVFoundation

/// Screen recorder berbasis ScreenCaptureKit + AVAssetWriter.
/// Membutuhkan macOS 12.3+.
@available(macOS 12.3, *)
class ScreenRecorder: NSObject {

    static let shared = ScreenRecorder()
    private override init() { super.init() }

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isRecording = false
    private var sessionStarted = false
    private var frameCount = 0
    private var droppedCount = 0
    private var currentOutputPath: String?

    private let sampleQueue = DispatchQueue(
        label: "com.jasnita.screenrec.samples",
        qos: .userInteractive
    )

    var onUnexpectedStop: ((String) -> Void)?

    // MARK: - Public

    func start(
        outputPath: String,
        quality: String,
        completion: @escaping (_ success: Bool, _ error: String) -> Void
    ) {
        guard !isRecording else { completion(false, "Rekaman sudah berjalan"); return }

        currentOutputPath = outputPath
        print("[SCRec] Starting → \(outputPath)")

        SCShareableContent.getExcludingDesktopWindows(
            false, onScreenWindowsOnly: false
        ) { [weak self] content, error in
            guard let self = self else { return }

            if let error = error {
                let msg = "Izin Screen Recording ditolak: \(error.localizedDescription)\n"
                    + "Buka System Settings → Privacy & Security → Screen & System Audio Recording "
                    + "dan aktifkan Screen Recorder."
                print("[SCRec] Permission error: \(error)")
                DispatchQueue.main.async { completion(false, msg) }
                return
            }

            guard let display = content?.displays.first else {
                DispatchQueue.main.async { completion(false, "Tidak ada display ditemukan") }
                return
            }

            print("[SCRec] Display found: \(display.displayID) \(display.width)×\(display.height)")

            do {
                try self.setupAndStart(display: display, outputPath: outputPath,
                                       quality: quality, completion: completion)
            } catch {
                print("[SCRec] Setup error: \(error)")
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
            }
        }
    }

    func stop(completion: @escaping (_ savedPath: String?) -> Void) {
        guard isRecording else { completion(nil); return }
        isRecording = false
        let savedPath = currentOutputPath
        print("[SCRec] Stopping — frames written: \(frameCount), dropped: \(droppedCount)")

        stream?.stopCapture { [weak self] err in
            if let err = err { print("[SCRec] stopCapture error: \(err)") }
            self?.finalizeWriter { ok in
                print("[SCRec] Finalize ok=\(ok) path=\(savedPath ?? "nil")")
                completion(ok ? savedPath : nil)
            }
        }
    }

    // MARK: - Private

    private func setupAndStart(
        display: SCDisplay,
        outputPath: String,
        quality: String,
        completion: @escaping (Bool, String) -> Void
    ) throws {
        let url = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: url)

        let displayID = display.displayID
        let width  = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        print("[SCRec] Pixel size: \(width)×\(height)")

        let config = SCStreamConfiguration()
        config.width  = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let bitrate = quality == "high" ? 8_000_000 : (quality == "low" ? 1_500_000 : 4_000_000)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey:  width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: 60,
            ],
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(vInput) else {
            throw NSError(domain: "ScreenRecorder", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Tidak dapat menambahkan video track"])
        }
        writer.add(vInput)

        assetWriter    = writer
        videoInput     = vInput
        sessionStarted = false
        frameCount     = 0
        droppedCount   = 0

        let filter   = SCContentFilter(display: display, excludingWindows: [])
        let scStream = SCStream(filter: filter, configuration: config, delegate: self)
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        stream = scStream

        guard writer.startWriting() else {
            let err = writer.error?.localizedDescription ?? "AVAssetWriter gagal startWriting"
            throw NSError(domain: "ScreenRecorder", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: err])
        }
        print("[SCRec] AVAssetWriter startWriting OK")

        scStream.startCapture { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("[SCRec] startCapture error: \(error)")
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
                return
            }
            print("[SCRec] Capture started OK")
            self.isRecording = true
            DispatchQueue.main.async { completion(true, "") }
        }
    }

    private func finalizeWriter(completion: @escaping (Bool) -> Void) {
        guard let writer = assetWriter else { completion(false); return }

        videoInput?.markAsFinished()

        if !sessionStarted {
            print("[SCRec] Warning: no frames received — starting dummy session")
            writer.startSession(atSourceTime: .zero)
        }

        writer.finishWriting { [weak self] in
            let status = writer.status
            let err    = writer.error
            print("[SCRec] finishWriting status=\(status.rawValue) error=\(String(describing: err))")
            self?.cleanup()
            DispatchQueue.main.async { completion(status == .completed) }
        }
    }

    private func cleanup() {
        stream             = nil
        assetWriter        = nil
        videoInput         = nil
        currentOutputPath  = nil
        sessionStarted     = false
        frameCount         = 0
        droppedCount       = 0
    }
}

// MARK: - SCStreamOutput

@available(macOS 12.3, *)
extension ScreenRecorder: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        guard isRecording else { return }

        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else {
            print("[SCRec] WARNING: no CVImageBuffer in sample buffer — skipping")
            return
        }

        guard let writer = assetWriter else { return }
        guard writer.status == .writing else {
            print("[SCRec] WARNING: writer status=\(writer.status.rawValue)")
            return
        }
        guard let vInput = videoInput else { return }

        if !sessionStarted {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
            print("[SCRec] First frame! Session started at pts=\(pts.seconds)s")
        }

        if vInput.isReadyForMoreMediaData {
            let ok = vInput.append(sampleBuffer)
            if ok {
                frameCount += 1
                if frameCount == 1 || frameCount % 90 == 0 {
                    print("[SCRec] Frames appended: \(frameCount)")
                }
            } else {
                droppedCount += 1
                if droppedCount % 30 == 0 {
                    print("[SCRec] append FAILED (dropped=\(droppedCount))")
                }
            }
        } else {
            droppedCount += 1
        }
    }
}

// MARK: - SCStreamDelegate

@available(macOS 12.3, *)
extension ScreenRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard isRecording else { return }
        print("[SCRec] Stream stopped with error: \(error)")
        isRecording = false
        finalizeWriter { _ in }
        DispatchQueue.main.async { [weak self] in
            self?.onUnexpectedStop?(error.localizedDescription)
        }
    }
}
