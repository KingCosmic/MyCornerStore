-- Customer Behavior System with POI Array
-- This system handles customer pathfinding, preferences, and interactions

local staff_manager = require 'shop_system.staff_manager'
local poi_manager = require 'shop_system.poi_manager'
local item_utils = require 'utils.items'
local shop = require 'shop_system.shop'

local POI_TYPES = require 'shop_system.poi_types'

local pathfinding = require 'shop_system.pathfinding'

local iso_utils = require 'isometric.utils'

local CUSTOMER_PERSONALITIES = require 'shop_system.personalities'
local CUSTOMER_STATES = require 'shop_system.customer_states'

local offset = vmath.vector3(0, 0, 0)

-- Customer class
local Customer = {}
Customer.__index = Customer

function Customer:new(personality_type, go_id, exit_pos)
	local customer = {
		id = go_id,
		personality = CUSTOMER_PERSONALITIES[personality_type],
		personality_name = personality_type,
		state = CUSTOMER_STATES.ENTERING,

		-- Position and movement
		path = {},
		-- movement_speed = CUSTOMER_PERSONALITIES[personality_type].movement_speed,
		movement_speed = .25,
		exit_pos = exit_pos,

		-- Behavior tracking
		visited_pois = {},
		current_poi = nil,
		items_of_interest = {},
		cart = {},
		patience = CUSTOMER_PERSONALITIES[personality_type].patience,
		current_patience = CUSTOMER_PERSONALITIES[personality_type].patience,

		-- Timing
		interaction_timer = 0,
		total_time_in_shop = 0,
		state_timer = 0
	}

	setmetatable(customer, Customer)
	return customer
end

function Customer:debug_state()
	return {
		state = self.state,
		is_traveling = self.is_traveling,
		has_path = self.path and #self.path > 0,
		current_step = self.step,
		animation_active = self.animation_callback_id ~= nil,
		completion_state = self.completion_state
	}
end

function Customer:update(dt)
	label.set_text(msg.url(nil, self.id, 'debug_label'), self.state)
	label.set_text(msg.url(nil, self.id, 'bg_label'), self.state)

	if self.state == CUSTOMER_STATES.QUEUED_FOR_DELETION then
		return
	end

	self.total_time_in_shop = self.total_time_in_shop + dt
	self.state_timer = self.state_timer + dt

	-- Detect stuck customers
	-- if self.state == CUSTOMER_STATES.TRAVELING and self.state_timer > 10.0 then
	-- 	print("Customer", self.id, "appears stuck in TRAVELING state")
	-- 	print("Debug info:", self:debug_state())
	-- 	self:handle_movement_error()
	-- 	return
	-- end

	-- Rest of your existing update logic...
	-- Patience decay over time
	if self.state == CUSTOMER_STATES.QUEUEING then
		self.current_patience = self.current_patience - (dt * 0.1)
		if self.current_patience <= 0 then
			self:become_frustrated()
			return
		end
	end

	-- State machine (existing code)
	if self.state == CUSTOMER_STATES.ENTERING then
		self:handle_entering()
	elseif self.state == CUSTOMER_STATES.SEEKING_POI then
		self:handle_seeking_poi()
	elseif self.state == CUSTOMER_STATES.TRAVELING then
		self:handle_traveling()
	elseif self.state == CUSTOMER_STATES.INTERACTING then
		self:handle_interacting(dt)
	elseif self.state == CUSTOMER_STATES.DECIDING then
		self:handle_deciding()
	elseif self.state == CUSTOMER_STATES.QUEUEING then
		self:handle_queueing()
	elseif self.state == CUSTOMER_STATES.CHECKING_OUT then
		self:handle_checkout(dt)
	elseif self.state == CUSTOMER_STATES.LEAVING then
		self:handle_leaving()
	end
end

