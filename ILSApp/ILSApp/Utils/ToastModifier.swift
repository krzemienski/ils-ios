import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2))
                            if reduceMotion {
                                isPresented = false
                            } else {
                                withAnimation { isPresented = false }
                            }
                        }
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}
