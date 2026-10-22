import SwiftData
import SwiftUI

struct GalleryView: View {
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]
    @Namespace private var modeUnderline

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .top) {
            GalleryWall().ignoresSafeArea()

            if lots.isEmpty {
                EmptySalon { router.isAcquiring = true }
                    .frame(maxHeight: .infinity)
            } else {
                switch router.galleryMode {
                case .salon: SalonHang(lots: lots, zoom: zoom)
                case .catalogue: CatalogueGrid(lots: lots, zoom: zoom)
                }
            }

            header
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gallery")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.ivory)
                Spacer()
                SmallCaps("\(lots.count) \(lots.count == 1 ? "lot" : "lots")", size: 9.5, color: Theme.mute, tracking: 2)
            }
            HStack(spacing: 22) {
                ForEach(GalleryMode.allCases) { mode in
                    let selected = router.galleryMode == mode
                    Button {
                        withAnimation(.smooth(duration: 0.35)) { router.galleryMode = mode }
                    } label: {
                        VStack(spacing: 6) {
                            SmallCaps(mode.rawValue, size: 10, color: selected ? Theme.champagne : Theme.mute)
                            ZStack {
                                Rectangle().fill(.clear).frame(height: 1)
                                if selected {
                                    Rectangle().fill(Theme.champagne).frame(height: 1)
                                        .matchedGeometryEffect(id: "underline", in: modeUnderline)
                                }
                            }
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Spacer()
            }
            .sensoryFeedback(.selection, trigger: router.galleryMode)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            LinearGradient(colors: [Theme.ink, Theme.ink.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .padding(.bottom, -30)
        }
    }
}

/// Dark gallery wall with a wainscot line and a polished floor.
struct GalleryWall: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0x15140F), Color(hex: 0x0E0E0D), Color(hex: 0x0A0A0A)],
                               startPoint: .top, endPoint: .bottom)
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0x060606), Color(hex: 0x111110)], startPoint: .top, endPoint: .bottom))
                    .frame(height: proxy.size.height * 0.3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .filmGrain(0.05)
        }
    }
}

// MARK: - Salon Hang

struct SalonHang: View {
    let lots: [Acquisition]
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @State private var focused: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(lots) { lot in
                        HangItem(lot: lot, zoom: zoom) { router.galleryPath.append(lot.id) }
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(1 - abs(phase.value) * 0.12)
                                    .opacity(1 - abs(phase.value) * 0.55)
                                    .rotation3DEffect(.degrees(phase.value * -18), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                    .offset(x: phase.value * -30)
                            }
                            .id(lot.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $focused)
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: focused)

            counter
                .padding(.top, 10)
                .padding(.bottom, 108)
        }
        .padding(.top, 96)
        .onAppear { if focused == nil { focused = lots.first?.id } }
    }

    private var counter: some View {
        let index = (lots.firstIndex { $0.id == focused } ?? 0) + 1
        return HStack(spacing: 10) {
            Text(String(format: "%02d", index))
                .font(Theme.display(16))
                .foregroundStyle(Theme.ivory)
                .contentTransition(.numericText(value: Double(index)))
                .animation(.smooth, value: index)
            Rectangle().fill(Theme.champagne.opacity(0.5)).frame(width: 34, height: 0.5)
            Text(String(format: "%02d", lots.count))
                .font(Theme.display(16))
                .foregroundStyle(Theme.mute)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lot \(index) of \(lots.count)")
    }
}

struct HangItem: View {
    let lot: Acquisition
    let zoom: Namespace.ID
    var open: () -> Void

