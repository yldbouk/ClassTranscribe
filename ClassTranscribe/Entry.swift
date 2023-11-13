//
//  Entry.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/26/23.
//

import Foundation
import SwiftWhisper
import SwiftUI

class Entry : WhisperDelegate, Equatable {
 
    enum State: Int {
        case Recording, Transcribing, Complete, Failed
    }
    
    struct EntryError: Error {
        let message: String

    }
    
    static func == (lhs: Entry, rhs: Entry) -> Bool {
        return lhs.id == rhs.id
    }
    
    static var recording: Entry!
    
    var microphone: Microphone!
    var forMeeting: Schedule.Meeting?
    var whisper: Whisper!
    var state: State
    var error: Error? // only populated after an error has occured
    var recordingStartedNotificationID: String?
    var selfLabel = (
        to: Control.AppState.Record,
        percentage: "...",
        forOperation: nil as String?
    )
    let id = UUID().hashValue
    
    /// Create an entry by recording then transcribing
    init(destination: Schedule.Meeting?, menuLabel: MenuBarLabel, recordingStartedNotificationID: String?) {

        // These two guards should never run but are here just in case
        guard Self.recording == nil else {
            state = .Failed
            error = EntryError(message: "A recording is already happening.")
            microphone = nil
            Control.main.EntryFailedCallback(self)
            return
        }
        guard menuLabel.recordingEnabled else {
            state = .Failed
            error = EntryError(message: "Permission to use the microphone is not granted.")
            microphone = nil
            Control.main.EntryFailedCallback(self)
            return
        }
        
        state = .Recording
        print("init microphone")
        microphone = Microphone()
        forMeeting = destination
        self.recordingStartedNotificationID = recordingStartedNotificationID
        
        do { try microphone.record() }
        catch {
            state = .Failed
            self.error = error
            microphone.stop()
            Control.main.EntryFailedCallback(self)

        }
        Self.recording = self
    }
    
    /// Create an entry by transcribing an existing recording
    init(destination: Schedule.Meeting?, withExistingRecording: URL, menuLabel: MenuBarLabel) {
//        Entry.latest = self
        self.forMeeting = destination
        state = .Transcribing

        transcribe(url: withExistingRecording)
    }

    private func updateLabel(to: Control.AppState, percentage: String = "...", forOperation: String? = nil) {
        selfLabel = (to: to, percentage: percentage, forOperation: forOperation)
//        DispatchQueue.main.async {
            MenuBarLabel.main.update(to: to, percentage: percentage, forOperation: forOperation, fromEntry: self)
//        }
    }
        
    public func stopRecording() {
        print("Stopping Recording")
        if recordingStartedNotificationID != nil {
            AppDelegate.removeNotification(recordingStartedNotificationID!)
        }
        microphone.stop()
    }
    
// will have to implement this a different way
//    public func stopTranscription()  {
//        Task { 
//            do {
//                print("Stopping Transcription")
//                try await whisper?.cancel()
//            } catch {
//                print("ERROR: Could not stop transcription: \(error)")
//            }
//        }
//    }
    
    func recordingSucceeded(dataURL: URL){
        Self.recording = nil
        MenuBarLabel.main.recordingEnabled = true
        
        state = .Transcribing
        Control.main.determineTrackedEntry()
        
        let data = try! Data(contentsOf: dataURL) // Handle error here
        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        transcribe(frames: floats)
    }
    
    func recordingFailed(error: Error){
        Self.recording = nil
        MenuBarLabel.main.recordingEnabled = true
        self.error = error
        state = .Failed
        
        Control.main.EntryFailedCallback(self)
    }
    
    func transcribe(frames: [Float]) {
        updateLabel(to: .Transcribe, forOperation: self.forMeeting?.course)
        Task {
            let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
            let model: URL = appsupport!.appending(path: "ClassTranscribe/model.bin")
            
            let whisper = Whisper(fromFileURL: model)
            whisper.delegate = self
            whisper.params.language = .english
            _=try! await whisper.transcribe(audioFrames: frames)
        }
    }
    
    func transcribe(url: URL)  {
        updateLabel(to: .Transcribe, forOperation: self.forMeeting?.course)
        Task {
            let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
            let model: URL = appsupport!.appending(path: "ClassTranscribe/model.bin")

            let whisper = Whisper(fromFileURL: model)
            whisper.delegate = self
            whisper.params.language = .english
            let frames = FormatConverter.convertAudioFileToPCMArray(inputURL: url)
            _=try! await whisper.transcribe(audioFrames: frames!)
        }
    }
    
    func formatSecondsFull(timems: Int) -> String { // use DateComponentsFormatter()

        // 00:00:00.000
        let ms  = timems % 1000
        let sec = timems / 1000
        let min = timems / 60000 % 60
        let hr  = timems / 3600000 % 24
        
        return String(format: "%02d:%02d:%02d.%03d", hr, min, sec, ms)

    }
    
    // Progress updates as a percentage from 0-1
    func whisper(_ aWhisper: Whisper, didUpdateProgress progress: Double) {
        if(Control.main.trackedEntry == self) {
            updateLabel(to: .Transcribe, percentage: String(format: "%.0f%%", progress*100), forOperation: forMeeting?.course)
        }
    }

    // Any time a new segments of text have been transcribed
    // func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {}
    
    // Finished transcribing, includes all transcribed segments of text
    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {
        print("Entry \(id): Transcription Complete")
        updateLabel(to: .Transcribe, percentage: "100%", forOperation: self.forMeeting?.course)
    var resData:String = "WEBVTT"
        segments.forEach { segment in
            // 00:00:00.000
            resData += "\n\n\(formatSecondsFull(timems: segment.startTime)) --> \(formatSecondsFull(timems: segment.endTime))\n\(segment.text.dropFirst())\n"
//            print(formatSeconds(timems: segment.startTime), "-->", formatSeconds(timems: segment.endTime))
//            print(segment.text)
        }
        do {
            try resData.write(to: determineDestination(title: "transcription"), atomically: false, encoding: .utf8)
        } catch {
            print("File Write Error")
            self.error = error
            Control.main.EntryFailedCallback(self)
        }
        state = .Complete
        Control.main.EntryCompleteCallback(self)
    }

    // Error with transcription
    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {
        print("Transcription Error")
        state = .Failed
        self.error = error
        Control.main.EntryFailedCallback(self)
    }

    func determineDestination(title: String) -> URL {
//        if(forMeeting == nil) {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.message = "Where will this entry's \(title) be saved?"
            
            // TODO: user must save the file (for now)
            while true { if (panel.runModal() == .OK) { break } }
            return panel.url!
//        } else {
            // TODO: Implement auto-saving to location
//            destinationURL =
//        }
    }
    
}
