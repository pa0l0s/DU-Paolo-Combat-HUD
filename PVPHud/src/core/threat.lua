-- Pure construct classification for radar/AR. No DU globals.
local M = {}

-- info = { threatRate, transponder, friend, abandoned, identified }
function M.classify(info)
  if info.abandoned then
    return { kind = "dead", role = "dim", identified = info.identified or false }
  end
  if info.friend or info.transponder then
    return { kind = "friend", role = "ready", identified = info.identified or false }
  end
  return { kind = "enemy", role = "threat", identified = info.identified or false }
end

-- Theme role for a classified kind (AR marker color).
function M.markerRole(kind)
  if kind == "friend" then return "ready"
  elseif kind == "dead" then return "dim"
  else return "threat" end
end

return M
