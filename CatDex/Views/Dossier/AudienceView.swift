import SwiftUI

/// An audience with a cat: correspondence, in character, written on device.
struct AudienceView: View {
    @Bindable var lot: Acquisition
    @Environment(\.dismiss) private var dismiss
    @State private var voice: AudienceVoice?
    @State private var letters: [Letter] = []
    @State private var draft = ""
    @State private var replying: String?
    @State private var isReplying = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        SmallCaps(Date.now.formatted(Format.editorialDate), size: 8.5, color: Theme.mute, tracking: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 18)
                        ForEach(letters) { letter in
                            LetterView(letter: letter, catName: lot.name, marque: lot.marque)
                                .id(letter.id)
                        }
                        if isReplying {
                            CatLine(text: replying ?? "", catName: lot.name, marque: lot.marque, writing: true)
                                .id("replying")
                        }
                        Color.clear.frame(height: 8).id("end")
                    }
                    .padding(.horizontal, 22)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: letters.count) { _, _ in withAnimation { reader.scrollTo("end", anchor: .bottom) } }
                .onChange(of: replying) { _, _ in reader.scrollTo("end", anchor: .bottom) }
            }
            composer
        }
        .background(background)
        .task { begin() }
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Theme.onyx
            PaletteBackdrop(palette: lot.palette, animated: false)
                .frame(height: 260)
                .mask(LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
                .blur(radius: 30)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(PaletteBackdrop.colors(for: lot.palette)[1])
                CutoutArt(image: ImageStore.cutout(for: lot), isCameo: lot.isCameo, marque: lot.marque, shadow: false)
                    .padding(lot.isCameo ? 0 : 5)
                    .clipShape(Circle())
                Circle().stroke(lot.marque.metal, lineWidth: 1.2)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                SmallCaps("An audience with", size: 8, color: Theme.mute)
                Text(lot.name)
                    .font(Theme.display(21))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            GlassIconButton(systemName: "xmark", label: "End the audience") { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 0.5) }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                TextField("", text: $draft, prompt: Text("Write to \(lot.name.components(separatedBy: " ").last ?? lot.name)…").foregroundStyle(Theme.mute), axis: .vertical)
                    .font(Theme.serif(16))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .maisonGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(canSend ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.smoke)))
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("sendLetter")
                .sensoryFeedback(.impact(weight: .light), trigger: letters.count)
            }
            HStack(spacing: 5) {
                Image(systemName: voice?.isAppleIntelligence == true ? "sparkles" : "pencil.and.scribble")
                Text(voice?.isAppleIntelligence == true ? "In character, on device · Apple Intelligence" : "In character · the house voice")
            }
            .font(Theme.serifItalic(10.5))
            .foregroundStyle(Theme.mute)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var canSend: Bool { !draft.trimmed.isEmpty && !isReplying }

    private func begin() {
        guard voice == nil else { return }
        let history = lot.correspondence
        let voice = AudienceVoice(persona: Persona(lot), history: history)
        self.voice = voice
        if history.isEmpty {
            let hello = Letter(author: .cat, text: voice.greeting())
            letters = [hello]
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
        Task {
            try? await Task.sleep(for: .milliseconds(450))
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

struct LetterView: View {
    let letter: Letter
    let catName: String
    let marque: Marque

    var body: some View {
        switch letter.author {
        case .cat:
            CatLine(text: letter.text, catName: catName, marque: marque, writing: false)
        case .patron:
            HStack {
                Spacer(minLength: 60)
                Text(letter.text)
                    .font(Theme.serif(15.5))
                    .foregroundStyle(Theme.ivory)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .maisonGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), tint: Theme.champagne)
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

/// The cat's reply, set like a handwritten note with a gilded initial.
struct CatLine: View {
    let text: String
    let catName: String
    let marque: Marque
    var writing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(LinearGradient(colors: [marque.accent, marque.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 1)
            VStack(alignment: .leading, spacing: 6) {
                SmallCaps(catName, size: 8.5, color: marque.accent.opacity(0.9), tracking: 2)
                if text.isEmpty && writing {
                    Quill()
                } else {
                    Text(text)
                        .font(Theme.serifItalic(18))
                        .foregroundStyle(Theme.ivory)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 30)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(writing ? "catLetterWriting" : "catLetter")
    }
}

/// Three gilded dots — the cat is composing.
struct Quill: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.champagne)
                        .frame(width: 5, height: 5)
                        .opacity(0.3 + 0.7 * max(0, sin(t * 4 - Double(i) * 0.7)))
                }
            }
            .frame(height: 22)
        }
        .accessibilityLabel("Writing")
    }
}
