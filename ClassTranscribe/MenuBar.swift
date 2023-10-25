//
//  ClassTranscribeApp.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import SwiftUI

class MenuBarLabel: ObservableObject {
    
    // TODO: fix text and image misalignment
//    @Published var icon: HStack = HStack(spacing: 0) { Image(systemName: "waveform"); Text("Loading") }
//    @Published var timerText: String = "0:00"
    
    var timer: Timer?
    var startTime: Date!
    private let formatter = DateFormatter()
    let timer2 = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    
    public func manageTimer(stop: Bool = false) {
        guard !stop else {
            print("Stopping timer..")
            timer?.invalidate()
            return
        }
        print("Starting timer..")
        startTime = Date.now
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            print("timer update")
            self.labels.icon.text = self.formatRelativeTime(seconds: Int(Date().timeIntervalSince(self.startTime)))
        }
        timer?.tolerance = 0.1 // test higher values
    }
    
    @Published var labels =
    (
        recording: "Begin Recording",
        transcription: "Transcribe Existing Recording...",
        icon: (
            text: "Loading",
            image: "waveform"
            )
    )
    
    func formatRelativeTime(seconds: Int) -> String {
        let sec = seconds % 60
        let min = seconds / 60 % 60
        let hr  = seconds / 3600
        
        if hr != 0 {
            return String(format: "%d:%02d:%02d", hr, min, sec)
        }
        return String(format: "%d:%02d", min, sec)
        
        
    }
    
    func update(to: Control.AppState, percentage: String = "...") {
        print("Updating MenuBar Label to \(to), \(percentage)")
        switch (to) {
        case .Idle:
//            icon = HStack() {
//                Image(systemName: "waveform")
//                Text("Idle")
//            }
            labels.icon.image = "waveform"
            labels.icon.text = "Idle"
            labels.recording = "Begin Recording"
            labels.transcription = "Transcribe Existing Recording..."
        break
        
        
        case .Record:
//            icon = HStack() {
//                Image(systemName: "record.circle")
//                Text(self.timerText)
//            }
            labels.icon.image = "record.circle"
            labels.icon.text = "7:00"
            labels.recording = "End Recording"
        break
       
        
        case .RecordingComplete: break
        
        
        case .Transcribe:
//            icon = HStack() {
//                Image(systemName: "recordingtape.circle.fill")
//                Text(percentage)
//            }
            labels.icon.image = "recordingtape.circle.fill"
            labels.icon.text = percentage // uh oh
            labels.transcription = "Stop Transcribing"
        break
        
        case .TranscribingComplete: break
        
        
        case .Waiting:
//            icon = HStack() {
//                Image(systemName: "timer")
//                Text("Idle")
//            }
            labels.icon.image = "timer"
            labels.icon.text = "Idle"
            break
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
            Button(menuLabel.labels.recording) { controller!.AttemptUpdateState(requested: .Record) } // TODO: Implement recording properly
                .keyboardShortcut("R")
            
            Button(menuLabel.labels.transcription) {controller!.AttemptUpdateState(requested: .Transcribe) }
                .keyboardShortcut("E")
            
            
            Divider()
            
            
            Button("Settings...") { NSApplication.shared.terminate(nil) } // TODO: Create settings view
                .keyboardShortcut(",")
                .disabled(true)
            
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
            
        } label: {
            HStack(spacing: 0) {
                Image(systemName: menuLabel.labels.icon.image)
                Text(menuLabel.labels.icon.text)
            }
        }
        
    }
}
