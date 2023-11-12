//
//  Entry.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/26/23.
//

import Foundation
import SwiftWhisper
import SwiftUI

extension Whisper {
    
    struct WhisperEntry { static var _course: String!; static var _for: Entry! }
    var course: String {
        get {  return WhisperEntry._course }
        set(newValue) { WhisperEntry._course = newValue  }
    }
    var forEntry: Entry {
        get {  return WhisperEntry._for }
        set(newValue) { WhisperEntry._for = newValue  }
    }
}

class Entry : WhisperDelegate {
    
    static var latest: Entry!
    
    var microphone: Microphone!
    var forMeeting: Schedule.Meeting?
    var whisper: Whisper!
    var menuLabel: MenuBarLabel!
    var recordingStartedNotificationID: String?

    public let id = UUID().hashValue
    
    
    /// Create an entry by recording then transcribing
    init(destination: Schedule.Meeting?, menuLabel: MenuBarLabel, recordingStartedNotificationID: String?) {

        Entry.latest = self
        print("init microphone")
        microphone = Microphone(entry: self)
        forMeeting = destination
        self.menuLabel = menuLabel
        self.recordingStartedNotificationID = recordingStartedNotificationID
        
        do { try microphone.record() }
        catch {
            print(error)
            microphone.stop()
        }
    }
    
    init(destination: Schedule.Meeting?, withExistingRecording: URL, menuLabel: MenuBarLabel) { // only transcription
        Entry.latest = self
        self.forMeeting = destination
        self.menuLabel = menuLabel

        
        Task { await transcribe(url: withExistingRecording) }
    }
        
    public func stopRecording() {
        print("Stopping Recording")
        if recordingStartedNotificationID != nil {
            AppDelegate.removeNotification(recordingStartedNotificationID!)
        }
        microphone.stop()
    }
    
    public func stopTranscription()  {
        Task { 
            do {
                print("Stopping Transcription")
                try await whisper?.cancel()
            } catch {
                print("ERROR: Could not stop transcription: \(error)")
            }
        }
    }
    
    func transcribe(frames: [Float]) async {
        let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
        let model: URL = appsupport!.appending(path: "ClassTranscribe/model.bin")
        
        DispatchQueue.main.sync { self.menuLabel.update(to: .Transcribe, forOperation: forMeeting?.course) }
        let whisper = Whisper(fromFileURL: model)
        whisper.delegate = self
        whisper.params.language = .english
        _=try! await whisper.transcribe(audioFrames: frames)
    }
    
    func transcribe(url: URL) async {
        let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
        let model: URL = appsupport!.appending(path: "ClassTranscribe/model.bin")
        
        DispatchQueue.main.sync { menuLabel.update(to: .Transcribe, forOperation: forMeeting?.course) }
        let whisper = Whisper(fromFileURL: model)
        whisper.delegate = self
        whisper.params.language = .english
        let frames = FormatConverter.convertAudioFileToPCMArray(inputURL: url)
        _=try! await whisper.transcribe(audioFrames: frames!)
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
        if(Control.main.state == .Transcribe) {
            menuLabel.update(to: .Transcribe, percentage: String(format: "%.0f%%", progress*100), forOperation: forMeeting?.course)
        }
    }

    // Any time a new segments of text have been transcribed
    // func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {}
    
    // Finished transcribing, includes all transcribed segments of text
    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {
        print("\n\nTranscription Complete")
        menuLabel.update(to: .Transcribe, percentage: "100%", forOperation: forMeeting?.course)
        
        

    var resData:String = "WEBVTT"
        segments.forEach { segment in
            // 00:00:00.000
            resData += "\n\n\(formatSecondsFull(timems: segment.startTime)) --> \(formatSecondsFull(timems: segment.endTime))\n\(segment.text.dropFirst())\n"
//            print(formatSeconds(timems: segment.startTime), "-->", formatSeconds(timems: segment.endTime))
//            print(segment.text)
        }
        do {
            try resData.write(to: determineDestination(), atomically: false, encoding: .utf8)
        } catch {
            print("ERROR writing file: ", error)
        }
        Control.main.EntryCompleteCallback(self)
    }

    // Error with transcription
    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {
        print("\n\nERROR:", error)
    }

    func determineDestination() -> URL {
//        if(forMeeting == nil) {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            
            // TODO: user must save the file (for now)
            while true { if (panel.runModal() == .OK) { break } }
            return panel.url!
//        } else {
            // TODO: Implement auto-saving to location
//            destinationURL =
//        }
    }
    
}
