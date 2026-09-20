# Project Istiqamah design system

The interface is calm by default and becomes visibly active when the user is
taking action. Green is reserved for primary actions, progress, and completion;
neutral surfaces carry the rest of the hierarchy.

## Semantic palette

| Role | Light | Dark |
| --- | --- | --- |
| Primary | `#356B5B` | `#8FD3B8` |
| Primary pressed | `#285548` | `#A8E4CA` |
| Background | `#F7F8F6` | `#0D1110` |
| Surface | `#FFFFFF` | `#151B19` |
| Elevated surface | `#F0F3F0` | `#1C2421` |
| Primary text | `#17201D` | `#F2F5F3` |
| Secondary text | `#68736F` | `#9DAAA5` |
| Tertiary text | `#929B97` | `#6F7B76` |
| Border | `#DDE3DF` | `#29332F` |
| Divider | `#E8ECE9` | `#202925` |
| Completed | `#3E8E70` | `#72C7A4` |
| Success | `#31805F` | `#6DCA9F` |
| Warning | `#B9853B` | `#E2B96D` |
| Error | `#B95353` | `#F07F7F` |
| Info | `#547D91` | `#82B8D0` |

All application colors are exposed as semantic values in `Sources/App/Theme.swift`.
Views should use a role such as `secondaryText` or `warning`, not embed a new
hex value. Light and dark variants resolve automatically from the system appearance.

## Usage rules

- Use `background` for screen canvases, `surface` for primary cards, and
  `elevatedSurface` for controls or nested emphasis.
- Use `primary` for the main action and active progress. Use `completed` for
  finished work so action and completion remain visually distinct.
- Use status colors only when they communicate state. Upcoming content uses
  `info`; missed or unfinished content uses `warning`; destructive failures use
  `error`.
- Prefer primary, secondary, and tertiary text roles over opacity changes.
- Cards use continuous 22-point corners, a one-point semantic border, and a
  restrained adaptive shadow.

## App icon

`assets/images/icon.png` is a full-bleed 1024 × 1024 RGB PNG. It uses the same
deep green, mint, graphite, and warm-white identity as the interface. Keep the
source square and unmasked; iOS applies the device-appropriate icon shape.
