//
//  Control.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/10/23.
//

import Foundation
import SwiftUI
import SwiftWhisper

class Control {
    
    public enum AppState: Int {
        case Record, Transcribe, Idle, Waiting
    }
    
    static var main: Control!
    
//    private var currentState: AppState = .Idle
//    var microphone: Microphone!
    var menuLabel: MenuBarLabel!
    var schedule = Schedule.main
    var nextClass: Schedule.Meeting?
    var trackedEntry: Entry?

    
//    var state: AppState {
//        get { return currentState }
//    }
    
    private var entries: [Entry] = []
    
    init(menuBar: MenuBarLabel) {
        Self.main = self
        menuLabel = menuBar
        menuLabel.update(to: .Idle)
    }
    
    func microphoneEnabled(){
        DispatchQueue.main.async { [self] in
            print("Schedule enabled, scheduling...")
            menuLabel.recordingEnabled = true
            if (schedule.enabledByUser && !schedule.isEmpty) {
                nextClass = schedule.nextMeeting()
                menuLabel.update(to: .Waiting, forOperation: nextClass!.title)
                ScheduleWait.main.ScheduleRecording(nextClass!)
            }
        }
    }
        
    func EntryCompleteCallback(_ entry: Entry){
//        entries.removeAll(where: { $0 == entry })
        determineTrackedEntry()
        if(schedule.enabledByUser && !schedule.isEmpty) {
            if trackedEntry == nil { menuLabel.update(to: .Idle) }
        } else {
            guard ScheduleWait.main.queue.isEmpty else { return }
            nextClass = schedule.nextMeeting()
//            menuLabel.update(to: .Waiting, forOperation: nextClass?.course)
            ScheduleWait.main.ScheduleRecording(nextClass!)
        }
    }
    
    func EntryFailedCallback(_ entry: Entry){
        determineTrackedEntry()
        // TODO: implement
        print("\n\nERROR with Entry \(entry.id):\n\(entry.error!)\n\n")
    }
    
    func determineTrackedEntry(){
        var entry: Entry?
        for i in entries.indices.reversed() {
            if(entries[i].state == .Complete || entries[i].state == .Failed) { continue }
            if(entries[i].state.rawValue < entry?.state.rawValue ?? Entry.State.Failed.rawValue) { entry = entries[i] }
        }
        trackedEntry = entry
        if entry?.state == .Recording {
            print("Accepting MenuBar updates from (Recording) \(String(describing: entry?.id))")
//            let label = entry!.selfLabel
//            menuLabel.update(to: label.to, percentage: label.percentage, forOperation: label.forOperation, fromEntry: entry)
            trackedEntry = entry
        } else if ScheduleWait.main.overrideDisplayPriority {
            print("Accepting MenuBar updates from Timers: ScheduleWait Display Override is on.")
            trackedEntry = nil
        } else if entry != nil {
            print("Accepting MenuBar updates from (Transcribing) \(String(describing: entry?.id))")
            let label = entry!.selfLabel
            menuLabel.update(to: label.to, percentage: label.percentage, forOperation: label.forOperation, fromEntry: entry)
        } else {
            print("Accepting MenuBar updates from anywhere.")

        }
    }
        
    func AttemptUpdateState(requested: AppState, notificationID:String? = nil) {
        if(requested == .Record) {
            if(Entry.recording != nil) {
                print("Stopping Recording")
                menuLabel.manageTimer(stop: true)
                menuLabel.recordingEnabled = false
                Entry.recording.stopRecording()
                determineTrackedEntry()
            } else {
                print("Starting Recording...")
                // ScheduleWait.main.cancelScheduledRecording()
                entries.append(Entry(
                    destination: nextClass,
                    menuLabel: menuLabel,
                    recordingStartedNotificationID: notificationID
                ))
                determineTrackedEntry()
                menuLabel.update(to: .Record, fromEntry: entries.last!)
                menuLabel.manageTimer()
            }

        } else if(requested == .Transcribe) {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            
            guard (panel.runModal() == .OK) else { return }
            print(panel.url!.absoluteString)
            
            entries.append(Entry(destination: nextClass, withExistingRecording: panel.url!, menuLabel: menuLabel))
            determineTrackedEntry()
        }
    }
}
