//
//  Control.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import Foundation
import AVFoundation
import SwiftUI
import SwiftWhisper

class Control : WhisperDelegate {
    
    public enum AppState: Int {
        case Idle, Record, RecordingComplete, Transcribe, TranscribingComplete, Waiting
    }
    private var currentState: AppState = .Idle
    var microphone: Microphone! = nil
    var menuLabel: MenuBarLabel! = nil
    init(menuBar: MenuBarLabel) {
        self.menuLabel = menuBar
        Task { @MainActor in
            InitializeMicrophone()
        }
        
    }
    
    func InitializeMicrophone(){
        print("Initializing Recording System")
        microphone = Microphone(controller: self)
        if(microphone.getState() == Microphone.State.None) {
            menuLabel.update(to: .Idle)
        }
    }
    
    func AttemptUpdateState(requested: AppState) {
        
        if(requested == .Record) {
            if(currentState == .Idle) { // Begin Recording
                print("Starting Recording...")
                currentState = requested
                menuLabel.update(to: .Record)
                do {
                    try microphone.record()
                }
                catch {
                    print(error)
                    microphone.stop()
                }
            } else if(currentState == .Record) {
                print("Stopping Recording")
                microphone.stop()
            }
        } else if(requested == .Transcribe) {
            if(currentState == .Idle) {
                currentState = .Transcribe
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                
                if (panel.runModal() != .OK) { currentState = .Idle; return }
                print(panel.url!.absoluteString)
                
                Task { await transcribe(url: panel.url!) }
              
            } else if(currentState == .Transcribe) {
                // TODO: Implement cancel transcribe
            }
            
        }
    }
    
    func transcribe(frames: [Float]) async {
        let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
        let model: URL = appsupport!.appending(path: "ClassTranscribe/model.bin")
        
        await MainActor.run { menuLabel.update(to: .Transcribe) }
        let whisper = Whisper(fromFileURL: model)
        whisper.delegate = self
        whisper.params.language = .english
        _=try! await whisper.transcribe(audioFrames: frames)
    }
    
    func transcribe(url: URL) async {
        let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
        let model: URL = appsupport!.appending(path: "ClassTranscribe/model.bin")
        
        await MainActor.run { menuLabel.update(to: .Transcribe) }
        let whisper = Whisper(fromFileURL: model)
        whisper.delegate = self
        whisper.params.language = .english
        let frames = FormatConverter.convertAudioFileToPCMArray(inputURL: url)
        _=try! await whisper.transcribe(audioFrames: frames!)
    }
    
    
    
    
    // Progress updates as a percentage from 0-1
    func whisper(_ aWhisper: Whisper, didUpdateProgress progress: Double) {
        if(currentState == .Transcribe) {
             menuLabel?.update(to: .Transcribe, percentage: String(format: "%.0f%%", progress*100))
        }
    }

    // Any time a new segments of text have been transcribed
    // func whisper(_ aWhisper: Whisper, didProcessNewSegments segments: [Segment], atIndex index: Int) {}
    
    // Finished transcribing, includes all transcribed segments of text
    func whisper(_ aWhisper: Whisper, didCompleteWithSegments segments: [Segment]) {
        print("\n\nTranscription Complete")
        menuLabel?.update(to: .Transcribe, percentage: "100%")
        

    var resData:String = "WEBVTT"
        segments.forEach { segment in
            // 00:00:00.000
            resData += "\n\n\(formatSeconds(timems: segment.startTime)) --> \(formatSeconds(timems: segment.endTime))\n\(segment.text.dropFirst())\n"
//            print(formatSeconds(timems: segment.startTime), "-->", formatSeconds(timems: segment.endTime))
//            print(segment.text)
        }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        
        // TODO: user must save the file (for now)
        while true { if (panel.runModal() == .OK) { break } }
        do {
            try resData.write(to: panel.url!, atomically: false, encoding: .utf8)
        } catch {
            print("ERROR writing file: ", error)
        }
        currentState = .Idle
        menuLabel.update(to: .Idle)
    }

    // Error with transcription
    func whisper(_ aWhisper: Whisper, didErrorWith error: Error) {
        print("\n\nERROR:", error)
    }
    
    func formatSeconds(timems: Int) -> String {
        // 00:00:00.000
        let ms  = timems % 1000
        let sec = timems / 1000
        let min = timems / 60000 % 60
        let hr  = timems / 3600000 % 24
        
        return String(format: "%02d:%02d:%02d.%03d", hr, min, sec, ms)

    }
    
}
