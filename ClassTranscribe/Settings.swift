//
//  Settings.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 11/13/23.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            RecordingSettingsView()
                .frame(width: 250, height: 75)
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }
            
            SavingSettingsView()
                .frame(width: 300, height: 150)
                .tabItem {
                    Label("Saving", systemImage: "square.and.arrow.down")
                }
            
            ScheduleSettingsView()
                .frame(width: 600, height: 400)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
        }
        
    }
    
    struct RecordingSettingsView: View {
        var body: some View {
            Text("Nothing here for now")
                .font(.title)
        }
    }
     
     
    struct SavingSettingsView: View {
        @AppStorage("defaultRecordingSaveLocation") var defaultRecordingSaveLocation = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!
        @AppStorage("defaultTranscriptionSaveLocation") var defaultTranscriptionSaveLocation = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!
        @AppStorage("writeWhileTranscribing") var writeWhileTranscribing = false
        
        func saveLocation(_ name: String, original: URL) -> URL{
            let panel = NSOpenPanel()
            panel.canCreateDirectories = true
            panel.directoryURL = original
            panel.canChooseFiles = false;
            panel.canChooseDirectories = true;
            panel.message = "Where will new \(name)s be saved?"
            guard panel.runModal() == .OK else { return original }
            return panel.url!
        }

        var body: some View {
            VStack {
                Spacer()
                // Default Recording Location
                HStack {
                    Text("Default Recording Folder: \(defaultRecordingSaveLocation.lastPathComponent)")
                    Button("Change") {  defaultRecordingSaveLocation = saveLocation("recording", original: defaultRecordingSaveLocation) }
                }
                Spacer()
                // Default Transcription Location
                HStack {
                    Text("Default Transcription Folder: \(defaultTranscriptionSaveLocation.lastPathComponent)")
                    Button("Change") { defaultTranscriptionSaveLocation = saveLocation("recording", original: defaultTranscriptionSaveLocation) }
                }
                Spacer()
                Toggle(isOn: $writeWhileTranscribing){Text("Simultaneously Transcribe and Write")}
                Spacer()

            }
        }
    }
     
    struct ScheduleSettingsView: View {
        var body: some View {
            ScheduleView()
        }
    }
}

#Preview { SettingsView() }
