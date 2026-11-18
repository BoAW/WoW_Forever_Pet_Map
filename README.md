# Pet Map

A World of Warcraft addon that shows where the beasts a hunter can tame are found, on the zone maps and the minimap.

Every tameable beast gets a small dot in the colour of its family, so you can tell cats from wolves and raptors at a glance. Point at a dot to see the beast's name, its levels, its family, and whether it is rare or elite.

## Features

- **Zone maps** - a coloured dot for each beast, in the colour of its family.
- **Minimap** - the beasts near you, in the same colours. The dots follow the minimap's zoom, indoors and outdoors, and turn with the minimap when Rotate Minimap is on.
- **One dot or every spawn** - one dot per beast in the middle of where it is found, or a dot for every spawn.
- **Rares** - show all hunter pets, only the rare ones, or only those that are not rare.
- **Families and beasts** - choose which families and which beasts in the zone to show. The choices apply to both maps.
- **Menu on the world map** - a button in the top right corner of the world map opens a menu with all the choices.
- **Options page** - the same choices are on the Pet Map page in the game's options.

## Installation

1. Download the latest release zip.
2. Unpack it into the game's `Interface\AddOns` folder, so the addon ends up in `Interface\AddOns\pet_map`.
3. Start the game, or type `/reload` if it is already running.

## How to use

1. Open the world map and go to a zone.
2. Point at a dot to see the beast.
3. Click the button in the top right corner of the map to change what is shown.
4. Tick **Show on minimap** in the same menu to see the beasts near you on the minimap. With the world map's dots set to Off, the minimap shows one dot per beast.

## Files

| File | What it does |
| --- | --- |
| `pet_map.toc` | The addon's name, version and the files it loads. |
| `pet_map.lua` | The dots on the zone maps, the button and menu on the world map, and the options page. |
| `minimap.lua` | The dots on the minimap. |
| `templates.xml` | The dot on the zone maps and a line of text on the options page. |
| `data/hunter_pets.lua` | The beast families and their colours, and the tameable beasts in each zone with their levels and spawns. |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
