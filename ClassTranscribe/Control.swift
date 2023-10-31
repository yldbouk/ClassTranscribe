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

class Control {
    
    public enum AppState: Int {
        case Idle, Record, RecordingComplete, Transcribe, TranscribingComplete, Waiting
    }
    
    static var main: Control!
    
    private var currentState: AppState = .Idle
//    var microphone: Microphone!
    var menuLabel: MenuBarLabel!
    var schedule: Schedule!
    var nextClass: Schedule.Meeting?
    var waiter: ScheduleWait!

    
    var state: AppState {
        get { return currentState }
    }
    
    private var entries: [Entry] = []
    
    init(menuBar: MenuBarLabel) {
        Self.main = self
        menuLabel = menuBar
        schedule = Schedule()
        if (schedule != nil) {
            currentState = .Waiting
            nextClass = schedule.nextMeeting()
            menuLabel.update(to: .Waiting, forOperation: nextClass!.course)
            waiter = ScheduleWait(menuLabel: menuBar)
            waiter.ScheduleRecording(meeting: nextClass!)
        } else { menuLabel.update(to: .Idle) }
    }
    
        
    func EntryCompleteCallback(_ entry: Entry){
        entries.removeAll(where: { $0.id == entry.id })
        if(schedule == nil) {
            currentState = .Idle;
            menuLabel.update(to: .Idle)
        } else {
            currentState = .Waiting
            nextClass = schedule.nextMeeting()
            menuLabel.update(to: .Waiting, forOperation: nextClass?.course)
            waiter.ScheduleRecording(meeting: nextClass!)
        }
    }
        
    func AttemptUpdateState(requested: AppState) {
        if(requested == .Record) {
            if(currentState == .Idle || currentState == .Waiting) { // Begin Recording
                print("Starting Recording...")
                currentState = requested
                menuLabel.update(to: .Record)
                entries.append(Entry(destination: nextClass, menuLabel: menuLabel))
                menuLabel.manageTimer()
                
            } else if(currentState == .Record) {
                print("Stopping Recording")
                menuLabel.manageTimer(stop: true)
                Entry.latest.stopRecording()
            }
            
        } else if(requested == .Transcribe) {
            
            if(currentState == .Idle || currentState == .Waiting) {
                let originalState = currentState
                currentState = .Transcribe
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                
                if (panel.runModal() != .OK) { currentState = originalState; return }
                print(panel.url!.absoluteString)
                
                entries.append(Entry(destination: nextClass, withExistingRecording: panel.url!, menuLabel: menuLabel))
              
            } else if(currentState == .Transcribe) {
                Entry.latest.stopTranscription()
            }
            
        }
    }
    
   
    
    
    
    
    
    
   
    
}
