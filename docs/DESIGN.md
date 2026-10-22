# CatDex Maison — v2 design

> A private collection of extraordinary cats — and a game about building it.

v1 was a playful trading-card game. v2 keeps the core loop — **photograph a cat → it
is lifted out of the photo → on-device AI writes it up → it joins your collection** — and
wraps it in a luxury-house fantasy (lots, marques, wax seals, certificates) with a real
game layer: a purse, levels, daily commissions, and cat shows where your cats' temperament
finally matters.

## Look — "Pearl"

The first v2 build was noir-and-gold with Didot type; it read as too dark and too
"AI luxury". The current look:

- **Pearl grounds** washing into blush and lilac; white cards with soft rose-tinted
  shadows; plum ink (`#2A2430`) instead of black.
- **Rose gold** for every call to action, the capture button, XP and progress.
- **SF Pro throughout** — bold display weights with tight tracking, rounded figures for
  the game layer (coins, levels, scores). No serif type; only the certificate's curator
  signature is script.
- **Compact** — 16 pt gutters, 12–18 pt rhythm, dense three-column collection grid.
- **Every cat brings its own colours.** Its coat palette becomes a pastel backdrop.
  Noir lots keep a deep plum card: the rarest cards are the dark ones.
- The camera viewfinder stays dark (it's a camera); everything else is light.

## The loop

1. **The Lens** — custom camera; on device a reticle locks onto any cat Vision sees.
2. **The Appraisal** — subject lift with a gold-edged dissolve (Metal), a coat palette
   named from a couture colour library, scene provenance, and the curator's note streamed
   from Foundation Models (seeded house writer as fallback).
3. **The Unsealing** — tap the wax seal three times; the card rises; the reveal shows the
   estimate and the finder's fee + XP about to land.
4. **Into the collection** — XP and guineas are paid, commissions tick, levels may rise.

## Game layer

| System | How it works |
|---|---|
| **Purse (guineas)** | Start with 500. Earn finder's fees (60–1,000 by marque), show prizes, commission rewards. Spend on show entry and grooming. |
| **Levels** | XP to reach level L = 60·(L−1)·L. Titles from Visitor to Founder's Circle. Level-ups show a celebration card and unlock show tiers. |
| **Commissions** | Three daily goals (one acquire, one show, one care), rotating at midnight, claimable for guineas + XP. |
| **Concours** | Pick three cats; face a rival collector's three over best-of-three rounds. Each round the judge names a trait; you send a cat; score = trait + marque flair + show experience + a little luck (±6). Ties go to you. Four tiers — Village Fête, Salon d'Automne (Lv 3), Grand Concours (Lv 6), Concours Royal (Lv 10) — with rising rivals, fees and prizes. Winning earns rosettes. |
| **Grooming** | Raise any trait by +3 for guineas; the price climbs as the trait nears 100. |
| **Show experience** | Every three rounds a cat wins adds +1 to all its future rounds (up to +5). |
| **Streak** | Consecutive days with an acquisition or a show. |
| **Exhibitions** | Ten collection achievements (first lot, a Noir, three marques, after dark…). |

## Marques (rarity)

| Marque | Odds | Estimate (gns) | XP | Finder's fee | Flair |
|---|---|---|---|---|---|
| Ivory | 50% | 800 – 2,400 | 40 | 60 | +0 |
| Silver | 26% | 2,400 – 6,000 | 60 | 120 | +2 |
| Gold | 14% | 6,000 – 18,000 | 100 | 250 | +4 |
| Platinum | 7% | 18,000 – 60,000 | 160 | 500 | +6 |
| Noir | 3% | 60,000 – 250,000 | 260 | 1,000 | +9 |

Pity: nine lots in a row below Gold guarantees the tenth is Gold or better.

## Screens

Five-slot tab bar — **Salon**, **Shows**, the rose-gold **Acquire** button, **Gallery**,
**Patron** — under a pinned HUD (level ring, title, XP, streak, purse).

- **Salon** — today's pick, commissions with claim buttons, the next show, recent finds.
- **Shows** — tier cards (rosette, venue, prize, XP, lock level) → team picker → match →
  verdict with rosette and rewards.
- **Gallery** — collection grid (search, marque filter, sort) and a showcase carousel.
- **Dossier** — coat-tinted hero, quick actions (Audience, Certificate, Shows), inline
  grooming per trait, curator's note, coat, provenance and show record.
- **Patron** — rose-gold membership card, record, rosette cabinet, marques held,
  exhibitions.

## Tech

SwiftUI + SwiftData (`Acquisition`, `Ledger`), zero dependencies, XcodeGen, iOS 18+;
iOS 26 adds Liquid Glass and Foundation Models (weak-linked). Pure, seeded game rules
(`Progression`, `Commission`, `Streak`, `Concours`, `Grooming`) are unit-tested; `Game`
wraps the ledger for the UI. Metal shaders for foil, dissolve, brushed metal and grain.
