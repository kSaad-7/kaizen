import AppKit
import SwiftUI

enum Theme {
    static let pink = Color(red: 201 / 255, green: 63 / 255, blue: 121 / 255)
    static let background = Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255)
    static let text = Color.white.opacity(0.92)
    static let muted = Color.white.opacity(0.45)
    static let hairline = Color.white.opacity(0.08)
    static let stroke = Color.white.opacity(0.16)
    static let fill = Color.white.opacity(0.06)
    static let fillStrong = Color.white.opacity(0.10)

    static let nsPink = NSColor(srgbRed: 201 / 255, green: 63 / 255, blue: 121 / 255, alpha: 1)
    static let nsBackground = NSColor(srgbRed: 32 / 255, green: 32 / 255, blue: 32 / 255, alpha: 1)

    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 8
    static let radiusL: CGFloat = 12
    static let fieldHeight: CGFloat = 32
    static let menuWidth: CGFloat = 276
    static let startSessionListHeight: CGFloat = 108
    static let checklistMenuWidth: CGFloat = 380
    static let checklistMenuMinHeight: CGFloat = 620
    static let expandedTimerSize = CGSize(width: 268, height: 296)
    static let widgetGap: CGFloat = 6
    static let hoverChecklistListHeight: CGFloat = 140
    static let persistentListHeight: CGFloat = 480

    static func compactTimerSize(clock: String, paused: Bool) -> CGSize {
        let timeWidth = CGFloat(clock.count) * 9.4
        return CGSize(width: ceil(20 + 13 + 6 + timeWidth + 20), height: 36)
    }

    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
    }

    enum Typeface {
        static func title() -> Font { .system(size: 13, weight: .semibold) }
        static func section() -> Font { .system(size: 11, weight: .semibold) }
        static func body() -> Font { .system(size: 12, weight: .regular) }
        static func label() -> Font { .system(size: 11, weight: .medium) }
        static func caption() -> Font { .system(size: 11, weight: .regular) }
        static func micro() -> Font { .system(size: 10, weight: .medium) }
        static func timer() -> Font { .system(size: 15, weight: .medium, design: .monospaced) }
        static func timerLarge() -> Font { .system(size: 22, weight: .medium, design: .monospaced) }
    }

    enum Motion {
        static let duration: TimeInterval = 0.3
        static let widgetFade: TimeInterval = 0.12
        static let widgetShrinkDelay: Duration = .milliseconds(140)
        static let hoverDelay: Duration = .milliseconds(90)
        static let hoverEnter: Duration = .milliseconds(300)
        static let hoverExit: Duration = .milliseconds(300)
        static let press: TimeInterval = duration
        static let fade: TimeInterval = duration
        static let vignette: TimeInterval = duration
        static let completionBurst: TimeInterval = 0.32
        static let completionFade: TimeInterval = 0.2
        static let closeArmTimeout: TimeInterval = 3

        static func easeOut(_ duration: TimeInterval = duration) -> Animation {
            .timingCurve(0.23, 1, 0.32, 1, duration: duration)
        }

        static var widgetFadeAnimation: Animation { .easeOut(duration: widgetFade) }
        static var hoverEnterAnimation: Animation { easeOut() }
        static var hoverExitAnimation: Animation { easeOut() }
        static var pressAnimation: Animation { easeOut() }
        static var fadeAnimation: Animation { easeOut() }
        static var colorAnimation: Animation { easeOut() }
    }
}

struct KaizenSurface: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.background)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Theme.pink.opacity(0.22), location: 0),
                                .init(color: Theme.pink.opacity(0.09), location: 0.42),
                                .init(color: .clear, location: 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }
}

