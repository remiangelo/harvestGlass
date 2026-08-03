import SwiftUI

/// The message input shared by both chats: a rounded field, an optional
/// leading accessory, and a send button with three states — disabled, ready,
/// and in-flight.
///
/// Focus is passed in rather than owned here so the host view can dismiss the
/// keyboard by tapping its transcript.
struct ChatComposer<Accessory: View>: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let accent: ChatAccent
    let placeholder: String
    let isSending: Bool
    let onSend: () -> Void
    @ViewBuilder let accessory: Accessory

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: HarvestTheme.Spacing.sm) {
            accessory

            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(HarvestTheme.Typography.bodyRegular)
                .foregroundStyle(HarvestTheme.Colors.textPrimary)
                .tint(accent.base)
                .focused(focused)
                .lineLimit(1...5)
                .padding(.horizontal, HarvestTheme.Spacing.md)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(HarvestTheme.Colors.wineRaised)
                        .overlay { Capsule().stroke(HarvestTheme.Colors.border, lineWidth: 1) }
                }

            sendButton
        }
        .padding(.horizontal, HarvestTheme.Spacing.md)
        .padding(.vertical, HarvestTheme.Spacing.sm)
        .background {
            HarvestTheme.Colors.wineBlack
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(HarvestTheme.Colors.border)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            ZStack {
                Circle()
                    .fill(canSend
                          ? AnyShapeStyle(LinearGradient(
                                colors: [accent.base, accent.deep],
                                startPoint: .top,
                                endPoint: .bottom))
                          : AnyShapeStyle(HarvestTheme.Colors.textTertiary.opacity(0.25)))
                    .frame(width: 36, height: 36)

                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HarvestTheme.Colors.textInverse)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend
                                         ? HarvestTheme.Colors.textInverse
                                         : HarvestTheme.Colors.textTertiary)
                }
            }
        }
        .disabled(!canSend)
        .animation(.easeInOut(duration: HarvestTheme.Animation.fast), value: canSend)
        .padding(.bottom, 2)
    }
}

extension ChatComposer where Accessory == EmptyView {
    init(
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        accent: ChatAccent,
        placeholder: String,
        isSending: Bool,
        onSend: @escaping () -> Void
    ) {
        self.init(
            text: text,
            focused: focused,
            accent: accent,
            placeholder: placeholder,
            isSending: isSending,
            onSend: onSend,
            accessory: { EmptyView() }
        )
    }
}
