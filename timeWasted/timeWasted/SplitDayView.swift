//
//  SplitDayView.swift
//  timeWasted
//
//  Created by Ann Hsu on 4/8/26.
//

import SwiftUI

// MARK: - Constants

private enum GridConstants {
    static let startHour: Int = 6       // 6 AM
    static let endHour: Int = 22        // 10 PM
    static let totalHours: Int = endHour - startHour // 16 hours
    static let hourHeight: CGFloat = 80
    static let totalHeight: CGFloat = CGFloat(totalHours) * hourHeight
    static let timeGutterWidth: CGFloat = 52
    static let columnSpacing: CGFloat = 8
    static let hourIndices: [Int] = (0...totalHours).map { $0 }
}

// MARK: - SplitDayView

struct SplitDayView: View {
    @ObservedObject var eventKitManager: EventKitManager
    @ObservedObject var logStore: TimeLogStore
    @Binding var activeLog: TimeLog?
    @Binding var activeTimerDate: Date

    var body: some View {
        GeometryReader { geo in
            let columnWidth = (geo.size.width - GridConstants.timeGutterWidth - GridConstants.columnSpacing * 3) / 2

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Time grid lines and labels
                    timeGrid

                    // Column headers
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: GridConstants.timeGutterWidth)

                            Text("PLANNED")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: columnWidth, alignment: .center)
                                .padding(.leading, GridConstants.columnSpacing)

                            Text("ACTUAL")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: columnWidth, alignment: .center)
                                .padding(.leading, GridConstants.columnSpacing)
                        }
                        .padding(.bottom, 4)

                        // Planned + Actual columns
                        HStack(alignment: .top, spacing: 0) {
                            Spacer()
                                .frame(width: GridConstants.timeGutterWidth)

                            // Left: Planned events
                            ZStack(alignment: .topLeading) {
                                Color.clear
                                    .frame(width: columnWidth, height: GridConstants.totalHeight)

                                if eventKitManager.events.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray.opacity(0.4))
                                        Text("No events today")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gray.opacity(0.5))
                                        Text("Add events in Calendar\nor grant permission")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray.opacity(0.35))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: columnWidth)
                                    .padding(.top, 80)
                                }

                                ForEach(eventKitManager.events) { event in
                                    PlannedEventBlock(
                                        event: event,
                                        columnWidth: columnWidth,
                                        onTap: {
                                            startLogging(event: event)
                                        }
                                    )
                                }
                            }
                            .padding(.leading, GridConstants.columnSpacing)

                            // Column divider
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 1, height: GridConstants.totalHeight)

                            // Right: Actual logs
                            ZStack(alignment: .topLeading) {
                                Color.clear
                                    .frame(width: columnWidth, height: GridConstants.totalHeight)

                                // Completed logs
                                ForEach(logStore.logsForToday().filter { $0.actualEnd != nil }) { log in
                                    CompletedLogBlock(log: log, columnWidth: columnWidth)
                                }

                                // Active log (growing in real time)
                                if let log = activeLog {
                                    ActiveLogBlock(
                                        log: log,
                                        currentTime: activeTimerDate,
                                        columnWidth: columnWidth
                                    )
                                }
                            }
                            .padding(.leading, GridConstants.columnSpacing)
                        }
                        .padding(.top, 20)
                    }

                    // Now indicator line
                    nowIndicator(totalWidth: geo.size.width)
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Now Indicator

    private func nowIndicator(totalWidth: CGFloat) -> some View {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let hoursFromStart = CGFloat(hour - GridConstants.startHour) + CGFloat(minute) / 60.0
        let yOffset = max(0, hoursFromStart * GridConstants.hourHeight) + 20

        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: GridConstants.timeGutterWidth - 4)

            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(height: 1)
        }
        .offset(y: yOffset)
    }

    // MARK: - Time Grid

    private var timeGrid: some View {
        ZStack(alignment: .topLeading) {
            ForEach(GridConstants.hourIndices, id: \.self) { i in
                let hour: Int = GridConstants.startHour + i
                let yOffset: CGFloat = CGFloat(i) * GridConstants.hourHeight + 20

                HStack(spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.gray)
                        .frame(width: GridConstants.timeGutterWidth - 8, alignment: .trailing)
                        .padding(.trailing, 8)

                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(height: 1)
                }
                .offset(y: yOffset)
            }
        }
        .frame(height: GridConstants.totalHeight + 40)
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return "\(h) \(period)"
    }

    private func startLogging(event: CalendarEvent) {
        guard activeLog == nil else { return }

        let (r, g, b, a) = eventKitManager.colorComponents(for: event)

        let log = TimeLog(
            id: UUID().uuidString,
            eventId: event.id,
            eventTitle: event.title,
            plannedStart: event.startTime,
            plannedEnd: event.endTime,
            actualStart: Date(),
            actualEnd: nil,
            colorR: r,
            colorG: g,
            colorB: b,
            colorA: a
        )
        activeLog = log
    }
}

