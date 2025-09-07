
local M = {}

M.chunk_width = 16
M.chunk_height = 16
--[[ chunk properties.
	x = 0
	y = 0
	tiles = {}
	heights = {}
	dirty = false
]]--
M.chunks = {}

function M.get_chunk_key(x, z)
	return x .. ',' .. z
end

function M.get_tile(chunk, tile_x, tile_y, tile_z)
	if chunk.layers[tile_y] then
		return chunk.layers[tile_y][tile_z][tile_x]
	end
end

function M.create_chunk(x, z)
	local chunk = {}

	chunk.heights = {}
	chunk.tiles = {}
	chunk.x = x
	chunk.z = z
	chunk.dirty = false

	chunk.layers = {}

	for y = 1, 4 do
		chunk.layers[y] = {}
		for h = 1, M.chunk_height do
			chunk.layers[y][h] = {}
			for w = 1, M.chunk_width do
				local tile = (y == 1) and 1 or 0

				if h == 1 and w == 1 then
					tile = 130
				elseif h == 1 and w == M.chunk_width then
					tile = 130
				elseif h == M.chunk_height and w == 1 then
					tile = 130
				elseif h == M.chunk_height and w == M.chunk_width then
					tile = 130
				end

				-- we only create data for 0, 0 by default.
				if not (x == 0 and z == 0) then
					tile = 0
				end

				chunk.layers[y][h][w] = tile
			end
		end
	end

	M.chunks[M.get_chunk_key(x, z)] = chunk

	return chunk
end

function M.get_chunk(x, z)
	local chunk = M.chunks[M.get_chunk_key(x, z)]

	if chunk then
		return chunk
	end

	-- if we're here, a chunk for this x and y doesn't exist.
	return M.create_chunk(x, z)
end

function M.fill_layer(chunk, y)
	chunk.layers[y] = {}

	for z = 1, M.chunk_height do
		chunk.layers[y][z] = {}
		
		for x = 1, M.chunk_width do
			chunk.layers[y][z][x] = 0
		end
	end
end

function M.erase_tile(chunk_x, chunk_y, x, y, z)
	local chunk = M.get_chunk(chunk_x, chunk_y)

	local target_height = y + 1

	-- if this layer doesn't exist we shouldn't need to erase anything
	if not chunk.layers[target_height] then
		M.fill_layer(chunk, target_height)
	end

	chunk.layers[target_height][z][x] = 0
end

function M.place_tile(chunk_x, chunk_z, x, y, z, tile_id)
	local chunk = M.get_chunk(chunk_x, chunk_z)

	local target_height = y + 1

	-- if this layer doesn't exist we should make an empty one.
	if not chunk.layers[target_height] then
		M.fill_layer(chunk, target_height)
	end

	chunk.layers[target_height][z][x] = tile_id
end

return M