function Customer:move()
	if not self.path or #self.path == 0 then
		print("Customer has no path to follow!")
		self:handle_movement_error()
		return
	end

	local target = self.path[self.step]
	if not target then
		-- Reached end of path - trigger state-specific completion
		self:on_path_complete()
		return
	end

	local target_tile = vmath.vector3(target.x, target.y, 0)
	local target_pos = iso_utils.to_screen_coordinates(target_tile + offset)

	-- Cancel any existing animation (safety check)
	if self.animation_callback_id then
		go.cancel_animations(self.id, "position")
	end

	self.is_traveling = true

	-- Store callback ID for proper cleanup
	local callback_executed = false
	self.animation_callback_id = go.animate(self.id, 'position', go.PLAYBACK_ONCE_FORWARD, 
	target_pos, go.EASING_LINEAR, self.movement_speed, 0,
	function()
		-- Prevent double execution
		if callback_executed then return end
		callback_executed = true

		-- Safety check - make sure we're still the right customer
		if not self.is_traveling then return end

		self.step = self.step + 1
		self:move() -- Continue to next waypoint
	end)
end

-- Called when customer reaches end of current path
function Customer:on_path_complete()
	-- Clean up movement state
	self.is_traveling = false
	self.animation_callback_id = nil
	self.walking_animation_playing = false

	-- Validate current state before proceeding
	local expected_state = self.completion_state or self.state

	-- Handle different completion scenarios based on expected state
	if expected_state == CUSTOMER_STATES.SEEKING_POI then
		self.state = CUSTOMER_STATES.SEEKING_POI
		self:on_enter_complete()
	elseif expected_state == CUSTOMER_STATES.INTERACTING then
		self.state = CUSTOMER_STATES.INTERACTING
		self:on_poi_reached()
	elseif expected_state == CUSTOMER_STATES.QUEUEING then
		self.state = CUSTOMER_STATES.QUEUEING
		self:on_queue_position_reached()
	elseif expected_state == CUSTOMER_STATES.CHECKING_OUT then
		self.state = CUSTOMER_STATES.CHECKING_OUT
	elseif expected_state == CUSTOMER_STATES.LEAVING then
		self.state = CUSTOMER_STATES.LEAVING
		self:on_exit_complete()
	else
		-- Fallback - should not happen
		print("Warning: Customer reached unexpected completion state:", expected_state)
		self.state = expected_state
	end

	-- Clear completion state
	self.completion_state = nil
end
-- Set new destination and calculate path
function Customer:set_destination(target_x, target_y, completion_state)
	-- Stop current movement and clear state
	self:stop_movement()

	-- Get current position in grid coordinates
	local current_pos = go.get_position(self.id)
	local current_grid = iso_utils.to_grid_coordinates(current_pos)

	-- Calculate A* path
	local path, error = pathfinding.find_path(
	{ x = current_grid.x, y = current_grid.y },
	{ x = target_x, y = target_y }
)
self.path = path

if self.path and #self.path > 0 then
	self.step = 1
	self.current_target = { x = target_x, y = target_y }
	self.completion_state = completion_state

	-- Set traveling state BEFORE starting movement
	self.state = CUSTOMER_STATES.TRAVELING
	self:move()
else
	-- Handle special cases
	if error == 'START_END_SAME' then
		-- We're already at the destination
		self.state = completion_state
		self:on_path_complete()
	else
		-- Handle no path scenario
		self:handle_no_path_found()
	end
end
end

function Customer:stop_movement()
if self.is_traveling then
	go.cancel_animations(self.id, "position")
	self.is_traveling = false
	self.animation_callback_id = nil
	self.walking_animation_playing = false
end
end

function Customer:handle_movement_error()
print("Movement error for customer", self.id, "in state", self.state)

-- Clean up state
self:stop_movement()

-- Try to recover based on current state
if self.state == CUSTOMER_STATES.TRAVELING then
	if self.current_poi then
		-- Were heading to a POI, mark as frustrated
		self:become_frustrated()
	else
		-- Try to go to exit
		self:set_destination(self.exit_pos.x, self.exit_pos.y, CUSTOMER_STATES.LEAVING)
	end
