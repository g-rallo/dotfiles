local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.default_prog = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' }
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 11.0
config.color_scheme = 'Rosé Pine Moon (base16)'

config.inactive_pane_hsb = {
  saturation = 0.7,
  brightness = 0.5,
}

return config
