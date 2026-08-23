-- Use the desktop's LXGW WenKai package for KOReader UI and documents.
-- Adjust these filenames when your OS packages the font elsewhere.
local font_dir = "/usr/share/fonts/TTF/"
local regular = "LXGWWenKai-Regular.ttf"
local medium = "LXGWWenKai-Medium.ttf"
local mono = "LXGWWenKaiMono-Regular.ttf"
local mono_medium = "LXGWWenKaiMono-Medium.ttf"

local probe = io.open(font_dir .. regular, "rb")
if not probe then return end
probe:close()

local function configureSettings()
    if not G_reader_settings then return end

    G_reader_settings:saveSetting("system_fonts", true)
    G_reader_settings:saveSetting("cre_font", "LXGW WenKai")
    G_reader_settings:saveSetting("fallback_font", "LXGW WenKai")
    G_reader_settings:saveSetting("header_font", "LXGW WenKai")
    G_reader_settings:saveSetting("monospace_font", "LXGW WenKai Mono")
    G_reader_settings:saveSetting("cre_font_family_fonts", {
        cursive = "LXGW WenKai",
        fangsong = "LXGW WenKai",
        fantasy = "LXGW WenKai",
        monospace = "LXGW WenKai Mono",
        ["sans-serif"] = "LXGW WenKai",
        serif = "LXGW WenKai",
    })

    local footer = G_reader_settings:readSetting("footer", {})
    footer.text_font_face = font_dir .. regular
    G_reader_settings:saveSetting("footer", footer)
end

local function configureUiFonts(Font)
    local regular_roles = {
        "cfont", "ffont", "smallffont", "largeffont", "rifont", "pgfont",
        "hfont", "infofont", "smallinfofont", "x_smallinfofont",
        "xx_smallinfofont",
    }
    local medium_roles = { "tfont", "smalltfont", "x_smalltfont", "smallinfofontbold" }
    local mono_roles = { "scfont", "hpkfont", "infont", "smallinfont" }

    for _, role in ipairs(regular_roles) do Font.fontmap[role] = regular end
    for _, role in ipairs(medium_roles) do Font.fontmap[role] = medium end
    for _, role in ipairs(mono_roles) do Font.fontmap[role] = mono end

    Font.bold_font_variant[regular] = medium
    Font.regular_font_variant[medium] = regular
    Font.bold_font_variant[mono] = mono_medium
    Font.regular_font_variant[mono_medium] = mono
    Font.fallbacks[1] = regular

    require("logger").info("LXGW font patch applied")
end

-- KOReader runs 1-* user patches very early on each start. Defer ui/font so
-- the role map is replaced before widgets request their first font face.
local loaded_font = package.loaded["ui/font"]
if loaded_font then
    configureSettings()
    configureUiFonts(loaded_font)
else
    local previous_preload = package.preload["ui/font"]
    package.preload["ui/font"] = function(...)
        configureSettings()
        local Font = previous_preload and previous_preload(...) or dofile("frontend/ui/font.lua")
        configureUiFonts(Font)
        return Font
    end
end