else
	-- Force customer to leave
	self:become_frustrated()
end
end

-- Enhanced state handlers using pathfinding

function Customer:handle_entering()
if self.is_traveling then
	return -- Still moving to initial position
end

if not self.current_poi then
	-- Set initial browsing position (center of shop)
	local random_pos = poi_manager.get_random_poi_of_type(POI_TYPES.BROWSE)
	self:set_destination(random_pos.x, random_pos.y, CUSTOMER_STATES.SEEKING_POI)
end
end

function Customer:on_enter_complete()
-- Customer has reached initial position, now look around
self.state_timer = 0

-- Play "looking around" animation
-- msg.post(self.id, "play_animation", { id = hash("look_around") })

-- Brief pause to survey the shop
-- Calculate first impression
-- local shop_appeal = calculate_shop_first_impression()
local shop_appeal = 1.0
if shop_appeal > 1.2 then
	self.current_patience = self.current_patience * 1.1
	-- msg.post(self.id, "play_animation", { id = hash("happy") })
elseif shop_appeal < 0.8 then
	self.current_patience = self.current_patience * 0.9
	-- msg.post(self.id, "play_animation", { id = hash("disappointed") })
end

self.state = CUSTOMER_STATES.SEEKING_POI
end

-- Fixed seeking POI handler
function Customer:handle_seeking_poi()
if self.is_traveling then
	return -- Still moving
end

local available_pois = self:find_suitable_pois()

if #available_pois == 0 then
	self:transition_to_checkout_or_leave()
	return
end

local target_poi = self:select_best_poi(available_pois)

if not target_poi then
	self:set_destination(self.exit_pos.x, self.exit_pos.y, CUSTOMER_STATES.LEAVING)
	return
end

-- Reserve the POI
target_poi.current_visitors = target_poi.current_visitors + 1
self.current_poi = target_poi

-- Move to POI - state will be set inside set_destination
self:set_destination(target_poi.x, target_poi.y, CUSTOMER_STATES.INTERACTING)
end

function Customer:transition_to_checkout_or_leave()
if self.is_traveling then
	-- Wait for current movement to complete
	return
end

if #self.cart > 0 then
	-- Find checkout and queue up
	local checkout_poi = poi_manager.get_random_poi_of_type(POI_TYPES.CHECKOUT)
	if checkout_poi then
		self.current_poi = checkout_poi

		-- Set queue join time for position calculation
		self.queue_join_time = self.total_time_in_shop

		-- Go directly to checkout area
		self:set_destination(checkout_poi.x, checkout_poi.y, CUSTOMER_STATES.QUEUEING)
	else
		-- No checkout available, become frustrated
		self:become_frustrated()
	end
else
	-- No items, just leave
	self:set_destination(self.exit_pos.x, self.exit_pos.y, CUSTOMER_STATES.LEAVING)
end
end

function Customer:handle_traveling()
-- Just wait - movement is handled by go.animate
-- Could add "walking" animation here
if not self.walking_animation_playing then
	-- msg.post(self.id, "play_animation", { id = hash("walking") })
	self.walking_animation_playing = true
end
end

function Customer:on_poi_reached()
-- Stop walking animation
self.walking_animation_playing = false
-- msg.post(self.id, "play_animation", { id = hash("idle") })

-- Start interaction
self.state = CUSTOMER_STATES.INTERACTING
self.state_timer = 0
self.interaction_timer = 0

-- Play POI-specific animation
local poi = self.current_poi
if poi then
	print('play poi anim')
	-- local interaction_anim = get_poi_interaction_animation(poi.type)
	-- msg.post(self.id, "play_animation", {id = hash(interaction_anim)})
end
end

function Customer:handle_interacting(dt)
self.interaction_timer = self.interaction_timer + dt

local poi = self.current_poi

if not poi then
	self.state = CUSTOMER_STATES.DECIDING
	self.state_timer = 0
	return
