--[[--
2-pdf-scroll-guard.lua

PDF scroll-leak guard.

`defaults.custom.lua` sets `DCREREADER_VIEW_MODE = "scroll"` so reflowable
documents (EPUB/FB2/TXT) open in continuous scroll. The same default leaks
into PDF `view_mode`; ReaderFooter's scroll branch then calls
`document:getPosFromXPointer()` — an API only the CRE engine implements —
so every PDF crashes on open with:

    readerfooter.lua: attempt to call method 'getPosFromXPointer' (a nil value)

This user patch makes any document lacking `getPosFromXPointer` (i.e. the
PDF paging engine) compute progress via the page-based branch regardless of
the leaked `view_mode`, keeping PDFs in page mode while EPUB/TXT stay in
scroll mode. It mirrors `scripts/patch-koreader-desktop.sh` but lives in the
config layer: it survives koreader-bin upgrades and restores, and is valid
only for the KOReader version it was written against (2026.07.x).
--]]

local ReaderFooter = require("apps/reader/modules/readerfooter")
if not ReaderFooter then
    return
end

local original_set_toc_markers = ReaderFooter.setTocMarkers

function ReaderFooter:setTocMarkers(reset)
    -- Frenzie's suggested issue #15910 guard: only rolling/CRE documents
    -- can convert TOC XPointer entries into scroll positions. Paging
    -- documents fall back to ReaderFooter's page-number branch.
    if self.view.view_mode == "scroll" and not self.ui.rolling then
        local saved_view_mode = self.view.view_mode
        self.view.view_mode = "page"
        local ok, result = pcall(original_set_toc_markers, self, reset)
        self.view.view_mode = saved_view_mode
        if not ok then
            error(result, 2)
        end
        return result
    end
    return original_set_toc_markers(self, reset)
end

require("logger").info("PDF scroll guard patch applied")