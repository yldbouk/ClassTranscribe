//
//  AppDelegate.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 11/9/23.
//

import Foundation
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main){ notification in
            ScheduleWait.main.rescheduleRecording()
        }
        
        UNUserNotificationCenter.current().requestAuthorization() { granted, error in
            if (!granted) {
                print("User did not grant notification permisison: \(error!)")
            }
        }
    }
    
    static func sendRecordingAutoStartNotification(_ ofStarting: Bool = false, meeting: String) {
        let content = UNMutableNotificationContent()
        if ofStarting {
            content.title = "Recording Started for \(meeting)"
            content.body = "The recording has started for this course."
        } else {
            content.title = "\(meeting) Meeting Soon"
            content.body = "Your course is meeting soon."
        }
        print("Notifying user: \(content.title)")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
