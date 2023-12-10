//
//  Schedule.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 10/25/23.
//

import Foundation

class Schedule: ObservableObject {

    struct Meeting : Codable {
        var title: String
        var startTime: Time
        var duration: Int
        let id = UUID()
        var popover: Bool = false
        var startDate: Date {
            get { Schedule.dateFrom(startTime) }
            set { startTime = Schedule.timeFrom(newValue) }
        }
        var startTimeInMinutes: Int {
                get {(startTime.hour * 60) + startTime.minute}
            }
        
        enum CodingKeys: CodingKey {
                case title, startTime, duration
            }

        func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(title, forKey: .title)
                try container.encode(startTime, forKey: .startTime)
                try container.encode(duration, forKey: .duration)
            }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            title = try! values.decode(String.self, forKey: .title)
            startTime = try! values.decode(Time.self, forKey: .startTime)
            duration = try! values.decode(Int.self, forKey: .duration)
        }
        
        
        init(title: String, startTime: Time, duration: Int, popover: Bool = false) {
            self.title = title
            self.startTime = startTime
            self.duration = duration
            self.popover = popover
        }
        
        static func from(_ data: Data?) -> [[Schedule.Meeting]] {
//            print("init Schedule from \(data)")
            guard data != nil else { return emptySchedule }
            let array = try? JSONDecoder().decode([[Meeting]].self, from: data!)
            return array ?? emptySchedule
        }
        
        static func toData(_ array: [[Schedule.Meeting]]) -> Data {
            guard let data = try? JSONEncoder().encode(array) else { return Self.toData(emptySchedule) }
            return data
        }
        
        
    }
    
    struct Time : Codable, Equatable, Comparable {
        let hour: Int
        let minute: Int
        var absoluteDate: Date?
        
        init(_ h: Int, _ m: Int) {
            hour = h; minute = m
        }
        static func == (t1: Time, t2: Time) -> Bool {
            return t1.hour == t2.hour && t1.minute == t2.minute
        }
        static func < (lhs: Schedule.Time, rhs: Schedule.Time) -> Bool {
            if(lhs.hour != rhs.hour) { return lhs.hour < rhs.hour }
            else { return lhs.minute < rhs.minute}
        }
        
        func relative(_ minutes: Int) -> Self {
                var minute = self.minute; var hour = self.hour
                minute += minutes
//                print("minutes: \(minutes)")
//                print("hour: Int(floor(\(minute) / 60)) (\(hour + (minute / 60))")
//                print("minute: (60 + \(minute) % 60) % 60 (\((60 + minute%60) % 60))")
//                print()
                hour += Int(floor(Double(minute) / 60.0))
                minute = (60 + minute % 60) % 60
                return .init( max(0, min(hour, 23)), max(0, min(60, minute)) )
                }
        
        func inMinutes() -> Int { hour * 60 + minute }
        
    }
        
    @Published var enabledByUser = UserDefaults.standard.bool(forKey: "scheduleEnabled") {
        didSet { UserDefaults.standard.set(enabledByUser, forKey: "scheduleEnabled") }
    }
    
    static func dateFrom(_ time: Schedule.Time) -> Date {
        let dateComponents = DateComponents(year: 0, month: 0, day: 0, hour: time.hour, minute: time.minute)
        return Calendar.current.date(from: dateComponents) ?? .now
    }
    
    static func timeFrom(_ date: Date) -> Schedule.Time {
        let c = Calendar.current
        let h = c.component(.hour, from: date)
        let m = c.component(.minute, from: date)
        return Schedule.Time(h, m)
    }
    
    // TODO: Replace all occurences with this format
    static let main: Schedule = .init()
    
    public static let emptySchedule: [[Schedule.Meeting]] =
    [
        [],
        [],
        [],
        [],
        [],
        [],
        []
    ]
        
    public static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    @Published var schedule = Meeting.from(UserDefaults.standard.data(forKey: "schedule")) /*{
        didSet { UserDefaults.standard.set(Meeting.toData(self.schedule), forKey: "schedule") }
    }*/
    
    var isEmpty: Bool { UserDefaults.standard.data(forKey: "schedule")?.count ?? 22 < 23 }
    
    public func nextMeeting() -> Meeting {
        var res: Meeting!
        var weekday = Calendar.current.dateComponents([.weekday], from: Date.now).weekday! - 1
        let today: [Meeting] = schedule[weekday]
        
        let now = Date.now
        var nextMeeting: Meeting!
        var timeTillMeeting = Double.infinity
        
        for meeting in today {
            let date = Calendar.current.date(bySettingHour: meeting.startTime.hour, minute: meeting.startTime.minute, second: 0, of: now)!
            let interval = date.timeIntervalSince(now)
            if interval < timeTillMeeting && interval > 0 {
                nextMeeting = meeting
                timeTillMeeting = interval
            }
        }
        
        if (nextMeeting != nil) {
            res = nextMeeting!
            res.startTime.absoluteDate =
                Calendar.current.date(bySettingHour: nextMeeting.startTime.hour, minute: nextMeeting.startTime.minute, second: 0, of: now)!
//            res.startTime.relativeInterval = timeTillMeeting
            
        } else { // no meetings left (or at all) for today. Get next meeting in schedule
            for _ in 1...7 {
                weekday = (weekday + 1) % 7
                if !schedule[weekday].isEmpty {
                    res = schedule[weekday].first
                    
                    // get absolute date of meeting
                    var component = DateComponents()
                    component.weekday = weekday+1
                    component.hour = res.startTime.hour
                    component.minute = res.startTime.minute
                    res.startTime.absoluteDate = Calendar.current.nextDate(after: now, matching: component, matchingPolicy: .strict)!
//                    res.startTime.relativeInterval = res.startTime.absoluteDate!.timeIntervalSince(now)
                    break
                }
            }
        }
        return res
    }
}
