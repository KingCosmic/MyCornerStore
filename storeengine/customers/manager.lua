local iso_utils = require 'isometric.utils'
local map = require 'map'

local Customer = require 'shop_system.customer'

local personalities = require 'shop_system.personalities'
local CUSTOMER_STATE = require 'shop_system.customer_states'

local offset = vmath.vector3(.5, 0, .5)

local M = {}

local function get_random_key(tbl)
	local keys = {}
	for key in pairs(tbl) do
		table.insert(keys, key)
	end
	return keys[math.random(#keys)]
end

M.customers = {}
M.spawn_side = 'left'

function M.initialize()
	M.handle = timer.delay(1, true, function() M.spawn_customer() end)
end

function M.spawn_customer()
	local spawn_pos
	local exit_pos

	if M.spawn_side == 'left' then
		spawn_pos = vmath.vector3(map.left_spawn)
		exit_pos = vmath.vector3(map.right_spawn)
		M.spawn_side = 'right'
	elseif M.spawn_side == 'right' then
		spawn_pos = vmath.vector3(map.right_spawn)
		exit_pos = vmath.vector3(map.left_spawn)
		M.spawn_side = 'left'
	end

	local converted_pos = iso_utils.to_screen_coordinates(spawn_pos + offset)

	-- depth for our tile
	local tile_depth = -(spawn_pos.x + spawn_pos.y) * 0.01
	converted_pos.z = tile_depth

	local cust_id = factory.create('#customer_factory', converted_pos)

	table.insert(M.customers, Customer:new(get_random_key(personalities), cust_id, exit_pos))
end

function M.update_customers(dt)
	for i = #M.customers, 1, -1 do
		if M.customers[i].state == CUSTOMER_STATE.QUEUED_FOR_DELETION then
			local id = M.customers[i].id
			table.remove(M.customers, i)
			go.delete(id)
		else
			M.customers[i]:update(dt)
		end
	end
end

return M