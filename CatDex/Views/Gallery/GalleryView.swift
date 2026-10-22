import SwiftData
import SwiftUI

struct GalleryView: View {
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @Query(sort: \Acquisition.lotNumber, order: .reverse) private var lots: [Acquisition]

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text("Gallery")
                    .font(Theme.display(26))
                    .tracking(Theme.displayTracking)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Picker("View", selection: $router.galleryMode) {
                    ForEach(GalleryMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if lots.isEmpty {
                Spacer()
                WelcomeCard { router.isAcquiring = true }
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                switch router.galleryMode {
                case .grid: CatalogueGrid(lots: lots, zoom: zoom)
                case .hang: SalonHang(lots: lots, zoom: zoom)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: router.galleryMode)
    }
}

// MARK: - Showcase

struct SalonHang: View {
    let lots: [Acquisition]
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @State private var focused: UUID?

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(lots) { lot in
                        HangItem(lot: lot, zoom: zoom) { router.paths[.gallery, default: []].append(lot.id) }
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(1 - abs(phase.value) * 0.12)
                                    .opacity(1 - abs(phase.value) * 0.5)
                                    .rotation3DEffect(.degrees(phase.value * -16), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
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

            let index = (lots.firstIndex { $0.id == focused } ?? 0) + 1
            HStack(spacing: 5) {
                ForEach(Array(lots.prefix(12).enumerated()), id: \.offset) { i, _ in
                    Capsule()
                        .fill(i + 1 == index ? Theme.rose : Theme.hairline)
                        .frame(width: i + 1 == index ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.3), value: index)
            .padding(.bottom, 100)
            .accessibilityLabel("Lot \(index) of \(lots.count)")
        }
        .onAppear { if focused == nil { focused = lots.first?.id } }
    }
}

struct HangItem: View {
    let lot: Acquisition
    let zoom: Namespace.ID
    var open: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: open) {
                LotCard(lot: lot.presentation)
                    .frame(maxWidth: 290)
                    .matchedTransitionSource(id: lot.id, in: zoom)
            }
            .buttonStyle(PressScale())
            HStack(spacing: 14) {
                stat("Estimate", Format.compact(lot.valuation) + " gns")
                Rectangle().fill(Theme.hairline).frame(width: 0.5, height: 26)
                stat("Show wins", "\(lot.showWins)")
                Rectangle().fill(Theme.hairline).frame(width: 0.5, height: 26)
                let top = lot.temperament.dominant
                stat(top.displayName, "\(lot.temperament[top])")
            }
            .pearlCard(16, padding: 10)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(Theme.number(15)).foregroundStyle(Theme.ink)
            Text(label).font(Theme.caption(10.5)).foregroundStyle(Theme.ink3)
        }
        .frame(minWidth: 64)
    }
}

// MARK: - Collection grid

struct CatalogueGrid: View {
    let lots: [Acquisition]
    let zoom: Namespace.ID
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var order: Order = .newest
    @State private var marque: Marque?

    enum Order: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case marque = "Marque"
        case estimate = "Estimate"
        case wins = "Show wins"
        var id: String { rawValue }
    }

    private var visible: [Acquisition] {
        var filtered = query.isEmpty ? lots : lots.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.epithet.localizedCaseInsensitiveContains(query)
                || $0.palette.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
        if let marque { filtered = filtered.filter { $0.marque == marque } }
        switch order {
        case .newest: return filtered.sorted { $0.lotNumber > $1.lotNumber }
        case .marque: return filtered.sorted { ($0.marque, $0.valuation) > ($1.marque, $1.valuation) }
        case .estimate: return filtered.sorted { $0.valuation > $1.valuation }
        case .wins: return filtered.sorted { $0.showWins > $1.showWins }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                controls
                marqueFilter
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(visible) { lot in
                        Button { router.paths[.gallery, default: []].append(lot.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                LotCard(lot: lot.presentation, compact: true, showsFoil: false)
                                    .matchedTransitionSource(id: lot.id, in: zoom)
                                HStack(spacing: 4) {
                                    CoinGlyph(size: 10)
                                    Text(Format.compact(lot.valuation))
                                        .font(Theme.number(11, weight: .semibold))
                                        .foregroundStyle(Theme.ink2)
                                    Spacer(minLength: 0)
                                    if lot.showWins > 0 {
                                        Image(systemName: "rosette").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.rose)
                                        Text("\(lot.showWins)").font(Theme.number(11, weight: .semibold)).foregroundStyle(Theme.ink2)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        .buttonStyle(PressScale())
                    }
                }
                if visible.isEmpty {
                    Text("No lots match.")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink3)
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                TextField("", text: $query, prompt: Text("Search by name or colour").foregroundStyle(Theme.ink3))
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 0.5))

            Menu {
                Picker("Order", selection: $order) {
                    ForEach(Order.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.roseDeep)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().stroke(Theme.hairline, lineWidth: 0.5))
            }
            .accessibilityLabel("Order by \(order.rawValue)")
        }
    }

    private var marqueFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip(nil, "All")
                ForEach(Marque.allCases) { chip($0, $0.displayName) }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private func chip(_ value: Marque?, _ title: String) -> some View {
        let selected = marque == value
        return Button {
            withAnimation(.snappy) { marque = value }
        } label: {
            HStack(spacing: 5) {
                if let value { Hallmark(marque: value, size: 10) }
                Text(title).font(Theme.caption(12.5, weight: .semibold))
            }
            .foregroundStyle(selected ? .white : Theme.ink2)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(selected ? AnyShapeStyle(Theme.roseGold) : AnyShapeStyle(Theme.surface)))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: selected ? 0 : 0.5))
        }
        .buttonStyle(.plain)
    }
}
