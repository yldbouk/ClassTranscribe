//
//  ScheduleView.swift
//  ClassTranscribe
//
//  Created by Youssef Dbouk on 11/20/23.
//

import Foundation
import SwiftUI


struct ScheduleView: View {
    
    @StateObject var schedule = Schedule.main
    
    static let hourHeight = 70.0
    @State var dragging = false
    
    var body: some View {
        VStack(alignment: .leading) {
            dayLabels()
            
            ScrollViewReader { scroll in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hourDividers()
                        dayDividers()
                        clickListener()
                            .offset(y: ScheduleView.hourHeight / 8)  // accounting for hour divider padding
                        
                        // Schedule.Meetings
                        HStack(spacing: 0) {
                            ForEach(schedule.schedule.indices, id: \.self) { day in
                                ZStack {
                                    // add an empty view so the column still exists when no events occur that day
                                    EmptyEventCell()
                                    
                                    ForEach(schedule.schedule[day], id: \.id) { event in
                                        EventCell(day, event)
                                    }
                                }
                            }
                        }
                    }
                }.onAppear { scroll.scrollTo(8, anchor: .top) } // scroll to 8:00AM; TODO: scroll to first event (before 8AM?)
            }
        }
    }
        
        struct dayDividers: View {
            var body: some View {
                HStack(alignment: .center, spacing: 0) {
                    Spacer()
                    ForEach(0..<6) { _ in
                        Color.gray.frame(width: 1, alignment: .trailing)
                        Spacer()
                    }
                }
            }
        }
        
        struct dayLabels: View {
            // to allow custom week start day, all i's must be + offset % 7
            let weekdays = ["S", "M", "T", "W", "R", "F", "S"]
            var body: some View {
                HStack {
                    Spacer()
                    ForEach(0..<6) { label in
                        Text(weekdays[label])
                        Spacer()
                        Spacer()
                    }
                    Text(weekdays.last!)
                    Spacer()
                }
            }
        }
        
        func hourDividers() -> some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<24) { hour in
                    let label = (hour % 12 == 0) ? ("12\(hour > 11 ? "p" : "a")") : ("\(hour%12)")
                    
                    HStack {
                        Text(label)
                            .font(.caption2)
                            .frame(alignment: .trailing)
                            .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
                            .id(hour)
                        Color.gray
                            .frame(height: 1)
                            .offset(x: -5)
                    }
                    .frame(height: ScheduleView.hourHeight)
                    // .border(.green)
                    .offset(y: -(3 * ScheduleView.hourHeight / 8))
                }
            }
        }
        
        func clickListener() -> some View {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<96) { quarterhour in
                    GridRow {
                        ForEach(0..<7) { day in
                            Rectangle().opacity(0.001)
                                .onTapGesture(count: 2) {  // create new event
                                    let start = (quarterhour / 4, quarterhour % 4 * 15)
                                    print("Creating New Meeting: \(Schedule.weekdayNames[day]) at \(start.0):\(start.1)")
                                    
                                    let event = Schedule.Meeting(
                                        title: "New Meeting",
                                        startTime: Schedule.Time(start.0, start.1),
                                        duration: min(60, determineMaximumDuration(quarterhour*15, forDay: day)),
                                        popover: true
                                    )
                                    schedule.schedule[day].append(event)
                                    ScheduleWait.main.scheduleChanged()
                                }
                                .gesture( // create an event by dragging
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if !dragging {
                                                let start = (quarterhour / 4, quarterhour % 4 * 15)
                                                
                                                print("Creating New Meeting: \(Schedule.weekdayNames[day]) at \(start.0):\(start.1)")
                                                
                                                let event = Schedule.Meeting(
                                                    title: "New Meeting", 
                                                    startTime: Schedule.Time(start.0, start.1),
                                                    duration: 0
                                                )
                                                schedule.schedule[day].append(event)
                                            }
                                            dragging = true
                                            let maxDuration = determineMaximumDuration(quarterhour * 15, forDay: day)
                                            let newDuration = Int(value.location.y / (ScheduleView.hourHeight / 4)) * 15
                                            schedule.schedule[day][schedule.schedule[day].count - 1].duration = min(max(newDuration, 15), maxDuration)
                                        }
                                        .onEnded { _ in
                                            guard dragging else { return }
                                            ScheduleWait.main.scheduleChanged()
                                            
                                            schedule.schedule[day][schedule.schedule[day].count - 1].popover = true
                                            
                                            dragging = false
                                        })
                        }
                    }
                }
            }
        }
       
    struct EventCell: View {
        enum Keys: Int { case title, startDate, duration, popover, remove }
        @ObservedObject var schedule = Schedule.main
        @State var title: String
        @State var startDate: Date
        let id: UUID
        var duration: Int
        @State var trueDuration: Int
        @State var popover: Bool = false
        let shouldPopover: Bool
        let day: Int
        let startOffset: Double
        
        init(
            _ day: Int,
            _ event: Schedule.Meeting
        ) {
            self.day = day
            self._title = State.init(initialValue: event.title)
            self.id = event.id
            self._startDate = State.init(initialValue: event.startDate)
            self.duration = event.duration
            self._trueDuration = State.init(initialValue: self.duration)
            self.shouldPopover = event.popover
            
            startOffset = (Double(Calendar.current.component(.hour, from: event.startDate)) * hourHeight) + 
                (hourHeight * (Double(Calendar.current.component(.minute, from: event.startDate)) / 60))
        }
        
        func determineMaximumDuration(_ startTime: Int, forDay: Int) -> Int {
            
            let daySorted = schedule.schedule[forDay].sorted(by: { $0.startTimeInMinutes < $1.startTimeInMinutes })
            let nextEvent = daySorted.first(where: { $0.startTimeInMinutes > startTime })
            return max(15, (nextEvent?.startTimeInMinutes ?? 1440) - startTime)
            
        }
        
        func presentPopover() { popover = true; didChange(.popover) }
        
        func didChange(_ key: Keys) {
            let i = schedule.schedule[day].firstIndex(where: {$0.id == id})!
            switch key {
            case .title:
                schedule.schedule[day][i].title = title
                break
            case .startDate:
                schedule.schedule[day][i].startDate = startDate
                break
            case .duration:
                schedule.schedule[day][i].duration = trueDuration
                break
            case .popover:
                schedule.schedule[day][i].popover = false
                break
            case .remove:
                print("\n\nDeleting event \(id) on day \(day)")
                schedule.schedule[day].remove(at: i)
            }
        }
        
        var popoverContent: some View {
            VStack {
                TextField("", text: $title)
                    .font(.headline)
                    .frame(alignment: .topLeading)
                    .labelsHidden()
                    .onChange(of: title) { didChange(.title) }
                
                 DatePicker(
                     "Start",
                     selection: $startDate,
                     displayedComponents: [.hourAndMinute]
                 )
                 .onChange(of: startDate) { didChange(.startDate) }

                Stepper(
                    "Duration: \(duration) mins",
                    value: $trueDuration,
                    in: 15...determineMaximumDuration((Calendar.current.component(.hour, from: startDate) * 60) + Calendar.current.component(.minute, from: startDate), forDay: day),
                    step: 5
                )
                .onChange(of: trueDuration) { didChange(.duration) }

                Divider()
                
                Button("Delete", role: .destructive) { didChange(.remove) }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
            .padding(10)
            .onDisappear {
                ScheduleWait.main.scheduleChanged()
            }
        }
        
        var body: some View {
            VStack(alignment: .leading) {
                // Text("\(event.startTime.0):\(event.startTime.1)")
                Text(title)
                    .bold()
                    .padding(.leading, 5)
                    .frame(alignment: .topLeading)
                
            }
            .onAppear { if shouldPopover { presentPopover() }}
            .onChange(of: shouldPopover) { presentPopover() }
            .onChange(of: duration){ trueDuration = duration }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(0)
            .frame(height: Double(duration) / 60 * hourHeight, alignment: .top)
            
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary).opacity(0.5)
            )
            .padding(.horizontal, 1)
            //        .border(.red)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .onTapGesture { popover = true }
            .popover(isPresented: $popover) { popoverContent }
            .offset(x: 0, y: startOffset + (hourHeight / 8)) // accounting for hour label padding
        }
        
    }
        
    
    struct EmptyEventCell: View {
        var body: some View {
            VStack(alignment: .leading) {
                // Text("\(event.startTime.0):\(event.startTime.1)")
                Text("")
                    .bold()
                    .padding(.leading, 5)
                    .frame(alignment: .topLeading)
                
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(0)
            .frame(height: 0, alignment: .top)
            
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary).opacity(0.5)
            )
            .padding(.horizontal, 1)
            //        .border(.red)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }
        
        
        
    func determineMaximumDuration(_ startTime: Int, forDay: Int) -> Int {
        
        let daySorted = schedule.schedule[forDay].sorted(by: { $0.startTimeInMinutes < $1.startTimeInMinutes })
        let nextEvent = daySorted.first(where: { $0.startTimeInMinutes > startTime })
        return max(15,(nextEvent?.startTimeInMinutes ?? 1440) - startTime)
        
    }
}