struct KaizenTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    var alignment: TextAlignment = .leading
    var monospaced: Bool = false
    var width: CGFloat? = nil
    var onSubmit: (() -> Void)? = nil
    var onChange: ((String) -> Void)? = nil
    var autoFocus: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(monospaced ? Theme.Typeface.timer() : Theme.Typeface.body())
            .monospacedDigit()
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(alignment)
            .padding(.horizontal, 8)
            .frame(width: width, height: Theme.fieldHeight, alignment: .center)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .background(Theme.fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                    .strokeBorder(focused ? Theme.pink : Color.clear, lineWidth: 1)
            }
            .focused($focused)
            .animation(Theme.Motion.colorAnimation, value: focused)
            .onSubmit { onSubmit?() }
            .onChange(of: text) { _, newValue in
                onChange?(newValue)
            }
            .onAppear {
                guard autoFocus else { return }
                DispatchQueue.main.async {
                    focused = true
                }
            }
    }
}

struct KaizenButtonStyle: ButtonStyle {
    var kind: Kind = .plain
    enum Kind { case plain, primary, quiet }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(kind == .primary ? Theme.Typeface.label() : Theme.Typeface.body())
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .plain ? 0 : 10)
            .padding(.vertical, kind == .plain ? 0 : 7)
            .frame(maxWidth: kind == .primary ? .infinity : nil)
            .background(background(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
            .scaleEffect(kind == .plain ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(kind == .plain ? nil : Theme.Motion.pressAnimation, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .plain, .quiet: Theme.text
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: Theme.pink.opacity(pressed ? 0.85 : 1)
        case .quiet: Theme.fill
        case .plain: .clear
        }
    }
}

struct TimerGlyph: View {
    var size: CGFloat = 12

    var body: some View {
        Image(systemName: "timer")
            .font(.system(size: size, weight: .semibold))
    }
}

struct SessionIconButton: View {
    var systemName: String
    var help: String
    var tint: Color = Theme.text
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? Theme.pink : tint)
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                        .fill(hovering ? Theme.fill : .clear)
                }
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(ScalePressStyle())
        .onHover { hovering = $0 }
        .animation(Theme.Motion.fadeAnimation, value: hovering)
        .animation(Theme.Motion.fadeAnimation, value: systemName)
        .help(help)
    }
}

struct BackButton: View {
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label("Back", systemImage: "chevron.left")
                .font(Theme.Typeface.label())
                .foregroundStyle(hovering ? Theme.pink : Theme.muted)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.fadeAnimation, value: hovering)
    }
}

struct PositionPicker: View {
    var selection: TimerPosition
    var onSelect: (TimerPosition) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timer Position")
                .font(Theme.Typeface.section())
                .foregroundStyle(Theme.text)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(TimerPosition.allCases) { position in
                    Button {
                        onSelect(position)
                    } label: {
                        ZStack(alignment: alignment(for: position)) {
                            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                                .fill(Theme.fill)
                            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                                .strokeBorder(selection == position ? Theme.pink : Theme.hairline, lineWidth: 1)
                            Capsule()
                                .fill(selection == position ? Theme.pink : Theme.muted)
                                .frame(width: 11, height: 3)
                                .padding(4)
                        }
                        .frame(height: 22)
                    }
                    .buttonStyle(ScalePressStyle())
                    .animation(Theme.Motion.colorAnimation, value: selection)
                    .help(position.title)
                }
            }
        }
    }

    private func alignment(for position: TimerPosition) -> Alignment {
        switch position {
        case .topLeft: .topLeading
        case .topCenter: .top
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomCenter: .bottom
        case .bottomRight: .bottomTrailing
        }
    }
}

struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.Motion.pressAnimation, value: configuration.isPressed)
    }
}

struct IconHoverButtonStyle: ButtonStyle {
    var idle: Color = Theme.text

    func makeBody(configuration: Configuration) -> some View {
        IconHoverLabel(
            label: configuration.label,
            isPressed: configuration.isPressed,
            idle: idle
        )
    }
}

private struct IconHoverLabel<Label: View>: View {
    var label: Label
    var isPressed: Bool
    var idle: Color
    @State private var hovering = false

    var body: some View {
        label
            .foregroundStyle(hovering ? Theme.pink : idle)
            .scaleEffect(isPressed ? 0.97 : 1)
            .onHover { hovering = $0 }
            .animation(Theme.Motion.fadeAnimation, value: hovering)
            .animation(Theme.Motion.pressAnimation, value: isPressed)
    }
}
