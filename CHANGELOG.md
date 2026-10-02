# Changelog

## 1.41

- Fixed the ban list spilling out of its box when it held more than a few items.
  It now shows five at a time; scroll with the mouse wheel to see the rest.

## 1.40 — First release

A button that always points at the next disenchantable item in your bags.

**One click per item.** The game does not let addons disenchant on their own, so
what this removes is the searching and the cursor aiming, never the click.

### What it does

- Auto-targets the next eligible item: weapons and armour of uncommon quality or better
- Counter showing how many candidates are left
- Ban list — skip an item type for good, remembered per character
- Quality filters: blues optional, epics excluded by default so a one-click
  button can never eat something valuable by accident
- Options window with checkboxes, a live count and an editable ban list
- Movable, lockable button
- `/dis status` prints a diagnosis when something misbehaves

### Languages

Translated into all ten WoW client languages: English, Spanish, German, French,
Italian, Portuguese, Russian, Korean, and Simplified and Traditional Chinese.
Anything else falls back to English. Commands are English on every client — only
the explanations are translated, so a guide or a forum answer works whatever
language you play in.

### Compatibility

Built and tested for WoW Forever 1.60.1 (`Interface: 16001`).
