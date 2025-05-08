------------------------------------------------------------------------
--                             Imports                                --
------------------------------------------------------------------------

local string_buffer = require('string.buffer')

local modes_table = require('tables._modes')
local devicons    = require('tables._icons')

local nvim_set_hl           = vim.api.nvim_set_hl
local nvim_get_current_buf  = vim.api.nvim_get_current_buf
local nvim_list_bufs        = vim.api.nvim_list_bufs
local nvim_get_option_value = vim.api.nvim_get_option_value
local nvim_get_mode         = vim.api.nvim_get_mode
local nvim_buf_get_name     = vim.api.nvim_buf_get_name
local nvim_command          = vim.api.nvim_command

local new_timer    = vim.uv.new_timer
local new_fs_event = vim.uv.new_fs_event

local getfsize    = vim.fn.getfsize
local expand      = vim.fn.expand
local finddir     = vim.fn.finddir
local findfile    = vim.fn.findfile
local fnamemodify = vim.fn.fnamemodify

------------------------------------------------------------------------
--                             Globals                                --
------------------------------------------------------------------------

local left_separator  = ' '
local right_separator = ' '
local space = ' '

local purple   = '#BF616A' --#B48EAD
local blue     = '#83a598' --#81A1C1
local yellow   = '#fabd2f' --#EBCB8B
local green    = '#8ec07c' --#A3BE8C
local red      = '#fb4934' --#BF616A
local black_fg = '#282c34'

local os_path_sep = package.config:sub(1, 1)
local git_branch = ''
local current_diagnostics = ''
local lsp_msg = ''
local lsp_is_required = false
local current_spinner = ''
local current_spinner_idx = -1

local git_head_file_event = new_fs_event()
local erase_lsp_msg_timer = new_timer()
local spinner_timer = new_timer()

local sb = string_buffer.new(100)

------------------------------------------------------------------------
--                            Privates                                --
------------------------------------------------------------------------

-- Returns full path to git directory for current directory
local function find_git_dir()
	-- get file dir so we can search from that dir
	local file_dir = expand('%:p:h') .. ';'
	-- find .git/ folder genaral case
	local git_dir = finddir('.git', file_dir)
	-- find .git file in case of submodules or any other case git dir is in
	-- any other place than .git/
	local git_file = findfile('.git', file_dir)
	-- for some weird reason findfile gives relative path so expand it to fullpath
	if #git_file > 0 then
		git_file = fnamemodify(git_file, ':p')
	end
	if #git_file > #git_dir then
		-- separate git-dir or submodule is used
		local file = io.open(git_file); assert(file)
		git_dir = file:read()
		git_dir = git_dir:match('gitdir: (.+)$')
		file:close()
		-- submodule / relative file path
		if git_dir:sub(1, 1) ~= os_path_sep and not git_dir:match('^%a:.*$') then
			git_dir = git_file:match('(.*).git') .. git_dir
		end
	end
	return git_dir
end

-- sets git_branch variable to branch name or commit hash if not on branch
local function get_git_head(head_file)
	local f_head = io.open(head_file)
	if f_head then
		local head = f_head:read()
		f_head:close()
		local branch = head:match('ref: refs/heads/(.+)$')
		if branch then
			git_branch = branch
		else
			git_branch = head:sub(1, 6)
		end
	end
	return nil
end

local function watch_git_head_file()
	git_head_file_event:stop()

	local git_dir = find_git_dir()
	if #git_dir > 0 then
		local head_file = git_dir .. os_path_sep .. 'HEAD'
		get_git_head(head_file)
		git_head_file_event:start(
			head_file,
			{},
			vim.schedule_wrap(function()
				watch_git_head_file()
			end)
		)
	else
		git_branch = ''
	end
end

local function get_git_branch()
	if #git_branch == 0 then
		return ''
	end
	local icon = ''
	return icon .. space .. git_branch .. space
end

local function set_diagnostics()
	local diag = ''
	local e, w, i, h
    local res = { 0, 0, 0, 0 }
    for _, diagnostic in ipairs(vim.diagnostic.get(0)) do
        res[diagnostic.severity] = res[diagnostic.severity] + 1
    end
    e = res[vim.diagnostic.severity.ERROR]
    w = res[vim.diagnostic.severity.WARN]
    i = res[vim.diagnostic.severity.INFO]
    h = res[vim.diagnostic.severity.HINT]

	diag = e ~= 0 and diag .. ' ' .. e .. space or diag
	diag = w ~= 0 and diag .. ' ' .. w .. space or diag
	diag = i ~= 0 and diag .. ' ' .. i .. space or diag
	diag = h ~= 0 and diag .. ' ' .. h .. space or diag

    current_diagnostics = diag
end

local function set_lsp_msg(msg)
    --          '100% '
    local res = '     '

    if msg.percentage then
        res = string.format("%3i%%%% ", msg.percentage)
    end
    if msg.title then
        res = res .. msg.title .. space
    end
    if msg.message then
        res = res .. msg.message .. space
    end

    erase_lsp_msg_timer:start(2000, 0, vim.schedule_wrap(function()
        lsp_msg = ''
        nvim_command('redrawstatus!')
    end))

	lsp_msg = res
end

local function get_lsp_msg()

    -- requiring lsp takes too much time
    if not lsp_is_required then return '' end

    -- There is room for improv here. What if we have more than 1 lsp
    -- at the same moment? Not my use case anyway...
    local clients = vim.lsp.get_clients()
    for i = 1, #clients, 1 do

        -- TODO: is lsp sending msgs out of order? ringbuf is fifo afaik,
        -- popping should be ok
        local msg = clients[i].progress:pop()

        if msg and msg.value then
            set_lsp_msg(msg.value)
            break;
        end
    end

    local final_msg = ''
    if #lsp_msg > 0 then
        final_msg = '    ' .. current_spinner .. space .. lsp_msg
    end

    return final_msg
