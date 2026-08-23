-- Focused desktop example for KOReader 2026.07.1.
-- Back up and merge with an existing hotkeys.lua instead of overwriting it.
return {
    ["hotkeys_fm"] = {
        ["alt_plus_h"] = {
            ["history"] = true,
        },
        ["alt_plus_j"] = {
            ["key_right_page_forward"] = true,
        },
        ["alt_plus_k"] = {
            ["key_right_page_back"] = true,
        },
    },
    ["hotkeys_reader"] = {
        ["alt_plus_f"] = {
            ["filemanager"] = true,
        },
        ["alt_plus_h"] = {
            ["history"] = true,
        },
        ["alt_plus_j"] = {
            ["scroll_step_down"] = true,
        },
        ["alt_plus_k"] = {
            ["scroll_step_up"] = true,
        },
        ["b"] = {
            ["bookmarks"] = true,
        },
        ["f"] = {
            ["filemanager"] = true,
        },
        ["h"] = {
            ["history"] = true,
        },
        ["j"] = {
            ["key_down"] = true,
        },
        ["k"] = {
            ["key_up"] = true,
        },
        ["m"] = {
            ["show_menu"] = true,
        },
        ["p"] = {
            ["toggle_status_bar"] = true,
        },
        ["q"] = {
            ["exit"] = true,
        },
        ["r"] = {
            ["edit_book_title"] = true,
        },
        ["t"] = {
            ["toc"] = true,
        },
    },
}
