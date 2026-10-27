# Duo and paywall reconciliation

The integration branch preserves the complete `codex/duo-twin-islands-paywall` history on top of main `989e535a` through a merge commit. The source worktree and the main worktree remain unchanged.

## Preserved changes

| Commit | Scope |
| --- | --- |
| `1ec87fc3` | Twin Islands navigation, adaptive layout, typography and contrast |
| `09a8f14a` | Shared entitlement, access gates, trial, gift, notifications and quick action |
| `016cbb15` | Root status capsule, full-screen covers and loaded-product plans |
| `79f12c12` | Paywall, sheet and scroll clearance |
| `d9ebb0ac` | Pro rows and fresh-user coverage |

`StoreManager` remains the single entitlement owner. The shared `PaywallRoute` controls presentation. Fresh users have no free starts. Existing users retain their remaining allowance, and existing legacy unlocks remain valid. An exhausted allowance gates a new game or rematch while keeping existing games, history and statistics accessible.

The Duo keeps its bottom trailing navigation island and non-interactive top status capsule. Compact layouts retain native tabs. Navigation paths and score-entry state stay in their existing owners. This reconciliation does not port the web handwriting prototype into the native app.

## Integration repairs

- Replace the old XCTest scheme job and simulator smoke script with the required TesterArmy acceptance gate
- Run one simulator at a time through SimSlim, retain required purchase and notification services, and validate test cleanup
- Replace the stale paywall-art requirement with checks for shared routing, loaded plans and essential controls
- Give a missing gift product an explicit unavailable message even when another product loads
- Use complete paywall and notification sentences without sentence-ending full stops
- Add native scoring, Undo, last-allowance, rematch and rotation acceptance cases
- Read fields before opening the iPad number pad and dismiss its native popup before asserting the score

The committed runner is `scripts/run_native_acceptance.py`. Its default iPhone/iPad matrix runs sequentially. It refuses unrelated booted devices, preserves evidence and never erases or deletes a device. See `tests/README.md` for focused and Duo runs.

The iPhone/iPad rotation gate measures the full-screen paywall frame in each requested orientation and retains a screenshot. The mobile engine can return a portrait-sized PNG containing sideways landscape content, so PNG dimensions alone cannot establish the app's orientation. The longer scoring, Undo and rematch case has a ten-minute limit because the hosted runner exceeded five minutes while still completing successful input assertions. Exact score, Undo and rematch assertions remain unchanged. CI allows sixty minutes for the sequential device matrix and build.

## Verification boundaries

Native build, static checks and runtime results are separate evidence. Access-state launch arguments use isolated in-memory storage. They verify app routing and access decisions, but do not replace StoreKit transactions or persistent-storage migration checks.

The local StoreKit catalog is retained. A command-line app launch does not activate the scheme's Run configuration. Product availability in these acceptance runs depends on the simulator's StoreKit environment. Annual pricing, introductory eligibility, purchase, restore, renewal, refund, billing grace, notification delivery and cold/warm Home Screen actions require their own OS-level acceptance before release. The production price relationship behind the gift claim must be verified in App Store Connect.

Current-pose Duo results do not prove folding. A fold run must change the hinge pose and retain the active route and score draft. If CoreDevice cannot report the hinge angle, record that as an environment blocker.

The reconciliation run verified a manual score of 46 through closing and reopening the Duo, then cancelled entry and confirmed the original saved totals of 7 and 9. The inner landscape viewport was 951 × 669. The driver acknowledged both orientation requests without changing that viewport, so the required 669 × 951 inner portrait check remains open. The exact-size assertion remains in `tests/native-glass-duo-poses.e2e.ts`; it is not replaced by a current-pose pass. The driver project records the same orientation limitation in [issue 2774](https://github.com/callstack/agent-device/issues/2774).

Some Duo captures also report a 669 × 951 accessibility viewport while the screenshot is 951 × 669. This can omit visible trailing controls from the test tree. The runtime pins e2e 0.21.3, mobile 0.12.4 and agent-device 0.21.32, with one shared driver resolution. The patch improves floating-bar and keyboard handling, but the remaining pose/viewport mismatch is still an acceptance limitation. Current-frame native input retains exact destination, score and visibility assertions; it does not turn missing-control checks into passes.
