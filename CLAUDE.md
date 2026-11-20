# PipCount (ScoreKeeper) — rules for agents

PipCount is a native SwiftUI + SwiftData app for iPhone and iPad (iOS 26+).
Users keep score for card and board games. They write each round's score by hand.

Read `Learnings.md` for project context, build commands and past decisions.
This file covers the design system. Follow it for every UI change.

## The 5 rules

1. Use only **role tokens** for color. Never use a palette color, a hex value or an Apple system color in feature code.
2. Use only **AppFonts**, **AppTheme** spacing and radius, and **AppMotion**. Never type a number for a font size, a gap, a padding or a corner.
3. Use an **existing component** before you build a new one. See "Components" below.
4. A component must not take a free `Color`. It takes a `PipTint` or a small enum.
5. Before you say the work is done, run `swiftlint lint --strict --baseline .swiftlint-baseline.json` and fix every error. CI runs the same check.

## Where the tokens live

| What | Swift | File |
|---|---|---|
| Color | `ClubhouseTheme.<role>` | `ScoreKeeper/Theme/ClubhouseTheme.swift` |
| Game, round and player tints | `PipTint` | `ScoreKeeper/Theme/ClubhouseTheme.swift` |
| Seat colors | `PipTint.seats`, `PlayerColors` | `ScoreKeeper/Theme/PlayerColors.swift` |
| Type | `AppFonts.<style>` | `ScoreKeeper/Theme/AppFonts.swift` |
| Space, radius, widths | `AppTheme.<token>` | `ScoreKeeper/Theme/AppTheme.swift` |
| Motion | `AppMotion.<value>` | `ScoreKeeper/Theme/AppTheme.swift` |

The PipCount Component Library page uses the same names in CSS form
(`accentPrimary` in Swift is `--accent-primary` on the page).

## Color: role tokens

A role token names a **job**, not a look. Pick the token by what the thing does.

| Role token | Use it for | Do not use it for |
|---|---|---|
| `surfacePage` | The page behind everything | Cards |
| `surfaceCard` | Cards, sheets, rows | The page background |
| `surfaceSunken` | Wells, tracks, input backgrounds | Raised cards |
| `surfaceRaised` | Popovers and menus above cards | Normal cards |
| `textPrimary` | Body text, titles, icons | Text on a blue, red or yellow fill |
| `textSecondary` | Subtitles, hints, column headers | Important values |
| `textOnAccent` | Text on `accentPrimary` or `accentDanger` fills | Text on yellow |
| `textOnHighlight` | Text on `accentHighlight` (yellow) fills | Text on blue or red |
| `textOn(_ tint:)` | Text on any `PipTint` fill | — |
| `textLink` | Links inside text | Buttons |
| `borderHairline` | Rules between rows, card edges | Focus |
| `borderStrong` | Strong dividers, selected outlines | Normal row rules |
| `borderPanel` | Panel edges | — |
| `borderWood` | The wood edge decoration | Plain borders |
| `borderFocus` | Keyboard focus rings | Selection |
| `accentPrimary` | The one main action on a screen, selected chips and tabs | More than one main button per screen |
| `accentPrimaryStrong` | Pressed state of `accentPrimary` | Resting state |
| `accentDanger` | Actions that delete or end something | Decoration, losing players |
| `accentLacquer` | Red decoration: stamps, starbursts | Warnings and errors |
| `accentHighlight` | Yellow buttons, highlight marks | Text |
| `accentLeader` | The player in first place: crown, score, outline | Anything else |
| `shadowCard` | Card shadows | — |
| `shadowArt` | Shadows inside artwork | Cards |
| `effectSheen` | The small top highlight on paper | — |
| `artBackdrop` | The area behind tile artwork | Cards |

### Palette names (blue, red, yellow, green, sky, coral, lilac, blueDeep)

The palette is raw. It feeds the role tokens. Palette names may appear only in:

- files in `ScoreKeeper/Theme/`
- artwork files (`*TileArt.swift`, artwork previews, confetti)
- `PipTint`, when a component needs a game, round or player color

### Old name → role name

Old names still compile, but lint blocks them in new code.

| Old | New |
|---|---|
| `paper` | `surfacePage` |
| `paperCard` | `surfaceCard` |
| `paperSunken` | `surfaceSunken` |
| `paperElevated` | `surfaceRaised` |
| `ink` | `textPrimary` |
| `inkMuted` | `textSecondary` |
| `rule` | `borderHairline` |
| `ruleStrong` | `borderStrong` |
| `onPrimary`, `onFelt` | `textOnAccent` |
| `onYellow` | `textOnHighlight` |
| `onButton(_:)` | `textOn(_:)` with a `PipTint` |
| `felt`, `primaryFill`, `blue` | `accentPrimary` (or `textLink`, `borderFocus`) |
| `feltDeep`, `blueDeep` | `accentPrimaryStrong` |
| `danger`, `red` (for delete or end) | `accentDanger` |
| `lacquer`, `red` (for decoration) | `accentLacquer` |
| `yellow` | `accentHighlight` |
| `brass` | `accentLeader` |
| `panelBorder` | `borderPanel` |
| `woodgrain` | `borderWood` |
| `paperShadow` | `shadowCard` |
| `artShadow` | `shadowArt` |
| `warmHighlight` | `effectSheen` |
| `sky` | `artBackdrop` |

