--- Imports ---

local string_buffer = require('string.buffer')

local devicons = require('tables._icons')


--- Globals ---

local left_separator = ''
local right_separator = ''
local space = ' '

---@type string|integer
local blue   = '#83a598'
local color2 = '#292929'
local color3 = '#504945'
local color4 = '#b8b894'

local sb = string_buffer.new(100)


--- Tabline ---

local M = {}

function M.set_tabline_colors()
    -- local identifier = vim.api.nvim_get_hl(0, {
    --     name = 'Identifier',
    --     link = false,
    --     create =false
    -- })
    -- if identifier and identifier.fg then
    --     blue = identifier.fg
    -- end
    vim.api.nvim_set_hl(0, 'TabLine',             { bg = color3, fg = color4})
    vim.api.nvim_set_hl(0, 'TabLineSel',          { bold = true, bg = blue, fg = color2})
    vim.api.nvim_set_hl(0, 'TabLineFill',         {})

    vim.api.nvim_set_hl(0, 'TabLineSeparator',    { fg = color3})
    vim.api.nvim_set_hl(0, 'TabLineSelSeparator', { bold = true, fg = blue})
end

function M.get_tabline()
    sb:reset()

    local current_buf = vim.api.nvim_get_current_buf()
    for _, v  in pairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_get_option_value('buflisted', { buf = v }) then

            local icon
            local file_name = vim.api.nvim_buf_get_name(v)
            if string.find(file_name, 'health://') ~= nil then
                file_name = 'checkhealth'
            elseif vim.api.nvim_get_option_value('filetype', { buf = v }) == 'qf' then
                file_name = 'quickfix'
            end

            if string.find(file_name, 'term://') ~= nil then
                icon = devicons.devicon_table['terminal']
            end
            file_name = vim.fn.fnamemodify(file_name, ":p:t")
            if icon == nil then
                icon = devicons.devicon_table[file_name]
            end

            if #file_name == 0 then
                file_name = 'No Name'
            end
            if icon ~= nil then
                file_name =  icon .. space .. file_name
            end
            if vim.api.nvim_get_option_value('modified', { buf = v }) then
                file_name = file_name .. space .. '+'
            end

            if v == current_buf then
                sb:putf('%%#TabLineSelSeparator# %s', left_separator)
                sb:putf('%%#TabLineSel# %s', file_name)
                sb:putf(' %%#TabLineSelSeparator#%s', right_separator)
            else
                sb:putf('%%#TabLineSeparator# %s', left_separator)
                sb:putf('%%#TabLine# %s', file_name)
                sb:putf(' %%#TabLineSeparator#%s', right_separator)
            end
        end
	end

    local tab_list = vim.api.nvim_list_tabpages()
    if #tab_list == 1 then
        return sb:tostring()
    end

    sb:put('%=')

    local current_tab = vim.api.nvim_get_current_tabpage()
    for _, val in ipairs(tab_list) do
        local win_count = 0
        local windows = vim.api.nvim_tabpage_list_wins(val)
        for _, v in ipairs(windows) do
            local b = vim.api.nvim_win_get_buf(v)
            if vim.api.nvim_get_option_value('buflisted', { buf = b }) then
                win_count = win_count + 1
            end
        end
        if val == current_tab then
            sb:putf('%%#TabLineSelSeparator# %s', left_separator)
            sb:putf('%%#TabLineSel# %s', win_count)
            sb:putf(' %%#TabLineSelSeparator#%s', right_separator)
        else
            sb:putf('%%#TabLineSeparator# %s', left_separator)
            sb:putf('%%#TabLine# %s', win_count)
            sb:putf(' %%#TabLineSeparator#%s', right_separator)
        end
    end

	return sb:tostring()
end


--- Init ---

M.set_tabline_colors()


return M
