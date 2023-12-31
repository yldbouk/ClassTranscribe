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
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main){ _ in
            ScheduleWait.main.rescheduleRecording()
        }
    
        Microphone.getPermission()
            
        UNUserNotificationCenter.current().requestAuthorization() { granted, error in
            if (!granted) {
                print("User did not grant notification permisison: \(error!)")
            }
        }
    }
    
    static func removeNotification(_ id: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
    
    static func sendRecordingAutoStartNotification(_ ofStarting: Bool = false, meeting: String, oldID: String? = nil) -> String {
        if oldID != nil { removeNotification(oldID!) }
        let content = UNMutableNotificationContent()
        if ofStarting {
            content.title = "Recording Started for \(meeting)"
            content.body = "The recording has started for this course."
        } else {
            content.title = "\(meeting) Meeting Soon"
            content.body = "Your course is meeting soon."
        }
        print("Notifying user: \(content.title)")
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        return identifier
    }
}
