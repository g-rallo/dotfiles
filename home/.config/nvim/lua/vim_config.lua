local o = vim.opt
vim.g.mapleader = ' '          -- space is the leader key
o.expandtab = true             -- spaces, not tabs
o.shiftwidth = 2               -- 2 spaces per indent level
o.number = true                -- absolute number on the cursor line, relative elsewhere
o.relativenumber = true        -- relative line numbers for fast jumps
o.ignorecase = true            -- search is case-insensitive by default
o.smartcase = true             -- case-sensitive only if i type a capital
o.clipboard = 'unnamedplus'    -- share the system clipboard
o.scrolloff = 16               -- keep cursor away from the screen edge
o.undofile = true              -- persistent undo across sessions
o.mouse = ''                   -- no mouse in nvim; also lets Herdr keep host mouse capture off so Escape isn't swallowed

-- WSL clipboard bridge: 'unnamedplus' alone does nothing here since WSL has
-- no X11/Wayland clipboard provider. Routes yanks/pastes through win32yank
-- to reach the actual Windows clipboard.
vim.g.clipboard = {
  copy = { ['+'] = 'win32yank.exe -i --crlf', ['*'] = 'win32yank.exe -i --crlf' },
  paste = { ['+'] = 'win32yank.exe -o --lf', ['*'] = 'win32yank.exe -o --lf' },
}

-- Auto-create parent directories on save, so opening a file in a
-- not-yet-existing folder never fails on :w.
vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function(args)
    local dir = vim.fn.fnamemodify(args.file, ':p:h')
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
  end,
})
