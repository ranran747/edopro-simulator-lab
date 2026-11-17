-- UNION ARENA on EDOPro: pending effects, moves, playing cards, raid, attacks, damage, turns and setup.
-- Rules: official rule manual (2023-08-18, "manual p.N") and the rules Q&A ("Q&A QN"); see docs/rules.md.
local P = UnionArenaAI
local list = P.list

------------------------------------------------------------------------------
-- Field identity: a card keeps its identity while it moves between the lines; it gets a new one when it comes
-- onto the field from elsewhere (Q&A Q104: effects it received end when it leaves the field).
------------------------------------------------------------------------------
P.fkey, P.nextKey = {}, 0
function P.newKey(c) P.nextKey = P.nextKey + 1; P.fkey[c] = P.nextKey; return P.nextKey end
function P.id(c)
  if not P.onField(c) then return -1 end
  return P.fkey[c] or P.newKey(c)
end
local function forget(c) P.fkey[c] = nil; P.erest[c] = nil end

------------------------------------------------------------------------------
-- Pending effects (manual p.13 "複数の効果が同時に発動した時"): the turn player's first, each player in the order
-- they were queued (the rules let the player choose the order), effects that trigger while one resolves join the
-- pending ones.
------------------------------------------------------------------------------
P.pending = {}
function P.enqueue(tp, label, fn)
  P.pending[#P.pending+1] = {tp = tp, label = label, fn = fn}
end
function P.drain()
  local guard = 0
  while #P.pending > 0 and not P.finished do
    guard = guard + 1
    if guard > 500 then P.log("PENDING_GUARD", "n=" .. #P.pending); P.pending = {} break end
    local tp = Duel.GetTurnPlayer()
    local idx = nil
    for i, e in ipairs(P.pending) do if e.tp == tp then idx = i break end end
    idx = idx or 1
    local e = table.remove(P.pending, idx)
    P.log("RESOLVE", "player=" .. e.tp .. ";what=" .. e.label)
    e.fn()
    P.checkState()
  end
end

------------------------------------------------------------------------------
-- State checks: BP 0 or less retires (manual p.13, Q&A Q94); life 0 loses (manual p.5, Q&A Q12, Q14).
------------------------------------------------------------------------------
P.inTriggerCheck = 0
P.outsideSeen = {}
function P.checkState()
  if P.finished or not P.started or P.checking then return end
  P.checking = true
  local again = true
  while again and not P.finished do
    again = false
    -- "このカードが場外に置かれた時、このカードを場外から自分の山札の下に置く"
    for tp = 0, 1 do
      for _, c in ipairs(P.outside(tp)) do
        if P.fxOf(c).outsideToTop and not P.checkingCards[c] and not P.outsideSeen[c] then
          P.outsideSeen[c] = true
          if P.ai.keepOnTop(tp, c, "outsideToTop") then
            Duel.SendtoDeck(c, nil, SEQ_DECKTOP, REASON_EFFECT)
            P.log("TO_DECK_TOP", "card=" .. P.label(c) .. ";why=own text")
          end
        end
        if P.fxOf(c).outsideToBottom and not P.checkingCards[c] then
          Duel.SendtoDeck(c, nil, SEQ_DECKBOTTOM, REASON_EFFECT)
          P.log("TO_DECK_BOTTOM", "card=" .. P.label(c) .. ";why=own text")
        end
      end
    end
    local dead = {}
    for _, c in ipairs(P.allChars()) do if P.bp(c) <= 0 then dead[#dead+1] = c end end
    if #dead > 0 then
      for _, c in ipairs(dead) do P.log("BP_ZERO", "card=" .. P.label(c) .. ";bp=" .. P.bp(c)) end
      P.retireMany(dead, {why = "bp0"})
      again = true
    end
  end
  P.checking = false
  if P.inTriggerCheck == 0 and not P.finished then
    local l0, l1 = P.lifeCount(0) == 0, P.lifeCount(1) == 0
    if l0 and l1 then P.finish(PLAYER_NONE, "both_life_0")
    elseif l0 then P.finish(1, "life_0")
    elseif l1 then P.finish(0, "life_0") end
  end
end
function P.ownedCards(tp)
  local where = LOCATION_DECK + LOCATION_HAND + LOCATION_MZONE + LOCATION_SZONE + LOCATION_GRAVE + LOCATION_REMOVED + LOCATION_EXTRA
  local n = Duel.GetMatchingGroup(function(c) return c:GetOwner() == tp end, tp, where, where, nil):GetCount()
  for c in aux.Next(Duel.GetFieldGroup(0, LOCATION_ONFIELD, LOCATION_ONFIELD)) do
    for _, x in ipairs(list(c:GetOverlayGroup())) do if x:GetOwner() == tp then n = n + 1 end end
  end
  return n
end
function P.finish(winner, reason)
  if P.finished then return end
  P.finished = true
  P.winner = winner
  for tp = 0, 1 do
    P.log("CARDS", "player=" .. tp .. ";deck=" .. P.deckCount(tp) .. ";hand=" .. #P.hand(tp) .. ";front=" .. #P.front(tp)
      .. ";energy=" .. #P.energy(tp) .. ";life=" .. P.lifeCount(tp) .. ";outside=" .. #P.outside(tp)
      .. ";remove=" .. #P.removeArea(tp) .. ";total=" .. P.ownedCards(tp))
  end
  P.log("WIN", "player=" .. winner .. ";reason=" .. reason .. ";turn=" .. P.turnNo)
  if P.logfile then P.logfile:close(); P.logfile = nil end
  Duel.Win(winner, 0xfd)
end

------------------------------------------------------------------------------
-- Moves
------------------------------------------------------------------------------
-- Q&A Q13: drawing from an empty deck outside the start phase does not lose; nothing is drawn.
function P.draw(tp, n)
  local got = {}
  for i = 1, n or 1 do
    if P.finished or P.deckCount(tp) == 0 then break end
    local c = P.deckTop(tp, 1)[1]
    Duel.Draw(tp, 1, REASON_EFFECT)
    got[#got+1] = c
  end
  if #got > 0 then
    P.log("DRAW", "player=" .. tp .. ";n=" .. #got .. ";hand=" .. #P.hand(tp))
    P.mark("drew:" .. tp, #got)
  end
  return got
end
-- Leaving the field: the top card goes to dest, the cards under a raided character to the outside area
-- (manual p.13, Q&A Q60-Q62).
local function sendUnder(c)
  local under = P.under(c)
  for _, x in ipairs(under) do P.fd[x] = nil end
  if #under > 0 then Duel.SendtoGrave(P.group(under), REASON_RULE) end
end
-- dest: "outside" | "hand" | "remove" | "deckBottom" | "deckTop" | "life"
function P.moveTo(c, dest, reason)
  reason = reason or REASON_EFFECT
  P.outsideSeen[c] = nil
  P.fd[c] = nil
  -- "このカードが使用されること以外でリムーブエリアに置かれる場合、代わりに場外に置く"
  if dest == "remove" and P.fxOf(c).removeToOutside and P.usingToRemove ~= c
      and not (c:IsLocation(LOCATION_SZONE) and c:GetSequence() == 4) then dest = "outside" end
  local wasField, owner, tp = P.onField(c), c:GetOwner(), c:GetControler()
  -- "…このキャラが場を離れる場合、代わりにこのカードをリムーブエリアに置いてもよい"
  if wasField and dest ~= "remove" and P.fxOf(c).leaveToRemove and P.condTrue and P.condTrue({tp = tp, c = c}, P.fxOf(c).leaveToRemove) then
    P.log("LEAVE_REPLACED", "card=" .. P.label(c) .. ";to=remove")
    dest = "remove"
  end
  local base = (wasField and dest == "hand") and P.raidUnder(c) or nil
  local fdBefore = wasField and #P.fdUnder(c) or 0
  if wasField then sendUnder(c) end
  if c:IsLocation(LOCATION_DECK) then Duel.DisableShuffleCheck() end
  if dest == "life" then P.mark("lifeAdded:" .. owner) end
  if dest == "outside" then Duel.SendtoGrave(c, reason)
  elseif dest == "hand" then Duel.SendtoHand(c, owner, reason)
  elseif dest == "remove" then Duel.Remove(c, POS_FACEUP, reason)
  elseif dest == "deckBottom" then Duel.SendtoDeck(c, owner, SEQ_DECKBOTTOM, reason)
  elseif dest == "deckTop" then Duel.SendtoDeck(c, owner, SEQ_DECKTOP, reason)
  elseif dest == "life" then Duel.Remove(c, POS_FACEDOWN, reason) end
  if wasField then forget(c); P.syncRest(tp) end
  if base and c:IsLocation(LOCATION_HAND) and P.fire then
    P.fire(c, "bounced", {ignoreWhere = true, base = base, fdBefore = fdBefore}, nil, tp)
  end
  return true
end
-- 退場 (manual p.13): moved from the field to the outside area by "退場させる", BP 0 or a battle. Fires 退場時.
function P.retireMany(cards, info)
  local gone = {}
  for _, c in ipairs(cards) do
    if P.onField(c) then
      if P.replaceRetire and P.replaceRetire(c, info) then
        -- a replacement effect moved it elsewhere
      elseif P.fxOf(c).leaveToRemove and P.condTrue({tp = c:GetControler(), c = c}, P.fxOf(c).leaveToRemove) then
        P.moveTo(c, "remove")
      else
        local rec = {card = c, tp = c:GetControler(), fx = P.fxOf(c), name = P.label(c), line = P.lineOf(c), key = P.id(c),
                     wasChar = P.isChar(c), raided = P.isRaided(c), toHand = P.hasFlag(c, "retireToHand"),
                     reenter = P.hasFlag(c, "retireReenter"), under = P.under(c), fdBefore = #P.fdUnder(c)}
        P.moveTo(c, "outside", REASON_EFFECT + REASON_DESTROY)
        P.log("RETIRE", "player=" .. rec.tp .. ";card=" .. rec.name .. ";why=" .. ((info and info.why) or "effect"))
        gone[#gone+1] = rec
      end
    end
  end
  for _, rec in ipairs(gone) do
    if P.onRetired then P.onRetired(rec, info) end
    if rec.reenter then
      P.enqueue(rec.tp, rec.name .. ":granted retire (re-enter)", function()
        local c = rec.card
        if not c:IsLocation(LOCATION_GRAVE) then return end
        local targets = P.raidTargets(rec.tp, c)
        if #targets > 0 and P.meetsNeed(rec.tp, c) then P.doRaid(rec.tp, c, P.ai.raidTarget(rec.tp, c, targets), {how = "effect"})
        else P.enter(rec.tp, c, P.ai.lineFor(rec.tp, c), {how = "effect", from = "outside"}) end
      end)
    end
    if rec.toHand then
      P.enqueue(rec.tp, rec.name .. ":granted retire", function()
        if rec.card:IsLocation(LOCATION_GRAVE) then Duel.SendtoHand(rec.card, rec.tp, REASON_EFFECT); P.log("TO_HAND", "card=" .. rec.name) end
      end)
    end
  end
  return gone
end
function P.retire(c, info) return #P.retireMany({c}, info) > 0 end
-- The AP area (manual p.8): n face-up AP cards, the rest face-down.
function P.setApCount(tp, n)
  local area = P.apArea(tp)
  local reserve = P.apReserve(tp)
  while #area < n and #reserve > 0 do
    local c = table.remove(reserve, 1)
    -- the core does not turn an Extra Deck card face-up in place; it passes through the hand (not a rules move)
    Duel.SendtoHand(c, tp, REASON_RULE)
    Duel.Sendto(c, LOCATION_EXTRA, REASON_RULE, POS_FACEUP_DEFENSE, tp)
    P.aprest[c] = nil
    area = P.apArea(tp)
  end
  P.syncRest(tp)
end
function P.apActive(tp) return P.filter(P.apArea(tp), P.isActive) end
function P.canPayAP(tp, n) return n <= 0 or #P.apActive(tp) >= n end
function P.payAP(tp, n, why)
  if n <= 0 then return true end
  local act = P.apActive(tp)
  if #act < n then return false end
  for i = 1, n do P.setRested(act[i], true) end
  P.log("AP_PAY", "player=" .. tp .. ";n=" .. n .. ";left=" .. #P.apActive(tp) .. (why and (";for=" .. why) or ""))
  return true
end

------------------------------------------------------------------------------
-- Active / rest with "次の1回アクティブにならない" (Q&A Q85, Q86, Q102)
------------------------------------------------------------------------------
function P.stand(c, why)
  if P.isActive(c) then return false end
  -- "自分の効果以外でアクティブにならない"
  if P.onField(c) and P.fxOf(c).standOnlyOwn and why ~= "own" then return false end
  if P.onField(c) and P.hasFlag(c, "noStand") then
    P.log("NO_STAND", "card=" .. P.label(c))
    return false
  end
  if P.onField(c) and P.useFlag(c, "freeze") then
    P.log("FROZEN", "card=" .. P.label(c) .. ";stays=rest")
    return false
  end
  P.setRested(c, false)
  if P.onField(c) and why == "effect" and P.onBecameActive then P.onBecameActive(c) end
  return true
end
function P.rest(c) return P.setRested(c, true) end

------------------------------------------------------------------------------
-- Placing cards on the lines (manual p.9, p.10; Q&A Q22: a full line first loses one card to the remove area)
------------------------------------------------------------------------------
function P.makeRoom(tp, line, keep)
  if P.lineCount(tp, line) < P.LINE then return true end
  local pool = line == "front" and P.front(tp) or P.energy(tp)
  pool = P.filter(pool, function(x) return not P.contains(keep or {}, x) end)
  if #pool == 0 then return false end
  local victim = P.ai.roomPick(tp, pool, line)
  P.log("LINE_FULL", "player=" .. tp .. ";line=" .. line .. ";removed=" .. P.label(victim))
  -- "このカードは手札やラインの上限超過の処理でリムーブエリアの代わりに場外に置かれる"
  P.moveTo(victim, P.fxOf(victim).overflowOutside and "outside" or "remove", REASON_RULE)
  return true
end
-- Moves card c onto tp's line (from anywhere, or from the other line). Keeps the cards under it.
local function putOnLine(c, tp, line, rested)
  local under = P.onField(c) and P.under(c) or {}
  local seq = P.freeSeq(tp, line)
  if not seq then return false end
  local ok
  if line == "front" then
    ok = Duel.MoveToField(c, tp, tp, LOCATION_MZONE, rested and POS_FACEUP_DEFENSE or POS_FACEUP_ATTACK, true, 1 << seq)
  else
    ok = Duel.MoveToField(c, tp, tp, LOCATION_SZONE, POS_FACEUP, true, 1 << seq)
  end
  if not ok or not P.lineOf(c) then return false end
  if #under > 0 then
    local still = P.under(c)
    local missing = P.filter(under, function(x) return not P.contains(still, x) end)
    if #missing > 0 then Duel.Overlay(c, P.group(missing)) end
  end
  if line == "energy" then P.erest[c] = rested and c:GetFieldID() or nil end
  P.registerDisplay(c)
  P.syncRest(tp)
  return true
end
function P.registerDisplay(c)
  if P.displayed and P.displayed[c] then return end
  P.displayed = P.displayed or {}
  P.displayed[c] = true
  local e = Effect.CreateEffect(c)
  e:SetType(EFFECT_TYPE_SINGLE)
  e:SetProperty(EFFECT_FLAG_SINGLE_RANGE + EFFECT_FLAG_CANNOT_DISABLE + EFFECT_FLAG_UNCOPYABLE)
  e:SetRange(LOCATION_MZONE)
  e:SetCode(EFFECT_SET_ATTACK_FINAL)
  e:SetValue(function(_, card) return math.max(0, P.bp(card)) end)
  c:RegisterEffect(e)
end
-- 登場 (manual p.9): a character to the front or energy line, a field to the energy line, rested unless said.
-- opts: rested (default true), how ("hand"|"effect"|"trigger"), from, silent (no 登場時)
function P.enter(tp, c, line, opts)
  opts = opts or {}
  if P.isFieldCard(c) then line = "energy" end
  if P.isChar(c) and P.fxOf(c).noFront and line == "front" then line = "energy" end
  if P.isChar(c) and P.fxOf(c).noEnergy and line == "energy" then line = "front" end
  local rested = opts.rested ~= false
  if P.fxOf(c).enterActive then rested = false end
  -- "次に自分の場に登場させる…1枚は、アクティブで登場させる"
  if rested and P.playerEffects then
    for _, e in ipairs(P.playerEffects(tp, "enterActiveNext")) do
      if P.matches and P.matches(c, e.data.filt, {tp = tp}) then
        rested = false
        if not e.data.all then e.used = true end
        break
      end
    end
  end
  if not P.makeRoom(tp, line) then return false end
  local fromField = P.onField(c)
  if fromField then sendUnder(c); forget(c) end
  if not putOnLine(c, tp, line, rested) then
    P.log("NO_ROOM", "player=" .. tp .. ";card=" .. P.label(c))
    return false
  end
  P.newKey(c)
  P.entered[P.id(c)] = P.turnNo
  P.enteredBy[P.id(c)] = opts.how or "effect"
  P.enteredFrom[P.id(c)] = opts.from
  P.enteredByChar[P.id(c)] = opts.byChar == true
  if opts.from then P.mark("enteredFrom:" .. opts.from .. ":" .. tp) end
  if opts.how == "effect" then P.mark("effectEnter:" .. tp) end
  P.log("ENTER", "player=" .. tp .. ";card=" .. P.label(c) .. ";line=" .. line .. ";rested=" .. (rested and 1 or 0)
    .. ";how=" .. (opts.how or "effect") .. (opts.from and (";from=" .. opts.from) or "") .. ";bp=" .. P.bp(c))
  P.mark("entered:" .. tp)
  P.enteredLog[#P.enteredLog+1] = {turn = P.turnNo, tp = tp, card = c}
  for _, n in ipairs(P.names(c)) do P.mark("enteredName:" .. n .. ":" .. tp) end
  if not opts.silent and P.onEntered then P.onEntered(c, tp, opts) end
  return true
end
-- Raid (manual p.9-10, Q&A Q41-Q62): c goes on top of target (a character without 【レイド】 that is not raided),
-- the target loses the effects it had received, c becomes active, may move to the front line, then 登場時.
function P.raidTargets(tp, c)
  local f = P.fxOf(c)
  if not f.raid and not f.upgrade then return {} end
  if f.raidIf and not P.condTrue({tp = tp, c = c}, f.raidIf) then return {} end
  if P.enterBlocked(tp, c) then return {} end
  return P.chars(tp, function(t)
    if f.raid and not f.upgradeOnly and P.raidMatches(f.raid, t) then return true end
    return f.upgrade ~= nil and P.upgradeMatches(f.upgrade, t)
  end)
end
-- "レイド状態の〈ラガン〉か〈グレン〉の一番上のカードをそのレイド元の下に裏向きで置き、そのレイド元にレイドできる"
function P.upgradeMatches(spec, t)
  if not P.isChar(t) or not P.isRaided(t) then return false end
  local ok = false
  for _, n in ipairs(spec.names) do if P.isNamed(t, n) then ok = true end end
  if not ok then return false end
  if spec.fresh and P.enteredBy[P.id(t)] == "raid" and P.entered[P.id(t)] == P.turnNo then return false end
  local base = P.raidUnder(t)[1]
  if base and P.hasFlag(t, "noRaidOnto") then return false end
  return true
end
-- "このキャラが自分の場にある場合、自分の場に〈カミナ〉は登場できない"
function P.enterBlocked(tp, c)
  if not P.auras then return false end
  for _, a in ipairs(P.auras()) do
    if a.s.effect == "noEnter" and a.tp == tp and a.src ~= c and P.matches(c, a.s.filt, {tp = tp, c = a.src}) then return true end
  end
  return false
end
function P.raidMatches(spec, t)
  if not P.isChar(t) or P.isRaided(t) or P.fxOf(t).raid then return false end
  if P.onField(t) and P.hasFlag(t, "noRaidOnto") then return false end
  if spec.names then
    for _, n in ipairs(spec.names) do if P.isNamed(t, n) then return true end end
  end
  if spec.trait and P.hasTrait(t, spec.trait) then return true end
  if spec.nameHas and P.nameHas(t, spec.nameHas) then return true end
  return false
end
function P.doRaid(tp, c, target, opts)
  opts = opts or {}
  -- an upgrade raid: the top card of the raided target goes face-down under its base, c goes on top
  if P.isRaided(target) then
    opts.base = P.raidUnder(target)[1]
    opts.upgradeFrom = target
  end
  local line = P.lineOf(target)
  local seq = target:GetSequence()
  local wasRested = P.isRested(target)
  local fdOfTarget = P.fdUnder(target)
  -- the raiding card goes to a free spot first (the spare 5th zone of the line, or the other line), then the
  -- target is put under it and it takes the target's place.
  local stage
  if line == "front" then
    if Duel.CheckLocation(tp, LOCATION_MZONE, 4) then stage = {LOCATION_MZONE, 4} end
  else
    if Duel.CheckLocation(tp, LOCATION_SZONE, 4) then stage = {LOCATION_SZONE, 4} end
  end
  if not stage and Duel.CheckLocation(tp, LOCATION_MZONE, 4) then stage = {LOCATION_MZONE, 4} end
  if not stage then P.log("NO_ROOM", "player=" .. tp .. ";card=" .. P.label(c) .. ";raid=1") return false end
  local ok
  if stage[1] == LOCATION_MZONE then ok = Duel.MoveToField(c, tp, tp, LOCATION_MZONE, POS_FACEUP_ATTACK, true, 1 << stage[2])
  else ok = Duel.MoveToField(c, tp, tp, LOCATION_SZONE, POS_FACEUP, true, 1 << stage[2]) end
  if not ok then P.log("NO_ROOM", "player=" .. tp .. ";card=" .. P.label(c) .. ";raid=stage") return false end
  local targetName = P.label(target)
  local underTarget = P.under(target)
  forget(target)
  Duel.Overlay(c, P.group({target}))
  -- the cards under the target stay under the stack (the core moves them with it; this makes sure)
  local still = P.under(c)
  local lost = P.filter(underTarget, function(x) return not P.contains(still, x) end)
  if #lost > 0 then Duel.Overlay(c, P.group(lost)) end
  if opts.upgradeFrom then P.fd[target] = true end
  -- back into the target's place
  local loc = line == "front" and LOCATION_MZONE or LOCATION_SZONE
  if c:IsLocation(loc) then
    Duel.MoveSequence(c, seq)
  else
    local under = P.under(c)
    if line == "front" then Duel.MoveToField(c, tp, tp, LOCATION_MZONE, POS_FACEUP_ATTACK, true, 1 << seq)
    else Duel.MoveToField(c, tp, tp, LOCATION_SZONE, POS_FACEUP, true, 1 << seq) end
    local still = P.under(c)
    local missing = P.filter(under, function(x) return not P.contains(still, x) end)
    if #missing > 0 then Duel.Overlay(c, P.group(missing)) end
  end
  if P.onFront(c) and c:IsDefensePos() then Duel.ChangePosition(c, POS_FACEUP_ATTACK) end
  P.erest[c] = nil
  P.newKey(c)
  P.entered[P.id(c)] = P.turnNo
  P.enteredBy[P.id(c)] = "raid"
  P.raidHow[P.id(c)] = opts.how or "hand"
  if opts.how and opts.how ~= "hand" then P.mark("effectEnter:" .. tp) end
  P.registerDisplay(c)
  P.syncRest(tp)
  P.log("RAID", "player=" .. tp .. ";card=" .. P.label(c) .. ";on=" .. (opts.base and (P.label(opts.base) .. ";upgradeFrom=" .. targetName) or targetName)
    .. ";line=" .. line .. ";wasRested=" .. (wasRested and 1 or 0) .. ";how=" .. (opts.how or "hand"))
  P.mark("raided:" .. tp)
  P.enteredLog[#P.enteredLog+1] = {turn = P.turnNo, tp = tp, card = c}
  for _, n in ipairs(P.names(c)) do P.mark("raidedName:" .. n .. ":" .. tp) end
  -- 4: from the energy line it may move to the front line (Q&A Q48: optional)
  if P.onEnergy(c) and P.ai.raidToFront(tp, c) then P.moveLine(c, "front") end
  if P.onRaided then P.onRaided(c, tp, target, opts) end
  return true
end
-- The top card of a raided character goes to the outside area; the card under it stays in its place.
function P.removeTop(c)
  local tp = c:GetControler()
  local under = P.raidUnder(c)
  local base = under[#under]
  if not base then return false end
  local line, seq, rested = P.lineOf(c), c:GetSequence(), P.isRested(c)
  local loc = line == "front" and LOCATION_MZONE or LOCATION_SZONE
  if not Duel.CheckLocation(tp, loc, 4) then return false end
  if loc == LOCATION_MZONE then Duel.MoveToField(base, tp, tp, LOCATION_MZONE, rested and POS_FACEUP_DEFENSE or POS_FACEUP_ATTACK, true, 1 << 4)
  else Duel.MoveToField(base, tp, tp, LOCATION_SZONE, POS_FACEUP, true, 1 << 4) end
  local rest = P.filter(P.under(c), function(x) return x ~= base end)
  if #rest > 0 then Duel.Overlay(base, P.group(rest)) end
  forget(c)
  Duel.SendtoGrave(c, REASON_EFFECT)
  Duel.MoveSequence(base, seq)
  P.newKey(base)
  P.entered[P.id(base)] = P.turnNo
  if loc == LOCATION_SZONE then P.erest[base] = rested and base:GetFieldID() or nil end
  P.registerDisplay(base)
  P.syncRest(tp)
  P.log("REMOVE_TOP", "player=" .. tp .. ";card=" .. P.label(c) .. ";stays=" .. P.label(base))
  return true
end
-- Two characters on different lines change places (moves that are not the movement phase's)
function P.swapLines(a, b)
  local tp = a:GetControler()
  local la, lb = P.lineOf(a), P.lineOf(b)
  local ka, kb = P.id(a), P.id(b)
  local ra, rb = P.isRested(a), P.isRested(b)
  local sa, sb = a:GetSequence(), b:GetSequence()
  local frontCard = la == "front" and a or b
  local energyCard = la == "front" and b or a
  if not Duel.CheckLocation(tp, LOCATION_MZONE, 4) then return false end
  -- the front one steps aside to the spare zone, the energy one takes its place, then the front one goes down
  local fseq = frontCard:GetSequence()
  local eseq = energyCard:GetSequence()
  local underF, underE = P.under(frontCard), P.under(energyCard)
  Duel.MoveSequence(frontCard, 4)
  Duel.MoveToField(energyCard, tp, tp, LOCATION_MZONE, (frontCard == a and rb or ra) and POS_FACEUP_DEFENSE or POS_FACEUP_ATTACK, true, 1 << fseq)
  Duel.MoveToField(frontCard, tp, tp, LOCATION_SZONE, POS_FACEUP, true, 1 << eseq)
  for _, pair in ipairs({{frontCard, underF}, {energyCard, underE}}) do
    local still = P.under(pair[1])
    local missing = P.filter(pair[2], function(x) return not P.contains(still, x) end)
    if #missing > 0 then Duel.Overlay(pair[1], P.group(missing)) end
  end
  P.fkey[a], P.fkey[b] = ka, kb
  P.erest[frontCard] = (frontCard == a and ra or rb) and frontCard:GetFieldID() or nil
  P.erest[energyCard] = nil
  P.registerDisplay(energyCard)
  P.syncRest(tp)
  P.log("SWAP", "player=" .. tp .. ";a=" .. P.label(a) .. ";b=" .. P.label(b))
  return true
end
-- Moving between the lines keeps the card's state and identity (manual p.8; Q&A Q20: a full line first loses one
-- card per moving card to the remove area).
function P.moveLine(c, line, keep, byOwn)
  local tp = c:GetControler()
  if P.lineOf(c) == line then return false end
  if P.isFieldCard(c) then return false end
  if line == "front" and P.fxOf(c).noFront and not (byOwn and P.fxOf(c).noFrontOwnOK) then return false end
  if P.hasFlag(c, "noMove") then return false end
  if not P.makeRoom(tp, line, keep) then return false end
  local key = P.id(c)
  local rested = P.isRested(c)
  if not putOnLine(c, tp, line, rested) then return false end
  P.fkey[c] = key
  P.log("MOVE", "player=" .. tp .. ";card=" .. P.label(c) .. ";to=" .. line .. ";rested=" .. (rested and 1 or 0))
  P.mark("moved:" .. key)
  if P.onMoved then P.onMoved(c, tp, line) end
  return true
end

------------------------------------------------------------------------------
-- Using cards from the hand (manual p.9-10; Q&A Q28: check energy, pay AP, use, resolve)
------------------------------------------------------------------------------
function P.apCostOf(tp, c, how)
  local n = P.apCost(c)
  if P.apCostMod then n = n + P.apCostMod(tp, c, how) end
  return math.max(0, n)
end
function P.canUse(tp, c, how)
  if P.finished then return false end
  if not P.supported(c) then return false end
  local f = P.fxOf(c)
  if f.useIf and not P.condTrue({tp = tp, c = c}, f.useIf) then return false end
  if P.isChar(c) and P.enterBlocked(tp, c) then return false end
  if not P.meetsNeed(tp, c) then return false end
  if not P.canPayAP(tp, P.apCostOf(tp, c, how)) then return false end
  if P.isEvent(c) and P.eventUsable and not P.eventUsable(tp, c) then return false end
  return true
end
function P.playFromHand(tp, c, line)
  if not P.canUse(tp, c, "hand") then return false end
  if P.fxOf(c).raidOnly then return false end
  local from = c:IsLocation(LOCATION_REMOVED) and "remove" or "hand"
  local cost = P.apCostOf(tp, c, from)
  P.payAP(tp, cost, P.label(c))
  if cost == 0 then P.mark("freeUsed:" .. P.name(c) .. ":" .. tp) end
  if P.consumeCostMods then P.consumeCostMods(tp, c, from) end
  P.mark("used:" .. tp)
  if from == "remove" then P.mark("usedFromRemove:" .. tp) end
  P.mark("usedName:" .. P.name(c) .. ":" .. tp)
  return P.enter(tp, c, line, {how = "hand", from = from})
end
function P.raidFromHand(tp, c, target)
  if not P.canUse(tp, c, "raid") or not P.contains(P.raidTargets(tp, c), target) then return false end
  local from = c:IsLocation(LOCATION_REMOVED) and "remove" or "hand"
  local cost = P.apCostOf(tp, c, "raid")
  P.payAP(tp, cost, P.label(c))
  if cost == 0 then P.mark("freeUsed:" .. P.name(c) .. ":" .. tp) end
  if from == "remove" then P.mark("usedFromRemove:" .. tp) end
  if P.consumeCostMods then P.consumeCostMods(tp, c, "raid") end
  P.mark("used:" .. tp)
  P.mark("usedName:" .. P.name(c) .. ":" .. tp)
  return P.doRaid(tp, c, target, {how = "hand", from = from})
end
-- Events (manual p.10): pay, resolve, then to the outside area.
function P.useEvent(tp, c, forcedDest)
  if not P.canUse(tp, c, "event") then return false end
  local from = c:IsLocation(LOCATION_REMOVED) and "remove" or "hand"
  P.payAP(tp, P.apCostOf(tp, c, from), P.label(c))
  if P.consumeCostMods then P.consumeCostMods(tp, c, from) end
  P.mark("used:" .. tp)
  if from == "remove" then P.mark("usedFromRemove:" .. tp) end
  P.mark("event:" .. tp)
  P.mark("usedName:" .. P.name(c) .. ":" .. tp)
  if Duel.CheckLocation(tp, LOCATION_SZONE, 4) then Duel.MoveToField(c, tp, tp, LOCATION_SZONE, POS_FACEUP, true, 1 << 4) end
  P.log("EVENT", "player=" .. tp .. ";card=" .. P.label(c))
  if P.showUse then P.showUse(tp, c) end
  local ectx = P.runEvent and P.runEvent(tp, c, from) or {}
  P.drain()
  if c:IsLocation(LOCATION_SZONE) or c:IsLocation(LOCATION_HAND) then
    P.usingToRemove = c
    P.moveTo(c, ectx.eventDest or forcedDest or "outside")
    P.usingToRemove = nil
  end
  return true
end

------------------------------------------------------------------------------
-- Damage and trigger checks (manual p.12, Q&A Q12, Q35-Q38, Q72-Q74, Q95, Q99)
------------------------------------------------------------------------------
P.checkingCards = {}
function P.damage(from, tp, n, why)
  if P.finished or n <= 0 then return end
  local life = P.life(tp)
  local take = {}
  for i = 1, math.min(n, #life) do take[i] = life[i] end
  P.log("DAMAGE", "player=" .. tp .. ";n=" .. n .. ";cards=" .. #take .. ";life=" .. #life .. (why and (";why=" .. why) or ""))
  P.mark("damaged:" .. tp, #take)
  P.inTriggerCheck = P.inTriggerCheck + 1
  -- face up; they leave the life area at once. The core cannot turn a banished card face-up in place, so a checked
  -- card goes to the outside area (where it ends up after the check anyway) and its trigger acts on it from there.
  for _, c in ipairs(take) do
    P.checkingCards[c] = true
    Duel.SendtoGrave(c, REASON_RULE)
    P.log("TRIGGER_CHECK", "player=" .. tp .. ";card=" .. P.label(c) .. ";trigger=" .. tostring(P.triggerKind(c)))
  end
  local order = P.ai.triggerOrder(tp, take)
  for _, c in ipairs(order) do
    if P.finished then break end
    if c:IsLocation(LOCATION_GRAVE) and P.checkingCards[c] then
      if P.hasTriggerIcon(c) and P.runTrigger and P.ai.useTrigger(tp, c) then
        P.runTrigger(tp, c)
        P.drain()
      end
    end
    P.checkingCards[c] = nil
  end
  for _, c in ipairs(take) do P.checkingCards[c] = nil end
  P.inTriggerCheck = P.inTriggerCheck - 1
  P.log("LIFE", "player=" .. tp .. ";life=" .. P.lifeCount(tp))
  P.checkState()
end
-- Life lost without damage (Q&A Q95: no trigger check), the losing player picks.
function P.lifeToOutside(tp, n)
  local life = P.life(tp)
  local moved = 0
  for i = 1, math.min(n, #life) do Duel.SendtoGrave(life[i], REASON_EFFECT); moved = moved + 1 end
  P.log("LIFE_LOST", "player=" .. tp .. ";n=" .. moved .. ";life=" .. P.lifeCount(tp))
  P.checkState()
  return moved
end
function P.addLife(tp, cards)
  for _, c in ipairs(cards) do
    if c:IsLocation(LOCATION_DECK) then Duel.DisableShuffleCheck() end
    Duel.Remove(c, POS_FACEDOWN, REASON_EFFECT)
  end
  if #cards > 0 then P.log("LIFE_ADD", "player=" .. tp .. ";n=" .. #cards .. ";life=" .. P.lifeCount(tp)) end
end

------------------------------------------------------------------------------
-- Attacks and battles (manual p.11-12, p.14)
------------------------------------------------------------------------------
P.battleKey = 0
function P.attackingLine(a)
  return P.onFront(a) or (P.onEnergy(a) and P.isChar(a) and P.hasFlag(a, "attackFromEnergy"))
end
function P.attackLimitReached(tp)
  if not P.playerEffects then return false end
  for _, e in ipairs(P.playerEffects(tp, "attackLimit")) do
    if P.markCount("attack:" .. tp) >= e.data.n then return true end
  end
  return false
end
function P.canAttack(a)
  if not P.attackingLine(a) or P.isRested(a) or P.finished then return false end
  if P.attackLimitReached(a:GetControler()) then return false end
  if P.hasFlag(a, "cannotAttack") or (P.condStatic and P.condStatic(a, "flag", "cannotAttack")) then return false end
  return true
end
function P.snipeTargets(a)
  if not P.kw(a, "snipe") then return {} end
  local limits = P.flagEntries(a, "snipeLimit")
  return P.front(1 - a:GetControler(), function(t)
    if not P.isChar(t) then return false end
    for _, e in ipairs(limits) do if P.matches(t, e.data.filt, {tp = a:GetControler(), c = a}) then return false end end
    return true
  end)
end
function P.canBlock(b, a)
  if not P.onFront(b) or P.isRested(b) or not P.isChar(b) then return false end
  if P.hasFlag(b, "cannotBlock") or (P.condStatic and P.condStatic(b, "flag", "cannotBlock")) then return false end
  if P.unblockableBy and P.unblockableBy(a, b) then return false end
  return true
end
-- target: nil = the opposing player, else a character (【狙い撃ち】)
function P.attack(a, target)
  local tp = a:GetControler()
  local dp = 1 - tp
  P.battleKey = P.battleKey + 1
  local key = P.battleKey
  P.rest(a)
  P.attackState = {key = key, attacker = a, target = target, tp = tp}
  local n = P.markCount("attacked:" .. P.id(a)) + 1
  P.mark("attacked:" .. P.id(a))
  P.mark("attack:" .. tp)
  P.mark("attackedName:" .. P.name(a) .. ":" .. tp)
  P.log("ATTACK", "player=" .. tp .. ";card=" .. P.label(a) .. ";bp=" .. P.bp(a) .. ";target=" .. (target and P.label(target) or "player")
    .. ";n=" .. n)
  -- 【2回アタック】: the first attack of the turn makes it active again (Q&A Q79)
  if n == 1 and P.kw(a, "doubleAttack") then P.stand(a, "rule") end
  if P.onAttack then P.onAttack(a, target) end
  P.drain()
  if P.finished then P.attackState = nil return end
  if not P.attackingLine(a) then P.log("ATTACK_GONE", "player=" .. tp) P.attackState = nil P.attackEnded(a, tp) return end
  local blocker = nil
  if target == nil then
    local options = P.filter(P.front(dp), function(b) return P.canBlock(b, a) end)
    blocker = P.ai.blockPick(dp, a, options)
    -- "相手はこのキャラのアタックを可能ならブロックしなければならない" / "このキャラは相手のアタックを可能ならブロックしなければならない"
    if not blocker and #options > 0 and (P.hasFlag(a, "mustBeBlocked") or (n == 1 and P.hasFlag(a, "mustBeBlockedFirst"))) then blocker = P.ai.forcedBlock(dp, a, options) end
    local must = P.filter(options, function(b) return P.condStatic(b, "flag", "mustBlock") end)
    if #must > 0 and not (blocker and P.contains(must, blocker)) then blocker = P.ai.forcedBlock(dp, a, must) end
    if blocker then
      P.rest(blocker)
      local bn = P.markCount("blocked:" .. P.id(blocker)) + 1
      P.mark("blocked:" .. P.id(blocker))
      P.log("BLOCK", "player=" .. dp .. ";card=" .. P.label(blocker) .. ";bp=" .. P.bp(blocker))
      if bn == 1 and P.kw(blocker, "doubleBlock") then P.stand(blocker, "rule") end
      P.attackState.target = blocker
      P.attackState.blocked = true
      if P.onBlock then P.onBlock(blocker, a) end
      P.drain()
    else
      if P.onUnblocked then P.onUnblocked(a) end
      P.drain()
    end
  end
  if P.finished then P.attackState = nil return end
  local t = P.attackState.target
  if t ~= nil then
    if P.attackingLine(a) and P.onField(t) then P.battle(a, t) end
  elseif P.attackingLine(a) then
    local dmg = P.kwValue(a, "damage")
    if dmg <= 0 then dmg = 1 end
    dmg = dmg + P.kwValue(a, "damagePlus")
    P.mark("hitPlayer:" .. tp)
    P.damage(tp, dp, dmg, "attack:" .. P.name(a))
    if P.onDirectHit then P.onDirectHit(a) P.drain() end
  end
  P.attackState = nil
  P.attackEnded(a, tp)
end
function P.attackEnded(a, tp)
  if P.finished then return end
  if P.onAttackEnd then P.onAttackEnd(a, tp) end
  P.drain()
end
-- manual p.12: the attacker wins on equal BP (Q&A Q33); a losing attacker is not retired.
function P.battle(a, d)
  P.battleState = {key = P.attackState.key, a = a, d = d}
  local ba, bd = P.bp(a), P.bp(d)
  local tp = a:GetControler()
  P.log("BATTLE", "attacker=" .. P.label(a) .. ";bp=" .. ba .. ";defender=" .. P.label(d) .. ";bp=" .. bd)
  if ba >= bd then
    -- 1 retire the loser, 2 退場時, 3 the winner's "バトルに勝利した時" (impact first among them, Q&A Q74)
    local impactLost = P.kw(d, "impactNull")
    local dest = P.loserBounce and P.loserBounce(a, d)
    if dest then
      P.moveTo(d, dest)
      P.log("BOUNCE", "card=" .. P.name(d) .. ";why=battle;to=" .. dest)
    else
      P.retireMany({d}, {why = "battle", by = a})
    end
    P.drain()
    if P.finished then P.battleState = nil return end
    if P.onBattleWin then P.onBattleWin(a, d) end
    local base = P.kwValue(a, "impact")
    local plus = P.kwValue(a, "impactPlus")
    local impact = base > 0 and base + plus or plus
    if impact > 0 and not impactLost and P.onFront(a) then
      P.log("IMPACT", "card=" .. P.label(a) .. ";n=" .. impact)
      P.damage(tp, 1 - tp, impact, "impact:" .. P.name(a))
    elseif impact > 0 then
      P.log("IMPACT_LOST", "card=" .. P.label(a))
    end
    P.drain()
  else
    if P.onBattleLose then P.onBattleLose(a, d) end
    P.drain()
  end
  P.battleState = nil
end

------------------------------------------------------------------------------
-- Turn (manual p.7-13)
------------------------------------------------------------------------------
P.ownTurns = {[0] = 0, [1] = 0}
P.AP_TABLE = {first = {1, 2, 3}, second = {2, 2, 3}}
function P.oneTurn(tp)
  P.turnNo = P.turnNo + 1
  P.ownTurns[tp] = P.ownTurns[tp] + 1
  if P.turnNo > (UnionArenaTurnLimit or 100) then P.finish(PLAYER_NONE, "turn_limit") return end
  P.log("TURN", "n=" .. P.turnNo .. ";player=" .. tp .. ";life=" .. P.lifeCount(tp) .. "/" .. P.lifeCount(1 - tp) .. ";hand=" .. #P.hand(tp)
    .. ";deck=" .. P.deckCount(tp) .. ";front=" .. #P.front(tp) .. "/" .. #P.front(1 - tp) .. ";energy=" .. #P.energy(tp) .. "/" .. #P.energy(1 - tp))
  -- Start phase (manual p.8): 1 "次の自分のターン開始時まで" ends, 2 everything of tp active, 3 AP cards, 4 draw
  -- (not the first player's first turn), 5 extra draw for 1 AP once (Q&A Q15-Q17)
  P.startCleared[tp] = P.turnNo
  P.prune()
  if P.onTurnStart then P.onTurnStart(tp) end
  P.drain()
  if P.finished then return end
  for _, c in ipairs(P.field(tp)) do if P.isRested(c) then P.stand(c, "rule") end end
  local row = tp == P.firstPlayer and P.AP_TABLE.first or P.AP_TABLE.second
  P.setApCount(tp, row[math.min(P.ownTurns[tp], 3)])
  for _, c in ipairs(P.apArea(tp)) do if P.isRested(c) then P.stand(c, "rule") end end
  P.syncRest(tp)
  if not (tp == P.firstPlayer and P.ownTurns[tp] == 1) then
    if P.deckCount(tp) == 0 then P.finish(1 - tp, "deck_out") return end
    P.draw(tp, 1)
  end
  if P.deckCount(tp) > 0 and #P.apActive(tp) > 0 and P.ai.extraDraw(tp) then
    P.payAP(tp, 1, "extra draw")
    P.log("EXTRA_DRAW", "player=" .. tp)
    P.draw(tp, 1)
  end
  -- Movement phase (manual p.8)
  P.phase = "move"
  P.ai.movement(tp)
  P.drain()
  if P.finished then return end
  -- Main phase
  P.phase = "main"
  P.ai.main(tp)
  if P.finished then return end
  if P.onMainEnd then P.onMainEnd(tp) end
  P.drain()
  if P.finished then return end
  -- Attack phase (manual p.11)
  P.phase = "attack"
  if P.onAttackPhaseStart then P.onAttackPhaseStart(tp) end
  P.drain()
  if P.finished then return end
  P.ai.attacks(tp)
  if P.finished then return end
  if P.onAttackPhaseEnd then P.onAttackPhaseEnd(tp) end
  P.drain()
  P.attackPhaseEnded[tp] = P.turnNo
  if P.finished then return end
  -- End phase (manual p.13)
  P.phase = "end"
  if P.onEndPhase then P.onEndPhase(tp) end
  P.drain()
  if P.finished then return end
  for _, c in ipairs(P.field(tp)) do
    -- "このキャラはこのターンのエンドフェイズにアクティブにならない"
    if P.isRested(c) and not P.hasFlag(c, "noStandEnd") then P.stand(c, "rule") end
  end
  local hand = P.hand(tp)
  if #hand > P.HAND_LIMIT then
    local drop = P.ai.handLimit(tp, hand, #hand - P.HAND_LIMIT)
    for _, c in ipairs(drop) do P.moveTo(c, P.fxOf(c).overflowOutside and "outside" or "remove", REASON_RULE) end
    P.log("HAND_LIMIT", "player=" .. tp .. ";removed=" .. #drop)
  end
  P.closedTurn = P.turnNo
  P.closedTurnOf = P.closedTurnOf or {}
  P.closedTurnOf[tp] = P.turnNo
  P.prune()
  P.phase = nil
end
function P.turn()
  if P.finished then return end
  if P.idleFirstCoreTurn and Duel.GetTurnCount() == 1 then
    P.log("IDLE_TURN", "player=" .. Duel.GetTurnPlayer() .. ";why=seat 1 goes first")
    return
  end
  P.oneTurn(Duel.GetTurnPlayer())
end

------------------------------------------------------------------------------
-- Setup (manual p.5) and installation
------------------------------------------------------------------------------
-- Deck rules (manual p.5): exactly 50 cards of one title, at most 4 of a card number, at most 4 cards with each
-- special trigger (SPECIAL / COLOR / FINAL); 3 AP cards.
function P.deckError(tp)
  local main = list(Duel.GetFieldGroup(tp, LOCATION_DECK, 0))
  if #main ~= 50 then return "deck " .. #main .. " cards" end
  local title, counts, special = nil, {}, {}
  for _, c in ipairs(main) do
    local d = P.data(c)
    if not d then return "unknown card" end
    title = title or d.title
    if d.title ~= title then return "two titles: " .. title .. "/" .. d.title end
    counts[d.no] = (counts[d.no] or 0) + 1
    if counts[d.no] > (P.fxOf(c).maxCopies or 4) then return "more than 4: " .. d.no end
    local k = P.triggerKind(c)
    if k == "special" or k == "color" or k == "final" then
      special[k] = (special[k] or 0) + 1
      if special[k] > 4 then return "more than 4 " .. k .. " triggers" end
    end
    if not P.supported(c) then return "unsupported card: " .. d.no .. " " .. d.name end
  end
  if #list(Duel.GetFieldGroup(tp, LOCATION_EXTRA, 0)) ~= 3 then return "AP cards" end
  return nil
end
function P.setup()
  P.logfile = io and io.open(UnionArenaAIDemoLogFile or "unionarena-ai-match.log", "w") or nil
  for tp = 0, 1 do
    local err = P.deckError(tp)
    if err then
      P.log("DECK_REJECTED", "player=" .. tp .. ";reason=" .. err)
      Debug.ShowHint("Player " .. (tp + 1) .. " deck error:\n" .. err)
      P.finished = true
      P.log("WIN", "player=2;reason=deck_rejected;turn=0")
      if P.logfile then P.logfile:close(); P.logfile = nil end
      Duel.Win(PLAYER_NONE, 0xfd)
      return
    end
  end
  P.firstPlayer = P.firstChoice or 0
  P.log("START", "rules=unionarena-manual-2023-08-18;hand=7;life=7")
  if P.deckNames then P.log("DECKS", "player0=" .. P.deckNames[0] .. ";player1=" .. P.deckNames[1] .. ";first=" .. P.firstPlayer) end
  for tp = 0, 1 do Duel.ShuffleDeck(tp); P.syncRest(tp) end
  for tp = 0, 1 do Duel.Draw(tp, 7, REASON_RULE) end
  -- manual p.5 step 4: one mulligan, the first player decides first
  for _, tp in ipairs({P.firstPlayer, 1 - P.firstPlayer}) do
    if P.ai.mulligan(tp) then
      P.log("MULLIGAN", "player=" .. tp)
      local old = P.hand(tp)
      Duel.Draw(tp, 7, REASON_RULE)
      Duel.SendtoDeck(P.group(old), nil, SEQ_DECKSHUFFLE, REASON_RULE)
      Duel.ShuffleDeck(tp)
    end
  end
  -- step 5: seven life cards from the top of the deck, face-down
  for tp = 0, 1 do
    Duel.DisableShuffleCheck()
    Duel.Remove(P.group(P.deckTop(tp, P.LIFE)), POS_FACEDOWN, REASON_RULE)
  end
  P.started = true
  P.log("READY", "deck0=" .. P.deckCount(0) .. ";deck1=" .. P.deckCount(1) .. ";life0=" .. P.lifeCount(0) .. ";life1=" .. P.lifeCount(1))
end
-- Puzzles call this between Debug.ReloadFieldBegin and ReloadFieldEnd. decks = { {main={codes}, ap=code}, ... }.
-- Q&A Q10: the winner of rock-paper-scissors chooses; here the first player is random. EDOPro always starts with
-- seat 0, so the first player's deck goes to seat 0.
function P.loadDecks(decks, names)
  local chooser = Duel.GetRandomNumber(0, 1)
  local a, b = (names and names[1]) or "A", (names and names[2]) or "B"
  P.deckNames = chooser == 0 and {[0] = a, [1] = b} or {[0] = b, [1] = a}
  local seats = chooser == 0 and {decks[1], decks[2]} or {decks[2], decks[1]}
  for tp = 0, 1 do
    local d = seats[tp + 1]
    for _, id in ipairs(d.main) do Debug.AddCard(id, tp, tp, LOCATION_DECK, 0, POS_FACEDOWN_DEFENSE) end
    for i = 1, 3 do Debug.AddCard(d.ap, tp, tp, LOCATION_EXTRA, 0, POS_FACEDOWN_DEFENSE) end
  end
end
function P.deckByKey(key)
  for _, d in ipairs(UnionArenaCatalog.decks) do if d.key == key then return d end end
  return nil
end
function P.enableCore()
  assert(Duel.EnablePokemonPrizes, "The Pokemon ocgcore is required for the AP cards in the Extra Deck")
  Duel.EnablePokemonPrizes()
end
function P.install()
  P.enableCore()
  for _, code in ipairs({EFFECT_SKIP_SP, EFFECT_SKIP_M1, EFFECT_SKIP_BP, EFFECT_CANNOT_BP, EFFECT_SKIP_M2, EFFECT_HAND_LIMIT,
      EFFECT_DRAW_COUNT, EFFECT_CANNOT_LOSE_LP, EFFECT_CANNOT_LOSE_DECK}) do
    local e = Effect.GlobalEffect()
    e:SetType(EFFECT_TYPE_FIELD)
    e:SetProperty(EFFECT_FLAG_PLAYER_TARGET + EFFECT_FLAG_CANNOT_DISABLE)
    e:SetCode(code)
    e:SetTargetRange(1, 1)
    e:SetValue(code == EFFECT_HAND_LIMIT and 999 or (code == EFFECT_DRAW_COUNT and 0 or 1))
    Duel.RegisterEffect(e, 0)
  end
  local start = Effect.GlobalEffect()
  start:SetType(EFFECT_TYPE_FIELD + EFFECT_TYPE_CONTINUOUS)
  start:SetCode(EVENT_STARTUP)
  start:SetOperation(function() if P.customSetup then P.customSetup() else P.setup() end end)
  Duel.RegisterEffect(start, 0)
  local turn = Effect.GlobalEffect()
  turn:SetType(EFFECT_TYPE_FIELD + EFFECT_TYPE_CONTINUOUS)
  turn:SetCode(EVENT_PHASE_START + PHASE_DRAW)
  turn:SetOperation(function() if P.started then P.turn() end end)
  Duel.RegisterEffect(turn, 0)
end
