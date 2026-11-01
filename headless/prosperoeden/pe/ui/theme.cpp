// ProsperoEden - The launcher's themes, and which one is in use.
// Copyright (C) 2026 BlackBearReloaded
// SPDX-License-Identifier: GPL-3.0-or-later

#include "pe/ui/theme.hpp"

#include "pe/core/strings.hpp"

#include <array>
#include <cstdint>

namespace pe::ui
{

namespace
{

Color rgb(std::uint32_t hex, float alpha = 1.0f)
{
    return Color::rgb(hex, alpha);
}

// Slate: neutral glass, clean and still.
Theme slate()
{
    Theme t;
    theme_from_kit("acrylic", &t);
    t.id = "slate";
    t.name = "Slate";
    t.summary = TR("Neutral glass, clean and still.");

    t.base = rgb(0x101012);
    t.scrim = rgb(0x080809);
    t.glass = rgb(0x1c1c20);
    t.panel = rgb(0x141416);
    t.panel_edge = rgb(0x3a3a3e);
    t.row = rgb(0x1e1e22);
    t.row_edge = rgb(0x34343a);
    t.row_focus = rgb(0x2c2c32);

    t.accent = rgb(0xc0bbb6);
    t.accent_deep = rgb(0x3a3836);
    t.accent_pale = rgb(0xdedbd8);
    t.on_accent = rgb(0x101012);
    t.highlight = rgb(0xe8e4e0);

    t.text = rgb(0xeae8e6);
    t.title = rgb(0xf2f0ee);
    t.value = rgb(0xe6e4e2);
    t.body = rgb(0xd0cecc);
    t.copy = rgb(0xb0aeac);
    t.meta = rgb(0x98969a);
    t.label = rgb(0x88868a);
    t.muted = rgb(0x78767a);
    t.faint = rgb(0x585660);
    t.warning = rgb(0xe0685e);
    t.rule = rgb(0x34343a);

    t.size_hero = 64.0f;
    t.size_display = 38.0f;
    t.size_heading = 28.0f;

    t.focus_glow = 18.0f;
    t.shadow_blur = 36.0f;
    t.shadow_offset = 14.0f;
    t.pill_chips = true;
    t.motes = 0;
    t.drift = 0.0f;

    t.list_settings = true;
    t.game_backdrop = false;
    t.minimal_home = true;
    t.top_nav = true;
    t.scrim_opacity = 0.92f;
    t.game_page_offset = 60.0f;

    t.backdrop = "slate-backdrop.tga";
    t.backdrop_blur = "slate-backdrop-blur.tga";
    t.brand = "brand.tga";
    t.light_x = 0.5f;
    t.light_y = 0.4f;
    return t;
}

// Canopy: the launcher's default look and the one a part missing from any other theme falls back
// to. Eglantine recolours it pink (rose glass over a plum dusk). It keeps the id "canopy" so the
// theme saved in /data/prosperoeden/config is still understood here and by ProsperoEden.
Theme canopy()
{
    Theme t;
    // The kit's frosted glass: translucent panels over the artwork, soft shadows, a ring of light
    // for the focus, movement that settles without a bounce.
    theme_from_kit("acrylic", &t);
    t.id = "canopy";
    t.name = "Eglantine";
    t.summary = TR("Pink dusk, rose glass and blush.");

    t.base = rgb(0x0c0709);
    t.scrim = rgb(0x080406);
    t.glass = rgb(0x25141c);
    t.panel = rgb(0x180d13);
    t.panel_edge = rgb(0x9a6f80);
    t.row = rgb(0x2a1822);
    t.row_edge = rgb(0x8a5f70);
    t.row_focus = rgb(0x4a2536);

    t.accent = rgb(0xf2a1c4);
    t.accent_deep = rgb(0x6b2142);
    t.accent_pale = rgb(0xffd6e6);
    t.on_accent = rgb(0x180d13);
    t.highlight = rgb(0xffc2da);

    t.text = rgb(0xfbf1f5);
    t.title = rgb(0xfff5f9);
    t.value = rgb(0xf8eaf0);
    t.body = rgb(0xeed8e2);
    t.copy = rgb(0xd5b8c6);
    t.meta = rgb(0xc7a9b8);
    t.label = rgb(0xbd9eae);
    t.muted = rgb(0xb89aaa);
    t.faint = rgb(0x9a7f8d);
    t.warning = rgb(0xffb199);
    t.rule = rgb(0x6d4757);

    t.radius_row = 18.0f;
    t.radius_card = 22.0f;
    t.radius_panel = 30.0f;
    t.pill_chips = true;
    t.focus_width = 2.0f;
    t.focus_glow = 30.0f;
    t.glass_panels = true;

    t.focus_spring = 20.0f;
    t.cursor_spring = 26.0f;
    t.scroll_spring = 16.0f;

    t.backdrop = "backdrop.tga";
    t.backdrop_blur = "backdrop-blur.tga";
    t.brand = "brand.tga";
    t.light_x = 0.710f;
    t.light_y = 0.391f;
    t.motes = 26;
    t.drift = 1.0f;
    return t;
}

// ---- accent presets: named colour sets a user can pick per theme ----

const AccentPreset kSlateAccents[] = {
    {"silver",  "Silver",  Color::rgb(0xc0bbb6), Color::rgb(0x3a3836), Color::rgb(0xdedbd8), Color::rgb(0x101012), Color::rgb(0xe8e4e0)},
    {"ice",     "Ice",     Color::rgb(0x7ec8e3), Color::rgb(0x1c4966), Color::rgb(0xb8e0f0), Color::rgb(0x0a1418), Color::rgb(0xd0ecf8)},
    {"rose",    "Rose",    Color::rgb(0xe88ca0), Color::rgb(0x5c2232), Color::rgb(0xf2c0cc), Color::rgb(0x120a0c), Color::rgb(0xf5d4dc)},
    {"amber",   "Amber",   Color::rgb(0xe0a848), Color::rgb(0x5a4018), Color::rgb(0xf0d090), Color::rgb(0x121008), Color::rgb(0xf5dca0)},
    {"mint",    "Mint",    Color::rgb(0x6ecaa0), Color::rgb(0x1e4a38), Color::rgb(0xb0e8cc), Color::rgb(0x0a1410), Color::rgb(0xc8f0d8)},
    {"lilac",   "Lilac",   Color::rgb(0xb098d8), Color::rgb(0x3c2868), Color::rgb(0xd4c4ec), Color::rgb(0x0e0a14), Color::rgb(0xe0d4f0)},
    {"coral",   "Coral",   Color::rgb(0xe88070), Color::rgb(0x5c2820), Color::rgb(0xf0b8ac), Color::rgb(0x140c0a), Color::rgb(0xf5c8c0)},
    {"sky",     "Sky",     Color::rgb(0x60a8e0), Color::rgb(0x1a3a5c), Color::rgb(0xa8d0f0), Color::rgb(0x0a1018), Color::rgb(0xc0dcf5)},
};

const AccentPreset kCanopyAccents[] = {
    {"rose",     "Rose",     Color::rgb(0xf2a1c4), Color::rgb(0x6b2142), Color::rgb(0xffd6e6), Color::rgb(0x180d13), Color::rgb(0xffc2da)},
    {"blush",    "Blush",    Color::rgb(0xf7b8c8), Color::rgb(0x5c2a38), Color::rgb(0xffdde5), Color::rgb(0x180d10), Color::rgb(0xffd0da)},
    {"magenta",  "Magenta",  Color::rgb(0xe56ab0), Color::rgb(0x601a48), Color::rgb(0xf6b4d8), Color::rgb(0x160a12), Color::rgb(0xf9a4cf)},
    {"peach",    "Peach",    Color::rgb(0xf5a89a), Color::rgb(0x5c2a24), Color::rgb(0xfcd0c8), Color::rgb(0x180e0c), Color::rgb(0xffc4b8)},
    {"coral",    "Coral",    Color::rgb(0xee8092), Color::rgb(0x582030), Color::rgb(0xf8bcc6), Color::rgb(0x160a0d), Color::rgb(0xfba8b4)},
    {"mauve",    "Mauve",    Color::rgb(0xc89ab8), Color::rgb(0x44243c), Color::rgb(0xe6cbdd), Color::rgb(0x120a10), Color::rgb(0xd9b4cc)},
    {"lilac",    "Lilac",    Color::rgb(0xcfa0e0), Color::rgb(0x40285c), Color::rgb(0xe8cff2), Color::rgb(0x120c16), Color::rgb(0xdcb8ec)},
    {"berry",    "Berry",    Color::rgb(0xd0709c), Color::rgb(0x501a38), Color::rgb(0xeab0cc), Color::rgb(0x140a10), Color::rgb(0xe494b8)},
};

struct Store
{
    std::array<Theme, 2> all{canopy(), slate()};
    int index = 0;
    int accent = -1;
    Theme active = all[0];
};

Store &store()
{
    static Store value;
    return value;
}

} // namespace

const Theme &th()
{
    return store().active;
}

std::span<const Theme> themes()
{
    return store().all;
}

int theme_index()
{
    return store().index;
}

bool use_theme(std::string_view id)
{
    Store &all = store();
    for (std::size_t i = 0; i < all.all.size(); ++i)
    {
        if (id == all.all[i].id)
        {
            all.index = static_cast<int>(i);
            all.active = all.all[i];
            all.accent = -1;
            return true;
        }
    }
    return false;
}

static std::span<const AccentPreset> presets_for(int theme_index)
{
    switch (theme_index)
    {
    case 0: return kCanopyAccents;
    case 1: return kSlateAccents;
    default: return {};
    }
}

std::span<const AccentPreset> accent_presets()
{
    return presets_for(store().index);
}

int accent_index()
{
    return store().accent;
}

void use_accent(std::string_view id)
{
    Store &s = store();
    if (id.empty())
    {
        s.accent = -1;
        s.active = s.all[static_cast<std::size_t>(s.index)];
        return;
    }
    const auto presets = presets_for(s.index);
    for (std::size_t i = 0; i < presets.size(); ++i)
    {
        if (id == presets[i].id)
        {
            s.accent = static_cast<int>(i);
            s.active.accent = presets[i].accent;
            s.active.accent_deep = presets[i].accent_deep;
            s.active.accent_pale = presets[i].accent_pale;
            s.active.on_accent = presets[i].on_accent;
            s.active.highlight = presets[i].highlight;
            return;
        }
    }
}

} // namespace pe::ui