If no role fits, do not invent a color. Add a new role token to `ClubhouseTheme.swift`,
add it to the Component Library page, and say so in your summary.

## Type, space, shape, motion

- **Type:** `AppFonts.display`, `hero`, `largeTitle`, `title`, `tileTitle`, `headline`, `body`, `label`, `caption`, `columnHeader`, `scoreDisplay`, `scoreMedium`, `scoreSmall`. Use `.columnHeaderStyle()` for column headers. Score digits use monospaced numbers. Display copy is lowercase ("scoreboard", "rounds").
- **Space:** `AppTheme.spacingXSmall` 6, `spacingSmall` 10, `spacingMedium` 16, `spacingLarge` 24, `spacingXLarge` 32, `spacingXXLarge` 44. `0` is allowed.
- **Radius:** `AppTheme.cornerRadiusSmall` 12, `cornerRadiusMedium` 18, `cornerRadiusLarge` 28, `cornerRadiusXLarge` 36.
- **Width:** content stops at `AppTheme.contentMaxWidth` (1,080) on iPad, forms at `formMaxWidth` (760). Phone layouts go edge to edge.
- **Motion:** `AppMotion.pressIn`, `pressOut`, `fade`, `state`, `page`, `theme`, `criticallyDamped`, `celebration`, `artEntrance`, `artExit`. Under Reduce Motion, use a fade.

## Components

Use these before you make anything new. Files are in `ScoreKeeper/Views/Components/` unless noted.

| Component | File | Use it when | Do not use it when |
|---|---|---|---|
| `.scorecardSurface(...)` / `ScorecardSurface` | ClubhouseComponents.swift | Any card. Paper, hard offset shadow, hairline, top highlight | You need a sheet or a full page |
| `AppActionButton` | AppSurfaces.swift | Main full-width actions, 56 pt tall. Roles `.primary`, `.secondary`, `.destructive` | Small inline actions (use `PaperChip`) |
| `PressableButtonStyle` | PressableButtonStyle.swift | Any tappable card. Gives the shared press feel | Plain text links |
| `PaperChip` | ClubhouseComponents.swift | 38 pt choice capsule. Selected fills `accentPrimary` | A main action |
| `StampBadge` | ClubhouseComponents.swift | Marks a finished state, for example final standings | Live status or errors |
| `PlayerBadge` | PlayerBadge.swift | A player's shape plus name. Sizes `.small` 32, `.medium` 44, `.large` 64 | Plain lists without a player mark |
| `BauhausPlayerShape` | ClubhouseComponents.swift | The seat shape for a player | — |
| `BrassCrown` | ClubhouseComponents.swift | Next to the leader's name or score only | Any other "best" mark |
| `BauhausStarburst` | ClubhouseComponents.swift | Decoration for wins and celebrations | Warnings |
| `StandingsList`, `LedgerRow` | StandingsList.swift, ClubhouseComponents.swift | Rank, mark, name and score on a ruled line. Winner row gets a 12% seat wash, crown, leader score | Score entry |
| `ScoreCard`, `ScoreboardHeader` | ScoreCard.swift, ScoringComponents.swift | One card per player in the scoring header, scrolled sideways | Standings after the game |
| `RoundBanner` | ScoringComponents.swift | Round title with a diamond in the game tint and a muted note | Section titles (use `AppSectionHeader`) |
| `RoundHistoryStrip` | ScoringComponents.swift | 140 pt round cards in a sideways strip | Lists of games |
| `GameTypeTile` | GameTypeTile.swift | Artwork, game name and player range for one game type | Anything that is not a game type |
| `ReleaseSheetHeader` | AppSurfaces.swift | Header of a tool sheet, with a tinted icon well | Page sections |
| `AppSectionHeader` | AppSurfaces.swift | Headline section title, optional symbol and subtitle | Sheet headers |
| `PipCountIsland`, `PipCountIslandButton` | AppSurfaces.swift | Navigation on wide windows (iPad, Duo). Replaces the tab bar | Phones in compact width |
| `PipCountPaperBackground` | Theme/AppTheme.swift | The page background | Cards |

### Rules for new components

- Take a `PipTint` (or a small enum) for color. Never `let tint: Color` or `var color: Color`.
- Take an enum for size and style (like `PlayerBadge` sizes), not raw numbers.
- Keep tap targets at 44 pt or more.
- Support Dynamic Type up to accessibility sizes. Support light and dark mode, Reduce Motion and Reduce Transparency.
- Never show a player by color alone. Use the seat shape or glyph too.
- Add the new component to the Component Library page with "use it when" and "do not use it when".

## Lint and CI

- Rules: `.swiftlint.yml`. Every rule message says what to use instead.
- Old code is listed in `.swiftlint-baseline.json`, so it does not fail. If you change a line that has an old violation, fix that line too.
- Do not edit `.swiftlint-baseline.json` to hide a new violation. Do not add `swiftlint:disable` comments unless the user agrees.
- CI: `.github/workflows/pipcount-design-lint.yml` runs on every pull request to `main`.
