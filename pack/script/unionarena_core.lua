-- UNION ARENA on EDOPro: state, zones, energy, BP and durations.
-- Rules: docs/rules.md (official rule manual 2023-08-18 + rules Q&A, docs/faq-rules.md). Rule references in the
-- comments are "manual p.N" (page of the official manual) or "Q&A QN".
-- Zones (README): front line = Monster Zones 0-3 (rested = face-up defense), energy line = Spell & Trap Zones 0-3
-- (characters and fields; rested is Lua state shown with hint 234), an event sits in Spell & Trap Zone 4 while it
-- resolves, raid = the cards under a raided character are its overlay, AP cards = face-up Extra Deck (the AP area,
-- rested is Lua state shown with hint 231) and face-down Extra Deck (AP cards not in the area yet), life area =
-- face-down banished, remove area = face-up banished, 場外 (outside area) = graveyard.
Duel.LoadScript("unionarena_catalog.lua")
Duel.LoadScript("unionarena_effects.lua")
UnionArenaAI = UnionArenaAI or {}
local P = UnionArenaAI
P.cat = UnionArenaCatalog.cards
P.fx = UnionArenaEffects or {}
P.started, P.finished = false, false
P.turnNo = 0
P.HINT_AP, P.HINT_ENERGY = 231, 234
P.LINE = 4          -- manual p.4: four cards per line
P.LIFE = 7          -- manual p.5: seven life cards
P.HAND_LIMIT = 8    -- manual p.13

