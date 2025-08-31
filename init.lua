local function required_percent()
  local p = tonumber(minetest.settings:get("sleep_skip_percent")) or 100
  if p < 1 then p = 1 end
  if p > 100 then p = 100 end
  return math.floor(p + 0.5)
end

local function is_sleeping(state)
  if type(state) == "table" and state.state then
    return state.state == "sleeping" or state.state == "laying"
  end
  return state and true or false
end

local function bed_mod_name()
  if rawget(_G, "mcl_beds") then return "mcl_beds" end
  if rawget(_G, "beds") then return "beds" end
  return nil
end

local function is_in_overworld(ply)
  local pos = ply and ply:get_pos()
  if not pos then
    return true
  end
  local w = rawget(_G, "mcl_worlds")
  if type(w) ~= "table" then
    return true
  end
  if type(w.pos_to_dimension) == "function" then
    local d = w.pos_to_dimension(pos)
    return d == "overworld" or d == w.DIMENSION_OVERWORLD
  end
  if type(w.get_dimension) == "function" then
    local d = w.get_dimension(pos)
    return d == "overworld" or d == w.DIMENSION_OVERWORLD
  end
  return true
end

local function eligible_player_count(bed_mod)
  local list = minetest.get_connected_players()
  if bed_mod ~= "mcl_beds" then
    return #list
  end
  local n = 0
  for _, ply in ipairs(list) do
    if is_in_overworld(ply) then
      n = n + 1
    end
  end
  return n
end

local function sleepers_info(bed_mod)
  local set = _G[bed_mod] and _G[bed_mod].player
  if type(set) ~= "table" then
    return 0, {}
  end
  local n, names = 0, {}
  for name, state in pairs(set) do
    local ply = minetest.get_player_by_name(name)
    if ply and is_sleeping(state) then
      n = n + 1
      names[#names + 1] = name
    end
  end
  return n, names
end

local function skip_and_get_up(bed_mod)
  if bed_mod == "mcl_beds" then
    local m = mcl_beds
    if m.update_sleeping_formspecs then m.update_sleeping_formspecs(true)
    elseif m.update_formspecs then m.update_formspecs(true) end
    if m.skip_night then m.skip_night() end
    if m.kick_players then m.kick_players() end
  else
    if beds.skip_night then beds.skip_night() end
    if beds.kick_players then beds.kick_players() end
  end
end

if required_percent() >= 100 then
  minetest.log("action", "[sleep_skip] disabled: sleep_skip_percent=100 (delegating to bed mod)")
  return
end

local skipped_once = false
local acc = 0

minetest.register_globalstep(function(dtime)
  acc = acc + dtime
  if acc < 1 then
    return
  end
  acc = 0

  local mod = bed_mod_name()
  if not mod then
    return
  end

  local total = eligible_player_count(mod)
  if total == 0 then
    return
  end

  local sleepers, to_close = sleepers_info(mod)
  local need = math.ceil(total * (required_percent() / 100))

  if sleepers == 0 then
    skipped_once = false
    return
  end

  if not skipped_once and sleepers >= need then
    skip_and_get_up(mod)

    minetest.after(0, function()
      for _, name in ipairs(to_close) do
        minetest.close_formspec(name, "")
      end
    end)

    skipped_once = true
    minetest.chat_send_all(("Night skipped: %d out of %d players in bed (threshold %d%%)")
      :format(sleepers, total, required_percent()))
  end
end)

