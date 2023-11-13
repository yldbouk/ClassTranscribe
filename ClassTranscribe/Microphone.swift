//
//  Microphone.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import AVFoundation

public class Microphone : NSObject, AVAudioRecorderDelegate {
    
    struct RecordingError: Error {
        let message: String

    }
    
    public enum State: Int {
        case None, Record, Play
    }
    
//    var entry: Entry!
    var url: URL?
    
    private var state: State = .None
    
    public func getState() -> State { return state }
    
    private var recorder: AVAudioRecorder?
    private var dateF = DateFormatter()
    
    static func getPermission() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if(authStatus == .authorized) { Control.main.microphoneEnabled() }
        else if(authStatus == .notDetermined) {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted { Control.main.microphoneEnabled() }
            }
        }
    }
    
//    init(entry: Entry) { self.entry = entry }
    
    
    // MARK: - Record
    private func prepare() throws -> URL {
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        
        dateF.dateStyle = .medium
        dateF.timeStyle = .medium
        
        let filename = dateF.string(from: Date()) + ".wav"
        url = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
        
        recorder = try AVAudioRecorder(url: url!, settings: settings)
        recorder?.delegate = self
        recorder?.prepareToRecord()
        return url!
    }

    public func record() throws {
        if recorder == nil { print("Starting recording to \(try prepare())") }
        recorder?.record()
        state = .Record
    }

    public func stop() {
        if (state == .Record) {
            recorder?.stop()
            recorder = nil
            state = .None
        }
    }

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully: Bool) {
        if (successfully) { Entry.recording.recordingSucceeded(dataURL: recorder.url) }
        else { Entry.recording.recordingFailed(error: RecordingError(message: "Audio recorder did not finish sucessfully.")) }
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Entry.recording.recordingFailed(error: error ?? RecordingError(message: "audioRecorderEncodeErrorDidOccur"))
    }
}
