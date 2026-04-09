//
//  ContentView.swift
//  timeWasted
//
//  Created by Ann Hsu on 4/8/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var eventKitManager = EventKitManager()
    @StateObject private var logStore = TimeLogStore()

    @State private var activeLog: TimeLog?
    @State private var activeTimerDate = Date()
    @State private var chatText = ""
    @State private var timer: Timer?
    @FocusState private var chatFocused: Bool

    var body: some View {
        ZStack {
            // Background
            Color(white: 0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Main split day view
                SplitDayView(
                    eventKitManager: eventKitManager,
                    logStore: logStore,
                    activeLog: $activeLog,
                    activeTimerDate: $activeTimerDate
                )
                .padding(.horizontal, 4)

                // Done button when a task is active
                if activeLog != nil {
                    doneButton
                }

                // Chat input bar
                chatBar
            }
        }
        .onAppear {
            eventKitManager.requestAccessAndFetchEvents()
        }
        .onChange(of: activeLog) { _ in
            if activeLog != nil {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("time wasted")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(todayDateString())
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status indicator
                if activeLog != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)

                        Text("TRACKING")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }

            // Permission warning
            if eventKitManager.authorizationStatus == .denied || eventKitManager.authorizationStatus == .restricted {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("Calendar access required — enable in Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button(action: { finishActiveLog() }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.green.opacity(0.35), radius: 8, y: 4)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeLog != nil)
    }

    // MARK: - Chat Bar

    private var chatBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField("Type a task name or \"done\"…", text: $chatText)
                .font(.system(size: 15, weight: .regular))
                .focused($chatFocused)
                .submitLabel(.send)
                .onSubmit { handleChatSubmit() }

            if !chatText.isEmpty {
                Button(action: { handleChatSubmit() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Chat Logic

    private func handleChatSubmit() {
        let input = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let lowered = input.lowercased()

        // Check for "done" or "finished" keywords
        if activeLog != nil && (lowered.contains("done") || lowered.contains("finished")) {
            finishActiveLog()
            chatText = ""
            chatFocused = false
            return
        }

        // Try to match an event title
        if activeLog == nil {
            let words = lowered.components(separatedBy: .whitespacesAndNewlines)
            for event in eventKitManager.events {
                let titleLower = event.title.lowercased()
                for word in words {
                    if !word.isEmpty && titleLower.contains(word) {
                        startLoggingFromChat(event: event)
                        chatText = ""
                        chatFocused = false
                        return
                    }
                }
            }
        }

        chatText = ""
        chatFocused = false
    }

    private func startLoggingFromChat(event: CalendarEvent) {
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

    // MARK: - Timer

    private func startTimer() {
        activeTimerDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            activeTimerDate = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func finishActiveLog() {
        guard var log = activeLog else { return }
        log.actualEnd = Date()
        logStore.save(log)
        activeLog = nil
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

#Preview {
    ContentView()
}
