--- Andys Preview - HiddenSimulate.lua
--
-- Face-down cards and jokers hide information from the player, so the simulation must not use it.
--
-- A face-down card in hand could be any card the player cannot see: one still in the deck, or any
-- of the face-down cards. (The game's deck view counts face-down cards as still in the deck, so this
-- is exactly what the player can know.) Face-down jokers (Amber Acorn) are known, but their order is not.
--
-- Every way the hidden information could turn out is a "scenario". The preview shows the lowest and
-- highest result over all scenarios. When there are too many to simulate them all, a search looks
-- for the lowest and highest results instead. Either way the result only depends on what the player
-- can see, never on what the face-down cards actually are.

-- The most scenarios simulated per calculation, which keeps the calculation fast:
FN.SIM.SCENARIO_BUDGET = 800

function FN.SIM.simulate_all_scenarios()
   FN.SIM.hand_info_cache = {}
   local ok, results = pcall(FN.SIM.simulate_all_scenarios_unprotected)
   FN.SIM.hand_info_cache = nil
   if not ok then error(results, 0) end
   return results
end

function FN.SIM.simulate_all_scenarios_unprotected()
   local hidden = FN.SIM.find_hidden()
   if not hidden then return FN.SIM.simulate_scenario(nil) end

   local range = FN.SIM.new_range()
   -- Simulates one scenario, adds it to the range, and returns its results:
   local function visit(choice)
      return FN.SIM.add_to_range(range, FN.SIM.simulate_scenario(FN.SIM.make_scenario(hidden, choice)))
   end

   local budget = FN.SIM.SCENARIO_BUDGET
   local num_scenarios = FN.SIM.count_card_choices(hidden, budget + 1) * FN.SIM.count_joker_orders(hidden, budget + 1)
   if num_scenarios <= budget then
      FN.SIM.for_each_choice(hidden, visit)
   else
      FN.SIM.search_choices(hidden, budget, visit)
   end

   return FN.SIM.range_results(range)
end

--
-- WHAT IS HIDDEN:
--

