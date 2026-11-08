# Familiar Names — developer notes

A small, dependency-free World of Warcraft: Forever addon for personal player-name colours, visibility and markers. Targets interface **16001**. All changes are local to your screen.

## Install

1. Extract `FamiliarNames.zip` into the **Forever client's** `Interface\AddOns` directory. Use your launcher's **Show in Explorer** option to find the correct client folder.
2. Check the resulting path is `Interface\AddOns\FamiliarNames\FamiliarNames.toc`; avoid an extra nested folder.
3. Enable **Familiar Names** in the game's AddOns list and log in, or `/reload` if already playing.
4. Type `/names` or left-click the minimap button. The same panel appears under **Settings → AddOns → Familiar Names**.

Settings are saved per character. No other addon or library is needed.

## Names

- Separate visibility and colour settings for party members, guildmates, character friends and Battle.net friends.
- The highest visible matching category supplies the colour and automatic marker. Move categories with the priority arrows. For example, hiding party names still allows a party member's name through if they are also in an enabled friends category.
- Each category has its own **Hide plates** checkbox. It removes the entire native plate (health/cast bars, auras and level badge) while keeping the addon's enabled name. Pets inherit their owner's category rule. **Hide stranger nameplates** controls unknown friendly plates independently of their names, and **Hide pet / minion nameplates** also covers your own and enemy minions. Hiding a category's names, or enabling **Hide strangers**, always hides its plate too.
- **Hide strangers** hides unknown *friendly players*. Enemy players have an independent visibility setting, enabled by default, and optional custom highlighting, disabled by default.
- Player-owned pets, guardians, summons, totems and companions follow their owner's visibility rule. Ownership is resolved by GUID, including chains of summons. Party tokens and the guild roster retain membership when an owner is off screen; friends and Battle.net friends are matched directly by GUID. Unidentified friendly minions are hidden when strangers are hidden.
- Battle.net friends display their character names, not their BattleTags or account names.
- Adjust size, outline, vertical position, player titles and guild text. NPC names remain under Blizzard's control.
- “Party members” uses your actual party, including your party subgroup in a raid; it does not automatically include every raid member.

## Personal markers

Choose any of the eight familiar raid icons. These are addon textures, separate from shared raid markers. The addon never assigns a shared raid marker or sends addon messages.

- Choose an automatic icon beside any name category, including enemy players.
- Use the target toolbar in settings, right-click the minimap button, or type `/names mark skull` to mark a player or NPC.
- Manual markers take priority over automatic markers. **Clear target** suppresses that target's automatic marker too; **Clear all** removes manual overrides so category markers apply again.
- Marker size, vertical position and visibility when player names are hidden are configurable. Icons are offset sideways to stay separate from shared raid icons.
- Manual assignments identify the exact unit by GUID and last until logout or `/reload`. Different NPC spawns are separate units. Automatic category settings persist.

## Commands

| Command | Action |
|---|---|
| `/names` | Open settings |
| `/names on` / `/names off` | Enable or disable the addon |
| `/names minimap` | Show or hide its minimap button |
| `/names mark star` | Place a personal marker on your target |
| `/names mark 1` … `/names mark 8` | Choose by raid-icon number |
| `/names clear` | Clear/suppress your target's personal marker |
| `/names clearall` | Remove all manual overrides |

`/familiarnames` is an alternative prefix. Marker names: `star`, `circle`, `diamond`, `triangle`, `moon`, `square`, `cross`, `skull`. Drag the minimap button to reposition it. Escape dismisses its marker picker.

## Display limits and restoration

Custom overhead names require an accessible nameplate within the client's normal nameplate range. They are not character-model outlines or unrestricted world labels.

**Player customisation is deliberately suspended in all instances**, including dungeons, raids, battlegrounds, arenas and scenarios. This keeps Blizzard player names available where friendly nameplates or player identities may be protected. Custom names and player markers resume in the open world. Manual NPC markers can still appear on accessible NPC nameplates in instances.

The addon enables friendly player plates and temporarily manages these player settings:

- `UnitNameFriendlyPlayerName`
- `UnitNameEnemyPlayerName`
- `nameplateShowFriendlyPlayers`

It does not force Blizzard's global friendly names-only setting. Unchecked **Hide plates** boxes use Blizzard's current plate style; social categories default to hidden plates so enabled names remain uncluttered. Enemy plates remain visible by default.

While filtering pets, it also temporarily suppresses native player-minion labels (`UnitNameFriendlyMinionName`, and available pet/guardian/totem variants; the equivalent enemy values when enemies are hidden) and enables friendly player-minion plates. All values are saved before writes and restored when filtering is turned off. Known friendly pets get replacement names on accessible plates. Their names honour the original minion-name setting. Their owners' automatic markers are not copied to pets.

It saves their original values and restores them when switched off, on normal logout, or when entering an instance. CVar changes wait until combat ends. Ordinary NPC name and NPC nameplate settings are never changed.

**Companion labels outside accessible nameplates remain client-controlled.** Blizzard groups non-combat companion names with wild critters under `UnitNameNonCombatCreatureName`. This addon leaves that setting alone to preserve NPC visibility. It can filter a companion on an accessible plate, but cannot selectively suppress its native 3D label when no plate is exposed. Unknown or restricted ownership cannot establish a friend's identity; there is no name-based guessing or attempt to bypass protected data.

**Custom enemy names require enemy nameplates to be enabled in Blizzard's settings.** The addon does not enable them globally because that would also change NPC nameplates. Without an accessible plate, enemy highlighting and hiding cannot be guaranteed; default enemy names continue to use Blizzard's normal display. Restricted or secret identities are skipped. Hiding a name never changes target-frame names, tooltips, chat or other players' screens.

Switch the addon off with `/names off` **outside combat before uninstalling** so its previous player settings are restored. A normal logout also restores them.

## Code and validation

- `Core.lua`: defaults, category rules, local marker assignments, player-setting restoration and events.
- `Nameplates.lua`: pooled, mouse-transparent labels and icons; observes Blizzard name updates without replacing its functions.
- `Options.lua`: Blizzard Settings panel, colour picker, icon picker and minimap button.

The test suite executes the actual addon in **Lua 5.1** with a strict WoW API fixture:

```powershell
python -m pip install --target .tools lupa
python tests/run.py
```

Tests cover filtering, category overlap, Battle.net matching, default and custom enemy colours, marker priority, NPC isolation, restricted values, pooled nameplates, combat deferral, settings controls and restoration. They do not replace an in-game layout and compatibility check. This build has **not been run inside the Forever client**.

The pet regression matrix covers six unit types across strangers, your own units, party members, character friends, Battle.net friends and guildmates. Additional cases cover enemy pets, missing/secret owners, nested ownership, ownership cycles, guild changes, native refreshes and restoration.

The nameplate regression cases also check health/cast bars and level badges, independent category controls, native alpha refreshes, shared raid markers, plate reuse and combat restrictions. Hidden plates' click areas are cleared only when `CanChangeHitTestPoints()` permits it. If combat protects the click area, visual hiding still applies and click-area updates wait for a permitted update or combat ending. Restoration uses the current Blizzard layout. Shared raid icons are mirrored outside a hidden plate so existing assignments remain visible.

The README images are drawn illustrations of the controls and visibility rules, not in-game screenshots.

API references checked against Blizzard's published UI source, mirrored on the `forever` branch:

- [Forever nameplate settings](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua)
- [Nameplate lifecycle](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlateBase.lua)
- [Native name rendering](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua)
- [Protected nameplate click areas](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPINamePlateDocumentation.lua)
- [Friend and Battle.net APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/BattleNetDocumentation.lua)
