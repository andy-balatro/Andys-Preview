--- Original: Divvy's Preview for Balatro - Interface.lua
--
-- The user interface components that display simulation results.

-- Append node for preview text to the HUD:
local orig_hud = create_UIBox_HUD
function create_UIBox_HUD()
   local contents = orig_hud()
   -- If anything goes wrong, the game simply gets its regular HUD without the preview:
   FN.safe_call("HUD setup", FN.PRE.add_preview_to_hud, contents)
   return contents
end

function FN.PRE.add_preview_to_hud(contents)
   local hand_text_area = FN.PRE.find_hand_text_area(contents)
   if not hand_text_area then return end
   local rows = hand_text_area.nodes and hand_text_area.nodes[1] and hand_text_area.nodes[1].nodes
   if type(rows) ~= "table" then return end

   -- Build everything first, so that the HUD is only touched once nothing can fail anymore:
   local preview_container = FN.PRE.get_preview_container()
   table.insert(rows, preview_container)

   -- The HUD already reaches the bottom edge of the screen, so the money row must not make it taller.
   -- Make room by trimming the (mostly empty) row that shows the name of the selected poker hand.
   -- The HUD keeps using this config table, so the money toggle can change the trim later on:
   local hand_name_row = rows[1]
   FN.PRE.hand_name_row_config = nil
   if type(hand_name_row) == "table" and type(hand_name_row.config) == "table" and type(hand_name_row.config.minh) == "number" then
      FN.PRE.hand_name_row_config = hand_name_row.config
      FN.PRE.hand_name_row_minh = hand_name_row.config.minh
      FN.PRE.trim_hand_name_row()
   end
end

function FN.PRE.trim_hand_name_row()
   local config = FN.PRE.hand_name_row_config
   if not config then return end
   if G.SETTINGS.FN.preview_dollars then
      config.minh = math.max(0.6, FN.PRE.hand_name_row_minh - FN.PRE.dollars_row_height)
   else
      config.minh = FN.PRE.hand_name_row_minh
   end
end

function G.FUNCS.calculate_score_button()
   FN.safe_call("calculate score button", FN.PRE.start_new_coroutine)
end

-- Keybind: press "s" to calculate the score (same as clicking the button).
FN.PRE.calculate_key = "s"
local orig_key_press = Controller.key_press_update
function Controller:key_press_update(key, dt)
   orig_key_press(self, key, dt)
   FN.safe_call("calculate score keybind", FN.PRE.on_key_press, self, key)
end

function FN.PRE.on_key_press(self, key)
   if key ~= FN.PRE.calculate_key then return end
   if self.locks.frame or self.text_input_hook then return end
   if G.SETTINGS.paused or G.OVERLAY_MENU then return end
   if not FN.PRE.enabled() then return end
   if not (G.STATE == G.STATES.SELECTING_HAND or
           G.STATE == G.STATES.DRAW_TO_HAND or
           G.STATE == G.STATES.PLAY_TAROT)
   then return end
   G.FUNCS.calculate_score_button()
end

function FN.PRE.get_preview_container()
   -- The money row sits between score and button. Its wrapper has no padding and the money text is
   -- small, so the HUD only grows by the height of that one line of text.
   local dollars_wrap = {n=G.UIT.R, config={id = "fn_pre_dollars_wrap", align = "cm"}, nodes={}}
   if G.SETTINGS.FN.preview_dollars then table.insert(dollars_wrap.nodes, FN.PRE.get_dollars_node()) end

   -- Like the money row, the button's wrapper has no padding, so a hidden button takes no space.
   local button_wrap = {n=G.UIT.R, config={id = "fn_calculate_score_button_wrap", align = "cm"}, nodes={}}
   if G.SETTINGS.FN.show_calculate_button then table.insert(button_wrap.nodes, FN.PRE.get_calculate_score_button()) end

   return {n=G.UIT.R, config={id = "fn_preview_container", align = "cm"}, nodes={
      {n=G.UIT.C, config={align = "cm"}, nodes={
         {n=G.UIT.R, config={id = "fn_pre_score_wrap", align = "cm", padding = G.SETTINGS.FN.preview_dollars and 0.05 or 0.1}, nodes={
            G.SETTINGS.FN.preview_score and FN.PRE.get_score_node() or nil
         }},
         dollars_wrap,
         button_wrap,
      }}
   }}
end

function FN.PRE.get_calculate_score_button()
   return {n=G.UIT.R, config={align = "cm", padding = 0.1}, nodes={
      {n=G.UIT.C, config={id = "calculate_score_button", button = "calculate_score_button", align = "cm", minh = 0.42, padding = 0.05, r = 0.02, colour = G.C.RED, hover = true, shadow = true}, nodes={
         {n=G.UIT.R, config={align = "cm"}, nodes={
            {n=G.UIT.T, config={text = "  Calculate Score  ", colour = G.C.UI.TEXT_LIGHT, shadow = true, scale = 0.36}}
         }}
      }}
   }}
end


