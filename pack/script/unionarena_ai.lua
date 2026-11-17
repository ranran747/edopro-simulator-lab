-- UNION ARENA on EDOPro: a simple greedy AI used by both players. Every player decision of the rules and of the
-- card effects (targets, "〜てもよい", "まで", line choice, blocks) is made here.
local P = UnionArenaAI
P.ai = P.ai or {}
local AI = P.ai

------------------------------------------------------------------------------
-- Card values
------------------------------------------------------------------------------
local function value(c)
  local d = P.data(c)
  if not d then return 0 end
  local v = (d.need or 0) * 10 + (d.bp or 0) / 250
  if P.fxOf(c).raid then v = v + 10 end
  if d.kind == "event" then v = v + 15 end
  if not P.supported(c) then v = v - 50 end
  return v
end
AI.value = value
local function fieldValue(c)
  local v = P.isChar(c) and P.bp(c) / 100 or 10
  if P.isRaided(c) then v = v + 30 end
  local g = P.data(c).gen
  if g then v = v + g.n * 8 end
  return v
end
local function sortBy(t, f, desc)
  table.sort(t, function(a, b)
    local x, y = f(a), f(b)
    if x == y then return a:GetRealFieldID() < b:GetRealFieldID() end
    if desc then return x > y end
    return x < y
  end)
  return t
end
-- the most energy of each color the cards in hand need (what the energy line should reach)
local function wantedEnergy(tp)
  local want = {}
  for _, c in ipairs(P.hand(tp)) do
    local d = P.data(c)
    if d and d.color ~= "" and P.supported(c) then want[d.color] = math.max(want[d.color] or 0, math.min(P.need(c), 7)) end
  end
  return want
end

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------
-- manual p.5: keep a hand that can start building the energy line (a card that needs 0 or 1 energy)
function AI.mulligan(tp)
  for _, c in ipairs(P.hand(tp)) do
    if P.isChar(c) and P.baseNeed(c) <= 1 and P.data(c).gen then return false end
  end
  return true
end
function AI.extraDraw(tp)
  local hand, ap = #P.hand(tp), #P.apActive(tp)
  return (ap >= 3 and hand <= 4) or (ap >= 2 and hand <= 1)
end

------------------------------------------------------------------------------
-- Lines
------------------------------------------------------------------------------
function AI.roomPick(tp, pool, line)
  return sortBy(pool, fieldValue)[1]
end
function AI.lineFor(tp, c)
  if P.isFieldCard(c) then return "energy" end
  if P.fxOf(c).noFront then return "energy" end
  local d = P.data(c)
  local want = wantedEnergy(tp)
  local col = d.gen and d.gen.color
  local needMore = col and (P.energyOf(tp, col) < math.max(want[col] or 0, 4))
  if d.gen and needMore and P.lineCount(tp, "energy") < P.LINE then return "energy" end
  if P.lineCount(tp, "front") < P.LINE then return "front" end
  if P.lineCount(tp, "energy") < P.LINE then return "energy" end
  return d.gen and "energy" or "front"