end

if self.interaction_timer >= (poi.interaction_time or 2.0) then
	-- Interaction complete
	self.state = CUSTOMER_STATES.DECIDING
	self.state_timer = 0

	-- Play "thinking" animation
	-- msg.post(self.id, "play_animation", { id = hash("thinking") })
end
end

function Customer:handle_deciding()
if self.state_timer < 1.0 then
	return -- Still thinking
end

local poi = self.current_poi

-- Make purchase decision
if poi and poi.item_id then
	local item = item_utils.get_by_id(poi.item_id)
	if item then
		local purchase_probability = self:calculate_purchase_probability(item, poi)

		if math.random() < purchase_probability then
			-- Decided to buy!
			table.insert(self.cart, {
				item_id = item.id,
				price = item.price,
				satisfaction_bonus = poi.appeal_score or 1.0
			})

			self.mood = "satisfied"
			self.current_patience = math.min(self.personality.patience, 
			self.current_patience + 0.3)

			-- Play happy animation
			-- msg.post(self.id, "play_animation", { id = hash("purchase_happy") })

			-- Show purchase effect (floating text, particles, etc.)
			-- show_purchase_effect(self.id, item.price)

		else
			-- Decided not to buy
			-- msg.post(self.id, "play_animation", { id = hash("disappointed") })
			self.current_patience = self.current_patience - 0.1
		end
	end
end

-- Clean up POI
if poi then
	self.visited_pois[poi] = true
	poi.current_visitors = poi.current_visitors - 1
	print('removing poi')
	self.current_poi = nil
end

if #self.cart > 0 and math.random() < self:calculate_checkout_probability() then
	self:transition_to_checkout_or_leave()
else
	self.state = CUSTOMER_STATES.SEEKING_POI
	self.state_timer = 0
end
end

function Customer:handle_queueing()
if self.is_traveling then
	return -- Still moving to queue position
end

local checkout_poi = self.current_poi

if not checkout_poi then
	-- no checkout, become frustrated and steal items.
	self:become_frustrated()
	return
end

-- Play waiting animation
if not self.waiting_animation_playing then
	-- msg.post(self.id, "play_animation", { id = hash("waiting") })
	self.waiting_animation_playing = true
end

local can_checkout = true

-- Simplified queue logic - if we're at the checkout POI and it's available, checkout
-- For now, assume first customer at checkout gets to go (you can enhance this later)
if can_checkout and not checkout_poi.current_customer then
	self.waiting_animation_playing = false

	-- Move directly to checkout counter for processing
	self:set_destination(checkout_poi.x, checkout_poi.y, CUSTOMER_STATES.CHECKING_OUT)

	-- Reserve checkout
	checkout_poi.current_customer = self.id
	return
end

-- if has_queue_entertainment() then
-- 	self.current_patience = self.current_patience + 0.01
-- end

if self.current_patience <= 0 then
	self:abandon_queue()
end
end

function Customer:on_queue_position_reached()
-- Just arrived at queue position
self.state = CUSTOMER_STATES.QUEUEING
self.state_timer = 0
end

-- You'll also need to add this missing function
function Customer:abandon_queue()
print("Customer", self.id, "abandoned queue due to impatience")

-- Clean up queue state
self.waiting_animation_playing = false

-- Become frustrated and leave
self:become_frustrated()
end

function Customer:handle_checkout(dt)
if self.is_traveling then
	return -- Still moving to checkout counter
end

