# Disenchant Forever

**A button that always points at the next disenchantable item in your bags.**

Levelling a crafting profession means making hundreds of items you immediately
want gone. The stock way to disenchant is: open the spellbook or click the
spell, then find the item, then click it. Every single time.

Disenchant Forever collapses that into one click. The button shows the next
item it will destroy, and re-aims itself the moment the previous one is gone.

## One click per item — and why it cannot be fewer

The game deliberately stops addons from disenchanting on their own: only a real
click from you can cast a spell on an item. No addon can get around this, and
any that claims otherwise is lying to you.

What *can* be removed is the hunting and the aiming, and that is exactly what
this does. The button carries a ready-made `/cast Disenchant` + `/use <bag>
<slot>` pointed at the next candidate, and rebuilds it after every change to
your bags.

## Features

- **Auto-aim.** Always targeted at the next disenchantable item: weapons and
  armour of uncommon quality or better. Whites and greys are skipped, because
  they cannot be disenchanted at all, and so are the few items the game will
  not let you disenchant, such as enchanter-made wands.
- **Counter.** Shows how many candidates are left, so you know when you are done.
- **Ban list.** The red X banishes an item, and it never comes up again —
  neither that one nor any others of the same kind. Remembered between
  sessions, stored per character.
- **Quality filters.** Blues can be toggled off. **Epics are excluded by
  default**, so a one-click button can never eat something valuable by
  accident; turn them on deliberately if you want them.
- **What it turns into.** Hover over any weapon or armour and the tooltip
  lists what disenchanting it gives: each material, its chance and how many.
  The button's own tooltip names the item it is aimed at and shows the same.
  One switch in the options window (or `/dis tooltip`) turns the materials
  off everywhere.
- **Sell or disenchant?** With [Auctionator](https://www.curseforge.com/wow/addons/auctionator)
  installed, each material shows its auction price, the tooltip adds up the
  average value of disenchanting, and it tells you whether that beats selling
  the item to a vendor or at the auction house. Without Auctionator you still
  see the materials, just without prices. On WoW Forever, Auctionator itself
  only prices disenchanting for much later expansions, so it shows nothing
  here.
- **Movable and lockable.** Right-click drag to move, so the left click stays
  free for the thing you actually came for.
- **Combat-safe.** The game forbids changing a secure button's action mid-fight,
  so updates are deferred and applied the moment you leave combat.
- **A diagnosis command**, for when something misbehaves and you would rather
  see facts than guess.

## Options window

Everything can be driven from a window: checkboxes for the button, the
quality filters and the disenchanting materials, a live count of what is left,
and the ban list with a cross on each row so you can let a single item back in.
Open it with the small gear on the button, or with `/dis options`.

The window is built from plain frames and textures rather than Blizzard's
widget templates, so a template that happens not to exist on a given client
cannot stop the addon from loading.

## Commands

Responds to `/dis`, `/disenchant` and `/di`.

**The commands are English on every client.** Only the explanations are
translated, never the word you type — so a guide, a forum answer or a
screenshot from another player works whatever language you play in.

| Command | What it does |
| --- | --- |
| `/dis` | Show or hide the button |
| `/dis options` | Open the options window |
| `/dis ban` | Ban the item shown — same as the red X |
| `/dis list` | See what is banned |
| `/dis clear` | Empty the ban list |
| `/dis blues` | Include or exclude blue items |
| `/dis epics` | Include or exclude epics (off by default) |
| `/dis tooltip` | Show or hide the disenchanting materials |
| `/dis lock` / `/dis reset` | Fix the button in place, or put it back |
| `/dis status` | Report what the addon can see, for diagnosis |

## Languages

Translated into **all ten WoW client languages**: English, Spanish, German,
French, Italian, Portuguese, Russian, Korean, and Simplified and Traditional
Chinese. That covers the interface, the tooltips, the options window and the
chat messages, as well as the description shown in the AddOns list.

A client in a language that is not on the list falls back to English rather
than showing something half-translated.

Translations live in their own file, one block per language, so adding one is
text only — no code to touch.

The output of `/dis status` deliberately stays in English: it exists to be
pasted into a bug report, and it is more use to whoever reads it that way.

The internals never depend on language at all. Items are identified by class
and item ID, and the spell by its ID — never by name — so the addon works the
same on any client, translated or not.

## Compatibility

Built and tested for **World of Warcraft: Forever**, build 1.60.1
(`Interface: 16001`).

Note that Forever runs Classic content on a modern interface codebase, so
several APIs live where retail keeps them rather than where Classic did. This
addon resolves each one wherever it exists instead of assuming, and says so
plainly if something is missing rather than failing silently.

## Where the disenchanting numbers come from

The game client knows which bracket an item falls into (by item level,
quality and weapon or armour) but not what each bracket gives: that lives on
the server. The brackets come straight from the WoW Forever client. The
materials, chances and amounts come from
[vmangos](https://github.com/vmangos/core), which reproduces Classic 1.12, and
were checked against [cmangos](https://github.com/cmangos/classic-db). The two
disagree in only two small places, which are noted in the code.

Forever added one bracket that Classic never had: blue items of item level 5
to 15. Nobody has published what they give yet, so the tooltip marks that
line as unconfirmed and does not price it.

Items the client marks as impossible to disenchant (PvP rank rewards and
enchanter-made wands, for example) show nothing, and the button skips them.
The game does not expose that mark to addons, so the list ships with the addon
and is regenerated from the client data after each patch with
`herramientas/actualizar_datos.py`.

## Installation

1. Extract the `DisenchantForever` folder into
   `World of Warcraft\_forever_\Interface\AddOns\`
2. Restart the game completely — a reload is not enough for a new addon.
3. Make sure it is ticked in the AddOns list on the character screen.

## Notes

- You need the Enchanting profession. Obviously.
- If a confirmation box appears when destroying an item, you have to accept it
  yourself. That one is not something an addon is allowed to touch either.

## License

MIT — see [LICENSE](LICENSE).
