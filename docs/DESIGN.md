# CatDex Maison — v2 design

> A private collection of extraordinary cats.

v1 was a playful trading-card game (yarn throws, foil packs, eggs, a den). v2 keeps
the core loop — **photograph a cat → it is lifted out of the photo → on-device AI
writes it up → it joins your collection** — and re-imagines it as a luxury house:
part auction catalogue, part couture atelier, part natural-history museum.

## Mood

- **Noir & champagne.** Onyx chrome, champagne-gold hairlines, ivory type. Dark by
  design; the only paper in the app is the certificate.
- **Editorial type.** Didot for display, New York italic for prose, tracked small caps
  for labels, Snell Roundhand for the curator's signature. All ship with iOS — no
  bundled fonts.
- **Light as a material.** Spotlights on plinths, a foil sheen that follows the
  phone's tilt (Core Motion), slowly breathing mesh-gradient backdrops built from
  each cat's own coat palette.
- **Every cat brings its own colour world.** The palette extracted from the cutout
  becomes that cat's backdrop, swatches and accents.
- **A game, not a website.** No instructional copy; affordances and progression
  (Patronage tiers, Exhibitions) carry the experience.

## The loop

1. **The Lens** — custom camera. On device, Vision watches the live feed and a gold
   reticle locks onto any cat it recognises (`FELIS CATUS · 94%`). Photo library too.
2. **The Appraisal** — a ceremony, not a spinner:
   - *Isolating subject* — Vision subject lift; the background dissolves away in a
     gold-edged burn (Metal shader). If lifting fails the photo is framed as an arched
     cameo instead — intentional, never broken.
   - *Reading the coat* — k-means palette over the cutout, each swatch named from a
     couture colour library ("Smoked Pearl", "Cognac", "Marmalade").
   - *Noting provenance* — on-device scene classification ("Drawing Room", "Garden")
     plus the hour ("Golden Hour", "Nocturne").
   - *Composing the dossier* — Apple Intelligence (Foundation Models, guided
     generation, streamed live) writes the name, epithet, Latin motto and curator's
     note. A seeded house writer covers devices without Apple Intelligence.
   - *Appraising* — marque roll + temperament + an estimate in guineas.
3. **The Unsealing** — the result arrives in an envelope closed with a wax seal whose
   colour hints at the marque. Tap the seal to crack it; the flap lifts and the lot
   card rises. Gold leaf for Gold and above.
4. **The Collection** — the cat is entered as the next lot number.

## Marques (rarity)

| Marque | Odds | Estimate (gns) | Treatment |
|---|---|---|---|
| Ivory | 50% | 800 – 2,400 | matte |
| Silver | 26% | 2,400 – 6,000 | cool sheen |
| Gold | 14% | 6,000 – 18,000 | gold foil, gold leaf |
| Platinum | 7% | 18,000 – 60,000 | iridescent foil |
| Noir | 3% | 60,000 – 250,000 | black lacquer, full foil |

Pity: nine lots in a row below Gold guarantees the tenth is Gold or better.

## Screens

- **Salon** (home) — wordmark, greeting, *Pièce du Jour* (a daily featured cat),
  the brushed-metal **Patron card** (tier, collection appraisal, progress), and
  **Exhibitions** (curated achievement sets as medallions).
- **Gallery** — two modes: **Salon Hang** (each cat on a plinth under a spotlight,
  3D carousel, floor reflection, tilt parallax) and **Catalogue** (lot grid, sort,
  search). Zoom transition into the dossier.
- **Dossier** — mesh backdrop, foil cutout, lot number + hallmark, Didot name,
  epithet, motto, drop-cap curator's note, temperament, palette, provenance table.
- **Certificate of Provenance** — ivory paper, procedurally drawn guilloche border,
  cameo, wax seal, curator signature; shareable as an image.
- **Audience** — converse with the cat in character (on-device LLM, streamed),
  written as correspondence.

## Tech

SwiftUI + SwiftData, zero dependencies, XcodeGen. iOS 18.0+; iOS 26 adds Liquid
Glass chrome and Foundation Models (weak-linked, availability-gated). Metal shaders
via SwiftUI `ShaderLibrary` (foil, dissolve, brushed metal, film grain). Core Motion
for tilt. `TextRenderer` glyph reveals. All AI runs on device.
