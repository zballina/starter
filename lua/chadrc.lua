-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "decay",

	hl_override = {
		-- Comentarios en cursiva (opcional)
		Comment = { italic = true },
		["@comment"] = { italic = true },

		-- Resaltado fuerte y nítido para texto seleccionado (Modo Visual / Mouse)
		Visual = {
			bg = "#243044", -- Fondo morado brillante de buen contraste con Decay
			--fg = "#ffffff", -- Texto blanco nítido
			--bold = true,
		},
	},
}

-- CONFIGURACIÓN DE TAMAÑOS POR DEFECTO DE LA TERMINAL:
M.term = {
  pos = "vsp", -- posición por defecto ('sp' para split horizontal, 'vsp' vertical)
  size = 0.5, -- 50% de la altura de la pantalla para terminal horizontal
  clear_cmd = "clear",
  
  -- Si utilizas splits específicos:
  sizes = {
    sp = 0.5,  -- Altura de la terminal horizontal (<Option-h>) -> 50%
    vsp = 0.5, -- Ancho de la terminal vertical (<Option-v>) -> 50%
  },

  -- Tamaño y posición de la terminal flotante (<Option-i>):
  float = {
    relative = "editor",
    row = 0.1,
    col = 0.1,
    width = 1.0,  -- 100% del ancho de la pantalla
    height = 0.85, -- 85% de la altura de la pantalla
    border = "rounded",
  },
}

return M
