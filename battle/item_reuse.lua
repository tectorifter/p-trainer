return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local snaps = setmetatable({}, { __mode = "k" })
  mod.events:on("battle.started", function(ev)
    if S.opt("item_reuse", true) ~= true then return end
    local battle = ev and ev.battle
    if type(battle) ~= "table" then return end
    S.visit(battle, function(mon)
      if mon.isEgg then return end
      local it, hi = mon.item, mon.heldItem
      if it ~= nil or hi ~= nil then snaps[mon] = { item = it, heldItem = hi } end
    end)
  end, 1000)
  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if type(battle) == "table" and S.opt("item_reuse", true) == true then
      S.visit(battle, function(mon)
        local s = snaps[mon]
        if not s then return end
        if s.item ~= nil and mon.item == nil then mon.item = s.item end
        if s.heldItem ~= nil and mon.heldItem == nil then mon.heldItem = s.heldItem end
      end)
    end
    for k in pairs(snaps) do snaps[k] = nil end
  end, -1000)
  mod.log:info("pokemon-trainer: item reuse installed")
end
