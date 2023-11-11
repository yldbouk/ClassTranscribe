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
//        print("[ScheduleWait] Updating menu icon to \(text)")
        DispatchQueue.main.async {
            self.menuLabel.update(to: .Waiting, percentage: text, forOperation: self.meetingName)
        }
    }
    
    
    
    func ScheduleRecording(meeting: Schedule.Meeting) {
        meetingName = meeting.course
        
        // DEBUG OVERRIDE
//        var meeting = meeting
//        let d = DateFormatter()
//        d.dateFormat = "yyyy-MM-dd HH:mm"
//        meeting.startsAt.relativeSeconds = d.date(from: "2023-11-08 14:37")!.timeIntervalSince(Date.now)
        
        var currentDate = Date.now
        var seconds = Int(meeting.startsAt.relativeSeconds!)
        var alignSeconds: Int = 0
        let alignSubSecond = meeting.startsAt.relativeSeconds!.truncatingRemainder(dividingBy: 1)
        var hr = seconds / 3600
        
        print("[ScheduleWait] Waiting till \(meeting.startsAt), which is in \(seconds) seconds.")

        var loopDays = 0
        var loopAlignDay = 0
        var loopHours = 0
        var loopMinutes = 0
        var loopSeconds = 900
        
        if(hr > 24) { alignSeconds = seconds % 86400 }
        else if (hr > 0) { alignSeconds = seconds % 3600 }
        else if(seconds > 900) { alignSeconds = seconds % 60 }
        
        seconds -= alignSeconds
        hr = seconds / 3600
        
        var label = ""
        
        if(hr >= 24) { label = String(ceil(Double(seconds) / 86400.0)) + (hr > 48 ? " days" : " day") }
        else if (hr > 12) { label = "1 day" }
        else if (hr >= 1) { label = String(hr) + (hr != 1 ? " hrs" : " hr") }
        else if (seconds > 900) { label = String(seconds / 60 + 1) + " mins" }
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
            print("[ScheduleWait] aligning by waiting \(alignSeconds) seconds")
            currentDate.addTimeInterval(Double(alignSeconds) + alignSubSecond)
        }
        if(loopDays != 0) {
            print("[ScheduleWait] waiting \(loopDays) days starting at \(currentDate.description(with: .current))")
                let timer = Timer(fire: currentDate, interval: 86400, repeats: true) {timer in
                    self.updateMenuIcon("\(loopDays) \(loopDays == 1 ? "day" : "days")")
                    loopDays -= 1
                    if(loopDays < 1) { timer.invalidate() }
//                }
            }
            currentDate.addTimeInterval(Double(loopDays) * 86400)
            RunLoop.current.add(timer, forMode: .common)
        }
        if(loopAlignDay != 0) {
            print("[ScheduleWait] aligning by waiting \(loopAlignDay) hours")
            currentDate.addTimeInterval(Double(loopAlignDay * 3600))
        }
        if(loopHours != 0) {
            print("[ScheduleWait] waiting \(loopHours) hours starting at \(currentDate.description(with: .current))")
            let timer = Timer(fire: currentDate, interval: 3600, repeats: true) { timer in
                    self.updateMenuIcon("\(loopHours) hours")
                loopHours -= 1
                if loopHours < 1 { timer.invalidate() }
                }
            currentDate.addTimeInterval(Double(loopHours) * 3600)
            RunLoop.current.add(timer, forMode: .common)
        }
        if (loopMinutes != 0) {
            print("[ScheduleWait] waiting \(loopMinutes) minutes starting at \(currentDate.description(with: .current))")
            let timer = Timer(fire: currentDate, interval: 60, repeats: true) { timer in
                self.updateMenuIcon("\(15+loopMinutes) mins")
                loopMinutes -= 1
                if loopMinutes < 1 { timer.invalidate() }
            }
            currentDate.addTimeInterval(Double(loopMinutes) * 60)

//            }
            RunLoop.current.add(timer, forMode: .common)
        }
            AppDelegate.sendRecordingAutoStartNotification(meeting: meeting.course)
            print("[ScheduleWait] waiting \(loopSeconds) seconds")
            loopSeconds -= 1 // TODO: check why it's off by 1
            let timer = Timer(timeInterval: 1, repeats: true){timer in
                self.updateMenuIcon(String(format: "%d:%02d", loopSeconds / 60, loopSeconds % 60))
                loopSeconds-=1
                if loopSeconds <= 0 {
                    print("[ScheduleWait] wait complete")
                    timer.invalidate()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
        currentDate.addTimeInterval(Double(loopSeconds))
        print("[ScheduleWait] Will start recording at \(currentDate.description(with: .current))")
        RunLoop.current.schedule(after: .init(currentDate))  {
            if (Control.main.state == .Waiting) {
                print("Requesting to start recording...")
                DispatchQueue.main.async {
                    Control.main.AttemptUpdateState(requested: .Record)
                }
            }
            print()
        }
    }
}
