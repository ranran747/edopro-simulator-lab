-- Original sample cards use simple energy and combat rules with no triggered effects.
UnionArenaEffects = {}
for _, base in ipairs({98000100, 98000200}) do
  for n = 1, 13 do UnionArenaEffects[base + n] = {ok = true} end
end
