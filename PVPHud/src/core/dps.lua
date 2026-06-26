-- Pure damage telemetry: rolling in/out buffers, stats, graph series.
-- Stateful instance; no DU globals.
local M = {}

function M.new(opts)
  opts = opts or {}
  local n = opts.buckets or 90
  local self = {
    received = {}, caused = {},
    shotsFired = 0, shotsHit = 0,
    damageDealt = 0, damageById = {},
    peakDps = 0, _window = opts.window or 10,
  }
  for i = 1, n do self.received[i] = 0; self.caused[i] = 0 end

  function self.recordReceived(amount)
    self.received[#self.received] = self.received[#self.received] + amount
  end

  function self.recordHit(targetId, damage)
    self.caused[#self.caused] = self.caused[#self.caused] + damage
    self.damageDealt = self.damageDealt + damage
    self.damageById[targetId] = (self.damageById[targetId] or 0) + damage
    self.shotsHit = self.shotsHit + 1
    self.shotsFired = self.shotsFired + 1
  end

  function self.recordMiss(targetId)
    self.shotsFired = self.shotsFired + 1
  end

  -- Update peak from the trailing window, then roll both buffers by one.
  function self.tick()
    local w = math.min(self._window, #self.caused)
    local sum = 0
    for i = #self.caused, #self.caused - w + 1, -1 do sum = sum + self.caused[i] end
    local windowDps = sum / w
    if windowDps > self.peakDps then self.peakDps = windowDps end
    table.remove(self.received, 1); self.received[#self.received + 1] = 0
    table.remove(self.caused, 1);   self.caused[#self.caused + 1] = 0
  end

  function self.accuracy()
    if self.shotsFired == 0 then return 0 end
    return self.shotsHit / self.shotsFired
  end

  function self.series(which)
    local src = (which == "received") and self.received or self.caused
    local out = {}
    for i = 1, #src do out[i] = src[i] end
    return out
  end

  return self
end

return M