end
-- Movement phase: move energy line characters to the front line when the energy they give is not needed.
function AI.movement(tp)
  local want = wantedEnergy(tp)
  local moved = {}
  local left = {}
  for _, color in ipairs({"赤", "青", "緑", "紫", "黄"}) do left[color] = P.energyOf(tp, color) end
  local cands = sortBy(P.energy(tp, function(c) return P.isChar(c) and not P.fxOf(c).noFront end), function(c) return P.bp(c) end, true)
  for _, c in ipairs(cands) do
    if #P.front(tp) + #moved >= P.LINE then break end
    local g = P.genOf(c)
    local ok = true
    for color, n in pairs(g) do
      if left[color] - n < math.max(want[color] or 0, 0) then ok = false end
      -- keep building toward 4-5 energy early
      if left[color] - n < 4 and P.ownTurns[tp] <= 4 then ok = false end
    end
    if ok and P.bp(c) >= 2000 then
      moved[#moved+1] = c
      for color, n in pairs(g) do left[color] = left[color] - n end
    end
  end
  for _, c in ipairs(moved) do P.moveLine(c, "front") end
  -- 【ステップ】: a rested front character that cannot attack may step back (not used by this AI)
end
function AI.raidToFront(tp, c) return P.lineCount(tp, "front") < P.LINE end

------------------------------------------------------------------------------
-- Main phase
------------------------------------------------------------------------------
local function playScore(tp, c)
  local d = P.data(c)
  local s = 50 + P.need(c) * 6 + (d.bp or 0) / 1000
  if d.kind == "field" then s = 35 end
  return s
end
local function eventScore(tp, c)
  local f = P.fxOf(c)
  local s = 30 + P.need(c) * 3
  -- an event that only targets the opponent's characters needs one there
  for _, op in ipairs(f.event or {}) do
    if op.op == "pick" and op.side == "opp" then
      local pool = P.filter(P.zoneCards({tp = tp, c = c}, "opp", op.zone or "field"), function(x) return P.matches(x, op.filt, {tp = tp, c = c}) end)
      if #pool == 0 then return nil end
      s = s + 20
    end
    if op.op == "apStand" then
      if #P.filter(P.apArea(tp), P.isRested) < 1 then return nil end
      s = 5
    end
  end
  return s
end
local function actions(tp)
  local out = {}
  for _, c in ipairs(P.concat(P.hand(tp), P.usableFromRemove and P.usableFromRemove(tp) or {})) do
    if P.isChar(c) or P.isFieldCard(c) then
      if P.canUse(tp, c, "hand") then
        local targets = P.isChar(c) and P.raidTargets(tp, c) or {}
        if #targets > 0 then
          out[#out+1] = {kind = "raid", c = c, score = 100 + P.need(c) * 5, targets = targets}
        end
        local line = AI.lineFor(tp, c)
        local full = P.lineCount(tp, line) >= P.LINE or P.fxOf(c).raidOnly
        if not full or (P.isChar(c) and (P.data(c).bp or 0) >= 3000) then
          out[#out+1] = {kind = "play", c = c, score = playScore(tp, c) - (full and 30 or 0), line = line}
        end
      end
    elseif P.isEvent(c) and P.canUse(tp, c, "event") then
      local s = eventScore(tp, c)
      if s then out[#out+1] = {kind = "event", c = c, score = s} end
    end
  end
  for _, entry in ipairs(P.mainAbilities(tp)) do
    local s = 25
    for _, k in ipairs(entry.ab.cost or {}) do
      if k.k == "ap" then s = s - 15 * k.n end
      if k.k == "retireSelf" or k.k == "removeSelf" then s = s - 20 end
      if k.k == "discard" then s = s - 8 * k.n end
    end
    if s > 0 then out[#out+1] = {kind = "ability", entry = entry, score = s} end
  end
  table.sort(out, function(a, b) return a.score > b.score end)
  return out
end
function AI.main(tp)
  local guard = 0
  local tried = {}
  while not P.finished and guard < 40 do
    guard = guard + 1
    local acts = actions(tp)
    local a = nil
    for _, x in ipairs(acts) do
      local key = x.kind .. ":" .. (x.c and x.c:GetRealFieldID() or (x.entry.c:GetRealFieldID() .. ":" .. x.entry.ab.idx))
      if not tried[key] then a = x; tried[key] = true break end
    end
    if not a then break end
    if a.kind == "raid" then
      P.raidFromHand(tp, a.c, AI.raidTarget(tp, a.c, a.targets))
      tried = {}
    elseif a.kind == "play" then
      if P.playFromHand(tp, a.c, a.line) then tried = {} end
    elseif a.kind == "event" then
      if P.useEvent(tp, a.c) then tried = {} end
    elseif a.kind == "ability" then
      P.useMain(tp, a.entry)
      tried = {}
    end
    P.drain()
  end
end

------------------------------------------------------------------------------
-- Attack phase
------------------------------------------------------------------------------
function AI.attacks(tp)
  local guard = 0
  while not P.finished and guard < 20 do
    guard = guard + 1
    local ready = sortBy(P.concat(P.front(tp, P.canAttack), P.energy(tp, P.canAttack)), function(c) return P.bp(c) end, true)
    local a = ready[1]
    if not a then break end
    local target = nil
    local snipe = P.snipeTargets(a)
    if #snipe > 0 then
      local beatable = P.filter(snipe, function(t) return P.bp(a) >= P.bp(t) end)
      if #beatable > 0 then target = sortBy(beatable, function(t) return P.bp(t) end, true)[1] end
    end
    P.attack(a, target)
  end
end
function AI.blockPick(dp, a, options)
  if #options == 0 then return nil end
  local abp = P.bp(a)
  local dmg = math.max(P.kwValue(a, "damage"), 1) + P.kwValue(a, "damagePlus")
  local safe = P.filter(options, function(b) return P.bp(b) > abp end)
  if #safe > 0 then return sortBy(safe, function(b) return P.bp(b) end)[1] end
  local life = P.lifeCount(dp)
  if life <= dmg + 1 then
    -- a chump block only helps when the attacker has no impact
    local impact = P.kwValue(a, "impact") + P.kwValue(a, "impactPlus")
    if impact == 0 or life <= dmg then return sortBy(options, fieldValue)[1] end
  end
  return nil
end

------------------------------------------------------------------------------
-- Triggers
------------------------------------------------------------------------------
function AI.triggerOrder(tp, cards)
  local out = {}
  for _, c in ipairs(cards) do out[#out+1] = c end
  -- FINAL last (it checks the life count after the others)
  table.sort(out, function(a, b)
    local fa, fb = P.triggerKind(a) == "final" and 1 or 0, P.triggerKind(b) == "final" and 1 or 0
    return fa < fb
  end)
  return out
end
function AI.useTrigger(tp, c)
  local f = P.fxOf(c)
  if not f.trig then return false end
  return P.actsPossible({tp = tp, c = c}, f.trig.act)
end
function AI.triggerRaid(tp, c, targets) return true end

------------------------------------------------------------------------------
-- Effect choices
------------------------------------------------------------------------------
function AI.millUpTo(tp, n) return math.min(n, math.max(0, P.deckCount(tp) - 10)) end
function AI.drawUpTo(tp, n) return math.min(n, math.max(0, P.deckCount(tp) - 5)) end
function AI.discardUpTo(tp, pool, n, op)
  if op.may then return (#P.hand(tp) >= n + 2) and n or 0 end
  if op.upTo then return #pool >= n + 2 and n or 0 end
  return n
end
-- What a card in hand is worth now: cards that can be used soon and energy makers while the energy line is short
-- are kept; far-off cards go first.
local function handValue(tp, c)
  local v = value(c)
  local d = P.data(c)
  if d and d.color ~= "" then
    local have = P.energyOf(tp, d.color)
    local gap = P.need(c) - have
    if gap <= 0 then v = v + 40 elseif gap == 1 then v = v + 20 end
    if d.gen and have < 5 then v = v + 30 end
  end
  return v
end
function AI.discardPick(tp, pool, n, op)
  local s = sortBy(pool, function(c) return handValue(tp, c) end)
  local out = {}
  for i = 1, math.min(n, #s) do out[i] = s[i] end
  return out
end
function AI.handLimit(tp, hand, n) return AI.discardPick(tp, hand, n, {}) end
-- op.ai: "harm" (opponent's cards: the strongest), "buff" (own: the strongest front character), "stand" (own rested
-- front), "cost" (own: the weakest), default: harm for the opponent's cards, buff for own.
function AI.pick(ctx, pool, n, op)
  if n <= 0 or #pool == 0 then return {} end
  local mode = op.ai
  -- "自分のフロントLの他のキャラを望む枚数このキャラの下に裏向きで置く": up to two weak ones
  if mode == "fodder" then
    local out = {}
    for _, c in ipairs(sortBy(pool, function(c) return P.onField(c) and fieldValue(c) or value(c) end)) do
      if #out < math.min(n, 2) and P.isChar(c) and P.bp(c) <= 4000 then out[#out+1] = c end
    end
    return out
  end
  if not mode then
    if op.side == "opp" then mode = "harm" elseif op.zone == "outside" or op.zone == "hand" then mode = "best" else mode = "buff" end
  end
  local sorted
  if mode == "harm" then sorted = sortBy(pool, function(c) return P.onField(c) and fieldValue(c) or value(c) end, true)
  elseif mode == "cost" or mode == "costRest" then sorted = sortBy(pool, function(c) return P.onField(c) and fieldValue(c) or value(c) end)
  elseif mode == "stand" then sorted = sortBy(pool, function(c) return (P.onFront(c) and 1000 or 0) + (P.isRested(c) and 500 or 0) + P.bp(c) / 100 end, true)
  elseif mode == "best" then sorted = sortBy(pool, value, true)
  else sorted = sortBy(pool, function(c) return (P.onFront(c) and 1000 or 0) + (P.isActive(c) and 300 or 0) + (P.isChar(c) and P.bp(c) / 100 or 0) end, true) end
  -- "まで" picks of the player's own cards for a harmful effect: none
  if op.upTo and mode == "cost" then return {} end
  local out = {}
  for i = 1, math.min(n, #sorted) do out[i] = sorted[i] end
  return out
end
function AI.lookPick(ctx, pool, n, pk)
  if pk.ai == "worst" then
    -- cards the player would rather not draw soon
    local out = {}
    for _, c in ipairs(pool) do if #out < n and not AI.keepOnTop(ctx.tp, c) then out[#out+1] = c end end
    return out
  end
  local s = sortBy(pool, value, true)
  local out = {}
  for i = 1, math.min(n, #s) do out[i] = s[i] end
  return out
end
function AI.keepOnTop(tp, c)
  return P.isChar(c) and P.baseNeed(c) <= P.energyOf(tp, P.color(c)) + 1
end
function AI.topOrBottom(tp, c, op) return AI.keepOnTop(tp, c) end
-- top or bottom of the card owner's deck, decided by tp (the effect's player): an opponent's card goes where its
-- owner would not want it
function AI.deckSide(tp, c, mode)
  local keep = AI.keepOnTop(c:GetOwner(), c)
  if mode == "opp" then return keep and "deckBottom" or "deckTop" end
  return keep and "deckTop" or "deckBottom"
end
function AI.putPick(ctx, pool, n, op)
  local s = sortBy(pool, function(c) return (P.data(c).bp or 0) + P.baseNeed(c) * 100 end, true)
  local out = {}
  for i = 1, math.min(n, #s) do out[i] = s[i] end
  return out
end
function AI.preferRaid(tp, c, targets) return true end
-- "手札に加えるか自分の場に登場させる": onto the field while a line has room
function AI.toHandInstead(tp, c)
  return P.lineCount(tp, AI.lineFor(tp, c)) >= P.LINE
end
function AI.forcedBlock(dp, a, options)
  table.sort(options, function(x, y) return P.bp(x) < P.bp(y) end)
  return options[1]
end
function AI.raidTarget(tp, c, targets)
  return sortBy(targets, function(t)
    return (P.onFront(t) and 20 or 0) + (P.isRested(t) and 10 or 0) - P.bp(t) / 1000
  end, true)[1]
end
function AI.chooseOptions(ctx, op)
  local out = {}
  local n = op.n or 1
  for i, o in ipairs(op.opts) do
    if #out >= n then break end
    if not (op.excluded and op.excluded[i]) and P.actsPossible(ctx, o) then out[#out+1] = i end
  end
  return out
end
-- "〜てもよい": decline only when it costs the player's own characters or a small hand
function AI.wantMay(ctx, op)
  for _, x in ipairs(op.act or {}) do
    if x.op == "discard" and #P.hand(ctx.tp) < (x.n or 1) + 1 then return false end
    if x.op == "pick" and x.side ~= "opp" and x.ai == "cost" then
      local pool = P.filter(P.zoneCards(ctx, x.side or "own", x.zone or "field"), function(c) return P.matches(c, x.filt, ctx) end)
      if #pool == 0 then return false end
    end
    if x.op == "lifeToHand" and P.lifeCount(ctx.tp) <= 3 then return false end
  end
  return true
end
function AI.wantCost(ctx, ab) return true end
function AI.payForMore(ctx, op) return #P.apActive(ctx.tp) >= 2 end
