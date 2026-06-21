--- Thin bridge to the NUI sound system. Sounds are synthesised in the UI
--- (web/src/lib/audio.ts), so there are no audio assets and nothing to collide
--- with another resource. Names: pickup | drop | throw | kick | use | open |
--- close | error.
local Sound = {}

function Sound.play(name)
    SendNUIMessage({ action = 'playSound', data = { name = name } })
end

_G.LkSound = Sound
return Sound
