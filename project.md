# Kaizen

Kaizen is a macOS menu bar app for timed focus sessions. You name a block of work, pick how long it lasts, and a small clock stays on screen until the block ends.

## Stack

This is a native macOS app written in Swift. SwiftUI draws the menu and the timer cards. AppKit owns the menu bar extra and the floating panel. There are no third-party packages.

The app runs as an accessory, so it has no Dock icon. The checklist and preferences are JSON files in `~/Library/Application Support/Kaizen`.

## Menu bar

The menu bar icon is a timer glyph. It turns pink while a session exists, and stays the template color when nothing is running.

### Home

With no session, home shows the app name, a Start session button, a Checklist row, and Quit. The Checklist row shows how many tasks are still open.

During a session, home shows the session name, the time left, pause and stop, a position picker for the floating clock, and a Hide timer switch.

### New session

You type a name, then pick a duration. The presets are 10m, 30m, 1h, and 2h. Custom takes hours and minutes. A session has to be at least 1 minute and at most 8 hours. The last duration you used is filled in the next time you open this screen.

There is also a short checklist for tasks that belong to this session only. Start stays disabled until the name is non-empty and the duration is inside that range.

### Checklist

This is the list that sticks around between sessions. You can add a task, check it off, or delete it. Open tasks sit above a Done group. The list is saved to disk and reloaded on launch.

When a session ends, any session task you did not check is copied onto this list, unless the same text is already an open task.

## Floating timer

A borderless panel sits on the menu bar screen, above normal windows, and follows you across Spaces. The compact form shows the session name, the time left, and how many session tasks are still open. Hovering it opens the session checklist plus pause and stop. If you are typing in the add-task field, the panel stays open.

The position picker places that clock at the top or bottom, on the left, center, or right. Hide timer removes the panel until the session ends. Pause greys the clock but does not clear the session.

The clock stores a deadline. Sleeping the Mac and waking it does not make the remaining time drift.

## End of a session

Stopping, or letting the clock hit zero, flashes the timer pink and then dismisses it. If the timer was hidden, the session ends without the flash.
