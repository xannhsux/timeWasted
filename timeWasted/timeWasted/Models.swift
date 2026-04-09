//
//  Models.swift
//  timeWasted
//
//  Created by Ann Hsu on 4/8/26.
//

import SwiftUI

// MARK: - CalendarEvent

/// Represents a planned event pulled from Apple Calendar via EventKit.
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let color: Color
}

// MARK: - TimeLog

/// Represents an actual logged session for a planned event.
struct TimeLog: Identifiable, Codable, Equatable {
    let id: String
    let eventId: String
    let eventTitle: String
    let plannedStart: Date
    let plannedEnd: Date
    let actualStart: Date
    var actualEnd: Date?

    /// The delta in minutes between actual duration and planned duration.
    /// Negative means finished early, positive means ran over.
    var deltaMinutes: Int? {
        guard let actualEnd = actualEnd else { return nil }
        let actualDuration = actualEnd.timeIntervalSince(actualStart)
        let plannedDuration = plannedEnd.timeIntervalSince(plannedStart)
        return Int((actualDuration - plannedDuration) / 60.0)
    }

    /// Color of the event — stored as RGBA for Codable compliance.
    var colorR: Double
    var colorG: Double
    var colorB: Double
    var colorA: Double

    var color: Color {
        Color(.sRGB, red: colorR, green: colorG, blue: colorB, opacity: colorA)
    }
}

// MARK: - TimeLogStore

/// Persists TimeLogs to UserDefaults using Codable.
class TimeLogStore: ObservableObject {
    private static let storageKey = "timeWasted_timeLogs"

    @Published var logs: [TimeLog] = []

    init() {
        load()
    }

    func save(_ log: TimeLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
        persist()
    }

    func logsForToday() -> [TimeLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return logs.filter { calendar.isDate($0.actualStart, inSameDayAs: today) }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            logs = try JSONDecoder().decode([TimeLog].self, from: data)
        } catch {
            print("Failed to decode TimeLogs: \(error)")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(logs)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("Failed to encode TimeLogs: \(error)")
        }
    }
}
