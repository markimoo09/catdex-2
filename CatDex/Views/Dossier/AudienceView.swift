import SwiftUI

/// An audience with a cat: a chat, in character, written on device.
struct AudienceView: View {
    @Bindable var lot: Acquisition
    @Environment(\.dismiss) private var dismiss
    @Environment(Game.self) private var game
    @State private var voice: AudienceVoice?
    @State private var letters: [Letter] = []
    @State private var draft = ""
    @State private var replying: String?
    @State private var isReplying = false
    @State private var counted = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(Theme.caption(11))
                            .foregroundStyle(Theme.ink3)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                        ForEach(letters) { letter in
                            LetterView(letter: letter, lot: lot)
                                .id(letter.id)
                        }
                        if isReplying {
                            CatLine(text: replying ?? "", lot: lot, writing: true)
                                .id("replying")
                        }
                        Color.clear.frame(height: 6).id("end")
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: letters.count) { _, _ in withAnimation { reader.scrollTo("end", anchor: .bottom) } }
                .onChange(of: replying) { _, _ in reader.scrollTo("end", anchor: .bottom) }
            }
            composer
        }
        .background(Theme.ground.ignoresSafeArea())
        .task { begin() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(lot: lot, size: 42)
            VStack(alignment: .leading, spacing: 1) {
                Text(lot.name)
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Circle().fill(Theme.win).frame(width: 6, height: 6)
                    Text(voice?.isAppleIntelligence == true ? "In character · Apple Intelligence" : "In character")
                        .font(Theme.caption(11))
                        .foregroundStyle(Theme.ink3)
                }
            }
            Spacer()
            GlassIconButton(systemName: "xmark", label: "End the audience") { dismiss() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.pearl.opacity(0.9))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("", text: $draft, prompt: Text("Message \(lot.name.components(separatedBy: " ").last ?? lot.name)").foregroundStyle(Theme.ink3), axis: .vertical)
                .font(Theme.body(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canSend ? AnyShapeStyle(Theme.roseGold) : AnyShapeStyle(Theme.ink3.opacity(0.4))))
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("sendLetter")
            .sensoryFeedback(.impact(weight: .light), trigger: letters.count)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.pearl.opacity(0.95).ignoresSafeArea())
    }

    private var canSend: Bool { !draft.trimmed.isEmpty && !isReplying }

    private func begin() {
        guard voice == nil else { return }
        let history = lot.correspondence
        let voice = AudienceVoice(persona: Persona(lot), history: history)
        self.voice = voice
        if history.isEmpty {
            letters = [Letter(author: .cat, text: voice.greeting())]
            lot.correspondence = letters
        } else {
            letters = history
        }
    }

    private func send() {
        let text = draft.trimmed
        guard !text.isEmpty, !isReplying, let voice else { return }
        draft = ""
        letters.append(Letter(author: .patron, text: text))
        isReplying = true
        replying = ""
        if !counted {
            counted = true
            game.recordAudience()
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            let reply = await voice.reply(to: text) { replying = $0 }
            withAnimation(.smooth) {
                letters.append(Letter(author: .cat, text: reply.trimmed))
                isReplying = false
                replying = nil
            }
            lot.correspondence = Array(letters.suffix(60))
        }
    }
}

/// The cat's portrait in a coat-tinted circle.
struct Avatar: View {
    let lot: Acquisition
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(PaletteBackdrop.colors(for: lot.palette, marque: lot.marque)[0])
            CutoutArt(image: ImageStore.cutout(for: lot), isCameo: lot.isCameo, marque: lot.marque, shadow: false)
                .padding(lot.isCameo ? 0 : size * 0.1)
                .clipShape(Circle())
            Circle().stroke(lot.marque.metal, lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }
}

struct LetterView: View {
    let letter: Letter
    let lot: Acquisition

    var body: some View {
        switch letter.author {
        case .cat:
            CatLine(text: letter.text, lot: lot, writing: false)
        case .patron:
            HStack {
                Spacer(minLength: 60)
                Text(letter.text)
                    .font(Theme.body(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.roseGold))
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

/// The cat's reply bubble.
struct CatLine: View {
    let text: String
    let lot: Acquisition
    var writing: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Avatar(lot: lot, size: 28)
            Group {
                if text.isEmpty && writing {
                    Quill()
                } else {
                    Text(text)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 0.5))
            Spacer(minLength: 40)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(writing ? "catLetterWriting" : "catLetter")
    }
}

/// Three dots — the cat is composing.
struct Quill: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.rose)
                        .frame(width: 6, height: 6)
                        .opacity(0.3 + 0.7 * max(0, sin(t * 4 - Double(i) * 0.7)))
                }
            }
            .frame(height: 20)
        }
        .accessibilityLabel("Writing")
    }
}
