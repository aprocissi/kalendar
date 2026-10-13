# Milestone 6 — Polish

Spec: `docs/SPEC.md` §3, §11, §12, §14, §17 item 6. Earlier milestones are in git history.

- [x] `Preferences`: one observable store for every setting, backed by UserDefaults (§12 defaults from §2)
- [x] General: shortcut recorder (re-registers the Carbon hotkey), default calendar, default task list, default event duration, start week on, day starts (new timed slots), play UI sound, go to today after adding, show alerts, updates
- [x] Appearance: menu bar icon (icon only / date / next event title / next event + countdown), color icon, text size (small / normal / large), theme (system / light / dark)
- [x] Events & Tasks: list shows (7 / 14 / 30 / all days), show when events end, show declined events (list only; the grid never dots them), combine identical events, dim past items, show tasks in list, show completed tasks, sort tasks by
- [x] Calendars: calendar checklist by account (Google `selected`), task-list checklist by account (local)
- [x] Shortcuts (§11) not yet handled: ⌘N, ⌘E / ⌘I, ↑ / ↓ selection, Enter opens the selection, ⌘↓ from search to the first result
- [x] Accessibility: labels on every icon-only control, task rows, VoiceOver on the grid (selected state, tasks due)
- [x] Offscreen snapshot mode (`-renderSnapshots <dir>`) to check light/dark and text sizes without taking focus
- [x] Tests for settings-driven logic in Core; build, tests, snapshots

## Review
- `Preferences` holds every §12 setting; changes reload the agenda, redraw the menu bar item, reschedule alerts and re-register the hotkey.
- Fonts go through `Font.ui`, scaled by Text size; the Mini Window grows with it.
- Snapshots (`.build/shots/m6`): popover light/dark × small/normal/large, all five Settings tabs, menu bar glyphs. Rendered in an off-screen non-activating panel.
- Declined events: no grid dot ever (user request); in the list only with Show declined events, drawn ⊘.
- No new Core logic, so no new unit tests; 91 pass.

## Review: interactive UI test (2026-10-12)

Run against dev builds with cua-driver (AX actions and per-process key events), a few real HID clicks, and real Google writes on the "test" calendar and throwaway "Kalendar test …" tasks. Branch `ui-test-fixes` fixes the bugs below.

### Fixed on `ui-test-fixes`
- **Location suggestions after retyping:** typing `at Tar`, clearing, and typing `at Tar` again showed no suggestions. `PlaceSearch` cancelled the completer but left its `queryFragment` at "Tar", and MKLocalSearchCompleter ignores an unchanged fragment. Clearing now resets the fragment.
- **Esc in a form field:** with focus in the location field, Esc closed the popover and skipped the discard dialog. Only the input field had `.onExitCommand`. The popover's key monitor now sends Esc and ⌘. to `escape()` from any field, except while an input method is composing text.
- **Discard and scope dialogs closed the popover:** when the §8.3 or §8.1 alert took key, the transient popover closed, so Cancel returned to nothing. `popoverShouldClose` now returns false while a modal window is up.
- **End date showed a stale value:** the "ends" DatePicker had `in: d.start...`. When the start moved earlier, NSDatePicker clamped the end to the old start and displayed it (seen as 11/13 7:00 AM while the model held 10/13 8:00 AM); editing the end then would write the clamped value. The picker keeps the range and is rebuilt (`.id(d.start)`) when the start changes. Removing the range instead would let a half-typed end (each segment commits) move the start.
- **Theme had no effect on the popover:** Light turned the Settings window light but the popover stayed dark. An NSPopover takes its appearance from the status item it is shown from. The popover now observes `NSApp.effectiveAppearance` (KVO), which covers a Theme change and, with System, the system switching between light and dark.
- **All-day pills did nothing on click:** they had no tap gesture or context menu, and VoiceOver saw static text. They now open the detail on click and have the event context menu, like timed rows.
- **Unnamed form controls:** the all-day checkbox and the starts, ends, repeat-until, due-date and Go to Date pickers had empty labels, so VoiceOver read them without a name. They now carry their row's name (still visually hidden).

