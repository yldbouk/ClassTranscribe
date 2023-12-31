//
//  ClassTranscribeApp.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import SwiftUI
import SettingsAccess

class MenuBarLabel: ObservableObject {
    var recordingTimer: Timer?
    var waitingTimer: Timer?
    var startTime: Date!
    private let formatter = DateFormatter()
    private static var _self: MenuBarLabel!
    public static var main: MenuBarLabel {
        get { return _self }
    }
    
    init () { MenuBarLabel._self = self }
    
    public func manageTimer(stop: Bool = false) {
        guard !stop else {
            print("Stopping timer..")
            recordingTimer?.invalidate()
            return
        }
        print("Starting timer..")
        startTime = Date.now
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let time = self.formatRelativeTime(seconds: Int(Date().timeIntervalSince(self.startTime)))
            self.labels.icon.text = time
            self.labels.status = "Recording, \(time) elapsed"
        }
        recordingTimer?.tolerance = 0.1 // test higher values
    }
    
    @Published var labels =
    (
        status: "Loading...",
        recording: "Begin Recording",
        transcription: "Transcribe Existing Recording...",
        icon: (
            text: "Loading",
            image: "waveform"
            )
    )
    @Published var recordingEnabled = false
    
    func formatRelativeTime(seconds: Int) -> String {
        let sec = seconds % 60
        let min = seconds / 60 % 60
        let hr  = seconds / 3600
        
        if hr != 0 {
            return String(format: "%d:%02d:%02d", hr, min, sec)
        }
        return String(format: "%d:%02d", min, sec)
    }
    
    func getLabelForWaiting(seconds: Int) -> String {
        let hr = seconds / 3600
        
        if(hr > 24) { return String(seconds / 86400) + (hr > 48 ? "days" : "day")}
        else if(hr > 12) { return "1 day" }
        else if (hr >= 1) { return String(hr) + (hr != 1 ? "hrs" : "hr") }
        else if (seconds > 900) { return String(seconds / 60) + "mins" }
        else { return String(format: "%d:%02d", seconds / 60, seconds % 60) }
    }
    
    func scheduleWaitingLabel(startsIn: Int) {
        
    }
    
    func update(to: Control.AppState, percentage: String = "...", forOperation: String? = nil, fromEntry: Entry? = nil) {
        guard fromEntry == Control.main.trackedEntry else {
            print("Would have updated MenuBar Label to \(to), \(percentage), from \(String(describing: fromEntry?.id))")
            return
        }
        var forOperation = forOperation
        if forOperation == nil { forOperation = "" }
        else { forOperation = " for \(forOperation!)" }
        print("Updating MenuBar Label to \(to), \(percentage), from \(String(describing: fromEntry?.id))")
        switch (to) {
        case .Idle:
            labels.icon.image = "waveform"
            labels.icon.text = "Idle"
            labels.status = "Idle"
            labels.transcription = "Transcribe Existing Recording..."
            if recordingEnabled {
                labels.recording = "Begin Recording"
            } else {
                labels.recording = "Microphone Disabled"
            }
        break
        
        
        case .Record:
            labels.icon.image = "record.circle"
            labels.icon.text = "0:00"
            labels.status = "Recording\(forOperation!) 0:00 elapsed"
            labels.recording = "End Recording"
        break
        
        case .Transcribe:
            labels.icon.image = "recordingtape.circle.fill"
            labels.icon.text = percentage 
            
            labels.recording = "Begin Recording"
            if(percentage.starts(with: ".")) {
                labels.status = "Transcribing\(forOperation!), preparing"
            } else if(percentage.starts(with: "100")) {
                labels.status = "Transcribing\(forOperation!), finalizing"
            } else {
                labels.status = "Transcribing\(forOperation!), \(percentage) complete"
            }
//            labels.transcription = "Stop Transcribing"
        break
        
        case .Waiting:
            labels.icon.image = "graduationcap.fill"
            labels.icon.text = percentage
            labels.status = "Waiting\(forOperation!), \(percentage) remaining"
            labels.recording = "Begin Recording"
            labels.transcription = "Transcribe Existing Recording..."
            break
        }
    }
}

@main
struct MenuBar: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var menuLabel = MenuBarLabel()
    
    var controller: Control?
    
    init() { controller = Control(menuBar: menuLabel) }

    var body: some Scene {
        
        // WindowGroup { ContentView() }
        Settings { SettingsView() }
        MenuBarExtra() {
            Text(menuLabel.labels.status)
            

            Divider()
            
            
            Button(menuLabel.labels.recording) { controller!.AttemptUpdateState(requested: .Record) } // TODO: Implement recording properly
                .keyboardShortcut("R")
                .disabled(!menuLabel.recordingEnabled)
            Button(menuLabel.labels.transcription) {controller!.AttemptUpdateState(requested: .Transcribe) }
                .keyboardShortcut("E")
            
            
            Divider()
            
            
            SettingsLink {
                        Text("Settings...")
                    } preAction: {
                        // code to run before Settings opens
                    } postAction: {
                         NSApp.activate(ignoringOtherApps: true)
                    }
                .keyboardShortcut(",")
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
