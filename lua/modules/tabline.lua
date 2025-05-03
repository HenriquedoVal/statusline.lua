--- Imports ---

local string_buffer = require('string.buffer')

local devicons = require('tables._icons')

local nvim_set_hl              = vim.api.nvim_set_hl
local nvim_list_tabpages       = vim.api.nvim_list_tabpages
local nvim_get_current_tabpage = vim.api.nvim_get_current_tabpage
local nvim_list_bufs           = vim.api.nvim_list_bufs
local nvim_get_current_buf     = vim.api.nvim_get_current_buf
local nvim_get_option_value    = vim.api.nvim_get_option_value

local fnamemodify = vim.fn.fnamemodify

local left_separator = ''
local right_separator = ''
local space = ' '

local blue   = '#83a598'
local color2 = '#292929'
local color3 = '#504945'
local color4 = '#b8b894'

local sb = string_buffer.new(100)


--- Init ---

nvim_set_hl(0, 'TabLine',             { bg = color3, fg = color4})
nvim_set_hl(0, 'TabLineSel',          { bold = true, bg = blue, fg = color2})
nvim_set_hl(0, 'TabLineFill',         {})

nvim_set_hl(0, 'TabLineSeparator',    { fg = color3})
nvim_set_hl(0, 'TabLineSelSeparator', { bold = true, fg = blue})


--- Tabline ---

local M = {}

function M.get_tabline()
    sb:reset()

    local current_buf = nvim_get_current_buf()
    for _, v  in pairs(nvim_list_bufs()) do
        if nvim_get_option_value('buflisted', { buf = v }) then

            local icon
            local file_name = vim.api.nvim_buf_get_name(v)
            if string.find(file_name, 'health://') ~= nil then
                file_name = 'checkhealth'
            elseif string.find(file_name, 'term://') ~= nil then
                icon = devicons.devicon_table['terminal']
            end

            file_name = fnamemodify(file_name, ":p:t")
            if icon == nil then
                icon = devicons.devicon_table[file_name]
            end

            if #file_name == 0 then
                file_name = 'No Name'
            end
            if icon ~= nil then
                file_name =  icon .. space .. file_name
            end
            if nvim_get_option_value('modified', { buf = v }) then
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

    local tab_list = nvim_list_tabpages()
    if #tab_list == 1 then
        return sb:tostring()
    end

    sb:put('%=')

    local current_tab = nvim_get_current_tabpage()
    for _, val in ipairs(tab_list) do
        local win_count = 0
        local windows = vim.api.nvim_tabpage_list_wins(val)
        for _, v in ipairs(windows) do
            local b = vim.api.nvim_win_get_buf(v)
            if nvim_get_option_value('buflisted', { buf = b }) then
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

return M