end

local function get_file_icon()
	local file_name = nvim_buf_get_name(0)
	if string.find(file_name, 'term://') ~= nil then
        file_name = 'terminal'
    elseif string.find(file_name, 'health://') ~= nil then
        file_name = 'checkhealth'
    end

	local icon = devicons.devicon_table[file_name]
	if icon ~= nil then
		return icon .. space
	end

    return ''
end

-- Returns the buffer name with term and health handling
local function get_buffer_name()
	local filename = expand('%:.')

    if string.find(filename, 'term://') ~= nil then
        local shell = expand('%:t') .. space

        -- Vim's pattern is 'path/to/shell//<pid>:'
        local tmp = string.sub(filename, string.find(filename,  '//%d+'))
        local pid = string.sub(tmp, string.find(tmp, '%d+'))

        return shell .. 'pid:' .. pid .. space

    elseif string.find(filename, 'health://') ~= nil then
        return 'checkhealth' .. space
    end

    if filename ~= '' then
        return filename .. space
    end

    local filetype = vim.bo.ft
    if filetype ~= '' then
        return filetype .. space
    end

    return ''
end

-- Returns formated string with current file size
local function get_file_size()
	local file = expand('%:p')
	if #file == 0 then
		return ''
	end
	local size = getfsize(file)
	if size <= 0 then
		return ''
	end

	if size < 1024 then
		return string.format('%dB ', size)
	elseif size < 1024 * 1024 then
		return string.format('%dKB ', size / 1024)
	elseif size < 1024 * 1024 * 1024 then
		return string.format('%dMB ', size / 1024 / 1024)
	else
		return string.format('%dGB ', size / 1024 / 1024 / 1024)
	end
end

-- Returns a string with 'b <current_bufnr>/<bufqtt>'
local function get_buffer_qtt()
    local bufqtt = 0
    local current_buf = nvim_get_current_buf()
    for _, v  in pairs(nvim_list_bufs()) do
        if nvim_get_option_value('buflisted', { buf = v }) then
            bufqtt = bufqtt + 1
        end
    end
    return string.format('b %i/%i ', current_buf, bufqtt)
end

-- Returns '+ ' if any buffer other than current buffer is modified
local function get_modified()
    local current_buf = nvim_get_current_buf()
    for _, v  in pairs(nvim_list_bufs()) do
        if v ~= current_buf and nvim_get_option_value('modified', { buf = v }) then
            return '+ '
        end
    end
    return ''
end

-- Change colors for different mode
local function set_mode_colors(mode)
	if mode == 'n' then
        nvim_set_hl(0, 'Mode', { fg = black_fg, bg = green, bold = true })
        nvim_set_hl(0, 'ModeSeparator', { fg = green })
	end
	if mode == 'i' then
        nvim_set_hl(0, 'Mode', { fg = black_fg, bg = blue, bold = true })
        nvim_set_hl(0, 'ModeSeparator', { fg = blue })
	end
	if mode == 'v' or mode == 'V' or mode == '^V' then
        nvim_set_hl(0, 'Mode', { fg = black_fg, bg = purple, bold = true })
        nvim_set_hl(0, 'ModeSeparator', { fg = purple })
	end
	if mode == 'c' then
        nvim_set_hl(0, 'Mode', { fg = black_fg, bg = yellow, bold = true })
        nvim_set_hl(0, 'ModeSeparator', { fg = yellow })
	end
	if mode == 't' or mode == 'nt' then
        nvim_set_hl(0, 'Mode', { fg = black_fg, bg = red, bold = true })
        nvim_set_hl(0, 'ModeSeparator', { fg = red })
	end
end


------------------------------------------------------------------------
--                              Init                                  --
------------------------------------------------------------------------

watch_git_head_file()

spinner_timer:start(0, 120, vim.schedule_wrap(function()
	local spinners = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

    current_spinner_idx = current_spinner_idx + 1
    current_spinner = spinners[current_spinner_idx % #spinners + 1]

    nvim_command('redrawstatus!')
end))

vim.api.nvim_create_autocmd('LspAttach', {
    once = true,
    callback = function()
        lsp_is_required = true
    end
})

vim.api.nvim_create_autocmd('DiagnosticChanged', {callback = set_diagnostics})

------------------------------------------------------------------------
--                              Statusline                            --
------------------------------------------------------------------------
local M = {}

function M.get_statusline()
	-- Mode
	local mode = nvim_get_mode()['mode']
	set_mode_colors(mode)

    sb:put('%#ModeSeparator#')
    sb:put(left_separator)
    sb:put('%#Mode#')
    sb:putf(' %s ', modes_table.current_mode[mode])
    sb:put('%#ModeSeparator#')
    sb:put(right_separator)
    sb:put('%#StatusLine#')

	-- Filetype and icons
    sb:put(get_buffer_name())
    sb:put(get_file_icon())

	-- Native Nvim LSP Diagnostic
    sb:put(current_diagnostics)

	-- git branch name
    sb:put(get_git_branch())

	--Lsp Progress
    sb:put(get_lsp_msg())

	-- Alignment to left
    sb:put('%=')

	-- FileSize, Modified, Row/Col
    sb:put('%m ')
    sb:put(get_modified())
    sb:put(get_file_size())
    sb:put(get_buffer_qtt())
    sb:put('ʟ %l/%L c %c')
    sb:put(space)

    local ret = sb:tostring()
    sb:reset()

    return ret
end

return M
