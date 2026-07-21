# Native editor recovery

## Repeated error

Computer Use returned `noWindowsAvailable` twice while coordinate-clicking the second Rive document tab. Read-only state capture by bundle ID continued to work, so the live file and Rive MCP were not treated as disconnected.

## Primary-source alternatives considered

1. Target the desktop editor by its bundle ID and raise its exposed standard window before acting.
2. Use keyboard tab navigation instead of coordinate clicking; Rive documents keyboard-driven tab navigation in its editor surfaces.
3. Use the Rive web editor, which Rive documents as feature-equivalent to the desktop editor.
4. Use the active-artboard and Animate-mode UI after switching tabs; Rive documents that the timeline follows the active artboard.
5. Relaunch the pre-existing desktop editor only if window recovery fails; Rive documents a restart/reconnect recovery path.

## Chosen recovery

Use the already-running desktop editor by exact bundle ID, invoke its exposed `Raise` window action, and use keyboard tab navigation. This is the smallest read-only recovery and avoids login/profile ambiguity in the browser editor.

Sources:
- https://rive.app/docs/editor/get-rive
- https://rive.app/docs/editor/interface-overview/overview
- https://rive.app/docs/editor/keyboard-shortcuts
- https://rive.app/docs/editor/fundamentals/artboards
- https://www.rive.app/changelog/marquee-zoom-manage-share-links-and-new-keyboard-shortcuts
