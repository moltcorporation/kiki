import SwiftUI

struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignedIn: () -> Void

    @State private var showSignIn = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            HeroGraphic()
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)
            Spacer(minLength: 24)

            VStack(spacing: 28) {
                Text("Your AI\nrunning coach.")
                    .font(.system(size: 44, weight: .black).italic())
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                VStack(spacing: 16) {
                    PrimaryButton("Get started", action: onGetStarted)
                    Button {
                        showSignIn = true
                    } label: {
                        Text("Already have an account? **Sign in**")
                            .foregroundStyle(.ink)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.haptic)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color.paper)
        .onAppear {
            withAnimation(.smooth(duration: 0.8)) { appeared = true }
            Analytics.screen("Welcome")
        }
        .sheet(isPresented: $showSignIn) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome back").font(.title.weight(.bold))
                SignInOptions {
                    showSignIn = false
                    onSignedIn()
                }
            }
            .padding(24)
            .presentationDetents([.height(200)])
        }
    }
}

/// A stylized "Today" screen that shows what Kiki does at a glance.
private struct HeroGraphic: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Week 6 of 12").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text("Today").font(.title2.weight(.bold))
                }
                Spacer()
                KikiLogo(size: 36)
            }
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 6) {
                        Text(day).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        Circle()
                            .fill(index == 3 ? Color.ink : index < 3 ? Color.wash : .clear)
                            .overlay(Circle().stroke(Color.secondary.opacity(index > 3 ? 0.25 : 0)))
                            .overlay {
                                if index < 3 && index != 2 {
                                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                                }
                            }
                            .frame(width: 30, height: 30)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("TEMPO").font(.caption.weight(.bold)).foregroundStyle(.paper.opacity(0.6))
                Text("Tempo Run").font(.title2.weight(.bold))
                HStack(spacing: 28) {
                    VStack(alignment: .leading) {
                        Text("8.0").font(.metric(.title))
                        Text("km").font(.caption).foregroundStyle(.paper.opacity(0.6))
                    }
                    VStack(alignment: .leading) {
                        Text("4:55").font(.metric(.title))
                        Text("tempo /km").font(.caption).foregroundStyle(.paper.opacity(0.6))
                    }
                }
                Text("Mark as done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.paper, in: .capsule)
                    .padding(.top, 4)
            }
            .foregroundStyle(.paper)
            .padding(18)
            .background(Color.ink, in: .rect(cornerRadius: 24))
        }
        .padding(20)
        .frame(maxWidth: 300)
        .background(Color.paper, in: .rect(cornerRadius: 36))
        .overlay(RoundedRectangle(cornerRadius: 36).stroke(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.12), radius: 30, y: 20)
        .rotationEffect(.degrees(-2))
        .accessibilityElement()
        .accessibilityLabel("Kiki shows today's workout and your week at a glance")
    }
}
