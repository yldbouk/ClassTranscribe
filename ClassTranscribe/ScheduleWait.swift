//
//  ScheduleWait.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/30/23.
//

import Foundation
import UserNotifications

class ScheduleWait {
    let menuLabel = MenuBarLabel.main
    var meeting: Schedule.Meeting
    var queue: [Timer] = []
    var recordingWillStartNotificationID: String?
    private static var _self: ScheduleWait?
    public static var main: ScheduleWait {
        get { return _self! }
    }
    
    init(_ meeting: Schedule.Meeting) {
        self.meeting = meeting
        Self._self = self
        ScheduleRecording(meeting)
        
    }
    
    func updateMenuIcon(_ text: String) {
//        print("[ScheduleWait] Updating menu icon to \(text)")
        DispatchQueue.main.async {
            self.menuLabel.update(to: .Waiting, percentage: text, forOperation: self.meeting.course)
        }
    }
    
    func cancelScheduledRecording(){
        DispatchQueue.main.async { [self] in
            for timer in queue { timer.invalidate() }
            queue.removeAll()
        }
    }
    
    
    func rescheduleRecording(){
        guard queue.count > 0 else { return } // not waiting for anything
        print("[ScheduleWait] Rescheduling Timers for next meeting")
        DispatchQueue.main.async { [self] in
            for timer in queue { timer.invalidate() }
            queue.removeAll()
            if Date.now.timeIntervalSince(meeting.startsAt.absoluteDate!) > 0 {
                // TODO: Add a (maybe 5 min) window where the meeting still starts
                meeting = Schedule.main.nextMeeting()
            }
            ScheduleRecording(meeting)
        }
    }
    
    func ScheduleRecording(_ meeting: Schedule.Meeting) {
        var currentDate = Date.now
        var relativeInterval = meeting.startsAt.absoluteDate!.timeIntervalSince(currentDate)
        
        // DEBUG OVERRIDE
        let d = DateFormatter()
        d.dateFormat = "yyyy-MM-dd HH:mm"
        relativeInterval = d.date(from: "2023-11-11 11:00")!.timeIntervalSince(currentDate)
        
        var seconds = Int(relativeInterval)
        var alignSeconds: Int = 0
        let alignSubSecond = relativeInterval.truncatingRemainder(dividingBy: 1)
        var hr = seconds / 3600
        
        print("[ScheduleWait] Waiting till \(meeting.startsAt.absoluteDate!.description), which is in \(seconds) seconds.")

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
        else if (seconds >= 900) { label = String(seconds / 60 + 1) + " mins" }
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
            queue.append(Timer(fire: currentDate, interval: 86400, repeats: true) { timer in
                self.updateMenuIcon("\(loopDays) \(loopDays == 1 ? "day" : "days")")
                loopDays -= 1
                if(loopDays < 1) { timer.invalidate() }
            })
            currentDate.addTimeInterval(Double(loopDays) * 86400)
        }
        if(loopAlignDay != 0) {
            print("[ScheduleWait] aligning by waiting \(loopAlignDay) hours")
            currentDate.addTimeInterval(Double(loopAlignDay * 3600))
        }
        if(loopHours != 0) {
            print("[ScheduleWait] waiting \(loopHours) hours starting at \(currentDate.description(with: .current))")
            queue.append(Timer(fire: currentDate, interval: 3600, repeats: true) { timer in
                    self.updateMenuIcon("\(loopHours) hours")
                loopHours -= 1
                if loopHours < 1 { timer.invalidate() }
                })
            currentDate.addTimeInterval(Double(loopHours) * 3600)
        }
        if (loopMinutes != 0) {
            print("[ScheduleWait] waiting \(loopMinutes) minutes starting at \(currentDate.description(with: .current))")
            queue.append(Timer(fire: currentDate, interval: 60, repeats: true) { timer in
                self.updateMenuIcon("\(15+loopMinutes) mins")
                loopMinutes -= 1
                if loopMinutes < 1 { timer.invalidate() }
            })
            currentDate.addTimeInterval(Double(loopMinutes) * 60)
        }
        queue.append(Timer(fire: currentDate, interval: 0, repeats: false) { timer in
            if self.recordingWillStartNotificationID == nil {
                self.recordingWillStartNotificationID = AppDelegate.sendRecordingAutoStartNotification(meeting: meeting.course)
            }
            print("[ScheduleWait] waiting \(loopSeconds) seconds")
            loopSeconds -= 1 // TODO: check why it's off by 1
            self.queue.append(Timer(timeInterval: 1, repeats: true){timer in
                self.updateMenuIcon(String(format: "%d:%02d", loopSeconds / 60, loopSeconds % 60))
                loopSeconds-=1
                if loopSeconds <= 0 {
                    print("[ScheduleWait] wait complete")
                    timer.invalidate()
                }
            })
            DispatchQueue.main.async {
                print("[ScheduleWait] enqueuing seconds timer")
                RunLoop.main.add(self.queue.last!, forMode: .common) }
        })
        currentDate.addTimeInterval(Double(loopSeconds))
        print("[ScheduleWait] Will start recording at \(currentDate.description(with: .current))")
        queue.append(Timer(fire: currentDate, interval: 0, repeats: false) { timer in
            DispatchQueue.main.async { self.queue.removeAll() }
            if (Control.main.state == .Waiting) {
                let recordingStartedNotificationID = AppDelegate.sendRecordingAutoStartNotification(true, meeting: meeting.course, oldID: self.recordingWillStartNotificationID)
                print("[ScheduleWait] Requesting to start recording...")
                DispatchQueue.main.async {
                    Control.main.AttemptUpdateState(requested: .Record, notificationID: recordingStartedNotificationID)
                }
            }
            print()
        })
        DispatchQueue.main.async {
            print("[ScheduleWait] Enqueuing \(self.queue.count) Timers")
            for timer in self.queue { RunLoop.main.add(timer, forMode: .common) }
        }
    }
}
