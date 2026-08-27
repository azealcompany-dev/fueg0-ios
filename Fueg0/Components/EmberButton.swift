import SwiftUI

struct EmberButton: View {
    let title: String
    var enabled: Bool = true
    var loading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(loading ? 0 : 1)
                if loading {
                    ProgressView()
                        .tint(Palette.onEmber)
                }
            }
            .foregroundStyle(enabled ? Palette.onEmber : Palette.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                    .fill(enabled ? Palette.ember : Palette.surfaceElevated)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
        .accessibilityAddTraits(.isButton)
    }
}

struct EmberOutlineButton: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                        .stroke(Palette.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct Fueg0Field<Trailing: View>: View {
    let title: String
    @Binding var text: String
    var secure: Bool = false
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    var focus: FocusState<String?>.Binding? = nil
    @ViewBuilder var trailing: Trailing

    init(
        title: String,
        text: Binding<String>,
        secure: Bool = false,
        submitLabel: SubmitLabel = .next,
        onSubmit: @escaping () -> Void = {},
        focus: FocusState<String?>.Binding? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self._text = text
        self.secure = secure
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
        self.focus = focus
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
            HStack(spacing: 8) {
                Group {
                    if secure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Palette.textPrimary)
                .tint(Palette.ember)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .modifier(Fueg0FieldFocus(title: title, focus: focus))
                trailing
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                    .fill(Palette.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                    .stroke(text.isEmpty ? Palette.hairline : Palette.emberBorder, lineWidth: 1)
            )
        }
    }
}

private struct Fueg0FieldFocus: ViewModifier {
    let title: String
    var focus: FocusState<String?>.Binding?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus, equals: title)
        } else {
            content
        }
    }
}

extension Fueg0Field where Trailing == EmptyView {
    init(
        title: String,
        text: Binding<String>,
        secure: Bool = false,
        submitLabel: SubmitLabel = .next,
        onSubmit: @escaping () -> Void = {},
        focus: FocusState<String?>.Binding? = nil
    ) {
        self.init(
            title: title,
            text: text,
            secure: secure,
            submitLabel: submitLabel,
            onSubmit: onSubmit,
            focus: focus
        ) { EmptyView() }
    }
}

struct QuietPill: View {
    let label: String
    var accent: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(accent ? Palette.gold : Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Palette.surfaceElevated)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent ? Palette.emberBorder : Palette.hairline, lineWidth: 1)
            )
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1)
            )
    }
}

struct ComingSoonView: View {
    let title: String
    let blurb: String
    let symbol: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.ember)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(Palette.surfaceElevated)
                    )
                    .overlay(
                        Circle().stroke(Palette.hairline, lineWidth: 1)
                    )

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(blurb)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.textSecondary)
                    .lineSpacing(4)

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming in this native port")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("The Flutter app still owns the full feature. This screen is a designed placeholder so the shell never crashes empty.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                            .lineSpacing(3)
                    }
                }
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
