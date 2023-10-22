//
//  Microphone.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import AVFoundation

public class Microphone : NSObject, AVAudioRecorderDelegate {
    
    public enum State: Int {
        case None, Record, Play
    }
    
    var controller: Control
    var url: URL?
    
    private var state: State = .None
    
    public func getState() -> State { return state }
    
    private var recorder: AVAudioRecorder?
    private var dateF = DateFormatter()
    
  
    // MARK: - Initializers
    init(controller: Control) {
        self.controller = controller
        dateF.dateStyle = .medium
        dateF.timeStyle = .medium
        }
    
    // MARK: - Record
    private func prepare() throws -> URL {
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        
        let filename = dateF.string(from: Date()) + ".wav"
        url = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
        
        recorder = try AVAudioRecorder(url: url!, settings: settings)
        recorder?.delegate = self
        recorder?.prepareToRecord()
        return url!
    }

    public func record() throws {
        if recorder == nil { print("Saving to \(try prepare())") }
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

    // MARK: - Delegates
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        let data = try! Data(contentsOf: recorder.url) // Handle error here

        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        Task { await controller.transcribe(frames: floats) }
        controller.AttemptUpdateState(requested: .RecordingComplete)
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("audioRecorderEncodeErrorDidOccur \(String(describing: error?.localizedDescription))")
    }
}
