//
//  ClassTranscribeApp.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import SwiftUI

class MenuBarLabel: ObservableObject {
    
    // TODO: fix text and image misalignment
    @Published var icon: HStack = HStack(spacing: 0) { Image(systemName: "waveform"); Text("Loading") }
    @Published var timerText: String = ""
    
//    let timer = Timer()
//    var startTime: Date = Date.now;
    
    @Published var buttonLabel =
    (
        recording: "Begin Recording",
        transcription: "Transcribe Existing Recording..."
    )
    
    
    func update(to: Control.AppState, percentage: String = "...") {
        print("Updating MenuBar Label to \(to), \(percentage)")
        switch (to) {
        case .Idle:
            icon = HStack() {
                Image(systemName: "waveform")
                Text("Idle")
            }
            buttonLabel.recording = "Begin Recording"
            buttonLabel.transcription = "Transcribe Existing Recording..."
        break
        
        
        case .Record:
//            startTime = Date.now
//            icon = HStack() {
//                Image(systemName: "record.circle")
//                Text(timerText)
//                    
//            }
//            buttonLabel.recording = "End Recording"
        break
       
        
        case .RecordingComplete: break
        
        
        case .Transcribe:
            icon = HStack() {
                Image(systemName: "recordingtape.circle.fill")
                Text(percentage)
            }
            buttonLabel.transcription = "Stop Transcribing"
        break
        
        case .TranscribingComplete: break
        
        
        case .Waiting:
            icon = HStack() {
                Image(systemName: "timer")
                Text("Idle")
            }

        }
    }
}

@main
struct MenuBar: App {
    @ObservedObject private var menuLabel = MenuBarLabel()
    var controller: Control?
    
    init() { controller = Control(menuBar: menuLabel) }

    var body: some Scene {
        // WindowGroup { ContentView() }
        MenuBarExtra() {
            Button(menuLabel.buttonLabel.recording) { controller!.AttemptUpdateState(requested: .Record) } // TODO: Implement recording properly
                .keyboardShortcut("R")
                .disabled(true)
            
            Button(menuLabel.buttonLabel.transcription) {controller!.AttemptUpdateState(requested: .Transcribe) }
                .keyboardShortcut("E")
            
            
            Divider()
            
            
            Button("Settings...") { NSApplication.shared.terminate(nil) } // TODO: Create settings view
                .keyboardShortcut(",")
                .disabled(true)
            
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
            
        } label: { menuLabel.icon }
        
    }
}
