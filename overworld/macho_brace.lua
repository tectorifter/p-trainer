return function(mod)
  local S = mod.exports.pt
  if not S then return end
  local ITEM = "MACHO_BRACE"
  local PRICE = 2500
  local SHOP_MOD = "src.ui.game3.shop_menu"
  local MART_MAP = "EM_OLDALE_TOWN_MART"
  local function on()
    return S.opt("macho_brace", false) == true
  end
  local function braceNumber()
    local ok, rec = pcall(function() return mod.content.items:get(ITEM) end)
    if ok and type(rec) == "table" then
      local n = tonumber(rec.itemId) or tonumber(rec.index)
      if n and n > 0 then return math.floor(n) end
    end
    return nil
  end
  local okI, rec = pcall(function() return mod.content.items:get(ITEM) end)
  if okI and type(rec) == "table" then
    local okP, err = pcall(function()
      mod.content.items:patch(ITEM, { price = PRICE })
    end)
    if okP then
      mod.log:info("pokemon-trainer: MACHO BRACE priced at 2500")
    else
      mod.log:warn("pokemon-trainer: MACHO BRACE price patch failed: %s",
        tostring(err))
    end
  else
    mod.log:warn("pokemon-trainer: MACHO BRACE not in the items registry")
  end
  local okS, SM = pcall(require, SHOP_MOD)
  if not (okS and SM and type(SM.show) == "function") then
    mod.log:warn("pokemon-trainer: shop wrap unavailable")
    return
  end
  if SM.__ptShopWrapped then return end
  SM.__ptShopWrapped = true
  local nativeShow = SM.show
  SM.show = function(...)
    local a1 = select(1, ...)
    if on() and type(a1) == "table" then
      pcall(function()
        local sess = a1.session
        if not (type(sess) == "table" and sess.map == MART_MAP) then return end
        local items = a1.items
        if type(items) ~= "table" then return end
        local n = 0
        for k, v in pairs(items) do
          if type(k) ~= "number" or type(v) ~= "number" then return end
          n = n + 1
        end
        if n < 1 or n > 60 then return end
        local brace = braceNumber()
        if not brace then return end
        for _, v in ipairs(items) do
          if v == brace then return end
        end
        items[#items + 1] = brace
        if items[#items] == brace then
          mod.log:info("pokemon-trainer: MACHO BRACE added to Oldale shop")
        end
      end)
    end
    return nativeShow(...)
  end
  mod.log:info("pokemon-trainer: macho brace installed")
end
