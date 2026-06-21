local Config = require 'config.config'

-- Loads the configured language over an English base (so missing keys fall back
-- to English). Used on both the server and client, and the full map is sent to
-- the NUI so the interface, prompts and messages share one source of truth.
local function loadLang(lang)
    local ok, tbl = pcall(require, 'locales.' .. lang)
    return (ok and type(tbl) == 'table') and tbl or {}
end

local strings = loadLang('en')
local selected = Config.locale or 'en'
if selected ~= 'en' then
    for key, value in pairs(loadLang(selected)) do
        strings[key] = value
    end
end

local Locale = {}

--- Translate a key, formatting with string.format when extra args are given.
function Locale.t(key, ...)
    local str = strings[key] or key
    if select('#', ...) > 0 then
        return str:format(...)
    end
    return str
end

--- The full string map, for the NUI.
function Locale.all()
    return strings
end

return Locale
