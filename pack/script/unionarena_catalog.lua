-- Original cards for the sample. Full card packs can supply their own catalog.
local cards = {}
for seat, color in ipairs({"赤", "青"}) do
  for n = 1, 13 do
    local id = 98000000 + seat * 100 + n
    local power = 1500 + n * 200
    local series = seat == 1 and "Cinder" or "Tide"
    cards[id] = { no = series .. "-" .. n, name = series .. " Scout " .. n, title = series,
      kind = "char", color = color, need = n <= 5 and 0 or 2, ap = 1, bp = power,
      gen = {color = color, n = 1}, traits = {}, rarity = "", effect = "", trigger = "" }
  end
  cards[98000000 + seat * 100 + 99] = {kind = "ap", name = "Action Point",
    title = seat == 1 and "Cinder" or "Tide", traits = {}, effect = "", trigger = ""}
end
UnionArenaCatalog = { cards = cards, decks = {} }
