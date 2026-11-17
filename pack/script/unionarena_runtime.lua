-- UNION ARENA on EDOPro: the interpreter of the compiled card effects (pack/script/unionarena_effects.lua, made by
-- tools/compile_effects.py from the official Japanese text). A card whose text has a sentence the compiler does not
-- know is unsupported (ok=false) and decks with it are rejected; nothing is approximated by a nearby effect.
local P = UnionArenaAI
local list = P.list

------------------------------------------------------------------------------
-- Filters (compiled "filt" tables)
------------------------------------------------------------------------------
function P.matches(c, f, ctx)
  if f == nil then return true end
  if f.kind then
    local k = P.kind(c)
    if (f.kind == "event" or (type(f.kind) == "table" and P.contains(f.kind, "event"))) and P.isAlsoEvent(c) then k = "event" end
    if type(f.kind) == "table" then if not P.contains(f.kind, k) then return false end
    elseif k ~= f.kind then return false end
  end
  if f.color then
    if type(f.color) == "table" then if not P.contains(f.color, P.color(c)) then return false end
    elseif P.color(c) ~= f.color then return false end
  end
  local onF = P.onField(c)
  local bpMax = f.bpMax
  if bpMax and f.bpMaxPlus and ctx and P.condTrue(ctx, f.bpMaxPlus.cond) then
    local per = f.bpMaxPlus.per
    local n
    if per.mark then n = P.markCount(per.mark .. ":" .. ctx.tp)
    elseif per.sel then n = #((ctx.sel or {})[per.sel] or {})
    else n = P.countOf(ctx, per) end
    bpMax = bpMax + n * f.bpMaxPlus.n
  end
  if bpMax and not (P.isChar(c) and (onF and P.bp(c) or P.baseBP(c)) <= bpMax) then return false end
  if f.bpMin and not (P.isChar(c) and (onF and P.bp(c) or P.baseBP(c)) >= f.bpMin) then return false end
  if f.baseBP and not (P.isChar(c) and P.baseBP(c) == f.baseBP) then return false end
  if f.baseBPMax and not (P.isChar(c) and P.baseBP(c) <= f.baseBPMax) then return false end
  if f.baseBPMin and not (P.isChar(c) and P.baseBP(c) >= f.baseBPMin) then return false end
  -- Q&A Q100: the required energy after effects
  if f.needMax and not f.needMaxPlus and P.need(c) > f.needMax then return false end
  if f.needMin and P.need(c) < f.needMin then return false end
  if f.needEq and P.need(c) ~= f.needEq then return false end
  if f.needOk and ctx and not P.meetsNeed(ctx.tp, c) then return false end
  if f.needMaxPlus and ctx and f.needMax then
    local cnt
    if f.needMaxPlus.per.names then
      local seen = {}
      cnt = 0
      for _, x in ipairs(P.zoneCards(ctx, f.needMaxPlus.per.side or "own", f.needMaxPlus.per.zone or "field")) do
        if P.matches(x, f.needMaxPlus.per.filt, ctx) and not seen[P.name(x)] then seen[P.name(x)] = true; cnt = cnt + 1 end
      end
    else
      cnt = P.countOf(ctx, f.needMaxPlus.per)
    end
    local lim = f.needMax + math.floor(cnt / f.needMaxPlus.every) * f.needMaxPlus.n
    if P.need(c) > lim then return false end
  end
  if f.ap and P.apCost(c) ~= f.ap then return false end
  if f.trait and not P.hasTrait(c, f.trait) then return false end
  if f.anyTrait then
    local ok = false
    for _, t in ipairs(f.anyTrait) do if P.hasTrait(c, t) then ok = true end end
    if not ok then return false end
  end
  if f.noTrait and not P.noTraits(c) then return false end
  if f.withTrait and P.noTraits(c) then return false end
  if f.kind == "char" and false then return false end
  if f.side and ctx and ((f.side == "own") ~= (c:GetControler() == ctx.tp)) then return false end
  if f.notTrait and P.hasTrait(c, f.notTrait) then return false end
  if f.apMin and P.apCost(c) < f.apMin then return false end
  if f.notTrig and P.contains(f.notTrig, P.triggerKind(c)) then return false end
  if f.frozen and not (onF and P.hasFlag(c, "freeze")) then return false end
  if f.names then
    local ok = false
    for _, n in ipairs(f.names) do if P.isNamed(c, n) then ok = true end end
    if not ok then return false end
  end
  if f.notNames then for _, n in ipairs(f.notNames) do if P.isNamed(c, n) then return false end end end
  if f.nameHas and not P.nameHas(c, f.nameHas) then return false end
  if f.nameNotHas and P.nameHas(c, f.nameNotHas) then return false end
  if f.nameHasAny then
    local ok = false
    for _, part in ipairs(f.nameHasAny) do if P.nameHas(c, part) then ok = true end end
    if not ok then return false end
  end  if f.other and ctx and c == ctx.c then return false end
  if f.self and ctx and c ~= ctx.c then return false end
  if f.active and not (onF and P.isActive(c)) then return false end
  if f.rested and not (onF and P.isRested(c)) then return false end
  if f.hasTrigger ~= nil and P.hasTriggerIcon(c) ~= f.hasTrigger then return false end
  if f.trig and P.triggerKind(c) ~= f.trig then return false end
  if f.hasRaid ~= nil and ((P.fxOf(c).raid ~= nil) ~= f.hasRaid) then return false end
  if f.raided ~= nil and P.isRaided(c) ~= f.raided then return false end
  if f.bpLtBase and not (onF and P.bp(c) < P.baseBP(c)) then return false end
  if f.bpGtBase and not (onF and P.bp(c) > P.baseBP(c)) then return false end
  if f.line and P.lineOf(c) ~= f.line then return false end
  if f.any then
    local ok = false
    for _, g in ipairs(f.any) do if P.matches(c, g, ctx) then ok = true break end end
    if not ok then return false end
  end
  if f.notSelected and ctx and ctx.picked and ctx.picked[c] then return false end
  if f.bpMaxSel and ctx then
    local lim = (ctx.selBP or {})[f.bpMaxSel]
    if lim == nil or not (P.isChar(c) and (onF and P.bp(c) or P.baseBP(c)) <= lim) then return false end
  end  if f.notAttacked and onF and P.marked("attacked:" .. P.id(c)) then return false end
  if f.genMin then
    local d = P.data(c)
    if not (d.gen and d.gen.n >= f.genMin) then return false end
  end
  if f.bpMaxSelNeed and ctx then
    local lim = ((ctx.selNeed or {})[f.bpMaxSelNeed.sel] or 0) * f.bpMaxSelNeed.mult
    if not (P.isChar(c) and (onF and P.bp(c) or P.baseBP(c)) <= lim) then return false end
  end
  if f.baseNames then
    local ok = false
    for _, x in ipairs(onF and P.raidUnder(c) or {}) do for _, n in ipairs(f.baseNames) do if P.isNamed(x, n) then ok = true end end end
    if not ok then return false end
  end
  -- face-down cards under a card (zone fdUnder): the card they are under
  if f.holderSelf and not (ctx and P.contains(P.fdUnder(ctx.c), c)) then return false end
  if f.holder then
    local h = P.holderOf(c)
    if not h or not P.matches(h, f.holder, ctx) then return false end
  end
  if f.baseNeedMin and P.baseNeed(c) < f.baseNeedMin then return false end
  if f.notNeedOfSel and ctx then
    for _, x in ipairs((ctx.sel or {})[f.notNeedOfSel] or {}) do if P.baseNeed(x) == P.baseNeed(c) then return false end end
  end
  if f.notSel and ctx then
    for _, x in ipairs((ctx.sel or {})[f.notSel] or {}) do if x == c then return false end end
  end
  if f.notRaidedName and ctx then
    for _, n in ipairs(P.names(c)) do if P.marked("raidedName:" .. n .. ":" .. ctx.tp) then return false end end
  end
  if f.fdNone and not (onF and #P.fdUnder(c) == 0) then return false end
  if f.fdSome and not (onF and #P.fdUnder(c) > 0) then return false end
  if f.notOnFieldName and ctx then
    for _, x in ipairs(P.field(ctx.tp)) do if P.isNamed(c, P.name(x)) then return false end end
  end
  if f.notNoOfSel and ctx then
    for _, x in ipairs((ctx.sel or {})[f.notNoOfSel] or {}) do if P.no(x) == P.no(c) then return false end end
  end
  if f.notNameOfSel and ctx then
    for _, x in ipairs((ctx.sel or {})[f.notNameOfSel] or {}) do if P.isNamed(c, P.name(x)) then return false end end
  end
  if f.hasMain then
    local ok = false
    for _, ab in ipairs(P.fxOf(c).abil or {}) do if ab.when == "main" then ok = true end end
    if not ok then return false end
  end
  if f.bpMaxPer and ctx then
    local limit
    if f.bpMaxPer.trigKinds then
      local kinds, n = {}, 0
      for _, x in ipairs(P.zoneCards(ctx, f.bpMaxPer.side or "own", f.bpMaxPer.zone or "outside")) do
        local k = P.triggerKind(x)
        if k and P.matches(x, f.bpMaxPer.filt, ctx) and not kinds[k] then kinds[k] = true; n = n + 1 end
      end
      limit = n * f.bpMaxPer.mult
    elseif f.bpMaxPer.names then
      local seen, n = {}, 0
      for _, x in ipairs(P.zoneCards(ctx, f.bpMaxPer.side or "own", f.bpMaxPer.zone or "field")) do
        if not (f.bpMaxPer.filt.other and x == ctx.c) and P.matches(x, f.bpMaxPer.filt, ctx) and not seen[P.name(x)] then seen[P.name(x)] = true; n = n + 1 end
      end
      limit = n * f.bpMaxPer.mult
    else
      limit = P.countOf(ctx, f.bpMaxPer) * f.bpMaxPer.mult
    end
    if not (P.isChar(c) and (onF and P.bp(c) or P.baseBP(c)) <= limit) then return false end
  end
  return true
end

-- Cards in a zone. side: "own" | "opp" | "both"; zone: field | front | energy | hand | outside | remove | deck | life
function P.zoneCards(ctx, side, zone)
  local out = {}
  local players = side == "opp" and {1 - ctx.tp} or (side == "both" and {ctx.tp, 1 - ctx.tp} or {ctx.tp})
  for _, p in ipairs(players) do
    local src
    if zone == "field" then src = P.field(p)
    elseif zone == "fieldOrOutside" then src = P.concat(P.field(p), P.outside(p))
    elseif zone == "fieldAndUnder" then
      src = P.field(p)
      for _, c in ipairs(P.field(p)) do for _, x in ipairs(P.under(c)) do src[#src+1] = x end end
    elseif zone == "fdUnder" then
      src = {}
      for _, c in ipairs(P.field(p)) do for _, x in ipairs(P.fdUnder(c)) do src[#src+1] = x end end
    elseif zone == "front" then src = P.front(p)
    elseif zone == "energy" then src = P.energy(p)
    elseif zone == "hand" then src = P.hand(p)
    elseif zone == "outside" then src = P.outside(p)
    elseif zone == "remove" then src = P.removeArea(p)
    elseif zone == "life" then src = P.life(p)
    elseif zone == "ap" then src = P.apArea(p)
    else src = {} end
    for _, c in ipairs(src) do out[#out+1] = c end
  end
  return out
end
function P.auraProtects(c, effect)
  for _, a in ipairs(P.auras()) do
    if a.s.effect == effect and a.tp == c:GetControler() and staticOnRef(a.src, a.s) and P.matches(c, a.s.filt, {tp = a.tp, c = a.src}) then return true end
  end
  return false
end
function P.handTaxed(c)
  if P.hasFlag(c, "handTax") then return true end
  for _, e in ipairs(P.playerEffects(c:GetControler(), "handTax")) do
    if P.matches(c, e.data.filt, {tp = c:GetControler()}) then return true end
  end
  return false
end
-- "自分の効果で自分の手札のキャラカードのBPを参照する場合、BP+1000されたものとして扱ってもよい"
function P.handBPPlus(tp)
  local n = 0
  for _, e in ipairs(P.playerEffects(tp, "handBPPlus")) do n = n + e.data.n end
  for _, a in ipairs(P.auras()) do
    if a.s.effect == "handBPPlus" and a.tp == tp and staticOnRef(a.src, a.s) then n = n + a.s.n end
  end
  return n
end
-- the field card a face-down card is under
function P.holderOf(x)
  for p = 0, 1 do
    for _, c in ipairs(P.field(p)) do if P.contains(P.under(c), x) then return c end end
  end
  return nil
end
function P.countOf(ctx, spec)
  local n = 0
  -- "自分の効果で自分の場外にあるイベントカードの枚数を参照する場合、その枚数は1枚多く" (does not stack)
  if (spec.side or "own") == "own" and spec.zone == "outside" and spec.filt and spec.filt.kind == "event" then
    for _, a in ipairs(P.auras()) do if a.s.effect == "outsideEventPlus" and a.tp == ctx.tp then n = 1 break end end
  end
  for _, c in ipairs(P.zoneCards(ctx, spec.side or "own", spec.zone or "field")) do
    if P.matches(c, spec.filt, ctx) then n = n + 1 end
  end
  return n
end

------------------------------------------------------------------------------
-- Conditions
------------------------------------------------------------------------------
function P.condTrue(ctx, cond)
  if cond == nil then return true end
  local k = cond.c
  if k == "and" then for _, x in ipairs(cond.list) do if not P.condTrue(ctx, x) then return false end end return true end
  if k == "or" then for _, x in ipairs(cond.list) do if P.condTrue(ctx, x) then return true end end return false end
  if k == "not" then return not P.condTrue(ctx, cond.x) end
  if k == "count" then
    local n = P.countOf(ctx, cond)
    if cond.min and n < cond.min then return false end
    if cond.max and n > cond.max then return false end
    return true
  end
  if k == "selfActive" then return P.onField(ctx.c) and P.isActive(ctx.c) end
  if k == "selfRested" then return P.onField(ctx.c) and P.isRested(ctx.c) end
  if k == "selfFront" then return P.onFront(ctx.c) end
  if k == "selfEnergy" then return P.onEnergy(ctx.c) end
  if k == "selfRaided" then return P.isRaided(ctx.c) end
  if k == "fieldOrBase" then
    for _, c in ipairs(P.field(ctx.tp)) do
      if P.isNamed(c, cond.name) then return true end
      for _, x in ipairs(P.raidUnder(c)) do if P.isNamed(x, cond.name) then return true end end
    end
    return false
  end
  if k == "ctxFlag" then return ctx[cond.key] == true end
  if k == "selNeedSum" then
    local n = 0
    for _, c in ipairs((ctx.sel or {})[cond.as or "d"] or {}) do n = n + P.baseNeed(c) end
    return n >= (cond.min or 0)
  end
  if k == "baseOutside" then
    for _, x in ipairs((ctx.data and ctx.data.base) or {}) do
      if x:IsLocation(LOCATION_GRAVE) and P.matches(x, cond.filt, ctx) then return true end
    end
    return false
  end
  if k == "raiderFd" then
    local r = ctx.data and ctx.data.raider
    return r ~= nil and P.onField(r) and #P.fdUnder(r) > 0
  end
  if k == "ownTurn" then return Duel.GetTurnPlayer() == ctx.tp end
  if k == "oppTurn" then return Duel.GetTurnPlayer() ~= ctx.tp end
  if k == "life" then
    local n = P.lifeCount(cond.side == "opp" and 1 - ctx.tp or ctx.tp)
    if cond.min and n < cond.min then return false end
    if cond.max and n > cond.max then return false end
    return true
  end
  if k == "lifeLess" then return P.lifeCount(ctx.tp) < P.lifeCount(1 - ctx.tp) end
  if k == "lifeMoreOrEq" then return P.lifeCount(ctx.tp) >= P.lifeCount(1 - ctx.tp) end
  if k == "enteredThisTurn" then return P.onField(ctx.c) and P.entered[P.id(ctx.c)] == P.turnNo end
  if k == "enteredBy" then return P.onField(ctx.c) and P.enteredBy[P.id(ctx.c)] == cond.how end
  if k == "notEnteredByChar" then return not (ctx.enterInfo and ctx.enterInfo.byChar) end
  if k == "marked" then return P.marked(cond.key .. ":" .. (cond.side == "opp" and 1 - ctx.tp or ctx.tp)) end
  if k == "ok" then return ctx.ok == true end
  if k == "selected" then
    local s = ctx.sel and ctx.sel[cond.as or "t"] or {}
    if cond.filt then for _, c in ipairs(s) do if not P.matches(c, cond.filt, ctx) then return false end end end
    return #s > 0
  end
  if k == "selfBPGtBase" then return P.onField(ctx.c) and P.bp(ctx.c) > P.baseBP(ctx.c) end
  if k == "deck" then
    local n = P.deckCount(ctx.tp)
    return (not cond.min or n >= cond.min) and (not cond.max or n <= cond.max)
  end
  if k == "handCount" then
    local n = #P.hand(cond.side == "opp" and 1 - ctx.tp or ctx.tp)
    return (not cond.min or n >= cond.min) and (not cond.max or n <= cond.max)
  end
  if k == "attacking" then return P.attackState ~= nil and P.attackState.attacker == ctx.c end
  if k == "selfOutside" then return ctx.c:IsLocation(LOCATION_GRAVE) end
  if k == "markCount" then
    local need = (cond.min or 1) + ((cond.otherEvent and P.isEvent(ctx.c)) and 1 or 0)
    return P.markCount(cond.key .. ":" .. (cond.side == "opp" and 1 - ctx.tp or ctx.tp)) >= need
  end
  if k == "sameLine" then
    if not P.onField(ctx.c) then return false end
    local line = P.lineOf(ctx.c)
    for _, c in ipairs(P.field(ctx.tp)) do if c ~= ctx.c and P.lineOf(c) == line and P.matches(c, cond.filt, ctx) then return true end end
    return false
  end
  if k == "trigKinds" then
    local kinds, n = {}, 0
    for _, c in ipairs(P.zoneCards(ctx, cond.side or "own", cond.zone or "outside")) do
      if not (cond.filt and cond.filt.other and c == ctx.c) and P.matches(c, cond.filt, ctx) then
        local k = P.triggerKind(c)
        if k and not kinds[k] then kinds[k] = true; n = n + 1 end
      end
    end
    return (not cond.min or n >= cond.min) and (not cond.max or n <= cond.max)
  end
  if k == "lineFree" then return P.lineCount(ctx.tp, cond.line) < P.LINE end
  if k == "movedThisTurn" then return P.onField(ctx.c) and P.marked("moved:" .. P.id(ctx.c)) end
  if k == "putFrom" then
    for _, c in ipairs((ctx.sel or {}).p or {}) do if (ctx.putFrom or {})[c] == cond.zone and P.onField(c) then return true end end
    return false
  end
  if k == "usedFromRemove" then
    if ctx.usedFrom then return ctx.usedFrom == "remove" end
    return P.onField(ctx.c) and P.enteredFrom[P.id(ctx.c)] == "remove"
  end
  if k == "handLess" then return #P.hand(ctx.tp) < #P.hand(1 - ctx.tp) end
  if k == "selfNeed" then return P.need(ctx.c) >= (cond.min or 0) end
  if k == "energy" then return P.energyOf(ctx.tp, cond.color) >= (cond.min or 0) end
  if k == "phase" then return P.phase == cond.phase and (not cond.own or Duel.GetTurnPlayer() == ctx.tp) end
  if k == "fdCount" then
    local n = P.onField(ctx.c) and #P.fdUnder(ctx.c) or ((ctx.data and ctx.data.fdBefore) or 0)
    return (not cond.min or n >= cond.min) and (not cond.max or n <= cond.max)
  end
  if k == "enteredNames" then
    local seen, n = {}, 0
    for _, e in ipairs(P.enteredLog) do
      if e.turn == P.turnNo and e.tp == ctx.tp and P.matches(e.card, cond.filt, ctx) and not seen[P.name(e.card)] then seen[P.name(e.card)] = true; n = n + 1 end
    end
    return n >= cond.min
  end
  if k == "selfBPMax" then return P.onField(ctx.c) and P.bp(ctx.c) <= cond.max end
  if k == "restedByOwnEffect" then return P.onField(ctx.c) and P.marked("restedOwn:" .. P.id(ctx.c)) end
  if k == "traitsOnly" then
    for _, c in ipairs(P.field(ctx.tp)) do
      for _, t in ipairs(P.traits(c)) do if t ~= cond.trait then return false end end
    end
    return true
  end
  if k == "srcNamed" then
    local by = ctx.data and ctx.data.by
    if not by then return false end
    for _, n in ipairs(cond.names) do if P.isNamed(by, n) then return true end end
    return false
  end
  if k == "firstAttack" then return P.markCount("attack:" .. ctx.tp) == 1 end
  if k == "movedByEffect" then return P.onField(ctx.c) and P.marked("movedByEffect:" .. P.id(ctx.c)) end
  if k == "raidedByEffect" then return P.onField(ctx.c) and P.raidHow[P.id(ctx.c)] ~= nil and P.raidHow[P.id(ctx.c)] ~= "hand" end
  if k == "enteredByChar" then return P.onField(ctx.c) and P.enteredByChar[P.id(ctx.c)] == true end
  if k == "allMatch" then
    for _, c in ipairs(P.zoneCards(ctx, cond.side or "own", cond.zone or "field")) do
      if (cond.kind == nil or P.kind(c) == cond.kind) and not P.matches(c, cond.filt, ctx) then return false end
    end
    return true
  end
  if k == "retiredBy" then return ctx.data and ctx.data.info and ctx.data.info.why == cond.why end
  if k == "retiredByOwnEffect" then
    local info = ctx.data and ctx.data.info
    return info ~= nil and info.why == "effect" and info.by ~= nil and info.by:GetControler() == ctx.tp
  end
  if k == "selectedAny" then
    for _, c in ipairs(ctx.sel and ctx.sel[cond.as or "t"] or {}) do if P.matches(c, cond.filt, ctx) then return true end end
    return false
  end
  if k == "xor" then
    local n = 0
    for _, x in ipairs(cond.list) do if P.condTrue(ctx, x) then n = n + 1 end end
    return n == 1
  end
  if k == "retiredThisTurn" then
    for _, r in ipairs(P.retiredLog) do
      if r.turn == P.turnNo and r.tp == ctx.tp and (not cond.other or r.card ~= ctx.c) and P.matches(r.card, cond.filt, ctx) then return true end
    end
    return false
  end
  if k == "retiredCount" then
    local n = 0
    for _, r in ipairs(P.retiredLog) do if r.turn == P.turnNo then n = n + 1 end end
    return n >= cond.min
  end
  if k == "enteredFrom" then return P.onField(ctx.c) and P.enteredFrom[P.id(ctx.c)] == cond.zone end
  if k == "selfBP" then return P.onField(ctx.c) and P.bp(ctx.c) >= (cond.min or 0) and (not cond.max or P.bp(ctx.c) <= cond.max) end
  if k == "baseMatch" then
    local b = P.onField(ctx.c) and P.raidUnder(ctx.c)[1]
    return b ~= nil and b ~= false and P.matches(b, cond.filt, ctx)
  end
  if k == "fdTargetRaided" then return ctx.fdTarget ~= nil and P.onField(ctx.fdTarget) and P.isRaided(ctx.fdTarget) end
  -- "このターン中にこのキャラが1回目のアタックをする際、そのアタック終了時まで": choosing or making its first attack
  if k == "firstAttackNow" then
    local n = P.markCount("attacked:" .. P.id(ctx.c))
    if P.attackState then return P.attackState.attacker == ctx.c and n == 1 end
    return n == 0 and P.phase == "attack" and Duel.GetTurnPlayer() == ctx.tp
  end
  if k == "names" then
    local seen, n = {}, 0
    for _, z in ipairs(cond.zones) do
      for _, c in ipairs(P.zoneCards(ctx, cond.side or "own", z)) do
        if c == ctx.c and cond.filt and cond.filt.other then goto continue end
        if P.matches(c, cond.filt, ctx) and not seen[P.name(c)] then seen[P.name(c)] = true; n = n + 1 end
        ::continue::
      end
    end
    return n >= cond.min
  end
  P.log("COND_UNKNOWN", "c=" .. tostring(k))
  return false
end

------------------------------------------------------------------------------
-- Statics: BP, generated energy, required energy, keywords and flags
------------------------------------------------------------------------------
local function staticCtx(src) return {tp = src:GetControler(), c = src} end
local staticOn
function staticOnRef(src, s) return staticOn(src, s) end
local function turnOk(s, tp)
  if s.turn == "own" then return Duel.GetTurnPlayer() == tp end
  if s.turn == "opp" then return Duel.GetTurnPlayer() ~= tp end
  return true
end
staticOn = function(src, s)
  if P.lostText(src) then return false end
  if s.where == "front" and not P.onFront(src) then return false end
  if s.where == "energy" and not P.onEnergy(src) then return false end
  return turnOk(s, src:GetControler()) and P.condTrue(staticCtx(src), s.cond)
end
P.inBP = 0
function P.bpStatic(c)
  if P.inBP > 3 then return 0 end
  P.inBP = P.inBP + 1
  local v = 0
  for _, s in ipairs(P.statics(c, "bp")) do
    if staticOn(c, s) then
      if s.per then v = v + s.amt * P.countOf(staticCtx(c), s.per)
      elseif s.perMark then v = v + s.amt * P.markCount(s.perMark .. ":" .. c:GetControler())
      else v = v + s.amt end
    end
  end
  for _, a in ipairs(P.auras()) do
    if a.s.effect == "bp" and staticOn(a.src, a.s) and P.matches(c, a.s.filt, staticCtx(a.src))
        and ((a.s.side == "opp") == (c:GetControler() ~= a.tp)) then
      v = v + a.s.amt
    end
  end
  P.inBP = P.inBP - 1
  return v
end
function P.genStatic(c)
  local out = {}
  for _, s in ipairs(P.statics(c, "gen")) do
    if staticOn(c, s) then out[s.color] = (out[s.color] or 0) + s.n * (s.perFd and #P.fdUnder(c) or 1) end
  end
  for _, e in ipairs(P.flagEntries(c, "gen")) do out[e.data.color] = (out[e.data.color] or 0) + e.value end
  return out
end
-- Required energy reductions of the card itself ("手札にあるこのカードの必要エナジーを【赤×2】減らす").
function P.needStatic(c)
  local n = 0
  if c:IsLocation(LOCATION_HAND) then
    for _, e in ipairs(P.playerEffects(c:GetControler(), "needHand")) do if P.matches(c, e.data.filt, {tp = c:GetControler()}) then n = n + e.data.n end end
    -- "自分の手札にある全てのフィールドカードの必要エナジーを【緑×1】減らす"
    for _, a in ipairs(P.auras()) do
      if a.s.effect == "needHand" and a.tp == c:GetControler() and staticOn(a.src, a.s) and P.matches(c, a.s.filt, staticCtx(a.src)) then n = n + a.s.n end
    end
  end
  -- "自分の山札にある紫のカードの必要エナジーを1減らす" (cards on the owner's field)
  if c:IsLocation(LOCATION_DECK) then
    for _, a in ipairs(P.auras()) do
      if a.s.effect == "needDeck" and a.tp == c:GetControler() and staticOn(a.src, a.s) and P.matches(c, a.s.filt, staticCtx(a.src)) then n = n + a.s.n end
    end
  end
  for _, s in ipairs(P.statics(c, "need")) do
    local ok = (s.zone == "hand" and c:IsLocation(LOCATION_HAND)) or s.zone == "all"
      or (s.zone == "notField" and not P.onField(c) and not c:IsLocation(LOCATION_GRAVE))
    if ok then
      local ctx = {tp = c:GetControler(), c = c}
      if P.condTrue(ctx, s.cond) then
        if s.per then n = n + s.n * math.floor(P.countOf(ctx, s.per) / (s.perEvery or 1)) else n = n + s.n end
      end
    end
  end
  return n
end
-- kw / flag statics with conditions: {kind="kw", kw=..., value=..., cond=...}
function P.condStatic(c, what, word)
  if what == "kw" then
    for _, s in ipairs(P.statics(c, "kw")) do if s.kw == word and staticOn(c, s) then return true end end
    for _, a in ipairs(P.auras()) do
      if a.s.effect == "kw" and a.s.kw == word and staticOn(a.src, a.s) and P.matches(c, a.s.filt, staticCtx(a.src))
          and ((a.s.side == "opp") == (c:GetControler() ~= a.tp)) then return true end
    end
    return false
  end
  if what == "kwValues" then
    local out = {}
    for _, s in ipairs(P.statics(c, "kw")) do if s.kw == word and staticOn(c, s) then out[#out+1] = s.value or 1 end end
    return out
  end
  if what == "flag" then
    for _, s in ipairs(P.statics(c, "flag")) do if s.flag == word and staticOn(c, s) then return true end end
    return false
  end
  return false
end
-- Cards tp may use from the remove area this turn
function P.usableFromRemove(tp)
  local out = {}
  for _, c in ipairs(P.removeArea(tp)) do
    local ok = false
    for _, e in ipairs(P.playerEffects(tp, "useFromRemove")) do if P.contains(e.data.cards, c) then ok = true end end
    if not ok then
      for _, a in ipairs(P.auras()) do
        if a.s.effect == "useFromRemove" and a.tp == tp and staticOn(a.src, a.s) and P.matches(c, a.s.filt, staticCtx(a.src)) then ok = true end
      end
    end
    if ok then out[#out+1] = c end
  end
  return out
end
-- "全ての場所でイベントカードとしても扱う": its own text, an aura of an own card, or an effect of this turn
function P.isAlsoEvent(c)
  if P.fxOf(c).alsoEvent then return true end
  if not P.isChar(c) then return false end
  local tp = c:GetOwner()
  for _, a in ipairs(P.auras()) do
    if a.s.effect == "alsoEvent" and a.tp == tp and staticOn(a.src, a.s) and P.matchesBase(c, a.s.filt) then return true end
  end
  for _, e in ipairs(P.playerEffects(tp, "alsoEvent")) do if P.matchesBase(c, e.data.filt) then return true end end
  return false
end
-- kind / color / names only (no recursion into isAlsoEvent)
function P.matchesBase(c, f)
  if f.kind and P.kind(c) ~= f.kind then return false end
  if f.color and P.color(c) ~= f.color then return false end
  if f.notNames then for _, n in ipairs(f.notNames) do if P.isNamed(c, n) then return false end end end
  return true
end
-- "相手の効果で選ばれない": its own flag or static, or an aura of a card on its side
function P.untargetable(c)
  if P.hasFlag(c, "untargetable") or P.condStatic(c, "flag", "untargetable") then return true end
  for _, a in ipairs(P.auras()) do
    if a.s.effect == "untargetable" and a.tp == c:GetControler() and staticOn(a.src, a.s) and P.matches(c, a.s.filt, staticCtx(a.src)) then return true end
  end
  return false
end
-- "BP2000以下のキャラにブロックされない"
function P.unblockableBy(a, b)
  for _, e in ipairs(P.flagEntries(a, "unblockable")) do
    if P.matches(b, e.data.filt, {tp = a:GetControler(), c = a}) then return true end
  end
  for _, s in ipairs(P.statics(a, "unblockable")) do
    if staticOn(a, s) and P.matches(b, s.filt, staticCtx(a)) then return true end
  end
  return false
end
-- AP cost changes for the next card ("このターン中、次に手札から使用する…の消費APを-1する") and the card's own
-- ("手札にあるこのカードの消費APを-1する")
function P.apCostMod(tp, c, how)
  local n = 0
  for _, s in ipairs(P.statics(c, "apCost")) do
    if c:IsLocation(LOCATION_HAND) and (s.how == nil or s.how == how) and P.condTrue({tp = tp, c = c}, s.cond) then n = n + s.n end
  end
  for _, e in ipairs(P.playerEffects(tp, "apNext")) do
    if (e.data.from == nil or e.data.from == how) and P.matches(c, e.data.filt, {tp = tp}) then n = n + e.data.amt end
  end
  return n
end
function P.consumeCostMods(tp, c, how)
  for _, e in ipairs(P.playerEffects(tp, "apNext")) do
    if (e.data.from == nil or e.data.from == how) and P.matches(c, e.data.filt, {tp = tp}) then e.used = true end
  end
end
-- Events that must choose a target need one (Q&A Q1119).
function P.eventUsable(tp, c)
  local f = P.fxOf(c)
  if not f.event then return false end
  return P.actsPossible({tp = tp, c = c}, f.event)
end

------------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------------
local function cardsOf(ctx, op)
  if op.sel == "self" then return P.onField(ctx.c) and {ctx.c} or {} end
  if op.sel == "by" then
    local b = ctx.data and ctx.data.by
    return (b and P.onField(b)) and {b} or {}
  end
  if op.sel == "fdTarget" then return ctx.fdTarget and P.onField(ctx.fdTarget) and {ctx.fdTarget} or {} end
  if op.sel == "entered" then
    local out = {}
    for _, c in ipairs(P.concat((ctx.sel or {}).p or {}, (ctx.sel or {}).lp or {})) do if P.onField(c) then out[#out+1] = c end end
    return out
  end
  if op.sel == "raider" then
    local r = ctx.data and ctx.data.raider
    -- "…をこのキャラにレイドさせる。そうした場合、レイドしたキャラは…": the card just raided
    if not r and ctx.sel and ctx.sel.p then r = ctx.sel.p[1] end
    return (r and P.onField(r)) and {r} or {}
  end
  if op.sel == "selfAny" then return {ctx.c} end
  return (ctx.sel and ctx.sel[op.sel or "t"]) or {}
end
-- Is there at least one legal choice for every mandatory pick (Q&A Q877, Q1119)?
function P.actsPossible(ctx, acts)
  for _, op in ipairs(acts or {}) do
    -- the branch that will run must be possible ("『BP3000以下』… 〈…〉がある場合、『BP5000以下』に代わる")
    if op.op == "if" then
      if P.condTrue(ctx, op.cond) then
        if not P.actsPossible(ctx, op.act) then return false end
      elseif op.elseAct and not P.actsPossible(ctx, op.elseAct) then return false end
    end
    if op.op == "choose" and not op.upTo then
      local any = false
      for _, o in ipairs(op.opts or {}) do if P.actsPossible(ctx, o) then any = true break end end
      if not any then return false end
    end
    if op.op == "payAP" and not P.canPayAP(ctx.tp, op.n or 1) then return false end
    if op.op == "pick" and not op.upTo and not op.all and (op.n or 1) > 0 and not op.optional then
      local pool = P.filter(P.zoneCards(ctx, op.side or "own", op.zone or "field"), function(c) return P.matches(c, op.filt, ctx) end)
      if #pool == 0 then return false end
    end
  end
  return true
end

local A = {}
P.actions = A
function P.run(ctx, acts)
  ctx.sel = ctx.sel or {}
  for _, op in ipairs(acts or {}) do
    if P.finished then return end
    P.durationSource = ctx.c
    local f = A[op.op]
    if not f then
      P.log("ACTION_UNKNOWN", "op=" .. tostring(op.op))
    else
      f(ctx, op)
    end
    P.checkState()
  end
end

A.draw = function(ctx, op)
  local n = op.n or 1
  if op.perSel then n = n * #((ctx.sel or {})[op.perSel] or {}) end
  if n <= 0 then ctx.ok = false return end
  if op.upTo then n = P.ai.drawUpTo(ctx.tp, n) end
  local who = op.who == "opp" and 1 - ctx.tp or ctx.tp
  local got = P.draw(who, n)
  -- "自分のメインフェイズ中に、自分の効果でカードを引いた時"
  if #got > 0 and P.phase == "main" and Duel.GetTurnPlayer() == who then
    for _, c in ipairs(P.field(who)) do P.fire(c, "drewMain", {}) end
  end
  ctx.ok = #got > 0
  ctx.count = #got
end
-- hand → outside / remove ("自分の手札を1枚場外に置く")
A.discard = function(ctx, op)
  local tp = op.who == "opp" and 1 - ctx.tp or ctx.tp
  local pool = P.filter(P.hand(tp), function(c) return P.matches(c, op.filt, ctx) end)
  local n = op.n or 1
  if op.upTo or op.may then n = P.ai.discardUpTo(tp, pool, n, op) end
  if op.all then n = #pool end
  if (op.exact or op.may) and #pool < (op.n or 1) and not op.upTo then ctx.ok = false; ctx.count = 0 return end
  if op.ai == "widen" then n = math.min(#pool, op.n or 1, 2) end
  local picked = P.ai.discardPick(tp, pool, math.min(n, #pool), op)
  for _, c in ipairs(picked) do
    local to = op.to or "outside"
    if to == "deckTopOrOutside" then to = P.ai.keepOnTop(tp, c, "discard") and "deckTop" or "outside" end
    P.moveTo(c, to, REASON_EFFECT + REASON_DISCARD)
  end
  if #picked > 0 then
    ctx.selBP = ctx.selBP or {}
    local plus = P.handBPPlus(tp)
    for _, c in ipairs(picked) do if P.isChar(c) then ctx.selBP[op.as or "d"] = math.max(ctx.selBP[op.as or "d"] or 0, P.baseBP(c) + plus) end end
    -- "このカードが自分の効果で自分の手札から公開されて山札の下に置かれた時"
    if op.reveal and op.to == "deckBottom" then
      for _, c in ipairs(picked) do P.fire(c, "revealedToBottom", {ignoreWhere = true, by = ctx.c}, nil, tp) end
    end
    -- "自分の〈黒崎 一護〉の効果で自分の手札を場外に置いた時"
    if (op.to or "outside") == "outside" and tp == ctx.tp then
      for _, src in ipairs(P.field(tp)) do
        for _, ab in ipairs(P.fxOf(src).abil or {}) do
          if ab.when == "ownDiscard" and src ~= ctx.c and (not ab.srcFilt or P.matches(ctx.c, ab.srcFilt, {tp = tp})) then
            local actx = {tp = tp, c = src, data = {cards = picked, by = ctx.c}}
            if abilityUsableRef(src, ab, actx) then
              P.enqueue(tp, P.name(src) .. ":ownDiscard", function()
                if ab.turn1 or ab.nameOnce then
                  if not abilityUsableRef(src, ab, actx) then return end
                  markUsedRef(src, ab, actx)
                end
                P.run(actx, ab.act)
              end)
            end
          end
        end
      end
    end
    if (op.to or "outside") == "outside" then
      P.mark("discarded:" .. tp)
      for _, c in ipairs(picked) do P.fire(c, "discardedSelf", {ignoreWhere = true, by = ctx.c}, nil, tp) end
    end
    P.log("DISCARD", "player=" .. tp .. ";n=" .. #picked .. ";to=" .. (op.to or "outside"))
    if P.onDiscarded then P.onDiscarded(tp, picked, ctx) end
  end
  ctx.ok = #picked > 0 and #picked >= (op.n or 1)
  ctx.count = #picked
  ctx.sel[op.as or "d"] = picked
end
-- Selections: {op="pick", side=, zone=, n=, upTo=, all=, filt=, as=, ai="good"|"bad"}
A.pick = function(ctx, op)
  local pool = P.filter(P.zoneCards(ctx, op.side or "own", op.zone or "field"), function(c)
    if not P.matches(c, op.filt, ctx) then return false end
    -- "相手の効果で選ばれない"
    if P.onField(c) and c:GetControler() ~= ctx.tp and P.untargetable(c) then return false end
    if P.onField(c) and c:GetControler() ~= ctx.tp and P.hasFlag(c, "apTax") and not P.canPayAP(ctx.tp, 1) then return false end
    if P.onField(c) and c:GetControler() ~= ctx.tp and P.handTaxed(c) and #P.hand(ctx.tp) == 0 then return false end
    if P.onField(c) and c:GetControler() ~= ctx.tp and ctx.trigger and P.hasFlag(c, "untargetableTrigger") then return false end
    return true
  end)
  if op.selPool then
    pool = P.filter((ctx.sel or {})[op.selPool] or {}, function(c) return P.onField(c) and P.matches(c, op.filt, ctx) end)
  end
  if op.fromSel then
    local from = ctx.sel[op.fromSel] or {}
    pool = P.filter(from, function(c) return c:IsLocation(LOCATION_GRAVE) and P.matches(c, op.filt, ctx) end)
  end
  if op.exactMin and #pool < (op.n or 1) then ctx.sel[op.as or "t"] = {}; ctx.ok = false return end
  local chosen
  if op.all then chosen = pool
  else
    local n = op.n or 1
    if op.nFrom then n = ctx[op.nFrom] or 0 end
    if op.nPlus then n = n + math.floor(P.countOf(ctx, op.nPlus.per) / op.nPlus.every) * op.nPlus.n end
    if op.distinctNeed and P.isHuman and P.isHuman(ctx.tp) then
      chosen = P.human.pickDistinct(ctx, pool, n, P.baseNeed, "必要エナジーの違うカードを選んでください")
    else
      if op.distinctNeed then
        local seen, uniq = {}, {}
        for _, c in ipairs(P.ai.pick(ctx, pool, #pool, op)) do
          if not seen[P.baseNeed(c)] then seen[P.baseNeed(c)] = true; uniq[#uniq+1] = c end
        end
        pool = uniq
      end
      chosen = P.ai.pick(ctx, pool, math.min(n, #pool), op)
    end
  end
  for _, c in ipairs(chosen) do
    if P.onField(c) and c:GetControler() ~= ctx.tp and P.hasFlag(c, "apTax") then P.payAP(ctx.tp, 1, "tax:" .. P.name(c)) end
    -- "相手は効果でこのキャラを選ぶ際、追加で自身の手札を1枚場外に置かないと選べない"
    if P.onField(c) and c:GetControler() ~= ctx.tp and P.handTaxed(c) then
      local h = P.ai.discardPick(ctx.tp, P.hand(ctx.tp), 1, {})
      for _, x in ipairs(h) do P.moveTo(x, "outside", REASON_EFFECT + REASON_DISCARD) end
      P.log("HAND_TAX", "player=" .. ctx.tp .. ";for=" .. P.label(c))
    end
  end
  ctx.sel[op.as or "t"] = chosen
  if op.addTo then
    local merged = {}
    for _, c in ipairs(ctx.sel[op.addTo] or {}) do merged[#merged+1] = c end
    for _, c in ipairs(chosen) do merged[#merged+1] = c end
    ctx.sel[op.addTo] = merged
  end
  ctx.picked = ctx.picked or {}
  for _, c in ipairs(chosen) do ctx.picked[c] = true end
  ctx.ok = #chosen > 0
  if #chosen > 0 then
    local names = {}
    for _, c in ipairs(chosen) do names[#names+1] = P.label(c) end
    P.log("PICK", "player=" .. ctx.tp .. ";as=" .. (op.as or "t") .. ";cards=" .. table.concat(names, ","))
  end
end
A.bp = function(ctx, op)
  local amt = op.amt
  if op.perSelNeed then
    local n = 0
    for _, c in ipairs((ctx.sel or {})[op.perSelNeed] or {}) do n = n + P.baseNeed(c) end
    amt = amt * n
  end
  if op.per then amt = amt * math.floor(P.countOf(ctx, op.per) / (op.perEvery or 1)) end
  if op.perSel then amt = amt * #((ctx.sel or {})[op.perSel] or {}) end
  if amt == 0 then return end
  for _, c in ipairs(cardsOf(ctx, op)) do
    if P.onField(c) then P.addBP(c, amt, P.durationOf(op.dur or "turn", ctx.tp), P.name(ctx.c)) end
  end
end
A.retire = function(ctx, op)
  local cards = P.filter(cardsOf(ctx, op), P.onField)
  -- "そのキャラのBP": remembered as it was on the field
  ctx.selBP = ctx.selBP or {}
  ctx.selNeed = ctx.selNeed or {}
  for _, c in ipairs(cards) do
    ctx.selBP[op.sel or "t"] = math.max(ctx.selBP[op.sel or "t"] or 0, P.bp(c))
    ctx.selNeed[op.sel or "t"] = math.max(ctx.selNeed[op.sel or "t"] or 0, P.need(c))
  end
  local gone = P.retireMany(cards, {why = "effect", by = ctx.c})
  ctx.ok = #gone > 0
  ctx.count = #gone
end
A.move = function(ctx, op)
  local n = 0
  for _, c in ipairs(cardsOf(ctx, op)) do
    local fromOutside = c:IsLocation(LOCATION_GRAVE)
    if P.onField(c) and P.replaceLeave(c, {why = "effect", by = ctx.c}, true) then goto nextCard end
    -- "自分の場の〈悪魔ほむら〉全ては自分と相手の効果でリムーブエリアに置くことができない"
    if P.onField(c) and op.to == "remove" and P.auraProtects(c, "noRemove") then P.log("PROTECTED", "card=" .. P.label(c)) goto nextCard end
    -- "このキャラは自分と相手の効果で手札に戻らず"
    if P.onField(c) and op.to == "hand" and P.condStatic(c, "flag", "noBounce") then P.log("PROTECTED", "card=" .. P.label(c)) goto nextCard end
    if P.onField(c) and op.to ~= nil then
      local leaver, ltp = c, c:GetControler()
      P.enqueue(ltp, P.name(c) .. ":left by effect", function() P.fire(leaver, "leftByEffect", {ignoreWhere = true}, nil, ltp) end)
    end
    if fromOutside and op.to == "hand" then
      P.enqueue(ctx.tp, P.name(c) .. ":recovered", function() P.fire(c, "recovered", {ignoreWhere = true, by = ctx.c}, nil, ctx.tp) end)
    end
    if not c:IsLocation(LOCATION_DECK) or op.from == "deck" then
      if op.to == "deckBottomOrTopOpp" then
        P.moveTo(c, P.ai.deckSide(ctx.tp, c, "opp"))
      elseif op.to == "deckBottomOrTopOwner" then
        P.moveTo(c, P.ai.deckSide(ctx.tp, c, "owner"))
      elseif op.to == "deckBottomOrTop" then
        P.moveTo(c, P.ai.topOrBottom(ctx.tp, c, op) and "deckTop" or "deckBottom")
      else
        P.moveTo(c, op.to)
      end
      n = n + 1
      P.log("MOVED", "card=" .. P.label(c) .. ";to=" .. op.to)
    end
    ::nextCard::
  end
  ctx.ok = n > 0
  ctx.count = n
end
A.rest = function(ctx, op)
  local n = 0
  for _, c in ipairs(cardsOf(ctx, op)) do
    if P.onField(c) or c:IsLocation(LOCATION_EXTRA) then
      if P.rest(c) then
        n = n + 1
        if P.onField(c) and c:GetControler() == ctx.tp then P.mark("restedOwn:" .. P.id(c)) end
      end
    end
  end
  ctx.ok = #cardsOf(ctx, op) > 0
  ctx.count = n
end
A.stand = function(ctx, op)
  local n = 0
  for _, c in ipairs(cardsOf(ctx, op)) do
    if P.onField(c) or c:IsLocation(LOCATION_EXTRA) then if P.stand(c, (c == ctx.c and P.fxOf(c).standOnlyOwn) and "own" or "effect") then n = n + 1 end end
  end
  ctx.ok = #cardsOf(ctx, op) > 0
  ctx.count = n
end
A.freeze = function(ctx, op)
  for _, c in ipairs(cardsOf(ctx, op)) do
    if P.onField(c) and not P.hasFlag(c, "freeze") then P.addFlag(c, "freeze", nil) end
  end
end
A.grant = function(ctx, op)
  for _, c in ipairs(cardsOf(ctx, op)) do
    if P.onField(c) then P.addFlag(c, op.flag, P.durationOf(op.dur or "turn", ctx.tp), op.value, op.data) end
  end
end
A.moveLine = function(ctx, op)
  local n = 0
  for _, c in ipairs(cardsOf(ctx, op)) do
    local line = op.line
    if line == "other" then line = P.lineOf(c) == "front" and "energy" or "front" end
    if P.onField(c) and P.lineOf(c) ~= line and P.isChar(c) then
      if P.moveLine(c, line, nil, c == ctx.c) then
        n = n + 1
        P.mark("movedByEffect:" .. P.id(c))
      end
    end
  end
  ctx.ok = n > 0
end
A.swapLines = function(ctx, op)
  local a, b = cardsOf(ctx, {sel = op.a})[1], cardsOf(ctx, {sel = op.b})[1]
  if not (a and b and P.onField(a) and P.onField(b)) then return end
  local la, lb = P.lineOf(a), P.lineOf(b)
  if la == lb then return end
  P.moveTo(b, "hand", REASON_RULE)  -- not reachable for compiled cards (kept for completeness)
end
-- "自分の山札の上から#枚見て、..." : look at the top (or bottom) n cards, picks move them, rest goes somewhere.
A.look = function(ctx, op)
  local tp = ctx.tp
  local n = op.n
  if op.nNames then
    local seen = {}
    n = 0
    for _, c in ipairs(P.field(tp)) do if P.matches(c, op.nNames.filt, ctx) and not seen[P.name(c)] then seen[P.name(c)] = true; n = n + 1 end end
  end
  local cards = op.from == "bottom" and P.deckBottom(tp, n) or P.deckTop(tp, n)
  -- "公開": revealed cards ("このターン中に自分の山札から必要エナジーが5以上のカードが公開されている", "山札から公開された時")
  if op.reveal then
    for _, c in ipairs(cards) do
      if P.baseNeed(c) >= 5 then P.mark("revealedNeed5:" .. tp) end
      if Duel.GetTurnPlayer() == tp then P.fire(c, "revealedFromDeck", {ignoreWhere = true}, nil, tp) end
    end
  end
  ctx.looked = cards
  ctx.sel["look"] = cards
  if P.isHuman and P.isHuman(tp) and #cards > 0 then Duel.ConfirmCards(tp, P.group(cards)) end
  local remaining = {}
  for _, c in ipairs(cards) do remaining[#remaining+1] = c end
  ctx.ok = false
  for _, pk in ipairs(op.picks or {}) do
    local pool = P.filter(remaining, function(c) return P.matches(c, pk.filt, ctx) end)
    local n = math.min(pk.n or 1, #pool)
    if pk.all then n = #pool end
    local chosen
    if pk.distinctName and P.isHuman and P.isHuman(tp) then
      chosen = P.human.pickDistinct(ctx, pool, n, P.name, "名称の違うカードを選んでください")
    else
      chosen = P.ai.lookPick(ctx, pool, n, pk)
    end
    if pk.distinctName and not (P.isHuman and P.isHuman(tp)) then
      local seen, uniq = {}, {}
      for _, c in ipairs(P.ai.lookPick(ctx, pool, #pool, pk)) do if not seen[P.name(c)] then seen[P.name(c)] = true; uniq[#uniq+1] = c end end
      chosen = uniq
    end
    ctx.sel[pk.as or "lp"] = chosen
    local dest = pk.to
    local alt = pk.alt and P.condTrue(ctx, pk.alt.cond)
    if alt then dest = pk.alt.to end
    for _, c in ipairs(chosen) do
      for i, x in ipairs(remaining) do if x == c then table.remove(remaining, i) break end end
      if alt and dest == "field" then
        local targets = pk.alt.raid and P.raidTargets(tp, c) or {}
        if #targets > 0 and P.meetsNeed(tp, c) then P.doRaid(tp, c, P.ai.raidTarget(tp, c, targets), {how = "effect", from = "deck"})
        else P.enter(tp, c, pk.alt.line or P.ai.lineFor(tp, c), {rested = not pk.alt.active, how = "effect", from = "deck"}) end
      elseif pk.to == "hand" then
        Duel.DisableShuffleCheck()
        Duel.SendtoHand(c, tp, REASON_EFFECT)
        if pk.reveal then Duel.ConfirmCards(1 - tp, c) end
      elseif pk.to == "outside" then
        Duel.DisableShuffleCheck()
        Duel.SendtoGrave(c, REASON_EFFECT)
        ctx.sel["lookOut"] = ctx.sel["lookOut"] or {}
        table.insert(ctx.sel["lookOut"], c)
      elseif pk.to == "field" then
        P.enter(tp, c, pk.line or P.ai.lineFor(tp, c), {rested = not pk.active, how = "effect", from = "deck"})
      elseif pk.to == "life" then
        P.addLife(tp, {c})
      elseif pk.to == "top" then
        -- stays on top
      end
    end
    if #chosen > 0 then ctx.ok = true end
    ctx.sel[pk.as or "lp"] = chosen
    P.log("LOOK_PICK", "player=" .. tp .. ";n=" .. #chosen .. ";to=" .. tostring(pk.to))
  end
  -- the rest
  local rest = op.rest or "bottom"
  if rest == "bottom" then
    for _, c in ipairs(remaining) do Duel.DisableShuffleCheck(); Duel.MoveSequence(c, SEQ_DECKBOTTOM) end
  elseif rest == "outside" then
    for _, c in ipairs(remaining) do Duel.DisableShuffleCheck(); Duel.SendtoGrave(c, REASON_EFFECT) end
  elseif rest == "remove" then
    for _, c in ipairs(remaining) do Duel.DisableShuffleCheck(); Duel.Remove(c, POS_FACEUP, REASON_EFFECT) end
  elseif rest == "topOrOutside" or rest == "topOrBottom" or rest == "topAnyOutside" then
    for _, c in ipairs(remaining) do
      local keep = P.ai.keepOnTop(tp, c, rest == "topOrBottom" and "lookTopOrBottom" or "lookTopOrOutside")
      if not keep then
        Duel.DisableShuffleCheck()
        if rest == "topOrBottom" then Duel.MoveSequence(c, SEQ_DECKBOTTOM) else
          Duel.SendtoGrave(c, REASON_EFFECT)
          ctx.sel["lookOut"] = ctx.sel["lookOut"] or {}
          table.insert(ctx.sel["lookOut"], c)
        end
      end
    end
  end
  P.log("LOOK", "player=" .. tp .. ";n=" .. #cards .. ";rest=" .. rest)
end
A.mill = function(ctx, op)
  local tp = op.who == "opp" and 1 - ctx.tp or ctx.tp
  local n = op.n
  if op.upTo then n = P.ai.millUpTo(tp, n) end
  local cards = op.from == "bottom" and P.deckBottom(tp, n) or P.deckTop(tp, n)
  for _, c in ipairs(cards) do
    Duel.DisableShuffleCheck()
    if op.to == "remove" then Duel.Remove(c, POS_FACEUP, REASON_EFFECT) else Duel.SendtoGrave(c, REASON_EFFECT) end
  end
  ctx.sel[op.as or "m"] = cards
  ctx.ok = #cards > 0
  P.log("MILL", "player=" .. tp .. ";n=" .. #cards .. (op.to == "remove" and ";to=remove" or ""))
end
A.apStand = function(ctx, op)
  local rested = P.filter(P.apArea(ctx.tp), P.isRested)
  local n = math.min(op.n or 1, #rested)
  for i = 1, n do P.stand(rested[i], "effect") end
  P.syncRest(ctx.tp)
  ctx.ok = n > 0
  P.log("AP_STAND", "player=" .. ctx.tp .. ";n=" .. n)
end
A.apRest = function(ctx, op)
  local tp = op.who == "opp" and 1 - ctx.tp or ctx.tp
  local act = P.apActive(tp)
  local n = math.min(op.n or 1, #act)
  for i = 1, n do P.rest(act[i]) end
  ctx.ok = n > 0
  P.log("AP_REST", "player=" .. tp .. ";n=" .. n)
end
-- "自分のライフが無い場合、自分の山札の上から1枚を自分のライフエリアに置く" and similar
A.lifeFromDeck = function(ctx, op)
  local top = P.deckTop(ctx.tp, op.n or 1)
  P.addLife(ctx.tp, top)
  ctx.ok = #top > 0
end
A.lifeToHand = function(ctx, op)
  local life = P.life(ctx.tp)
  local n = math.min(op.n or 1, #life)
  for i = 1, n do Duel.SendtoHand(life[i], ctx.tp, REASON_EFFECT) end
  if n > 0 then P.mark("lifeToHand:" .. ctx.tp) end
  P.log("LIFE_TO_HAND", "player=" .. ctx.tp .. ";n=" .. n .. ";life=" .. P.lifeCount(ctx.tp))
  ctx.ok = n > 0
  P.checkState()
end
A.lifeToOutside = function(ctx, op)
  local tp = op.who == "opp" and 1 - ctx.tp or ctx.tp
  ctx.ok = P.lifeToOutside(tp, op.n or 1) > 0
end
A.damage = function(ctx, op)
  P.damage(ctx.tp, op.who == "self" and ctx.tp or 1 - ctx.tp, op.n or 1, "effect:" .. P.name(ctx.c))
end
-- Put cards onto the field: {op="put", zone=, side="own", filt=, n=, upTo=, line="any"|"front"|"energy", active=,
-- raid=bool (登場させるかレイドさせる), raidOnly=bool (レイドさせる), free=true}
A.put = function(ctx, op)
  local tp = ctx.tp
  if ctx.trigger and op.filt and op.filt.kind == "char" and P.triggerKind(ctx.c) == "color" then
    for _, src in ipairs(P.field(tp)) do
      for _, st in ipairs(P.statics(src, "colorTriggerField")) do
        if st.color == P.color(ctx.c) and staticOn(src, st) then
          local f = {}
          for k, v in pairs(op.filt) do f[k] = v end
          f.kind = {"char", "field"}
          op = setmetatable({filt = f}, {__index = op})
        end
      end
    end
  end
  local pool = op.sel and cardsOf(ctx, op) or P.zoneCards(ctx, op.side or "own", op.zone or "hand")
  if op.zones then
    pool = {}
    for _, z in ipairs(op.zones) do for _, c in ipairs(P.zoneCards(ctx, op.side or "own", z)) do pool[#pool+1] = c end end
  end
  ctx.putFrom = ctx.putFrom or {}
  for _, c in ipairs(pool) do
    ctx.putFrom[c] = c:IsLocation(LOCATION_REMOVED) and "remove" or (c:IsLocation(LOCATION_GRAVE) and "outside" or (c:IsLocation(LOCATION_HAND) and "hand" or "deck"))
  end
  pool = P.filter(pool, function(c)
    if not P.matches(c, op.filt, ctx) or not P.supported(c) then return false end
    if P.fxOf(c).enterIf and not P.condTrue({tp = tp, c = c}, P.fxOf(c).enterIf) then return false end
    if op.needOk and not P.meetsNeed(tp, c) then return false end
    if op.raidOnly then return #P.raidTargets(tp, c) > 0 and (not op.onto or #P.filter(P.raidTargets(tp, c), function(t) return P.contains(cardsOf(ctx, {sel = op.onto}), t) end) > 0) end
    if P.isEvent(c) then return false end
    if P.fxOf(c).raidOnly and not (op.raid and #P.raidTargets(tp, c) > 0) then return false end
    return true
  end)
  local n = op.n or 1
  local chosen = P.ai.putPick(ctx, pool, math.min(n, #pool), op)
  local done = 0
  for _, c in ipairs(chosen) do
    local targets = P.raidTargets(tp, c)
    if op.onto then targets = P.filter(targets, function(t) return P.contains(cardsOf(ctx, {sel = op.onto}), t) end) end
    local doRaid = (op.raidOnly or op.raid) and #targets > 0 and (op.raidOnly or P.ai.preferRaid(tp, c, targets))
    if doRaid then
      if P.doRaid(tp, c, P.ai.raidTarget(tp, c, targets), {how = "effect", from = op.zone}) then done = done + 1 end
    elseif op.orHand and (P.ai.toHandInstead(tp, c) or (op.enterFilt and not P.matches(c, op.enterFilt, ctx))) then
      if c:IsLocation(LOCATION_GRAVE) or c:IsLocation(LOCATION_REMOVED) then Duel.SendtoHand(c, tp, REASON_EFFECT) end
      P.log("TO_HAND", "player=" .. tp .. ";card=" .. P.label(c))
      done = done + 1
    elseif not op.raidOnly then
      local line = op.line == "front" and "front" or (op.line == "energy" and "energy" or P.ai.lineFor(tp, c))
      if P.enter(tp, c, line, {rested = not op.active, how = "effect", from = op.zone, byChar = P.isChar(ctx.c), silent = op.silent}) then done = done + 1 end
    end
  end
  ctx.ok = done > 0
  ctx.count = done
  ctx.sel[op.as or "p"] = chosen
end
P.choseLog = {}
A.choose = function(ctx, op)
  if op.nIf and P.condTrue(ctx, op.nIf.cond) then op = setmetatable({n = op.nIf.n}, {__index = op}) end
  -- "自分の場の［特徴：ガンメン］1枚につき、以下から1つまで選ぶ"
  if op.nPer then op = setmetatable({n = (op.n or 1) * P.countOf(ctx, op.nPer)}, {__index = op}) end
  -- "APを1支払ってもよい。そうした場合、2つに代わる"
  if op.nPay and P.canPayAP(ctx.tp, op.nPay.ap) and P.ai.payForMore(ctx, op) then
    P.payAP(ctx.tp, op.nPay.ap, P.name(ctx.c))
    op = setmetatable({n = op.nPay.n}, {__index = op})
  end
  local excluded = {}
  if op.excl then
    for _, e in ipairs(P.choseLog) do
      if e.turn == P.turnNo and e.tp == ctx.tp then
        local same = (op.excl.key == "self" and e.id == P.id(ctx.c)) or (op.excl.name and e.name == op.excl.name and not (op.excl.other and e.id == P.id(ctx.c)))
        if same then excluded[e.i] = true end
      end
    end
    op = setmetatable({excluded = excluded}, {__index = op})
  end
  local picks = P.ai.chooseOptions(ctx, op)
  for _, i in ipairs(picks) do
    P.log("CHOOSE", "player=" .. ctx.tp .. ";option=" .. i)
    if op.excl then P.choseLog[#P.choseLog+1] = {turn = P.turnNo, tp = ctx.tp, id = P.id(ctx.c), name = op.excl.name, i = i} end
    P.run(ctx, op.opts[i])
  end
  ctx.ok = #picks > 0
  if ctx.ok and op.thenAct then P.run(ctx, op.thenAct) end
  if op.post then P.run(ctx, op.post) end
end
A["if"] = function(ctx, op)
  if P.condTrue(ctx, op.cond) then P.run(ctx, op.act) elseif op.elseAct then P.run(ctx, op.elseAct) end
end
-- "Aか、Bてもよい": the first option the player can do
A.either = function(ctx, op)
  if P.isHuman and P.isHuman(ctx.tp) then
    local i = P.human.either(ctx, op.opts, op.texts or {})
    if not i then ctx.ok = false return end
    ctx.ok = nil
    P.run(ctx, op.opts[i])
    if ctx.ok == nil then ctx.ok = true end
    return
  end
  for _, o in ipairs(op.opts) do
    local ok = P.actsPossible(ctx, o)
    for _, x in ipairs(o) do if x.op == "discard" and #P.hand(ctx.tp) < (x.n or 1) then ok = false end end
    if ok then
      ctx.ok = nil
      P.run(ctx, o)
      if ctx.ok == nil then ctx.ok = true end
      return
    end
  end
  ctx.ok = false
end
-- tiers by the required energy of the card just looked at ("公開した紫のカードの必要エナジーの数により")
A.tiers = function(ctx, op)
  local c = (ctx.sel and ctx.sel["look"] or {})[1]
  if not c or (op.color and P.color(c) ~= op.color) then return end
  local need = P.need(c)
  for _, t in ipairs(op.tiers) do if need <= t.max then P.run(ctx, t.act) end end
end
A.ifNotDid = function(ctx, op)
  if not ctx.ok then P.run(ctx, op.act) end
end
A.payAP = function(ctx, op)
  ctx.ok = P.canPayAP(ctx.tp, op.n) and P.payAP(ctx.tp, op.n, P.name(ctx.c))
  if ctx.ok then P.mark("apByEffect:" .. P.color(ctx.c) .. ":" .. ctx.tp) end
end
-- "〜てもよい。そうした場合、…": the AI decides; then = the rest that needs it
A.may = function(ctx, op)
  if not P.actsPossible(ctx, op.act) then ctx.ok = false return end
  if not P.ai.wantMay(ctx, op) then ctx.ok = false; P.log("DECLINE", "player=" .. ctx.tp .. ";card=" .. P.name(ctx.c)) return end
  ctx.ok = nil
  P.run(ctx, op.act)
  if ctx.ok == nil then ctx.ok = true end
  if ctx.ok and op.thenAct then P.run(ctx, op.thenAct) end
end
A.ifDid = function(ctx, op)
  if ctx.ok then P.run(ctx, op.act) end
end
A.selfToHand = function(ctx, op)
  if ctx.c:IsLocation(LOCATION_HAND) then return end
  P.checkingCards[ctx.c] = nil
  Duel.SendtoHand(ctx.c, ctx.tp, REASON_EFFECT)
  P.log("TO_HAND", "player=" .. ctx.tp .. ";card=" .. P.label(ctx.c))
  ctx.ok = ctx.c:IsLocation(LOCATION_HAND)
end
-- 【レイド】 trigger: "このカードを手札に加えるか、必要エナジーを満たしている場合、レイドさせる" (Q&A Q56, Q57)
A.raidSelf = function(ctx, op)
  local c = ctx.c
  local targets = P.raidTargets(ctx.tp, c)
  if #targets > 0 and P.meetsNeed(ctx.tp, c) and P.ai.triggerRaid(ctx.tp, c, targets) then
    P.checkingCards[c] = nil
    P.doRaid(ctx.tp, c, P.ai.raidTarget(ctx.tp, c, targets), {how = "trigger"})
  else
    A.selfToHand(ctx, op)
  end
end
-- this card itself onto the field from where it is ("このカードを自分の場に登場させる")
A.putSelf = function(ctx, op)
  local c = ctx.c
  if op.needOk and not P.meetsNeed(ctx.tp, c) then ctx.ok = false return end
  P.checkingCards[c] = nil
  P.enter(ctx.tp, c, op.line or P.ai.lineFor(ctx.tp, c), {rested = not op.active, how = "effect"})
end
A.playerEffect = function(ctx, op)
  if op.kind == "atAttackPhaseStart" then
    local data = {act = op.data.act, c = ctx.c}
    P.addPlayerEffect(ctx.tp, op.kind, P.durationOf("turn", ctx.tp), data)
    return
  end
  local plus = op.data and op.data.needMaxPlus
  if plus then
    local data = {}
    for k, v in pairs(op.data) do data[k] = v end
    local filt = {}
    for k, v in pairs(op.data.filt) do filt[k] = v end
    filt.needMax = filt.needMax + math.floor(P.countOf(ctx, plus.per) / plus.every) * plus.n
    data.filt = filt
    data.needMaxPlus = nil
    op = setmetatable({data = data}, {__index = op})
  end
  P.addPlayerEffect(op.who == "opp" and 1 - ctx.tp or ctx.tp, op.kind, P.durationOf(op.dur or "turn", ctx.tp), op.data)
end
A.shuffle = function(ctx, op) Duel.ShuffleDeck(ctx.tp) end
A.noop = function(ctx, op) end
-- trigger the 【登場時】 of this card again ("このキャラの【登場時】を発動する")
A.fireEnter = function(ctx, op)
  if op.sel then
    for _, c in ipairs(cardsOf(ctx, op)) do if P.onField(c) then P.fire(c, "enter", {}) end end
    return
  end
  if P.onField(ctx.c) then P.fire(ctx.c, "enter", {})
  else P.fire(ctx.c, "enter", {ignoreWhere = true}, nil, ctx.tp) end
end
-- "このキャラのレイド元のカードを1枚自分の場にレストで登場させる"
A.putUnder = function(ctx, op)
  local under = P.under(ctx.c)
  if not P.onField(ctx.c) and ctx.data and (ctx.data.base or ctx.data.under) then
    under = P.filter(ctx.data.base or ctx.data.under, function(x) return x:IsLocation(LOCATION_GRAVE) and P.matches(x, op.filt, ctx) end)
  end
  if op.orHand then
    for _, c in ipairs(P.ai.putPick(ctx, under, math.min(op.n or 1, #under), op)) do
      if P.ai.toHandInstead(ctx.tp, c) then Duel.SendtoHand(c, ctx.tp, REASON_EFFECT)
      else P.enter(ctx.tp, c, P.ai.lineFor(ctx.tp, c), {rested = not op.active, how = "effect", from = "under"}) end
    end
    return
  end
  local chosen = P.ai.putPick(ctx, under, math.min(op.n or 1, #under), op)
  local done = 0
  for _, c in ipairs(chosen) do
    if P.enter(ctx.tp, c, P.ai.lineFor(ctx.tp, c), {rested = not op.active, how = "effect", from = "under"}) then done = done + 1 end
  end
  ctx.ok = done > 0
end
-- "このキャラのレイド元のカードを1枚場外に置く"
A.moveUnder = function(ctx, op)
  local under = op.fd and P.fdUnder(ctx.c) or P.under(ctx.c)
  if op.need and #under < op.need then ctx.ok = false return end
  -- a retired character's text reads the cards that were under it (now in the outside area)
  if not P.onField(ctx.c) and ctx.data and ctx.data.under then
    under = P.filter(ctx.data.under, function(x) return x:IsLocation(LOCATION_GRAVE) end)
  end
  if op.to == "hand" then
    local n = math.min(op.n or 1, #under)
    for i = 1, n do P.fd[under[i]] = nil; Duel.SendtoHand(under[i], ctx.tp, REASON_EFFECT) end
    ctx.ok = n > 0
    return
  end
  local n = math.min(op.n or 1, #under)
  for i = 1, n do
    P.fd[under[i]] = nil
    if op.to == "remove" then Duel.Remove(under[i], POS_FACEUP, REASON_EFFECT) else Duel.SendtoGrave(under[i], REASON_EFFECT) end
  end
  ctx.ok = n > 0
end
-- "…を1枚選び、このキャラと位置を入れ替えてもよい": the two characters change lines
A.swap = function(ctx, op)
  local other = cardsOf(ctx, op)[1]
  local me = op.with and cardsOf(ctx, {sel = op.with})[1] or ctx.c
  if not (other and P.onField(other) and P.onField(me)) or P.lineOf(other) == P.lineOf(me) then return end
  P.swapLines(me, other)
end
-- "このキャラの一番上のカードを場外に置く": the card under it stays on the field in its place
A.removeTop = function(ctx, op)
  local c = op.sel and cardsOf(ctx, op)[1] or ctx.c
  if not c or not P.onField(c) or not P.isRaided(c) then ctx.ok = false return end
  local under = P.under(c)
  local base = under[#under]
  ctx.ok = P.removeTop(c)
  if ctx.ok then ctx.sel.base = {base}; ctx.sel.topOut = {c} end
end
A.restSelfActive = function(ctx, op)
  if not (P.onField(ctx.c) and P.isActive(ctx.c)) then ctx.ok = false return end
  P.rest(ctx.c)
  ctx.ok = true
end
-- "そのカードの【トリガー】を発動してもよい"
A.runTriggerOf = function(ctx, op)
  for _, c in ipairs(cardsOf(ctx, {sel = op.sel})) do
    if P.hasTriggerIcon(c) and P.ai.useTrigger(ctx.tp, c) then P.runTrigger(ctx.tp, c) end
  end
end
-- "このターン中、自分はそのカードをリムーブエリアから使用できる"
A.allowFromRemove = function(ctx, op)
  local cards = {}
  for _, c in ipairs((ctx.sel or {})[op.sel or "m"] or {}) do if c:IsLocation(LOCATION_REMOVED) then cards[#cards+1] = c end end
  if #cards > 0 then P.addPlayerEffect(ctx.tp, "useFromRemove", P.durationOf("turn", ctx.tp), {cards = cards}) end
end
A.eventDest = function(ctx, op) ctx.eventDest = op.to end
A.loserTo = function(ctx, op) end   -- read by P.loserBounce before the loser leaves (battle rules)
-- face-down cards under a character: {from = hand|deckTop|outside|self, onto = self|sel|named, n, upTo, orOutside, may}
A.putFD = function(ctx, op)
  local tp = ctx.tp
  local target
  if op.onto == "self" then target = P.onField(ctx.c) and ctx.c or nil
  elseif op.onto == "other" then target = ctx.other
  elseif op.onto == "filt" then
    local pool = P.chars(tp, function(c) return P.matches(c, op.ontoFilt, ctx) end)
    target = P.ai.pick(ctx, pool, 1, {ai = "buff"})[1]
  elseif op.onto == "sel" then target = ((ctx.sel or {}).t or (ctx.sel or {}).p or {})[1]
  else
    local pool = P.chars(tp, function(c) for _, n in ipairs(op.names) do if P.isNamed(c, n) then return true end end return false end)
    target = pool[1]
  end
  local cards = {}
  if op.from == "hand" then
    local pool = P.hand(tp)
    if not target and op.orOutside then
      for _, c in ipairs(P.ai.discardPick(tp, pool, math.min(op.n, #pool), {})) do P.moveTo(c, "outside") end
      return
    end
    cards = P.ai.discardPick(tp, pool, math.min(op.n, #pool), {})
  elseif op.from == "deckTop" then
    cards = P.deckTop(tp, op.n)
    if op.may and cards[1] and P.ai.keepOnTop(tp, cards[1], "fdDeckTop") then return end
  elseif op.from == "outside" then
    cards = P.ai.pick(ctx, P.filter(P.outside(tp), function(c) return P.matches(c, op.filt, ctx) end), op.n, {ai = "best"})
  elseif op.from == "self" then
    cards = {ctx.c}
  elseif op.from == "dataCards" then
    cards = P.filter((ctx.data and ctx.data.cards) or {}, function(c) return c:IsLocation(LOCATION_GRAVE) end)
    cards = {cards[1]}
    if not cards[1] then cards = {} end
  elseif op.from == "other" then
    cards = (ctx.other and ctx.other:IsLocation(LOCATION_GRAVE)) and {ctx.other} or {}
  elseif op.from == "handOrOutside" then
    local names = {}
    local b = target and P.raidUnder(target)[1]
    if b then for k, v in pairs(op.nameByBase or {}) do if P.isNamed(b, k) then names = v end end end
    local function named(c) for _, n in ipairs(names) do if P.isNamed(c, n) then return true end end return false end
    local h = P.filter(P.hand(tp), named)
    if #h > 0 then cards = {h[1]}; ctx.fdFromHand = true
    else
      local o = P.filter(P.outside(tp), named)
      cards = o[1] and {o[1]} or {}
    end
  elseif op.from == "sel" then
    -- the cards an effect chose: retired ones now in the outside area, or characters still on the field
    cards = P.filter((ctx.sel or {})[op.sel or "t"] or {}, function(c) return c:IsLocation(LOCATION_GRAVE) or (P.onField(c) and c ~= target) end)
  end
  -- cards that leave the field to go under another card: the cards under them go to the outside area
  if target and op.from ~= "deckTop" then
    for _, c in ipairs(cards) do
      if P.onField(c) then
        local under = P.under(c)
        for _, x in ipairs(under) do P.fd[x] = nil end
        if #under > 0 then Duel.SendtoGrave(P.group(under), REASON_RULE) end
        P.fkey[c] = nil; P.erest[c] = nil
      end
    end
  end
  if op.from == "self" and target == ctx.c then cards = {} end
  if not target or not P.onField(target) or #cards == 0 then ctx.ok = false return end
  local fromField = false
  for _, c in ipairs(cards) do
    if c:IsLocation(LOCATION_DECK) then Duel.DisableShuffleCheck() end
    Duel.Overlay(target, P.group({c}))
    P.fd[c] = true
  end
  ctx.fdTarget = target
  ctx.ok = true
  P.syncRest(tp)
  P.log("FACE_DOWN_UNDER", "player=" .. tp .. ";onto=" .. P.label(target) .. ";n=" .. #cards)
end
-- "自分の場外から〈命の神水〉を1枚までAPを支払って使用する"
A.useFrom = function(ctx, op)
  for _, c in ipairs(P.zoneCards(ctx, "own", op.zone)) do
    if P.matches(c, op.filt, ctx) and P.isEvent(c) and P.canUse(ctx.tp, c, "event") then P.useEvent(ctx.tp, c, op.dest) return end
  end
end
-- "この効果で場外に置いたカードが〈ポチタ〉の場合、それを1枚まで自分のエナジーLにレストで登場させる"
A.putSel = function(ctx, op)
  for _, c in ipairs((ctx.sel or {})[op.sel or "t"] or {}) do
    if c:IsLocation(LOCATION_GRAVE) and P.matches(c, op.filt, ctx) and P.supported(c) then
      P.enter(ctx.tp, c, op.line == "front" and "front" or (op.line == "energy" and "energy" or P.ai.lineFor(ctx.tp, c)),
        {rested = not op.active, how = "effect", from = "outside"})
      return
    end
  end
end
-- "自分の場外の〈鹿目 まどか〉を必要エナジーの合計が4以上になるように望む枚数を望む順で自分の山札の下に置く"
A.pickNeedSum = function(ctx, op)
  local pool = P.filter(P.zoneCards(ctx, "own", op.zone or "outside"), function(c) return P.matches(c, op.filt, ctx) end)
  table.sort(pool, function(a, b) return P.baseNeed(a) > P.baseNeed(b) end)
  local chosen, sum = {}, 0
  for _, c in ipairs(pool) do
    if sum >= op.min then break end
    chosen[#chosen+1] = c
    sum = sum + P.baseNeed(c)
  end
  if sum < op.min then ctx.ok = false return end
  for _, c in ipairs(chosen) do P.moveTo(c, op.to or "deckBottom") end
  P.log("MOVED", "n=" .. #chosen .. ";to=" .. (op.to or "deckBottom") .. ";needSum=" .. sum)
  ctx.ok = true
end
A.extraEnergy = function(ctx, op)
  for _, c in ipairs(cardsOf(ctx, op)) do
    if P.onField(c) then P.addFlag(c, "gen", P.durationOf(op.dur or "turn", ctx.tp), op.n or 1, {color = op.color}) end
  end
end

------------------------------------------------------------------------------
-- Abilities and events
------------------------------------------------------------------------------
local function abilityUsable(c, ab, ctx, offField)
  if not offField then
    if P.lostText(c) and P.onField(c) then return false end
    if ab.where == "front" and not P.onFront(c) then return false end
    if ab.where == "energy" and not P.onEnergy(c) then return false end
    if ab.where == "outside" and not c:IsLocation(LOCATION_GRAVE) then return false end
    if ab.where == "hand" and not c:IsLocation(LOCATION_HAND) then return false end
    if ab.where ~= "hand" and ab.when == "main" and c:IsLocation(LOCATION_HAND) then return false end
    if ab.where ~= "outside" and ab.when == "main" and c:IsLocation(LOCATION_GRAVE) then return false end
    if ab.where == "remove" and not c:IsLocation(LOCATION_REMOVED) then return false end
    if ab.where ~= "remove" and ab.when == "main" and c:IsLocation(LOCATION_REMOVED) then return false end
  end
  if ab.turn == "own" and Duel.GetTurnPlayer() ~= ctx.tp then return false end
  if ab.turn == "opp" and Duel.GetTurnPlayer() == ctx.tp then return false end
  if ab.turn1 and P.usedThisTurn("ab:" .. P.id(c) .. ":" .. ab.idx) then return false end
  if ab.nameOnce and P.usedThisTurn("name:" .. ctx.tp .. ":" .. ab.nameOnce) then return false end
  if ab.cond and not P.condTrue(ctx, ab.cond) then return false end
  return true
end
local function markUsed(c, ab, ctx)
  if ab.turn1 then P.firstTime("ab:" .. P.id(c) .. ":" .. ab.idx) end
  if ab.nameOnce then P.firstTime("name:" .. ctx.tp .. ":" .. ab.nameOnce) end
end
function abilityUsableRef(c, ab, ctx) return abilityUsable(c, ab, ctx) end
function markUsedRef(c, ab, ctx) return markUsed(c, ab, ctx) end
-- Costs of 【起動メイン】 abilities: rest this card, discard, pay AP, retire this card, …
function P.costPossible(ctx, cost)
  for _, k in ipairs(cost or {}) do
    if k.k == "restSelf" and not (P.onField(ctx.c) and P.isActive(ctx.c)) then return false end
    if k.k == "ap" and not P.canPayAP(ctx.tp, k.n) then return false end
    if k.k == "discard" and #P.filter(P.hand(ctx.tp), function(c) return P.matches(c, k.filt, ctx) end) < k.n then return false end
    if k.k == "retireSelf" and not P.onField(ctx.c) then return false end
    if k.k == "removeSelf" and not P.onField(ctx.c) then return false end
    if k.k == "restOther" and #P.filter(P.field(ctx.tp), function(c) return c ~= ctx.c and P.isActive(c) and P.matches(c, k.filt, ctx) end) < (k.n or 1) then return false end
  end
  return true
end
function P.payCost(ctx, cost)
  for _, k in ipairs(cost or {}) do
    if k.k == "restSelf" then P.rest(ctx.c); P.mark("restedOwn:" .. P.id(ctx.c))
    elseif k.k == "ap" then
      P.payAP(ctx.tp, k.n, P.name(ctx.c))
      P.mark("apByEffect:" .. P.color(ctx.c) .. ":" .. ctx.tp)
    elseif k.k == "discard" then
      local pool = P.filter(P.hand(ctx.tp), function(c) return P.matches(c, k.filt, ctx) end)
      for _, c in ipairs(P.ai.discardPick(ctx.tp, pool, k.n, {cost = true})) do P.moveTo(c, "outside", REASON_COST + REASON_DISCARD) end
    elseif k.k == "retireSelf" then P.retire(ctx.c, {why = "cost"})
    elseif k.k == "removeSelf" then P.moveTo(ctx.c, "remove", REASON_COST)
    elseif k.k == "restOther" then
      local pool = P.filter(P.field(ctx.tp), function(c) return c ~= ctx.c and P.isActive(c) and P.matches(c, k.filt, ctx) end)
      for _, c in ipairs(P.ai.pick(ctx, pool, k.n or 1, {ai = "costRest"})) do P.rest(c) end
    end
  end
end
-- Enqueue the abilities of card c with timing `when` (src = where the text is read; a retired card's text is read
-- from the record taken when it left).
function P.fire(c, when, data, fx, tp)
  fx = fx or P.fxOf(c)
  if not fx.abil then return end
  tp = tp or c:GetControler()
  for _, ab in ipairs(fx.abil) do
    if ab.when == when then
      local ctx = {tp = tp, c = c, data = data, enterInfo = data}
      local offField = data and data.ignoreWhere
      if abilityUsable(c, ab, ctx, offField) then
        if not (ab.filt and data and data.other and not P.matches(data.other, ab.filt, ctx))
            and not (ab.srcFilt and not (data and data.by and P.matches(data.by, ab.srcFilt, ctx))) then
          P.enqueue(tp, P.name(c) .. ":" .. when, function()
            if ab.turn1 or ab.nameOnce then
              if not abilityUsable(c, ab, ctx, offField) then return end
              markUsed(c, ab, ctx)
            end
            if ab.cost then
              if not P.costPossible(ctx, ab.cost) or not P.ai.wantCost(ctx, ab) then return end
              P.payCost(ctx, ab.cost)
            end
            P.run(ctx, ab.act)
          end)
        end
      end
    end
  end
end
-- Abilities of every card on both fields that listen to an event about another card ({when="ownCharEnter", ...}).
function P.emit(when, other, data)
  for _, tp in ipairs({Duel.GetTurnPlayer(), 1 - Duel.GetTurnPlayer()}) do
    for _, src in ipairs(P.field(tp)) do
      local fx = P.fxOf(src)
      if fx.abil then
        for _, ab in ipairs(fx.abil) do
          if ab.when == when then
            local mine = other == nil or other:GetControler() == tp
            local sideOk = (ab.side == "opp" and not mine) or (ab.side ~= "opp" and mine) or ab.side == "any"
            if sideOk and (ab.allowSelf or other ~= src) then
              local ctx = {tp = tp, c = src, data = data, other = other}
              if abilityUsable(src, ab, ctx) and (not ab.filt or (other and P.matches(other, ab.filt, ctx))) then
                ctx.sel = {other = other and {other} or {}}
                P.enqueue(tp, P.name(src) .. ":" .. when, function()
                  if ab.turn1 or ab.nameOnce then
                    if not abilityUsable(src, ab, ctx) then return end
                    markUsed(src, ab, ctx)
                  end
                  P.run(ctx, ab.act)
                end)
              end
            end
          end
        end
      end
    end
  end
end

-- Hooks called by the flow
function P.onEntered(c, tp, opts)
  P.fire(c, "enter", opts)
  P.emit("charEnter", c, opts)
end
function P.onRaided(c, tp, target, opts)
  if opts and opts.base then target = opts.base end
  P.fire(c, "enter", opts)
  -- "このキャラがレイドされた時" on the card now under it
  P.fire(target, "raided", {ignoreWhere = true, raider = c}, nil, tp)
  P.emit("charRaid", c, opts)
end
function P.onRetired(rec, info)
  P.retiredLog[#P.retiredLog+1] = {turn = P.turnNo, tp = rec.tp, card = rec.card}
  -- "自分か相手の効果によってこのキャラが場を離れた時"
  if info and info.why == "effect" then P.fire(rec.card, "leftByEffect", {ignoreWhere = true}, rec.fx, rec.tp) end
  P.fire(rec.card, "retire", {ignoreWhere = true, info = info, under = rec.under, fdBefore = rec.fdBefore}, rec.fx, rec.tp)
  if rec.wasChar then P.emitRetired(rec, info) end
end
function P.emitRetired(rec, info)
  for _, tp in ipairs({Duel.GetTurnPlayer(), 1 - Duel.GetTurnPlayer()}) do
    for _, src in ipairs(P.field(tp)) do
      local fx = P.fxOf(src)
      for _, ab in ipairs(fx.abil or {}) do
        if ab.when == "charRetire" then
          local mine = rec.tp == tp
          if (ab.side == "opp" and not mine) or (ab.side ~= "opp" and mine) then
            local ctx = {tp = tp, c = src, other = rec.card}
            if abilityUsable(src, ab, ctx) and (not ab.filt or P.matches(rec.card, ab.filt, ctx)) then
              P.enqueue(tp, P.name(src) .. ":charRetire", function()
                if ab.turn1 or ab.nameOnce then
                  if not abilityUsable(src, ab, ctx) then return end
                  markUsed(src, ab, ctx)
                end
                P.run(ctx, ab.act)
              end)
            end
          end
        end
      end
    end
  end
end
function P.onAttack(a, target)
  P.fire(a, "attack", {target = target})
  for _, e in ipairs(P.flagEntries(a, "onAttack")) do
    local ctx = {tp = a:GetControler(), c = a}
    P.enqueue(ctx.tp, P.name(a) .. ":granted attack", function() P.run(ctx, e.data.act) end)
  end
  P.emit("charAttack", a, {target = target})
end
function P.onBlock(b, a)
  P.fire(b, "block", {attacker = a})
  P.fire(a, "blocked", {blocker = b})
end
function P.onUnblocked(a)
  P.fire(a, "unblocked", {})
  P.emit("charUnblocked", a, {})
  for _, e in ipairs(P.flagEntries(a, "onUnblocked")) do
    local ctx = {tp = a:GetControler(), c = a}
    P.enqueue(ctx.tp, P.name(a) .. ":granted unblocked", function() P.run(ctx, e.data.act) end)
  end
end
function P.onDirectHit(a) P.fire(a, "hitPlayer", {}) end
function P.onBattleWin(a, d)
  if P.onField(a) then P.fire(a, "battleWin", {other = d}) end
  if P.onField(a) then P.emit("charBattleWin", a, {other = d}) end
  for _, e in ipairs(P.flagEntries(a, "onBattleWin")) do
    local ctx = {tp = a:GetControler(), c = a}
    P.enqueue(ctx.tp, P.name(a) .. ":granted battleWin", function() P.run(ctx, e.data.act) end)
  end
end
function P.onBattleLose(a, d)
  if P.onField(a) then P.fire(a, "battleLose", {other = d}) end
  for _, e in ipairs(P.flagEntries(a, "onBattleLose")) do
    local ctx = {tp = a:GetControler(), c = a}
    if e.data.once then e.used = true end
    P.enqueue(ctx.tp, P.name(a) .. ":granted battleLose", function() P.run(ctx, e.data.act) end)
  end
  if P.onField(d) then P.fire(d, "battleWin", {other = a, defending = true}) end
end
function P.onAttackEnd(a, tp)
  if P.onField(a) then
    P.fire(a, "attackEndSelf", {})
    for _, e in ipairs(P.flagEntries(a, "onAttackEndSelf")) do
      local ctx = {tp = a:GetControler(), c = a}
      P.enqueue(ctx.tp, P.name(a) .. ":granted attack end", function() if P.onField(a) then P.run(ctx, e.data.act) end end)
    end
    if P.hasFlag(a, "retireAtAttackEnd") then
      P.enqueue(tp, P.name(a) .. ":retire at attack end", function() if P.onField(a) then P.retire(a, {why = "effect"}) end end)
    end
  end
  P.emit("charAttackEnd", a, {})
end
function P.onAttackPhaseStart(tp)
  for _, c in ipairs(P.field(tp)) do P.fire(c, "attackPhaseStart", {}) end
  for _, c in ipairs(P.field(tp)) do
    for _, e in ipairs(P.flagEntries(c, "onAttackPhaseStart")) do
      if not e.data.where or (e.data.where == "energy" and P.onEnergy(c)) or (e.data.where == "front" and P.onFront(c)) then
        local ctx = {tp = tp, c = c}
        P.enqueue(tp, P.name(c) .. ":granted attack phase start", function() if P.onField(c) then P.run(ctx, e.data.act) end end)
      end
    end
  end
  for _, e in ipairs(P.playerEffects(tp, "atAttackPhaseStart")) do
    e.used = true
    P.enqueue(tp, "delayed:attack phase start", function() P.run({tp = tp, c = e.data.c or P.field(tp)[1]}, e.data.act) end)
  end
end
function P.onMainEnd(tp)
  for _, c in ipairs(P.field(tp)) do
    P.fire(c, "mainEnd", {})
    if P.hasFlag(c, "retireAtMainEnd") then
      P.enqueue(tp, P.name(c) .. ":retire at main end", function() if P.onField(c) then P.retire(c, {why = "effect"}) end end)
    end
  end
end
function P.onTurnStart(tp)
  for _, c in ipairs(P.field(tp)) do P.fire(c, "turnStart", {}) end
end
function P.onEndPhase(tp)
  for _, c in ipairs(P.field(tp)) do P.fire(c, "endPhase", {}) end
  for _, c in ipairs(P.field(1 - tp)) do P.fire(c, "oppEndPhase", {}) end
  for p = 0, 1 do
    for _, e in ipairs(P.playerEffects(p, "endPhaseAct")) do
      if e.data.turn == P.turnNo then
        e.used = true
        local ctx = {tp = p, c = e.data.c}
        P.enqueue(p, "delayed", function() P.run(ctx, e.data.act) end)
      end
    end
  end
  for _, f in ipairs(P.flags) do
    if f.flag == "retireAtOppAttackEnd" then end
  end
end
function P.onAttackPhaseEnd(tp)
  -- "相手のアタックフェイズ終了時、このキャラを退場させる。"
  for _, c in ipairs(P.chars(1 - tp)) do
    if P.hasFlag(c, "retireAtOppAttackEnd") then
      P.enqueue(1 - tp, P.name(c) .. ":retire at attack end", function() if P.onField(c) then P.retire(c, {why = "effect"}) end end)
    end
  end
  for _, c in ipairs(P.field(tp)) do P.fire(c, "attackPhaseEnd", {}) end
  for _, c in ipairs(P.field(tp)) do
    for _, e in ipairs(P.flagEntries(c, "onAttackPhaseEnd")) do
      local ctx = {tp = tp, c = c}
      P.enqueue(tp, P.name(c) .. ":granted attack phase end", function() if P.onField(c) then P.run(ctx, e.data.act) end end)
    end
  end
  for _, c in ipairs(P.field(tp)) do
    if P.hasFlag(c, "bounceAtAttackPhaseEnd") then
      P.enqueue(tp, P.name(c) .. ":to hand at attack phase end", function() if P.onField(c) then P.moveTo(c, "hand"); P.log("BOUNCE", "card=" .. P.name(c)) end end)
    end
  end
end
function P.onBecameActive(c) P.fire(c, "becameActive", {}) end
function P.onBPPlus(c) P.fire(c, "bpPlus", {}) end
function P.onMoved(c, tp, line) P.fire(c, "moved", {line = line}) end
function P.runEvent(tp, c, from)
  local f = P.fxOf(c)
  local ctx = {tp = tp, c = c, usedFrom = from}
  P.run(ctx, f.event)
  return ctx
end
function P.runTrigger(tp, c)
  local f = P.fxOf(c)
  if not f.trig then return end
  P.log("TRIGGER", "player=" .. tp .. ";card=" .. P.label(c) .. ";kind=" .. tostring(f.trig.kind))
  if P.showUse then P.showUse(tp, c) end
  P.mark("trigger:" .. tp)
  local ctx = {tp = tp, c = c, trigger = true}
  -- "このカードの【カラートリガー】を発動する場合、…に代えてもよい": the other text when only it can do something
  if f.trigAlt and not P.actsPossible(ctx, f.trig.act) and P.actsPossible(ctx, f.trigAlt) then
    P.log("TRIGGER_ALT", "card=" .. P.label(c))
    P.run(ctx, f.trigAlt)
    return
  end
  P.run(ctx, f.trig.act)
end
-- 【起動メイン】 abilities tp can use now (manual p.11; Q&A Q30, Q31, Q877)
function P.mainAbilities(tp)
  local out = {}
  for _, c in ipairs(P.concat(P.concat(P.hand(tp), P.outside(tp)), P.removeArea(tp))) do
    for _, ab in ipairs(P.fxOf(c).abil or {}) do
      if ab.when == "main" and (ab.where == "hand" or ab.where == "outside" or ab.where == "remove") then
        local ctx = {tp = tp, c = c}
        if abilityUsable(c, ab, ctx) and P.costPossible(ctx, ab.cost) and P.actsPossible(ctx, ab.act) then out[#out+1] = {c = c, ab = ab} end
      end
    end
  end
  for _, c in ipairs(P.field(tp)) do
    local fx = P.fxOf(c)
    for _, ab in ipairs(fx.abil or {}) do
      if ab.when == "main" then
        local ctx = {tp = tp, c = c}
        if abilityUsable(c, ab, ctx) and P.costPossible(ctx, ab.cost) and P.actsPossible(ctx, ab.act) then
          out[#out+1] = {c = c, ab = ab}
        end
      end
    end
  end
  return out
end
function P.useMain(tp, entry)
  local c, ab = entry.c, entry.ab
  local ctx = {tp = tp, c = c}
  markUsed(c, ab, ctx)
  P.payCost(ctx, ab.cost)
  P.log("ACTIVATE", "player=" .. tp .. ";card=" .. P.label(c) .. ";ability=" .. ab.idx)
  if P.showUse then P.showUse(tp, c) end
  P.mark("activated:" .. tp)
  P.run(ctx, ab.act)
  P.drain()
end
-- "自分の場の〈レム〉が相手の効果で退場する場合、代わりにこのキャラを退場させてもよい"
-- "BP500以上のこのキャラが退場する場合、代わりにこのキャラの下の裏向きのカードを1枚場外に置く" and the like.
-- leaving: true for any leaving the field by an effect or a battle, false for 退場 only.
P.inReplace = 0
function P.replaceLeave(c, info, leaving)
  if P.inReplace > 0 or not P.onField(c) then return false end
  local tp = c:GetControler()
  for _, st in ipairs(P.statics(c, "replaceLeave")) do
    local ok = staticOn(c, st) and (leaving == false or st.leave)
    if ok and st.minBP and P.bp(c) < st.minBP then ok = false end
    if ok and st.byOpp then
      local why = info and info.why
      ok = why == "battle" or (why == "effect" and info.by ~= nil and info.by:GetControler() ~= tp)
    end
    if ok and st.needRaided and not P.isRaided(c) then ok = false end
    if ok and st.needHand and #P.hand(tp) < st.needHand then ok = false end
    if ok and st.act and st.act[1].op == "moveUnder" and #P.fdUnder(c) < 1 then ok = false end
    if ok and st.need == "pick" and not P.actsPossible({tp = tp, c = c, sel = {}}, st.act) then ok = false end
    if ok and st.turn1 and P.usedThisTurn("rl:" .. P.id(c) .. ":" .. st.turn1) then ok = false end
    if ok and st.turn1 then P.firstTime("rl:" .. P.id(c) .. ":" .. st.turn1) end
    if ok then
      P.inReplace = P.inReplace + 1
      P.log("LEAVE_REPLACED", "card=" .. P.label(c) .. ";by=" .. (st.toHand and "hand" or (st.act and st.act[#st.act].op or "?")))
      if st.toHand then P.moveTo(c, "hand")
      else P.run({tp = tp, c = c, sel = {}}, st.act) end
      P.inReplace = P.inReplace - 1
      return true
    end
  end
  return false
end
function P.replaceRetire(c, info)
  if P.replaceLeave(c, info, false) then return true end
  if not info or info.why ~= "effect" or not info.by or info.by:GetControler() == c:GetControler() then return false end
  local tp = c:GetControler()
  for _, s in ipairs(P.field(tp)) do
    if s ~= c then
      for _, st in ipairs(P.statics(s, "substitute")) do
        if staticOn(s, st) and P.matches(c, st.filt, staticCtx(s)) then
          P.log("SUBSTITUTE", "card=" .. P.label(c) .. ";instead=" .. P.label(s))
          P.retireMany({s}, {why = "substitute"})
          return true
        end
      end
    end
  end
  return false
end
-- "このバトルで敗北した相手のキャラは退場する代わりに、手札に戻る / 相手の山札の下に置かれる": a battleWin ability of the
-- attacker that can resolve now (its conditions hold) changes where the loser goes.
function P.loserBounce(a, d)
  if P.hasFlag(a, "loserBounce") then return "hand" end
  local ctx = {tp = a:GetControler(), c = a}
  for _, ab in ipairs(P.fxOf(a).abil or {}) do
    if ab.when == "battleWin" and abilityUsable(a, ab, ctx) then
      for _, o in ipairs(ab.act or {}) do
        if o.op == "loserTo" then
          if o.to == "hand" then
            for _, x in ipairs(P.auras()) do
              if x.s.effect == "loserToBottom" and x.tp == ctx.tp and staticOn(x.src, x.s) and P.matches(a, x.s.filt, staticCtx(x.src)) then return "deckBottom" end
            end
          end
          return o.to
        end
      end
    end
  end
  return nil
end
