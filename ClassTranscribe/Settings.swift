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
                .frame(width: 450, height: 300)
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
        @AppStorage("unscheduledSaveLocation") var unscheduledSaveLocation = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!
        @AppStorage("unscheduledRecordingsSubpath") var unscheduledRecordingsSubpath = ""
        @AppStorage("unscheduledTranscriptionsSubpath") var unscheduledTranscriptionsSubpath = ""
        
        @AppStorage("scheduledSaveLocation") var scheduledSaveLocation = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!
        @AppStorage("scheduledRecordingsSubpath") var scheduledRecordingsSubpath = ""
        @AppStorage("scheduledTranscriptionsSubpath") var scheduledTranscriptionsSubpath = ""
        
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
                Text("Unscheduled Recordings")
                    .bold()
                    .font(.title2)
                HStack {
                    Text("Save To: \(unscheduledSaveLocation.lastPathComponent)")
                    Button("Change") {  unscheduledSaveLocation = saveLocation("recording", original: unscheduledSaveLocation) }
                }
                HStack {
                    Text("Recordings Subpath:")
                    TextField("Recordings/%MMM d YYYY, h:mm a%.m4a", text: $unscheduledRecordingsSubpath)
                }
                HStack {
                    Text("Transcriptions Subpath:")
                    TextField("Transcriptions/%MMM d YYYY, h:mm a%.txt", text: $unscheduledTranscriptionsSubpath)
                }
                Text("Use placeholders to fill in identifying information about the entry. Use ISO8601 formats.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
            Divider()
                Text("Scheduled Recordings")
                    .bold()
                    .font(.title2)
                HStack {
                    Text("Save To: \(scheduledSaveLocation.lastPathComponent)")
                    Button("Change") {  scheduledSaveLocation = saveLocation("recording", original: scheduledSaveLocation) }
                }
                HStack {
                    Text("Recordings Subpath:")
                    TextField("%name%/Recordings/%MMM dd%.m4a", text: $scheduledRecordingsSubpath)
                }
                HStack {
                    Text("Transcriptions Subpath:")
                    TextField("%name%/Transcriptions/%MMM dd%.txt", text: $scheduledTranscriptionsSubpath)
                }
                Text("Use placeholders to fill in identifying information about the entry. Use ISO8601 formats.\n• Use %name% to fill in the meeting name.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    
                }
            .padding(.horizontal, 10)
        }
    }
     
    struct ScheduleSettingsView: View {
        @StateObject var schedule = Schedule.main
        var body: some View {
            VStack {
                Toggle(isOn: $schedule.enabledByUser) {Text("Enabled")}
                    .onChange(of: schedule.enabledByUser) {
                        DispatchQueue.main.async { ScheduleWait.main.scheduleChanged() }
                    }
                ScheduleView()
            }
        }
    }
}

#Preview { SettingsView() }
#Preview { SettingsView.SavingSettingsView().frame(width:450, height:300) }
