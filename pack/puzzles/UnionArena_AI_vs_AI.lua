Debug.ReloadFieldBegin(DUEL_ATTACK_FIRST_TURN + DUEL_1ST_TURN_DRAW + DUEL_NO_HAND_LIMIT + DUEL_EMZONE, 4)
Debug.SetAIName("Tide or Cinder")
Debug.SetPlayerInfo(0, 8000, 0, 0)
Debug.SetPlayerInfo(1, 8000, 0, 0)
Duel.LoadScript("unionarena.lua")
local P = UnionArenaAI
P.enableCore()
local decks = {}
for seat = 1, 2 do
  local main = {}
  for n = 1, 13 do
    for copy = 1, n == 13 and 2 or 4 do
      main[#main + 1] = 98000000 + seat * 100 + n
    end
  end
  decks[seat] = {main = main, ap = 98000000 + seat * 100 + 99}
end
P.loadDecks(decks, {"Cinder", "Tide"})
Debug.ReloadFieldEnd()
P.install()
