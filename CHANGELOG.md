# Changelog

## Unreleased

- **Let Apps and Agents Type and Click** (While Closed menu): with Accessibility access,
  only the physical keyboard, trackpad and mouse are blocked while the curtain is closed,
  and only a physical Esc opens it. Clicks and keystrokes posted by software, such as
  automation and AI agents, reach the apps behind the curtain. Without the access, all
  input is blocked as before.

## 0.1.0 — 2026-10-01

First release.

- Menu bar app with no window and no Dock icon. **Close Curtain** from the menu or
  with Control–Option–C turns the screen black and the keyboard light off while the
  Mac keeps running. **Esc** brings both back exactly as they were.
- Covers every display, above the menu bar, the Dock, full-screen apps and
  notifications. Keys, clicks and the pointer are swallowed while it is closed, and
  Command–Tab is blocked.
- Takes built-in and Apple displays to zero brightness and turns the keyboard
  backlight off, pausing auto-brightness so the light sensor cannot turn it back on.
  Your levels and auto-brightness settings are restored when it opens.
- Keeps the Mac awake while closed, so it neither sleeps nor locks behind the
  curtain (can be turned off in the menu).
- Safe to quit or kill: a logout or `kill` restores the lights before exiting, and
  after a crash the next launch puts them back.
- Launch at Login from the menu.