    var body: some View {
        let presentation = lot.presentation
        VStack(spacing: 0) {
            Button(action: open) {
                ZStack(alignment: .bottom) {
                    // Spotlight cone.
                    SpotCone()
                        .fill(RadialGradient(colors: [lot.marque.accent.opacity(0.22), .clear],
                                             center: .top, startRadius: 0, endRadius: 360))
                        .frame(width: 300)
                        .blendMode(.screen)

                    VStack(spacing: 0) {
                        CutoutArt(image: presentation.cutout, isCameo: lot.isCameo, marque: lot.marque)
                            .frame(maxWidth: 260, maxHeight: 270)
                            .overlay {
                                if lot.marque.foilStrength > 0 && !lot.isCameo {
                                    FoilSheen(strength: lot.marque.foilStrength * 0.45, hueShift: Double(lot.lotNumber % 7) / 7, marque: lot.marque)
                                        .mask(CutoutArt(image: presentation.cutout, isCameo: false, shadow: false))
                                }
                            }
                            .tiltParallax(5)
                            .padding(.bottom, -6)
                        Plinth(width: 168, plaque: "\(Format.lot(lot.lotNumber).uppercased()) · \(lot.name.uppercased())")
                    }
                }
                .matchedTransitionSource(id: lot.id, in: zoom)
            }
            .buttonStyle(PressScale())

            // Floor reflection.
            CutoutArt(image: presentation.cutout, isCameo: lot.isCameo, marque: lot.marque, shadow: false)
                .frame(maxWidth: 200, maxHeight: 60)
                .scaleEffect(x: 1, y: -1)
                .opacity(0.08)
                .blur(radius: 2)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Hallmark(marque: lot.marque, size: 14)
                    SmallCaps(lot.marque.displayName, size: 9.5, color: lot.marque.accent)
                }
                Text(lot.name)
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.ivory)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(lot.epithet)
                    .font(Theme.serifItalic(15))
                    .foregroundStyle(Theme.parchment)
                    .lineLimit(1)
                SmallCaps("Estimate  \(Format.estimate(lot.valuation))", size: 8.5, color: Theme.mute, tracking: 1.6)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 32)
            .padding(.top, 4)
        }
        .frame(maxHeight: .infinity)
    }
}

/// A soft trapezoid of light from the ceiling.
struct SpotCone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Catalogue

struct CatalogueGrid: View {
    let lots: [Acquisition]
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var order: Order = .newest

    enum Order: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case marque = "Marque"
        case estimate = "Estimate"
        var id: String { rawValue }
    }

    private var visible: [Acquisition] {
        let filtered = query.isEmpty ? lots : lots.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.epithet.localizedCaseInsensitiveContains(query)
                || $0.marque.displayName.localizedCaseInsensitiveContains(query)
                || $0.palette.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
        switch order {
        case .newest: return filtered.sorted { $0.lotNumber > $1.lotNumber }
        case .marque: return filtered.sorted { ($0.marque, $0.valuation) > ($1.marque, $1.valuation) }
        case .estimate: return filtered.sorted { $0.valuation > $1.valuation }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                controls
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                    ForEach(visible) { lot in
                        Button { router.galleryPath.append(lot.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                LotCard(lot: lot.presentation, compact: true, showsFoil: false)
                                    .matchedTransitionSource(id: lot.id, in: zoom)
                                HStack {
                                    SmallCaps(Format.lot(lot.lotNumber), size: 8, color: Theme.mute, tracking: 1.4)
                                    Spacer()
                                    Text(lot.valuation.formatted())
                                        .font(Theme.numerals(11))
                                        .foregroundStyle(Theme.parchment)
                                    + Text(" gns").font(Theme.serif(9)).foregroundStyle(Theme.mute)
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .buttonStyle(PressScale())
                    }
                }
                if visible.isEmpty {
                    Text("No lots match.")
                        .font(Theme.serifItalic(16))
                        .foregroundStyle(Theme.mute)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 100)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.mute)
                TextField("", text: $query, prompt: Text("Search the catalogue").foregroundStyle(Theme.mute))
                    .font(Theme.serifItalic(15))
                    .foregroundStyle(Theme.ivory)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .maisonGlass(in: Capsule())

            Menu {
                Picker("Order", selection: $order) {
                    ForEach(Order.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.champagne)
                    .frame(width: 42, height: 42)
                    .maisonGlass(in: Circle())
            }
            .accessibilityLabel("Order by \(order.rawValue)")
        }
    }
}
