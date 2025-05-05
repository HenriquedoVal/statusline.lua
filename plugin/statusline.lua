--     _____  ______  ___   ______  __  __  _____   __     ____  _   __  ______
--    / ___/ /_  __/ /   | /_  __/ / / / / / ___/  / /    /  _/ / | / / / ____/
--    \__ \   / /   / /| |  / /   / / / /  \__ \  / /     / /  /  |/ / / __/
--   ___/ /  / /   / ___ | / /   / /_/ /  ___/ / / /___ _/ /  / /|  / / /___
--  /____/  /_/   /_/  |_|/_/    \____/  /____/ /_____//___/ /_/ |_/ /_____/


--- Set statusline ---

vim.api.nvim_set_hl(0, 'StatusLine', {})
vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function(_ev)
        vim.api.nvim_set_hl(0, 'StatusLine', {})
    end
})

vim.api.nvim_set_option_value(
    "statusline", "%!v:lua.require'modules.statusline'.get_statusline()", {}
)
vim.api.nvim_create_autocmd('LspProgress', {command = 'redrawstatus!'})
vim.api.nvim_create_autocmd('DiagnosticChanged', {command = 'redrawstatus!'})

--- Set Tabline ---

vim.api.nvim_set_hl(0, 'TabLine', {})
vim.api.nvim_set_hl(0, 'TabLineSel', {})
vim.api.nvim_set_hl(0, 'TabLineFill', {})
vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function(_ev)
        require('modules.tabline').set_tabline_colors()
    end
})

vim.api.nvim_set_option_value(
    "tabline", "%!v:lua.require'modules.tabline'.get_tabline()", {}
)
