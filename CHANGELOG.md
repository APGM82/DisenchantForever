# Changelog

## 1.44

- The button also offers the few items meant to be disenchanted for a reward of their own, such as the wax effigies for the enchanting quest at the Tower of Azora. It used to skip them. Their tooltip says they give their own items instead of listing the usual materials.
- The button remembers being hidden, per character: hiding it with /dis or the options window now lasts through a /reload or a relog.
- On characters without Enchanting the button starts hidden, and turns up by itself when the character learns it. Hiding or showing it yourself always wins.
- Showing, hiding or moving the button during combat no longer fails with "Interface action failed because of an AddOn": it happens as soon as combat ends.
- The button's tooltip pointed to /dis for the options, but /dis hides the button. It now says /dis options.

## 1.43

- Item tooltips show what disenchanting gives: each material with its chance and how many. The button's tooltip now names the item it is aimed at and shows the same.
- With Auctionator installed, each material shows its auction price, and the tooltip adds up the average value of disenchanting and says whether it beats selling to a vendor or at the auction house.
- New option to show or hide the materials, also with /dis tooltip.
- The button skips items the game will not let you disenchant, such as enchanter-made wands. It used to get stuck on them until you banned them.

## 1.42

- New look shared with the other Forever addons: the options window is dark glass with bronze lines, buttons have relief and a gold edge under the mouse, and ticks are gold.
- The disenchant button has a bronze frame and glows gold under the mouse.
- Arrows next to the ban list to scroll it up and down. The mouse wheel still works.

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