local function list(g)
  local out = {}
  if g == nil then return out end
  for c in aux.Next(g) do out[#out+1] = c end
  return out
end
P.list = list
function P.group(cards)
  local g = Group.CreateGroup()
  for _, c in ipairs(cards) do g:AddCard(c) end
  return g
end
function P.log(event, details)
  local line = "UA|" .. event .. "|" .. (details or "")
  Debug.Message(line)
  if P.logfile then P.logfile:write(line .. "\n"); P.logfile:flush() end
end
function P.rand(a, b) if b <= a then return a end return Duel.GetRandomNumber(a, b) end
function P.shuffled(t)
  local out = {}
  for i, v in ipairs(t) do out[i] = v end
  for i = #out, 2, -1 do local j = P.rand(1, i); out[i], out[j] = out[j], out[i] end
  return out
end
function P.contains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function P.filter(t, f) local out = {} for _, x in ipairs(t) do if f(x) then out[#out+1] = x end end return out end
function P.concat(a, b) local out = {} for _, x in ipairs(a) do out[#out+1] = x end for _, x in ipairs(b) do out[#out+1] = x end return out end

------------------------------------------------------------------------------
-- Card data (manual pp.1-3)
------------------------------------------------------------------------------
function P.data(c) return c and P.cat[c:GetCode()] end
function P.fxOf(c) return c and P.fx[c:GetCode()] or {} end
function P.name(c) local d = P.data(c); return d and d.name or "?" end
function P.no(c) local d = P.data(c); return d and d.no or "?" end
function P.label(c) return P.name(c) .. "(" .. P.no(c) .. ")" end
function P.kind(c) local d = P.data(c); return d and d.kind end
function P.isChar(c) return P.kind(c) == "char" end
function P.isEvent(c) return P.kind(c) == "event" end
function P.isFieldCard(c) return P.kind(c) == "field" end
function P.isAP(c) return P.kind(c) == "ap" end
function P.color(c) return P.data(c).color end
function P.traits(c) return P.data(c).traits end
function P.hasTrait(c, t)
  for _, x in ipairs(P.traits(c)) do if x == t then return true end end
  local f = P.fxOf(c)
  if f.traitsAlso then for _, x in ipairs(f.traitsAlso) do if x == t then return true end end end
  return false
end
function P.noTraits(c) return #P.traits(c) == 0 end
-- Q&A Q87: "カード名を〈〇〇〉として扱う" works everywhere.
function P.names(c)
  local f = P.fxOf(c)
  -- "全ての場所でこのカードのカード名は〈…〉に変わる"
  if f.renameIf and P.condTrue and P.condTrue({tp = c:GetControler(), c = c}, f.renameIf.cond) then return {f.renameIf.name} end
  local out = {P.name(c)}
  if f.alias then for _, n in ipairs(f.alias) do out[#out+1] = n end end
  return out
end
function P.isNamed(c, n) for _, x in ipairs(P.names(c)) do if x == n then return true end end return false end
function P.nameHas(c, part) for _, x in ipairs(P.names(c)) do if x:find(part, 1, true) then return true end end return false end
function P.baseBP(c) return P.data(c).bp or 0 end
function P.baseNeed(c) return P.data(c).need or 0 end
function P.apCost(c) return P.data(c).ap or 1 end
function P.hasTriggerIcon(c) return (P.data(c).trigger or "") ~= "" end
function P.triggerKind(c) local f = P.fxOf(c); return f.trig and f.trig.kind end
function P.id(c) return c:GetRealFieldID() end
function P.supported(c) local f = P.fxOf(c); return f.ok == true end

------------------------------------------------------------------------------
-- Zones (manual p.4)
------------------------------------------------------------------------------
function P.onFront(c) return c ~= nil and c:IsLocation(LOCATION_MZONE) and c:GetSequence() < 4 end
function P.onEnergy(c) return c ~= nil and c:IsLocation(LOCATION_SZONE) and c:GetSequence() < 4 end
function P.onField(c) return P.onFront(c) or P.onEnergy(c) end
function P.lineOf(c) if P.onFront(c) then return "front" elseif P.onEnergy(c) then return "energy" end return nil end
function P.front(tp, filter)
  local out = {}
  for seq = 0, 3 do
    local c = Duel.GetFieldCard(tp, LOCATION_MZONE, seq)
    if c and (not filter or filter(c)) then out[#out+1] = c end
  end
  return out
end
function P.energy(tp, filter)
  local out = {}
  for seq = 0, 3 do
    local c = Duel.GetFieldCard(tp, LOCATION_SZONE, seq)
    if c and (not filter or filter(c)) then out[#out+1] = c end
  end
  return out
end
function P.field(tp, filter) return P.concat(P.front(tp, filter), P.energy(tp, filter)) end
function P.chars(tp, filter) return P.field(tp, function(c) return P.isChar(c) and (not filter or filter(c)) end) end
function P.allChars(filter)
  local tp = Duel.GetTurnPlayer()
  return P.concat(P.chars(tp, filter), P.chars(1 - tp, filter))
end
function P.freeSeq(tp, line)
  for seq = 0, 3 do
    if line == "front" and not Duel.GetFieldCard(tp, LOCATION_MZONE, seq) then return seq end
    if line == "energy" and not Duel.GetFieldCard(tp, LOCATION_SZONE, seq) then return seq end
  end
  return nil
end
function P.lineCount(tp, line) return line == "front" and #P.front(tp) or #P.energy(tp) end
function P.hand(tp) return list(Duel.GetFieldGroup(tp, LOCATION_HAND, 0)) end
function P.outside(tp) return list(Duel.GetFieldGroup(tp, LOCATION_GRAVE, 0)) end
function P.life(tp)
  local out = {}
  for _, c in ipairs(list(Duel.GetFieldGroup(tp, LOCATION_REMOVED, 0))) do if c:IsFacedown() then out[#out+1] = c end end
  table.sort(out, function(a, b) return a:GetSequence() > b:GetSequence() end)
  return out
end
function P.removeArea(tp)
  local out = {}
  for _, c in ipairs(list(Duel.GetFieldGroup(tp, LOCATION_REMOVED, 0))) do if c:IsFaceup() then out[#out+1] = c end end
  return out
end
function P.lifeCount(tp) return #P.life(tp) end
function P.deckCount(tp) return Duel.GetFieldGroupCount(tp, LOCATION_DECK, 0) end
function P.deckTop(tp, n) return list(Duel.GetDecktopGroup(tp, n)) end
function P.deckBottom(tp, n)
  local all = list(Duel.GetFieldGroup(tp, LOCATION_DECK, 0))
  table.sort(all, function(a, b) return a:GetSequence() < b:GetSequence() end)
  local out = {}
  for i = 1, math.min(n, #all) do out[i] = all[i] end
  return out
end
-- AP cards (manual p.3, p.8): face-up Extra Deck = the AP area, face-down = not in the area yet.
function P.apArea(tp)
  local out = {}
  for _, c in ipairs(list(Duel.GetFieldGroup(tp, LOCATION_EXTRA, 0))) do if c:IsFaceup() then out[#out+1] = c end end
  table.sort(out, function(a, b) return a:GetSequence() < b:GetSequence() end)
  return out
end
function P.apReserve(tp)
  local out = {}
  for _, c in ipairs(list(Duel.GetFieldGroup(tp, LOCATION_EXTRA, 0))) do if c:IsFacedown() then out[#out+1] = c end end
  return out
end
-- Raid (manual p.10): the cards under a raided character are its overlay. Face-down cards placed under a character
-- by effects ("裏向きでこのキャラの下に置く") are overlay cards too, marked in P.fd (Lua state; the client shows them like
-- the raided card's base).
P.fd = {}
function P.under(c)
  if not P.onField(c) then return {} end
  return list(c:GetOverlayGroup())
end
function P.fdUnder(c)
  local out = {}
  for _, x in ipairs(P.under(c)) do if P.fd[x] then out[#out+1] = x end end
  return out
end
function P.raidUnder(c)
  local out = {}
  for _, x in ipairs(P.under(c)) do if not P.fd[x] then out[#out+1] = x end end
  return out
end
function P.isRaided(c) return #P.raidUnder(c) > 0 end
function P.controller(c) return c:GetControler() end

------------------------------------------------------------------------------
-- Active / rest (manual p.6). Front line: position. Energy line and AP: Lua state + hints.
------------------------------------------------------------------------------
P.erest = {}  -- [card] = field id while that energy line card is rested
P.aprest = {} -- [card] = field id while that AP card is rested
function P.isRested(c)
  if P.onFront(c) then return c:IsDefensePos() end
  if P.onEnergy(c) then return P.erest[c] == c:GetFieldID() end
  if c:IsLocation(LOCATION_EXTRA) then return P.aprest[c] == c:GetFieldID() end
  return false
end
function P.isActive(c) return not P.isRested(c) end
function P.syncRest(tp)
  P.hintCache = P.hintCache or {}
  local m = 0
  for _, c in ipairs(P.energy(tp)) do if P.isRested(c) then m = m | (1 << c:GetSequence()) end end
  if P.hintCache["e" .. tp] ~= m then P.hintCache["e" .. tp] = m; Duel.Hint(P.HINT_ENERGY, tp, m) end
  local a = 0
  for i, c in ipairs(P.apArea(tp)) do if P.isRested(c) and i <= 63 then a = a | (1 << (i - 1)) end end
  if P.hintCache["a" .. tp] ~= a then P.hintCache["a" .. tp] = a; Duel.Hint(P.HINT_AP, tp, a) end
end
-- Raw state change (no "when it becomes active" triggers; flow.lua P.stand / P.rest handle those).
function P.setRested(c, rested)
  if P.onFront(c) then
    if rested and c:IsAttackPos() then Duel.ChangePosition(c, POS_FACEUP_DEFENSE) return true end
    if not rested and c:IsDefensePos() then Duel.ChangePosition(c, POS_FACEUP_ATTACK) return true end
    return false
  end
  local tbl = P.onEnergy(c) and P.erest or (c:IsLocation(LOCATION_EXTRA) and P.aprest or nil)
  if not tbl then return false end
  if P.isRested(c) == rested then return false end
  tbl[c] = rested and c:GetFieldID() or nil
  P.syncRest(c:GetControler())
  return true
end

------------------------------------------------------------------------------
-- Durations: {turn = n} ends with turn n ("このターン中"); {ownStart = tp, after = n} ends at the start of tp's
-- next turn after turn n ("次の自分のターン開始時まで"); {battle = k} ends with battle k; nil = while on the field.
------------------------------------------------------------------------------
function P.thisTurn() return {turn = P.turnNo} end
P.startCleared = {}
P.closedTurn = 0
function P.active(exp)
  if exp == nil then return true end
  if exp.turn then return exp.turn >= P.turnNo and P.closedTurn ~= exp.turn end
  if exp.ownStart then return (P.startCleared[exp.ownStart] or -1) <= exp.after end
  if exp.battle then return P.battleState ~= nil and P.battleState.key == exp.battle end
  if exp.whileOnFront then return P.onFront(exp.whileOnFront) and P.id(exp.whileOnFront) == exp.key end
  if exp.attackEndOf then return (P.attackPhaseEnded[exp.attackEndOf] or -1) <= exp.after end
  if exp.nextTurnOf then
    -- "次の相手のターン中": from the start of that player's next turn to its end
    return P.turnNo > exp.after and (P.closedTurn < P.turnNo or Duel.GetTurnPlayer() ~= exp.nextTurnOf)
      and not (P.turnNo > exp.after + 1 and P.closedTurnOf and (P.closedTurnOf[exp.nextTurnOf] or -1) > exp.after)
  end
  return true
end
P.attackPhaseEnded = {}
function P.durationOf(kind, tp)
  if kind == "turn" then return P.thisTurn() end
  if kind == "untilOwnStart" then return {ownStart = tp, after = P.turnNo} end
  if kind == "battle" then return P.battleState and {battle = P.battleState.key} or P.thisTurn() end
  if kind == "whileSelfFront" then return P.durationSource and {whileOnFront = P.durationSource, key = P.id(P.durationSource)} or P.thisTurn() end
  if kind == "untilOppAttackEnd" then return {attackEndOf = 1 - tp, after = P.turnNo} end
  if kind == "nextOppTurn" then return {nextTurnOf = 1 - tp, after = P.turnNo} end
  return nil
end

P.mods = {}     -- {card=, fid=, bp=n, exp=}
P.flags = {}    -- {card=, fid=, flag=, value=, exp=, data=}
P.peffects = {} -- player effects {tp=, kind=, exp=, data=}
function P.alive(entry) return entry.card and P.onField(entry.card) and P.id(entry.card) == entry.fid end
function P.addBP(c, n, exp, why)
  if not P.onField(c) then return end
  if n < 0 and P.condStatic and P.condStatic(c, "flag", "noBPMinus") then P.log("BP_IMMUNE", "card=" .. P.label(c)) return end
  P.mods[#P.mods+1] = {card = c, fid = P.id(c), bp = n, exp = exp}
  P.log("BP", "card=" .. P.label(c) .. ";by=" .. n .. ";now=" .. P.bp(c) .. (why and (";why=" .. why) or ""))
  if n > 0 and P.onBPPlus then P.onBPPlus(c) end
end
function P.addFlag(c, flag, exp, value, data)
  if not P.onField(c) then return end
  P.flags[#P.flags+1] = {card = c, fid = P.id(c), flag = flag, value = value, exp = exp, data = data}
  P.log("FLAG", "card=" .. P.label(c) .. ";flag=" .. flag .. (value and (";value=" .. tostring(value)) or ""))
end
function P.flagEntries(c, flag)
  local out = {}
  if not P.onField(c) then return out end
  local fid = P.id(c)
  for _, f in ipairs(P.flags) do
    if f.card == c and f.fid == fid and f.flag == flag and P.active(f.exp) and not f.used then out[#out+1] = f end
  end
  return out
end
function P.hasFlag(c, flag) return #P.flagEntries(c, flag) > 0 end
function P.useFlag(c, flag) local e = P.flagEntries(c, flag)[1]; if e then e.used = true; return e end return nil end
function P.addPlayerEffect(tp, kind, exp, data)
  P.peffects[#P.peffects+1] = {tp = tp, kind = kind, exp = exp, data = data or {}}
  P.log("PLAYER_EFFECT", "player=" .. tp .. ";kind=" .. kind)
end
function P.playerEffects(tp, kind)
  local out = {}
  for _, e in ipairs(P.peffects) do if e.tp == tp and e.kind == kind and P.active(e.exp) and not e.used then out[#out+1] = e end end
  return out
end
function P.prune()
  local function keep(t)
    local out = {}
    for _, x in ipairs(t) do
      if P.active(x.exp) and not x.used and (x.card == nil or P.alive(x)) then out[#out+1] = x end
    end
    return out
  end
  P.mods, P.flags, P.peffects = keep(P.mods), keep(P.flags), keep(P.peffects)
end

------------------------------------------------------------------------------
-- Static abilities. A raided character keeps only the top card's text (manual p.10, Q&A Q50).
-- A card's own statics: P.fxOf(c).static = list of {kind=, ...} compiled by tools/compile_effects.py.
------------------------------------------------------------------------------
function P.statics(c, kind)
  local out = {}
  local f = P.fxOf(c)
  if f.static then for _, s in ipairs(f.static) do if s.kind == kind then out[#out+1] = s end end end
  return out
end
-- Auras: statics of cards on the field that change other cards ({kind="aura", ...}).
function P.auras()
  local out = {}
  for tp = 0, 1 do
    for _, src in ipairs(P.field(tp)) do
      for _, s in ipairs(P.statics(src, "aura")) do out[#out+1] = {src = src, s = s, tp = tp} end
    end
  end
  return out
end

------------------------------------------------------------------------------
-- Keywords (manual p.14): own text (P.fxOf(c).kw), granted flags, conditional statics.
------------------------------------------------------------------------------
P.KW_VALUE = {impact = true, impactPlus = true, damage = true, damagePlus = true}
function P.kw(c, word)
  if not P.onField(c) then
    local f = P.fxOf(c)
    return f.kw and f.kw[word] or nil
  end
  if word == "impact" or word == "impactPlus" or word == "damage" or word == "damagePlus" then return P.kwValue(c, word) end
  local f = P.fxOf(c)
  if f.kw and f.kw[word] and not P.lostText(c) then return true end
  if P.hasFlag(c, word) then return true end
  if P.condStatic and P.condStatic(c, "kw", word) then return true end
  for _, e in ipairs(P.flagEntries(c, "condKw")) do
    if e.data.kw == word and P.condTrue({tp = c:GetControler(), c = c}, e.data.cond) then return true end
  end
  return false
end
-- Impact: the largest of the given values (Q&A: impact(1) twice is impact(1)); impact+1 stacks (Q&A Q76).
function P.kwValue(c, word)
  local f = P.fxOf(c)
  local best, sum = 0, 0
  local function add(v)
    if word == "impactPlus" or word == "damagePlus" then sum = sum + (v or 1) else best = math.max(best, v or 0) end
  end
  if f.kw and f.kw[word] and not P.lostText(c) then add(f.kw[word]) end
  for _, e in ipairs(P.flagEntries(c, word)) do add(e.value) end
  for _, e in ipairs(P.flagEntries(c, "condKw")) do
    if e.data.kw == word and P.condTrue({tp = c:GetControler(), c = c}, e.data.cond) then add(e.data.value) end
  end
  if P.condStatic then for _, v in ipairs(P.condStatic(c, "kwValues", word) or {}) do add(v) end end
  if word == "impactPlus" or word == "damagePlus" then return sum end
  return best
end
function P.lostText(c) return P.hasFlag(c, "loseText") end

------------------------------------------------------------------------------
-- BP (manual p.12, Q&A Q32): base + modifiers + statics. P.bpStatic is set by the runtime.
------------------------------------------------------------------------------
P.battleState = nil
function P.bp(c)
  local v = P.baseBP(c)
  local fid = P.id(c)
  for _, m in ipairs(P.mods) do
    if m.card == c and m.fid == fid and P.active(m.exp) then v = v + (m.fn and m.fn(c) or m.bp) end
  end
  if P.bpStatic then v = v + P.bpStatic(c) end
  return v
end

------------------------------------------------------------------------------
-- Energy (manual p.4, p.9; Q&A Q25, Q26): the generated energy of the cards in the energy line, rested or active.
------------------------------------------------------------------------------
function P.genOf(c)
  local out = {}
  local d = P.data(c)
  if d.gen then out[d.gen.color] = d.gen.n end
  if P.genStatic then
    for color, n in pairs(P.genStatic(c)) do out[color] = (out[color] or 0) + n end
  end
  return out
end
-- except: cards that will be removed to make room still count (Q&A Q24).
function P.energyOf(tp, color, extra)
  local n = 0
  local src = P.energy(tp)
  local allFront = P.playerEffects and #P.playerEffects(tp, "allFrontEnergy") > 0
  for _, c in ipairs(P.front(tp)) do
    if P.hasFlag(c, "frontEnergy") or (allFront and P.isChar(c)) or (P.condStatic and P.condStatic(c, "flag", "frontEnergy")) then src[#src+1] = c end
  end
  -- "自分の場のカード全ての発生エナジーは2倍になる" (stacks)
  local mult = 1
  if P.playerEffects then for _ in ipairs(P.playerEffects(tp, "genDouble")) do mult = mult * 2 end end
  for _, c in ipairs(src) do
    local g = P.genOf(c)
    if color == nil then for _, k in pairs(g) do n = n + k * mult end else n = n + (g[color] or 0) * mult end
  end
  if extra and extra[color] then n = n + extra[color] end
  return n
end
function P.need(c)
  local n = P.baseNeed(c)
  if P.needStatic then n = n - P.needStatic(c) end
  -- increases: "このターン中、必要エナジーを2増やす", "自分の場の他のキャラ全ての必要エナジーを2増やす"
  if P.onField(c) then
    for _, e in ipairs(P.flagEntries(c, "needPlus")) do n = n + (e.value or 0) end
    if P.auras then
      for _, a in ipairs(P.auras()) do
        if a.s.effect == "needPlus" and a.tp == c:GetControler() and a.src ~= c and P.matches(c, a.s.filt, {tp = a.tp, c = a.src}) then n = n + a.s.n end
      end
    end
  end
  return math.max(0, n)
end
function P.meetsNeed(tp, c, extra) return P.energyOf(tp, P.color(c), extra) >= P.need(c) end

------------------------------------------------------------------------------
-- Once-per-turn bookkeeping
------------------------------------------------------------------------------
P.once = {}
function P.firstTime(key) if P.once[key] == P.turnNo then return false end P.once[key] = P.turnNo return true end
function P.usedThisTurn(key) return P.once[key] == P.turnNo end
P.history = {}
function P.mark(key, n) P.history[key] = {turn = P.turnNo, n = (P.marked(key) and P.history[key].n or 0) + (n or 1)} end
function P.marked(key) return P.history[key] ~= nil and P.history[key].turn == P.turnNo end
function P.markCount(key) return P.marked(key) and P.history[key].n or 0 end
P.entered = {}   -- [field id] = turn it came onto the field
P.enteredBy = {} -- [field id] = "hand" | "effect" | "raid" | ...
P.enteredFrom = {} -- [field id] = the zone it came from
P.enteredByChar = {} -- [field id] = true when a character's effect put it there
P.raidHow = {} -- [field id] = how it raided (hand / effect / trigger)
P.retiredLog = {} -- {turn=, tp=, card=}
P.enteredLog = {} -- {turn=, tp=, card=}