-- Play checkout animation sequence
local checkout_time = 2.0 + (#self.cart * 0.5)
-- local employee_efficiency = get_cashier_efficiency()
local employee_efficiency = 1.0
local actual_checkout_time = checkout_time / employee_efficiency

if self.state_timer >= actual_checkout_time then
	self:complete_purchase()
else
	-- Update checkout animation based on progress
	local progress = self.state_timer / actual_checkout_time
	-- 		local current_anim = get_checkout_animation_for_progress(progress)
	-- 
	-- 		if self.current_checkout_anim ~= current_anim then
	-- 			self.current_checkout_anim = current_anim
	-- 			msg.post(self.id, "play_animation", {id = hash(current_anim)})
	-- 		end
end
end

function Customer:complete_purchase()
-- Calculate totals and process payment (your existing logic)
local total_cost = 0
for _, cart_item in pairs(self.cart) do
	total_cost = total_cost + cart_item.price
end

-- Apply bonuses and update game state
-- local upsell_bonus = get_employee_upsell_bonus()
local upsell_bonus = 1.0
local final_cost = total_cost * upsell_bonus

shop.add_revenue(final_cost)

-- Play purchase complete animation
-- msg.post(self.id, "play_animation", { id = hash("purchase_complete") })

-- Show money effect
-- show_money_effect(self.id, final_cost)

-- Free up checkout
self.current_poi.current_customer = nil
self.cart = {}
self.mood = "satisfied"

-- Head to exit after brief delay
self:set_destination(self.exit_pos.x, self.exit_pos.y, CUSTOMER_STATES.LEAVING)
self.state = CUSTOMER_STATES.LEAVING
end

function Customer:handle_leaving(dt)
-- Movement handled by go.animate
if not self.leaving_animation_playing then
	-- msg.post(self.id, "play_animation", { id = hash("leaving") })
	self.leaving_animation_playing = true
end
end

function Customer:on_exit_complete()
-- Customer has reached exit
self:exit_shop()
end

function Customer:exit_shop()
-- Record analytics (your existing logic)
-- record_customer_exit({
-- 	customer_id = self.id,
-- 	personality = self.personality_name,
-- 	total_time = self.total_time_in_shop,
-- 	final_mood = self.mood,
-- 	items_purchased = #self.cart > 0
-- })

-- Remove game object
self.state = CUSTOMER_STATES.QUEUED_FOR_DELETION

-- Remove from active customers
-- remove_customer_from_shop(self.id)
end

function Customer:find_suitable_pois()
local suitable = {}

for _, poi in pairs(shop.pois) do

	-- Check capacity
	local over_capacity = poi.current_visitors >= poi.capacity

	-- Check if already visited (for methodical shoppers)
	local already_visited = self.visited_pois[poi]

	if not over_capacity and not already_visited then
		local poi_appeal = self:calculate_poi_appeal(poi)
		if poi_appeal > 0.1 then -- minimum interest threshold
			table.insert(suitable, { poi = poi, appeal = poi_appeal })
		end
	end
end

return suitable
end

function Customer:calculate_poi_appeal(poi)
local base_appeal = poi.appeal_score or 1.0

-- Personality weight
local personality_weight = self.personality.poi_weights[poi.type] or 0.1

-- Theme bonus
local theme_bonus = 1.0
if self.personality.theme_sensitive then
	theme_bonus = 1.0
	-- TODO add this in
	-- theme_bonus = calculate_theme_synergy(poi.theme_tags, shop.get_theme())
end

-- Seasonal bonus
local seasonal_bonus = 1.0
if self.personality.seasonal_bonus and poi.seasonal_modifier then
	seasonal_bonus = self.personality.seasonal_bonus * poi.seasonal_modifier
end

local our_pos = go.get_position(self.id)
local target_pos = iso_utils.to_screen_coordinates(poi)

-- Distance penalty (closer is better)
local distance = math.sqrt((our_pos.x - target_pos.x)^2 + (our_pos.y - target_pos.y)^2)
local distance_penalty = math.max(0.5, 1.0 - (distance * 0.1))

return base_appeal * personality_weight * theme_bonus * seasonal_bonus * distance_penalty
end

function Customer:select_best_poi(available_pois)
-- Sort by appeal score
table.sort(available_pois, function(a, b) return a.appeal > b.appeal end)

-- Add some randomness - don't always pick the absolute best
local selection_pool_size = math.min(3, #available_pois)
local selected_index = math.random(1, selection_pool_size)

return available_pois[selected_index].poi
end

function Customer:make_purchase_decision(poi)
if not poi.item_id then return end

local item = item_utils.get_by_id(poi.item_id)
local purchase_probability = self:calculate_purchase_probability(item, poi)

if math.random() < purchase_probability then
	table.insert(self.cart, {
		item_id = item.id,
		price = item.price,
		satisfaction_bonus = poi.appeal_score
	})

	-- Boost patience slightly after successful purchase
	self.current_patience = math.min(self.personality.patience, 
	self.current_patience + 0.2)
end
end

function Customer:calculate_purchase_probability(item, poi)
local base_probability = 1.0 - self.personality.buy_threshold

-- Appeal bonus
local appeal_multiplier = poi.appeal_score or 1.0

-- Price sensitivity (could be personality-based)
local price_factor = math.max(0.1, 1.0 - (item.price / 100.0))

-- Food enthusiast bonus
if item.category == "food" and self.personality.food_bonus then
	appeal_multiplier = appeal_multiplier * self.personality.food_bonus
end

-- Employee effects (if you have friendly cashier, etc.)
local staff_bonus = staff_manager.calculate_staff_influence_on_customer(self)

return math.min(0.95, base_probability * appeal_multiplier * price_factor * staff_bonus)
end

-- Calculate Checkout Probability for Customer
-- Determines likelihood that customer will proceed to checkout vs continue shopping

function Customer:calculate_checkout_probability()
-- Base probability starts with personality
local base_probability = self.personality.checkout_tendency or 0.5

-- CART FACTORS
local cart_size = #self.cart

-- More items = more likely to checkout (diminishing returns)
local cart_factor = 1.0
if cart_size > 0 then
	cart_factor = math.min(2.0, 1.0 + (cart_size * 0.3))
else
	-- No items = never checkout
	return 0.0
end

-- PATIENCE FACTORS
-- Low patience = want to checkout and leave
local patience_ratio = self.current_patience / self.personality.patience
local patience_factor = 1.0

if patience_ratio < 0.3 then
	-- Very impatient - likely to checkout immediately
	patience_factor = 2.0
elseif patience_ratio < 0.6 then
	-- Somewhat impatient - moderately likely to checkout
	patience_factor = 1.4
elseif patience_ratio > 0.8 then
	-- Still patient - might want to shop more
	patience_factor = 0.7
end

-- TIME FACTORS
-- Been shopping a long time = more likely to finish up
local time_factor = 1.0
if self.total_time_in_shop > 300 then -- 5 minutes
	time_factor = 1.8
elseif self.total_time_in_shop > 180 then -- 3 minutes
	time_factor = 1.3
elseif self.total_time_in_shop < 60 then -- 1 minute
	-- Just arrived, probably want to shop more
	time_factor = 0.4
end

-- CART VALUE FACTORS
-- Calculate total cart value
local total_cart_value = 0
for _, cart_item in pairs(self.cart) do
	total_cart_value = total_cart_value + cart_item.price
end

-- Expensive cart = more likely to checkout (don't want to lose items)
local value_factor = 1.0
if total_cart_value > 50 then
	value_factor = 1.5
elseif total_cart_value > 20 then
	value_factor = 1.2
elseif total_cart_value < 5 then
	-- Cheap items, might as well get more
	value_factor = 0.8
end

-- PERSONALITY-SPECIFIC MODIFIERS
local personality_modifier = 1.0

-- Methodical shoppers have specific checkout patterns
if self.personality_name == CUSTOMER_PERSONALITIES.methodical_shopper then
	-- Methodical customers like to check everything before buying
	local pois_visited = 0
	for _ in pairs(self.visited_pois) do
		pois_visited = pois_visited + 1
	end

	-- If they haven't visited many POIs yet, less likely to checkout
	if pois_visited < 3 then
		personality_modifier = 0.5
	elseif pois_visited >= 5 then
		personality_modifier = 1.3
	end

	-- Impulsive shoppers checkout more randomly
elseif self.personality_name == "impulsive" then
	-- Add some randomness
	personality_modifier = 0.8 + (math.random() * 0.6) -- 0.8 to 1.4

	-- Budget shoppers are more cautious
elseif self.personality_name == "budget_conscious" then
	-- More likely to checkout with fewer, cheaper items
	if cart_size >= 2 and total_cart_value < 15 then
		personality_modifier = 1.4
	elseif total_cart_value > 25 then
		personality_modifier = 0.6 -- Might reconsider expensive purchases
	end

	-- Enthusiast shoppers want to see everything
elseif self.personality_name == "enthusiast" then
	-- Less likely to checkout early
	if self.total_time_in_shop < 120 then -- 2 minutes
		personality_modifier = 0.3
	end
end

-- SHOP CONDITIONS
local shop_factor = 1.0

-- If shop is very crowded, might want to checkout quickly
-- (You'd need to implement shop.get_crowd_level())
-- local crowd_level = shop.get_crowd_level()
-- if crowd_level > 0.8 then
-- 	shop_factor = 1.3
-- end

-- If there's a long checkout queue, might continue shopping
local checkout_poi = poi_manager.get_random_poi_of_type(POI_TYPES.CHECKOUT)
if checkout_poi then
	local queue_length = checkout_poi.current_visitors
	if queue_length > 3 then
		shop_factor = 0.7 -- Less likely to checkout if long line
	elseif queue_length == 0 then
		shop_factor = 1.2 -- More likely if no wait
	end
end

-- MOOD FACTORS
local mood_factor = 1.0
if self.mood == "satisfied" then
	mood_factor = 1.3 -- Happy customers checkout more readily
elseif self.mood == "frustrated" then
	mood_factor = 1.8 -- Frustrated customers want to leave
elseif self.mood == "disappointed" then
	mood_factor = 0.9 -- Might keep trying to find something good
end

-- SEASONAL/TIME FACTORS (if you have time-of-day system)
local temporal_factor = 1.0
-- if shop.is_closing_soon() then
-- 	temporal_factor = 1.5 -- Need to buy now or never
-- end

-- COMBINE ALL FACTORS
local final_probability = base_probability * 
cart_factor * 
patience_factor * 
time_factor * 
value_factor * 
personality_modifier * 
shop_factor * 
mood_factor * 
temporal_factor

-- Clamp between 0 and 1
final_probability = math.max(0.0, math.min(1.0, final_probability))

-- Add small amount of randomness to prevent predictable behavior
local randomness = (math.random() - 0.5) * 0.1 -- ±5%
final_probability = math.max(0.0, math.min(1.0, final_probability + randomness))

return final_probability
end

-- Optional: Get queue position for this customer
function Customer:get_queue_position()
local checkout_poi = poi_manager.find_checkout()
if not checkout_poi then
	return 1
end

-- Calculate position based on other queueing customers
-- This is also a placeholder
local position = 1
-- for _, other_customer in pairs(customer_manager.get_all_customers()) do
-- 	if other_customer.state == CUSTOMER_STATES.QUEUEING and 
-- 	   other_customer.id ~= self.id and
-- 	   other_customer.queue_join_time < self.queue_join_time then
-- 		position = position + 1
-- 	end
-- end

return position
end

function Customer:handle_no_path_found()
-- Fallback when pathfinding fails
print("Customer", self.id, "couldn't find path, becoming frustrated")
self:become_frustrated()
end

function Customer:become_frustrated()
self.mood = "frustrated"
self.movement_speed = self.movement_speed * 1.3 -- leave faster

-- msg.post(self.id, "play_animation", { id = hash("angry") })

-- Head straight to exit
self:set_destination(self.exit_pos.x, self.exit_pos.y, CUSTOMER_STATES.LEAVING)
self.state = CUSTOMER_STATES.LEAVING

-- Clear cart
self.cart = {}
end

return Customer