import SwiftUI

struct StartSessionView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    var onBack: () -> Void

    @State private var name = ""
    @State private var selectedPreset: TimeInterval?
    @State private var isCustom = false
    @State private var hoursText = "0"
    @State private var minutesText = "30"
    @State private var sessionTasks: [ChecklistItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackButton(action: onBack)

            Text("New session")
                .font(Theme.Typeface.title())
                .foregroundStyle(Theme.text)

            KaizenTextField(text: $name, autoFocus: true)

            Text("Duration")
                .font(Theme.Typeface.section())
                .foregroundStyle(Theme.text)

            HStack(spacing: 4) {
                ForEach(DurationLimits.presets, id: \.seconds) { preset in
                    pill(preset.label, selected: !isCustom && selectedPreset == preset.seconds) {
                        isCustom = false
                        selectedPreset = preset.seconds
                    }
                }
                pill("Custom", selected: isCustom) {
                    isCustom = true
                    selectedPreset = nil
                }
            }

            if isCustom {
                customFields
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    )
            }

            Text("Checklist")
                .font(Theme.Typeface.section())
                .foregroundStyle(Theme.text)

            ChecklistList(
                items: sessionTasks,
                addPrompt: "Add a task for this session",
                itemListHeight: Theme.startSessionListHeight,
                onAdd: { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    sessionTasks.append(ChecklistItem(text: trimmed))
                },
                onToggle: { id in
                    guard let index = sessionTasks.firstIndex(where: { $0.id == id }) else { return }
                    sessionTasks[index].isChecked.toggle()
                },
                onDelete: { id in
                    sessionTasks.removeAll { $0.id == id }
                }
            )

            Button("Start") { start() }
                .buttonStyle(KaizenButtonStyle(kind: .primary))
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.45)
        }
        .animation(Theme.Motion.fadeAnimation, value: isCustom)
        .onAppear(perform: loadDefaults)
    }

    private var customFields: some View {
        HStack(spacing: 10) {
            periodField("H", text: $hoursText, max: 8)
            periodField("M", text: $minutesText, max: customHours >= 8 ? 0 : 59)
            Spacer(minLength: 0)
        }
        .onChange(of: hoursText) { _, _ in
            if customHours >= 8 {
                minutesText = "0"
            }
        }
    }

    private func periodField(_ label: String, text: Binding<String>, max: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Theme.Typeface.label())
                .foregroundStyle(Theme.muted)
            KaizenTextField(
                text: text,
                placeholder: "0",
                alignment: .center,
                monospaced: true,
                width: 56,
                onChange: { newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(2))
                    if digits != newValue {
                        text.wrappedValue = digits
                        return
                    }
                    if let value = Int(digits), value > max {
                        text.wrappedValue = String(max)
                    }
                }
            )
        }
    }

    private func pill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typeface.micro())
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.fill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                        .strokeBorder(selected ? Theme.pink : Theme.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(ScalePressStyle())
        .animation(Theme.Motion.colorAnimation, value: selected)
    }

    private var customHours: Int { min(8, Int(hoursText) ?? 0) }
    private var customMinutes: Int { min(customHours >= 8 ? 0 : 59, Int(minutesText) ?? 0) }

    private var duration: TimeInterval {
        if isCustom {
            return TimeInterval(customHours * 3600 + customMinutes * 60)
        }
        return selectedPreset ?? 0
    }

    private var canStart: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if sessionManager.isDebugShortTimers { return true }
        return duration >= DurationLimits.minimum && duration <= DurationLimits.maximum
    }

    private func loadDefaults() {
        let last = sessionManager.preferences.lastDuration
        if let preset = DurationLimits.presets.first(where: { $0.seconds == last }) {
            selectedPreset = preset.seconds
            isCustom = false
            hoursText = "0"
            minutesText = "30"
            return
        }
        isCustom = true
        selectedPreset = nil
        let total = Int(last)
        let hours = min(8, total / 3600)
        hoursText = String(hours)
        minutesText = hours == 8 ? "0" : String((total % 3600) / 60)
    }

    private func start() {
        sessionManager.startSession(
            name: name,
            duration: duration,
            items: sessionTasks
        )
        onBack()
    }
}