// MARK: - Planned Event Block

private struct PlannedEventBlock: View {
    let event: CalendarEvent
    let columnWidth: CGFloat
    let onTap: () -> Void

    var body: some View {
        let yOffset = yPosition(for: event.startTime)
        let height = blockHeight(from: event.startTime, to: event.endTime)

        RoundedRectangle(cornerRadius: 10)
            .fill(event.color.opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(timeRangeString(event.startTime, event.endTime))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6),
                alignment: .topLeading
            )
            .frame(width: columnWidth, height: max(height, 28))
            .offset(y: yOffset)
            .onTapGesture { onTap() }
            .shadow(color: event.color.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Completed Log Block

private struct CompletedLogBlock: View {
    let log: TimeLog
    let columnWidth: CGFloat

    var body: some View {
        let yOffset = yPosition(for: log.actualStart)
        let height = blockHeight(from: log.actualStart, to: log.actualEnd ?? log.actualStart)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(log.color.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(log.eventTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let end = log.actualEnd {
                    Text(timeRangeString(log.actualStart, end))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Delta badge
            if let delta = log.deltaMinutes {
                DeltaBadge(deltaMinutes: delta)
                    .offset(x: columnWidth - 64, y: max(height, 28) - 24)
            }
        }
        .frame(width: columnWidth, height: max(height, 28))
        .offset(y: yOffset)
        .shadow(color: log.color.opacity(0.25), radius: 4, y: 2)
    }
}

// MARK: - Active Log Block (growing in real time)

private struct ActiveLogBlock: View {
    let log: TimeLog
    let currentTime: Date
    let columnWidth: CGFloat

    @State private var pulse = false

    var body: some View {
        let yOffset = yPosition(for: log.actualStart)
        let height = blockHeight(from: log.actualStart, to: currentTime)

        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                log.color,
                style: StrokeStyle(lineWidth: 2.5, dash: [8, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(log.color.opacity(pulse ? 0.15 : 0.08))
            )
            .overlay(
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.eventTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(log.color)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .opacity(pulse ? 1.0 : 0.3)

                        Text("Recording…")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6),
                alignment: .topLeading
            )
            .frame(width: columnWidth, height: max(height, 36))
            .offset(y: yOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Delta Badge

private struct DeltaBadge: View {
    let deltaMinutes: Int

    private var badgeText: String {
        if deltaMinutes == 0 { return "On time" }
        let abs = abs(deltaMinutes)
        return deltaMinutes < 0 ? "\(abs)m early" : "\(abs)m over"
    }

    private var badgeColor: Color {
        deltaMinutes <= 0 ? .green : .red
    }

    private var badgeIcon: String {
        if deltaMinutes == 0 { return "checkmark" }
        return deltaMinutes < 0 ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: badgeIcon)
                .font(.system(size: 8, weight: .bold))
            Text(badgeText)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.9))
                .shadow(color: badgeColor.opacity(0.4), radius: 3, y: 1)
        )
    }
}

// MARK: - Global Layout Helpers

/// Computes the Y position for a given time on the grid.
private func yPosition(for date: Date) -> CGFloat {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let hoursFromStart = CGFloat(hour - GridConstants.startHour) + CGFloat(minute) / 60.0
    return max(0, hoursFromStart * GridConstants.hourHeight)
}

/// Computes the block height between two times.
private func blockHeight(from start: Date, to end: Date) -> CGFloat {
    let duration = end.timeIntervalSince(start)
    let hours = CGFloat(duration) / 3600.0
    return max(0, hours * GridConstants.hourHeight)
}

/// Formats a time range like "9:00–10:30"
private func timeRangeString(_ start: Date, _ end: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm"
    return "\(f.string(from: start))–\(f.string(from: end))"
}
