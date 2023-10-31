//
//  Schedule.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/25/23.
//

import Foundation

class Schedule {
    struct Meeting : Codable {
        let course: String
        var startsAt: Time
        let duration: Int
    }
    struct Time : Codable, Equatable {
        let hour: Int
        let minute: Int
        var relativeSeconds: Double?
        
        static func == (t1: Time, t2: Time) -> Bool {
            return t1.hour == t2.hour && t1.minute == t2.minute
            }
    }
    
    private var schedule: [[Meeting]]!
    
    init?() {
        schedule = loadScheduleFromFile()
        if schedule == nil { return nil }
    }

    func loadScheduleFromFile() -> [[Meeting]]? {
        let appsupport = FileManager.default.urls(for:.applicationSupportDirectory, in: .userDomainMask).first
        let url: URL = appsupport!.appending(path: "ClassTranscribe/schedule.json")
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([[Meeting]].self, from: data)
        } catch {
            print("\n\nERROR: \(error)")
        }
        return nil
    }
    
    public func nextMeeting() -> Meeting {
        var res: Meeting!
        var weekday = Calendar.current.dateComponents([.weekday], from: Date.now).weekday! - 1
        let today: [Meeting] = schedule![weekday]
        
        let now = Date.now
        var nextMeeting: Meeting!
        var timeTillMeeting = 0.0 // should this be 0?
        
        for meeting in today {
            let date = Calendar.current.date(bySettingHour: meeting.startsAt.hour, minute: meeting.startsAt.minute, second: 0, of: now)!
            let interval = date.timeIntervalSince(now)
            if interval > timeTillMeeting {
                nextMeeting = meeting
                timeTillMeeting = interval
            }
        }
        
        if (nextMeeting != nil) {
            res = nextMeeting!
            res.startsAt.relativeSeconds = timeTillMeeting
        } else { // no meetings left (or at all) for today. Get next meeting in schedule
            for i in 1...7 {
                weekday = (weekday + i) % 7
                if !schedule[weekday].isEmpty {
                    res = schedule[weekday].first
                    
                    // get relative time till meeting
                    var component = DateComponents()
                    component.weekday = weekday+1
                    component.hour = res.startsAt.hour
                    component.minute = res.startsAt.minute
                    let date = Calendar.current.nextDate(after: now, matching: component, matchingPolicy: .strict)!
                    res.startsAt.relativeSeconds = date.timeIntervalSince(now)
                    break
                }
            }
        }
        return res
    }
}