-- Returns nil if nothing is hidden. Otherwise:
--   card_slots:  the face-down cards in hand
--   pool:        the cards those could be, as {card = <a card like this>, count = <how many there are>}
--   joker_slots: positions of the face-down jokers in G.jokers.cards
function FN.SIM.find_hidden()
   local card_slots = {}
   for _, card in ipairs(G.hand.cards) do
      if card.facing == "back" then table.insert(card_slots, card) end
   end

   local joker_slots = {}
   for i, joker in ipairs(G.jokers.cards) do
      if joker.facing == "back" then table.insert(joker_slots, i) end
   end
   -- A single face-down joker can only be the one joker the player cannot see:
   if #joker_slots < 2 then joker_slots = {} end

   if #card_slots == 0 and #joker_slots == 0 then return nil end

   return {
      card_slots = card_slots,
      pool = (#card_slots > 0) and FN.SIM.get_card_pool(card_slots) or {},
      joker_slots = joker_slots
   }
end

function FN.SIM.get_card_pool(card_slots)
   local pool, by_key = {}, {}
   local function add(card)
      local key = FN.SIM.card_key(card)
      local entry = by_key[key]
      if not entry then
         entry = {card = card, count = 0, key = key}
         by_key[key] = entry
         table.insert(pool, entry)
      end
      entry.count = entry.count + 1
   end

   -- The Mark only flips face cards, so the player knows a face-down card is not in the deck's other cards:
   local blind = G.GAME.blind
   local only_faces = blind and blind.name == "The Mark" and not blind.disabled and not G.GAME.modifiers.flipped_cards
   for _, card in ipairs(G.deck.cards) do
      if not only_faces or card:is_face(true) then add(card) end
   end
   for _, card in ipairs(card_slots) do add(card) end

   -- A fixed order, so that nothing depends on the order of the deck (which is hidden as well):
   table.sort(pool, function(a, b) return a.key < b.key end)
   return pool
end

-- Cards with the same key score the same, so they only need to be simulated once.
function FN.SIM.card_key(card)
   local ability = card.ability or {}
   local edition = card.edition and (card.edition.key or card.edition.type) or ""
   local parts = {
      tostring(card.base.id), tostring(card.base.suit), tostring(card.base.nominal),
      tostring(card.config.center.key), tostring(edition), tostring(card.seal), tostring(card.debuff),
      tostring(ability.bonus), tostring(ability.mult), tostring(ability.x_mult),
      tostring(ability.h_mult), tostring(ability.h_x_mult), tostring(ability.p_dollars)
   }
   -- Permanent bonuses (eg. from Hiker):
   local perma = {}
   for k, v in pairs(ability) do
      if type(k) == "string" and k:sub(1, 6) == "perma_" then table.insert(perma, k .. "=" .. tostring(v)) end
   end
   table.sort(perma)
   for _, p in ipairs(perma) do table.insert(parts, p) end
   return table.concat(parts, "|")
end

--
-- SCENARIOS:
--
-- A "choice" picks one scenario:
--   choice.cards[s]:  index into the pool for the s-th face-down card
--   choice.jokers[n]: which face-down joker sits in the n-th face-down joker position

function FN.SIM.make_scenario(hidden, choice)
   local cards = {}
   for s, card in ipairs(hidden.card_slots) do
      cards[card] = hidden.pool[choice.cards[s]].card
   end

   local jokers = {}
   for i, joker in ipairs(G.jokers.cards) do jokers[i] = joker end
   for n, slot in ipairs(hidden.joker_slots) do
      jokers[slot] = G.jokers.cards[hidden.joker_slots[choice.jokers[n]]]
   end

   return {cards = cards, jokers = jokers}
end

function FN.SIM.copy_choice(choice)
   local cards, jokers = {}, {}
   for i, v in ipairs(choice.cards) do cards[i] = v end
   for i, v in ipairs(choice.jokers) do jokers[i] = v end
   return {cards = cards, jokers = jokers}
end

function FN.SIM.choice_key(choice)
   return table.concat(choice.cards, ",") .. "/" .. table.concat(choice.jokers, ",")
end

-- How many cards of each pool entry a choice uses:
function FN.SIM.pool_usage(choice)
   local used = {}
   for _, p in ipairs(choice.cards) do used[p] = (used[p] or 0) + 1 end
   return used
end

-- Number of ways to pick the face-down cards from the pool, but stops counting at `cap`:
function FN.SIM.count_card_choices(hidden, cap)
   local num_slots, pool = #hidden.card_slots, hidden.pool
   local used, count = {}, 0
   local function recurse(s)
      if count >= cap then return end
      if s > num_slots then count = count + 1; return end
      for p = 1, #pool do
         if (used[p] or 0) < pool[p].count then
            used[p] = (used[p] or 0) + 1
            recurse(s + 1)
            used[p] = used[p] - 1
         end
      end
   end
   recurse(1)
   return count
end

function FN.SIM.count_joker_orders(hidden, cap)
   local count = 1
   for n = 2, #hidden.joker_slots do
      count = count * n
      if count >= cap then return cap end
   end
   return count
end

-- Calls `visit(choice)` for every scenario:
function FN.SIM.for_each_choice(hidden, visit)
   local num_slots, pool, num_jokers = #hidden.card_slots, hidden.pool, #hidden.joker_slots
   local choice = {cards = {}, jokers = {}}
   local used, joker_used = {}, {}

   local function recurse_jokers(n)
      if n > num_jokers then visit(choice); return end
      for j = 1, num_jokers do
         if not joker_used[j] then
            joker_used[j] = true
            choice.jokers[n] = j
            recurse_jokers(n + 1)
            joker_used[j] = false
         end
      end
   end

   local function recurse_cards(s)
      if s > num_slots then recurse_jokers(1); return end
      for p = 1, #pool do
         if (used[p] or 0) < pool[p].count then
            used[p] = (used[p] or 0) + 1
            choice.cards[s] = p
            recurse_cards(s + 1)
            used[p] = used[p] - 1
         end
      end
   end

   recurse_cards(1)
end

--
-- SEARCH (when there are too many scenarios to simulate them all):
--

-- A small random number generator with a fixed seed, so the same situation always gives the same preview.
-- (The game's own random numbers must not be used: they decide what actually happens next.)
function FN.SIM.new_rng()
   local state = 20240613
   return function(n) -- Random integer from 1 to n
      state = (state * 16807) % 2147483647
      return (state % n) + 1
   end
end

function FN.SIM.random_choice(hidden, rng)
   -- Draw face-down cards from the pool as if dealing from a shuffled deck:
   local deck = {}
   for p, entry in ipairs(hidden.pool) do
      for _ = 1, entry.count do table.insert(deck, p) end
   end
   local cards = {}
   for s = 1, #hidden.card_slots do
      local i = s - 1 + rng(#deck - s + 1)
      deck[s], deck[i] = deck[i], deck[s]
      cards[s] = deck[s]
   end

   local jokers = {}
   for n = 1, #hidden.joker_slots do jokers[n] = n end
   for n = #jokers, 2, -1 do
      local i = rng(n)
      jokers[n], jokers[i] = jokers[i], jokers[n]
   end

   return {cards = cards, jokers = jokers}
end

-- Looks for the lowest and highest score and money, simulating at most `budget` scenarios.
-- First tries random scenarios, then improves the best one for each goal one card or one joker swap at a time.
function FN.SIM.search_choices(hidden, budget, visit)
   local results, num_evaluated = {}, 0
   local function evaluate(choice)
      local key = FN.SIM.choice_key(choice)
      if results[key] then return results[key] end
      if num_evaluated >= budget then return nil end
      num_evaluated = num_evaluated + 1

      local result = visit(choice)
      results[key] = result
      return result
   end

   local goals = {
      function(r) return r.score.max end,
      function(r) return -r.score.min end,
      function(r) return r.dollars.max end,
      function(r) return -r.dollars.min end,
   }

   -- Random scenarios:
   local rng = FN.SIM.new_rng()
   local best = {}
   for _ = 1, math.floor(budget / 5) do
      local choice = FN.SIM.random_choice(hidden, rng)
      local r = evaluate(choice)
      if not r then break end
      for g, goal in ipairs(goals) do
         if not best[g] or goal(r) > best[g].value then best[g] = {choice = choice, value = goal(r)} end
      end
   end

   -- Improve on the best one for each goal, sharing what is left of the budget:
   for g, goal in ipairs(goals) do
      if best[g] then
         local limit = num_evaluated + math.floor((budget - num_evaluated) / (#goals - g + 1))
         FN.SIM.climb(hidden, best[g].choice, best[g].value, goal, evaluate, function() return num_evaluated < limit end)
      end
   end
end

function FN.SIM.climb(hidden, choice, value, goal, evaluate, can_continue)
   local pool = hidden.pool
   local improved = true
   while improved and can_continue() do
      improved = false

      -- Try every other card for each face-down card:
      for s = 1, #choice.cards do
         local used = FN.SIM.pool_usage(choice)
         for p = 1, #pool do
            if not can_continue() then return end
            if p ~= choice.cards[s] and (used[p] or 0) < pool[p].count then
               local candidate = FN.SIM.copy_choice(choice)
               candidate.cards[s] = p
               local r = evaluate(candidate)
               if r and goal(r) > value then
                  choice, value, improved = candidate, goal(r), true
                  used = FN.SIM.pool_usage(choice)
               end
            end
         end
      end

      -- Try swapping each pair of face-down jokers:
      for a = 1, #choice.jokers - 1 do
         for b = a + 1, #choice.jokers do
            if not can_continue() then return end
            local candidate = FN.SIM.copy_choice(choice)
            candidate.jokers[a], candidate.jokers[b] = candidate.jokers[b], candidate.jokers[a]
            local r = evaluate(candidate)
            if r and goal(r) > value then
               choice, value, improved = candidate, goal(r), true
            end
         end
      end
   end
end

--
-- COMBINING RESULTS:
--

function FN.SIM.new_range()
   return {
      score   = {min = math.huge, max = -math.huge},
      dollars = {min = math.huge, max = -math.huge}
   }
end

function FN.SIM.add_to_range(range, results)
   for _, field in ipairs({"score", "dollars"}) do
      range[field].min = math.min(range[field].min, results[field].min)
      range[field].max = math.max(range[field].max, results[field].max)
   end
   return results
end

function FN.SIM.range_results(range)
   -- NOTE: There is no exact result when something is hidden, so `exact` is just the lowest result
   return {
      score   = {min = range.score.min,   exact = range.score.min,   max = range.score.max},
      dollars = {min = range.dollars.min, exact = range.dollars.min, max = range.dollars.max}
   }
end
