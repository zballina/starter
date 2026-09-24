local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- ==========================================
-- DEFINICIÓN DE ESQUEMAS PERSONALIZADOS
-- ==========================================
config.color_schemes = {
  ['CustomGentoo'] = {
    background = '#000000',
    foreground = '#ffffff',

    cursor_bg = '#aaaaaa',
    cursor_fg = '#000000',

    selection_bg = '#7e57c2',
    selection_fg = '#ffffff',

    ansi = {
      '#000000', -- Black
      '#aa0000', -- Red
      '#00aa00', -- Green
      '#aa5500', -- Yellow
      '#3b82f6', -- Blue (Azul brillante legible)
      '#54487a', -- Magenta (Gentoo Purple)
      '#00aaaa', -- Cyan
      '#aaaaaa', -- White
    },

    brights = {
      '#555555', -- Bright Black
      '#ff5555', -- Bright Red
      '#73d216', -- Bright Green (Gentoo Green)
      '#ffff55', -- Bright Yellow
      '#5555ff', -- Bright Blue
      '#6e56af', -- Bright Magenta (Gentoo Purple Claro)
      '#55ffff', -- Bright Cyan
      '#ffffff', -- Bright White
    },
  },
}

-- ==========================================
-- SELECTOR DE ESQUEMA ACTIVO
-- ==========================================
-- Cambia aquí el nombre según lo que quieras probar:
-- Opciones: 'CustomGentoo', 'Tokyo Night', 'Catppuccin Mocha', 'Dracula', etc.
config.color_scheme = 'CustomGentoo'


-- --- 1. Ajustes de Letra del Contenido ---
config.font_size = 20
config.font = wezterm.font('JetBrains Mono')

-- --- 2. Estética General y Transparencia ---
config.window_background_opacity = 0.90
config.macos_window_background_blur = 20
config.window_decorations = "TITLE | RESIZE"

-- --- 3. Comportamiento y Gestión de Pestañas ---
config.audible_bell = "Disabled"

-- Oculta la barra de pestañas cuando solo hay 1 pestaña activa
config.hide_tab_bar_if_only_one_tab = true

-- Estilo de pestañas (cuando haya 2 o más abiertas)
config.window_frame = {
  font_size = 14.0,
  font = wezterm.font('JetBrains Mono', { bold = true }),
}

-- --- 4. Evento dinámico para la Barra de Título Superior ---
wezterm.on('format-window-title', function(tab, pane, tabs, panes, config)
  local process_name = ''
  if pane.foreground_process_name and pane.foreground_process_name ~= '' then
    process_name = string.gsub(pane.foreground_process_name, '(.*[/\\])(.*)', '%2')
  end
  if process_name == '' then
    process_name = pane.title or 'zsh'
  end

  local path = ''
  local cwd = pane.current_working_dir
  if cwd then
    local raw_path = cwd.file_path or tostring(cwd)
    raw_path = raw_path:gsub('^file://[^/]*', '')

    local home = os.getenv('HOME')
    if home and home ~= '' then
      raw_path = raw_path:gsub('^' .. home, '~')
    end
    path = raw_path
  end

  if path ~= '' then
    return ' ' .. process_name .. '  |  ' .. path .. ' '
  end

  return ' ' .. process_name .. ' '
end)

-- --- 5. Configuración de atajos de teclado ---
config.keys = {
  -- CMD + SHIFT + V: Pegar captura / imagen con PATH corregido
  {
    key = 'v',
    mods = 'CMD|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local cmd = [[
        export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
        tmp="/tmp/clip_$(date +%s).png"
        if command -v pngpaste >/dev/null 2>&1; then
          if pngpaste "$tmp" 2>/dev/null; then
            echo -n "$tmp"
          fi
        fi
      ]]

      local success, stdout, stderr = wezterm.run_child_process {
        '/bin/zsh',
        '-c',
        cmd,
      }

      if success and stdout and stdout ~= '' then
        window:perform_action(wezterm.action.SendString(stdout .. ' '), pane)
      end
    end),
  },
  -- CMD + Flecha Izquierda: Ir al inicio de la línea nativo de macOS (\x01 es Ctrl+A)
  { key = 'LeftArrow', mods = 'CMD', action = wezterm.action.SendString '\x01' },
  
  -- CMD + Flecha Derecha: Ir al final de la línea nativo de macOS (\x05 es Ctrl+E)
  { key = 'RightArrow', mods = 'CMD', action = wezterm.action.SendString '\x05' },
  
  -- OPT + Flecha Izquierda: Saltar una palabra a la izquierda (\x1bb es Alt+B)
  { key = 'LeftArrow', mods = 'OPT', action = wezterm.action.SendString '\x1bb' },
  
  -- OPT + Flecha Derecha: Saltar una palabra a la derecha (\x1bf es Alt+F)
  { key = 'RightArrow', mods = 'OPT', action = wezterm.action.SendString '\x1bf' },
  
  -- OPT + Backspace: Borrar una palabra entera hacia atrás (\x17 es Ctrl+W)
  { key = 'Backspace', mods = 'OPT', action = wezterm.action.SendString '\x17' },
  
  -- Cmd + Delete (Backspace): Borra toda la línea hasta el inicio (\x15 es Ctrl+U)
  { key = 'Backspace', mods = 'CMD', action = wezterm.action.SendString '\x15' },
}

return config