Verified in the running fix build: each case above, plus `swift build -Xswiftc -warnings-as-errors` and 94 tests.

### Passed
- New item: location (↑↓, Tab, Enter accept), contact and `/calendar` suggestions; Esc sequence (hide, clear, close); × with and without hand edits, Cancel and Discard; double-click a day then `Gym 6pm` dates the form that day; `/test … tomorrow 7am` + Enter adds to "test", clears, returns to today after ~2 s; `todo … tomorrow 3pm` shows the task form with "Google Tasks stores dates only"; ▣ | ✓ toggle.
- Keyboard: ↑↓ selection with a multi-day event as one stop; Enter, ⌘E, ⌘I; ⌫ then ⌘Z restores in place; ⌘N; ⌘F, ⌘↓; ⌘T; ← → months; ⇧ arrows by day and week; ⌘R and ⌘3.
- Tasks: circle checkbox complete and uncomplete; task menu Complete, Move to List, Delete.
- Event menu: Color, Show As, Duplicate, Duplicate as Task, Delete.
- Detail: title and time edits reach Google on close; §8.1 on a recurring "test" event: Only This Event changes one instance; All deletes the series.
- Settings: every tab responds; text size applies immediately; menu bar styles including "Kalendar test alert in 4m"; shortcut recorder record, Esc, Reset, then ⌃⌥Space opens the popover; Show declined events adds ⊘ rows and leaves grid dots unchanged.
- Alerts: banner title and "4:51 – 5:21 PM · Room 4, https://zoom.us/j/…"; actions Show Details, Snooze 5 Minutes, Join, Close.
- Sparkle: v0.1.0 → Check for Updates… → Install Update → Install and Relaunch; the app's Info.plist reads 0.1.1 (build 2), notarized.
- VoiceOver: status item "Kalendar, Monday, October 12, 2026" (plus "next: … in 4m" with the countdown style); grid days "Monday, October 5, 2026, 6 events"; task rows "Task, pay office rent, overdue, due Oct 1, 2026"; toolbar Search, Previous month, Next month, View, Calendars, Actions; declined rows start with "Declined".

### Not tested
- **Snooze 5 Minutes and clicking the banner.** Kalendar's banners were presented (usernoted log) but did not appear in Notification Center's AX tree, except once while a persistent Fantastical alert was stacked. No action could be performed on them.
- **Task menu Duplicate as Event.** It always writes to the task account's primary calendar (`AgendaModel.defaultCalendar`, which ignores the Default calendar setting), and events may go only to "test".

### Other findings (not changed)
- Enter with no suggestion list showing adds the item. An early test added an all-day "Coffee" to darrin@massena.com this way; it was deleted within a minute.
- After a delete, the same event stays visible until the next sync when another account also caches that calendar (darrin@playful.software caches darrin@massena.com).
- ⌘T scrolls to today but keeps the old selection, so the next ↓ continues from an off-screen row.
- The app has no icon: `scripts/bundle.sh` copies `Resources/AppIcon.icns` only if present, and the repo has none. Alerts show a blank icon; §8.1 calls for the app icon.
- The event context menu offers Color, Show As and Delete on read-only calendars (Columbus Day on Holidays).
- While another app holds ⌃⌥Space (Fantastical did), recording a shortcut leaves Kalendar's hotkey dead until relaunch, because Kalendar unregisters during recording.
- A release build run with `CFFIXED_USER_HOME` still reads the real `com.massena.kalendar` preferences (cfprefsd ignores it), so it finds the accounts and waits on a keychain prompt. The Sparkle test used `-accounts '()'` instead.

### State after testing
All test events and tasks are deleted; "test" is hidden again; preferences match the pre-test export byte for byte; the global shortcut is ⌃⌥Space.
