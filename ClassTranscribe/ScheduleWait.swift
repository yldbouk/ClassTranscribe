//
//  ScheduleWait.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/30/23.
//

import Foundation
import UserNotifications

class ScheduleWait {
    let queue = DispatchQueue(label: "me.yldbouk.schedulequeue", qos: .utility)
    let menuLabel: MenuBarLabel
    var meetingName: String!

    init(menuLabel: MenuBarLabel) {
        self.menuLabel = menuLabel
    }
    
    func updateMenuIcon(_ text: String) {
        print("[ScheduleWait] Updating menu icon to \(text)")
        DispatchQueue.main.async {
            self.menuLabel.update(to: .Waiting, percentage: text, forOperation: self.meetingName)
//            self.menuLabel.labels.icon.text = text
//            self.menuLabel.labels.status = "Waiting For Class... \(text) remain"
        }
    }
    
    
    
    func ScheduleRecording(meeting: Schedule.Meeting) {
        meetingName = meeting.course
        var seconds = Int(meeting.startsAt.relativeSeconds!)
        
//        var currentTime =
//        var seconds = Int(target! - Date.now.timeIntervalSince1970)
        
        var alignSeconds: Int = 0
        let alignMilliseconds = meeting.startsAt.relativeSeconds!.truncatingRemainder(dividingBy: 1)
        
        var hr = (seconds) / 3600
        
        var loopDays = 0
        var loopAlignDay = 0
        var loopHours = 0
        var loopMinutes = 0
        var loopSeconds = 900
        
        if(hr > 24) { alignSeconds = seconds % 86400 }
        else if (hr > 1) { alignSeconds = seconds % 3600 }
        else if(seconds > 900) { alignSeconds = seconds % 60 }
        
        seconds -= alignSeconds
        hr = seconds / 3600
        
        var label = ""
        
        if(hr >= 24) { label = String(ceil(Double(seconds) / 86400.0)) + (hr > 48 ? " days" : " day") }
        else if (hr > 12) { label = "1 day" }
        else if (hr >= 1) { label = String(hr) + (hr != 1 ? " hrs" : " hr") }
        else if (seconds > 900) { label = String(ceil(Double(seconds) / 60.0)) + " mins" }
        else { label = String(format: "%d:%02d", seconds / 60, seconds % 60) }

        if(hr > 24) {
            loopDays = seconds / 86400 - 1
            loopAlignDay = 11
            loopHours = 12
            loopMinutes = 45
        } else if(hr > 12) {
            loopAlignDay = hr - 13
            loopHours = 12
            loopMinutes = 45
        } else if(hr > 1) {
            loopHours = hr - 1
            loopMinutes = 45
        } else if(seconds > 15*60) {
            loopMinutes = seconds/60 - 15
        } else {
            loopSeconds = seconds
        }
        
        // start adding to queue
        
        updateMenuIcon(label)
        
        if(alignSeconds != 0) {
            queue.async {
//                currentTime += alignSeconds
                print("[ScheduleWait] waiting \(alignSeconds) seconds")
                Thread.sleep(forTimeInterval: Double(alignSeconds) - (1-alignMilliseconds))
            }
        }
        if(loopDays != 0) {
            queue.async {
                print("[SheduleWait] waiting \(loopDays) days ")
                while loopDays > 0 {
                    Thread.sleep(forTimeInterval: 86400)
//                    currentTime += 86400
                    self.updateMenuIcon("\(loopDays) \(loopDays == 1 ? "day" : "days")")
                    loopDays -= 1
                }
            }
        }
        if(loopAlignDay != 0) {
            queue.async {
                print("[ScheduleWait] aligning by waiting \(loopAlignDay) hours")
//                currentTime += loopAlignDay * 3600
                Thread.sleep(forTimeInterval: Double(loopAlignDay*3600))
                // no need for updating the icon
            }
        }
        if(loopHours != 0) {
            queue.async {
                print("[ScheduleWait] waiting \(loopHours) hours")
                while loopHours > 0 {
//                    currentTime += 3600
                    Thread.sleep(forTimeInterval: 3600)
                    self.updateMenuIcon("\(loopHours) hours")
                    loopHours -= 1
                }
            }
        }
        if (loopMinutes != 0) {
            queue.async {
                print("[ScheduleWait] waiting \(loopMinutes) minutes")
                while loopMinutes > 0 {
//                    currentTime += 60
                    Thread.sleep(forTimeInterval: 60)
                    self.updateMenuIcon("\(14+loopMinutes) mins")
                    loopMinutes -= 1
                }
            }
        }
        queue.async {
            
            // notify user
            let content = UNMutableNotificationContent()
            content.title = "\(meeting.course) Meeting Soon"
            content.body = "Your course is meeting soon."
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { (error) in
               if error != nil { print("ERROR with notification warn: \(error!)") }
            }
            
            print("[ScheduleWait] waiting \(seconds) seconds")
            while loopSeconds+1 > 0 {
                Thread.sleep(forTimeInterval: 1)
                self.updateMenuIcon(String(format: "%d:%02d", loopSeconds / 60, loopSeconds % 60))
                loopSeconds -= 1
            }
        }
        queue.async {
            print("[ScheduleWait] waiting complete.", terminator: " ")
            if (Control.main.state == .Waiting) {
                
                // notify user that the recording is starting
                let content = UNMutableNotificationContent()
                content.title = "Recording Started for \(meeting.course)"
                content.body = "The recording has started for this course."
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { (error) in
                   if error != nil { print("ERROR with notification alert: \(error!)") }
                }
                
                print("Requesting to start recording...")
                DispatchQueue.main.async {
                    Control.main.AttemptUpdateState(requested: .Record)
                }
            }
            print()
        }
    }
}
