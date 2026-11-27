return function(mod)
  local function normKey(s)
    if s == nil then return nil end
    local n = tostring(s):upper()
    n = n:gsub("NIDORAN_F", "NIDORANF"):gsub("NIDORAN_M", "NIDORANM")
    n = n:gsub("MR_MIME", "MRMIME"):gsub("MIME_JR", "MIMEJR")
    n = n:gsub("FARFETCH[_']?D", "FARFETCHD")
    n = n:gsub("HO[_%-]?OH", "HOOH")
    n = n:gsub("FARFETCH'D", "FARFETCHD")
    n = n:gsub("MR%.%s*MIME", "MRMIME"):gsub("MR%.", "MR")
    n = n:gsub("HO%-OH", "HOOH")
    n = n:gsub("[^A-Z0-9]", "")
    if n == "" then return nil end
    return n
  end
  local function livePokemon()
    local ok, P = pcall(require, "src.core.game3.pokemon")
    if ok and type(P) == "table" then return P end
    return nil
  end
  local function nameMissing(P, slot)
    if type(P.name) ~= "function" then return true end
    return not pcall(P.name, slot)
  end
  local function fillFromRegistry()
    local P = livePokemon()
    if not P then return 0, "no-pokemon-module" end
    local reg = mod.content and mod.content.pokemon
    if not reg then return 0, "no-pokemon-registry" end
    local okEach, iter = pcall(function() return reg:each() end)
    if not okEach or type(iter) ~= "function" then return 0, "no-each" end
    local filled, seen = 0, 0
    for id, rec in iter do
      if type(rec) == "table" then
        local slot = tonumber(rec.index) or tonumber(rec.gen3Species)
        local nm = rec.name
        local dx = tonumber(rec.dex)
        if slot and slot >= 1 and type(nm) == "string" and nm ~= "" then
          seen = seen + 1
          if nameMissing(P, slot) then
            pcall(function()
              P._names = P._names or {}
              P._names[slot] = nm
              P._byName = P._byName or {}
              local k = normKey(nm)
              if k and P._byName[k] == nil then P._byName[k] = slot end
              local kid = normKey(id)
              if kid and P._byName[kid] == nil then P._byName[kid] = slot end
              if dx then
                local nat = P._national
                if type(nat) == "table" then
                  nat.toNational = nat.toNational or {}
                  nat.toSpecies = nat.toSpecies or {}
                  if nat.toNational[slot] == nil then nat.toNational[slot] = dx end
                  if nat.toSpecies[dx] == nil then nat.toSpecies[dx] = slot end
                end
              end
            end)
            if not nameMissing(P, slot) then filled = filled + 1 end
          end
        end
      end
    end
    return filled, "seen=" .. seen
  end
  mod.events:on("mods.loaded", function()
    local ok, n, note = pcall(fillFromRegistry)
    if ok then
      mod.log:info("pokemon-trainer: save-editor name check: %d filled (%s)",
        tonumber(n) or 0, tostring(note))
    else
      mod.log:warn("pokemon-trainer: save-editor name check failed: %s", tostring(n))
    end
  end)
  mod.log:info("pokemon-trainer: save-editor guard installed")
end