function FN.PRE.get_score_node()
   local text_scale = nil
   if true then text_scale = 0.5
   else text_scale = 0.75 end

   return {n = G.UIT.C, config = {id = "fn_pre_score", align = "cm"}, nodes={
              {n=G.UIT.O, config={id = "fn_pre_l", func = "fn_pre_score_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.score, ref_value = "l"}}, colours = {G.C.UI.TEXT_LIGHT}, shadow = true, float = true, scale = text_scale})}},
              {n=G.UIT.O, config={id = "fn_pre_r", func = "fn_pre_score_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.score, ref_value = "r"}}, colours = {G.C.UI.TEXT_LIGHT}, shadow = true, float = true, scale = text_scale})}},
   }}
end

function FN.PRE.find_hand_text_area(node)
   if node.config and node.config.id == "hand_text_area" then
      return node
   end
   if node.nodes then
      for _, child in ipairs(node.nodes) do
         local found = FN.PRE.find_hand_text_area(child, id)
         if found then return found end
      end
   end
   return nil
end

-- Net height that the money row adds to the HUD (its text, minus padding saved around the score):
FN.PRE.dollars_row_height = 0.25

function FN.PRE.get_dollars_node()
   local text_scale = 0.4
   local colour = FN.PRE.get_dollar_colour(0)

   return {n = G.UIT.C, config = {id = "fn_pre_dollars", align = "cm"}, nodes={
              {n=G.UIT.O, config={id = "fn_pre_dollars_l", func = "fn_pre_dollars_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.dollars, ref_value = "l"}}, colours = {colour}, shadow = true, float = true, scale = text_scale})}},
              {n=G.UIT.O, config={id = "fn_pre_dollars_r", func = "fn_pre_dollars_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.dollars, ref_value = "r"}}, colours = {colour}, shadow = true, float = true, scale = text_scale})}},
   }}
end

--
-- SETTINGS:
--

-- An "Andys Preview" button in the options menu, next to Settings and Collection, opens the settings page:
local orig_options = create_UIBox_options
function create_UIBox_options()
   local contents = orig_options()
   FN.safe_call("options menu button", FN.PRE.add_options_button, contents)
   return contents
end

function FN.PRE.add_options_button(contents)
   local button = UIBox_button({label = {"Andys Preview"}, button = "fn_preview_options", minw = 5, colour = G.C.ORANGE})
   local buttons = contents.nodes[1].nodes[1].nodes[1].nodes
   -- Some of the menu's buttons only exist in a run, which leaves gaps in the list, so add after the last one:
   table.insert(buttons, table.maxn(buttons) + 1, button)
end

function G.FUNCS.fn_preview_options(e)
   G.SETTINGS.paused = true
   G.FUNCS.overlay_menu{
      definition = create_UIBox_generic_options({back_func = "options", contents = {FN.get_preview_settings_page()}}),
   }
end

-- Puts `node` (or nothing) into the HUD element `wrap_id`, while a run is going.
-- Removing an element doesn't unlink it from its parent, so the wrapper's children are cleared directly.
function FN.PRE.refill_hud_wrap(wrap_id, node)
   if not G.HUD then return end
   local wrap = G.HUD:get_UIE_by_ID(wrap_id)
   if not wrap then return end

   remove_all(wrap.children)
   wrap.children = {}
   if node then G.HUD:add_child(node, wrap) end
   G.HUD:recalculate()
end

function FN.get_preview_settings_page()
   -- Toggling a preview only shows or hides its text. The last result already holds both score and money.
   local function preview_score_toggle_callback(show)
      FN.safe_call("score preview toggle", FN.PRE.refill_hud_wrap, "fn_pre_score_wrap", show and FN.PRE.get_score_node() or nil)
   end

   local function preview_dollars_toggle_callback(show)
      FN.safe_call("money preview toggle", function()
         -- Same room-making as when the HUD is built, see FN.PRE.add_preview_to_hud(..):
         FN.PRE.trim_hand_name_row()
         local score_wrap = G.HUD and G.HUD:get_UIE_by_ID("fn_pre_score_wrap")
         if score_wrap then score_wrap.config.padding = show and 0.05 or 0.1 end
         FN.PRE.refill_hud_wrap("fn_pre_dollars_wrap", show and FN.PRE.get_dollars_node() or nil)
      end)
   end

   -- The last result may not match the new setting anymore, so hide it until the next calculation:
   local function face_down_toggle_callback(_)
      FN.PRE.invalidate()
   end

   -- The button's row makes the HUD taller, pushing its top into the space above the blind box,
   -- where other mods (like andy-bot-balatro's streak bar) may draw. Hiding it leaves the "s" key.
   local function calculate_button_toggle_callback(show)
      FN.safe_call("calculate score button toggle", FN.PRE.refill_hud_wrap, "fn_calculate_score_button_wrap", show and FN.PRE.get_calculate_score_button() or nil)
   end

   return
      {n=G.UIT.C, config={align = "cm", padding = 0.05}, nodes={
          create_toggle({label = "Enable Score Preview",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "preview_score",
                         callback = preview_score_toggle_callback}),
          create_toggle({label = "Enable Money Preview",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "preview_dollars",
                         callback = preview_dollars_toggle_callback}),
          create_toggle({label = "Hide Preview if Any Card is Face-Down",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "hide_face_down",
                         callback = face_down_toggle_callback}),
          create_toggle({label = "Show Calculate Score Button",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "show_calculate_button",
                         callback = calculate_button_toggle_callback}),
      }}
end
