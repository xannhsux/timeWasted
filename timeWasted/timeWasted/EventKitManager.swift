//
//  EventKitManager.swift
//  timeWasted
//
//  Created by Ann Hsu on 4/8/26.
//

import EventKit
import SwiftUI

/// Manages EventKit calendar access: requests permission and fetches today's events.
class EventKitManager: ObservableObject {
    private let store = EKEventStore()

    @Published var events: [CalendarEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Requests calendar access and fetches today's events on success.
    func requestAccessAndFetchEvents() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.authorizationStatus = status

        switch status {
        case .authorized, .fullAccess:
            fetchTodayEvents()
        case .notDetermined:
            if #available(iOS 17.0, macOS 14.0, *) {
                store.requestFullAccessToEvents { [weak self] granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self?.authorizationStatus = .fullAccess
                            self?.fetchTodayEvents()
                        } else {
                            self?.authorizationStatus = .denied
                            self?.errorMessage = error?.localizedDescription ?? "Calendar access denied."
                        }
                    }
                }
            } else {
                store.requestAccess(to: .event) { [weak self] granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self?.authorizationStatus = .authorized
                            self?.fetchTodayEvents()
                        } else {
                            self?.authorizationStatus = .denied
                            self?.errorMessage = error?.localizedDescription ?? "Calendar access denied."
                        }
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Calendar access is denied. Please enable it in Settings."
        default:
            errorMessage = "Unexpected calendar authorization status."
        }
    }

    /// Fetches all EKEvents for today between 6:00 AM and midnight.
    private func fetchTodayEvents() {
        let calendar = Calendar.current
        let now = Date()

        guard let startOfDay = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        DispatchQueue.main.async { [weak self] in
            self?.events = ekEvents.map { event in
                let (r, g, b, a) = Self.rgbaFromCGColor(event.calendar.cgColor)

                return CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled",
                    startTime: event.startDate,
                    endTime: event.endDate,
                    color: Color(.sRGB, red: r, green: g, blue: b, opacity: a)
                )
            }
            .sorted { $0.startTime < $1.startTime }
        }
    }

    /// Extracts RGBA components from a CalendarEvent's color.
    func colorComponents(for event: CalendarEvent) -> (Double, Double, Double, Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfDay = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        else { return (0.4, 0.6, 1.0, 1.0) }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        if let ekEvent = ekEvents.first(where: { $0.eventIdentifier == event.id }) {
            return Self.rgbaFromCGColor(ekEvent.calendar.cgColor)
        }

        return (0.4, 0.6, 1.0, 1.0)
    }

    /// Extracts RGBA from a CGColor without UIKit/AppKit dependency.
    private static func rgbaFromCGColor(_ cgColor: CGColor?) -> (Double, Double, Double, Double) {
        guard let cgColor = cgColor,
              let converted = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
              let c = converted.components, converted.numberOfComponents >= 3
        else { return (0.4, 0.6, 1.0, 1.0) }

        let r = Double(c[0])
        let g = Double(c[1])
        let b = Double(c[2])
        let a = converted.numberOfComponents >= 4 ? Double(c[3]) : 1.0
        return (r, g, b, a)
    }
}
