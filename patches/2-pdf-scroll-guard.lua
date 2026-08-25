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

local original_update = ReaderFooter.updateFooterChapterProgress

function ReaderFooter.updateFooterChapterProgress(self, force)
    -- paging-engine documents (PDF) have no CRE-only method; force the
    -- page branch when the leaked default set view_mode to scroll.
    if self and self.ui and self.ui.document
        and not self.ui.document.getPosFromXPointer
        and self.view and self.view.view_mode ~= "page" then
        local saved = self.view.view_mode
        self.view.view_mode = "page"
        local ok, err = pcall(original_update, self, force)
        self.view.view_mode = saved
        if not ok then
            error(err, 2)
        end
        return
    end
    return original_update(self, force)
end