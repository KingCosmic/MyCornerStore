
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

function M.get_chunk_key(x, y)
	return x .. ',' .. y
end

function M.get_tile(chunk, tile_x, tile_y, tile_z)
	if chunk.layers[tile_z] then
		return chunk.layers[tile_z][tile_y][tile_x]
	end
end

function M.create_chunk(x, y)
	local chunk = {}

	chunk.heights = {}
	chunk.tiles = {}
	chunk.x = x
	chunk.y = y
	chunk.dirty = false

	chunk.layers = {}

	for z = 1, 4 do
		chunk.layers[z] = {}
		for h = 1, M.chunk_height do
			chunk.layers[z][h] = {}
			for w = 1, M.chunk_width do
				
				local tile = (z == 1) and 1 or 0

				if h == 1 and w == 1 then
					tile = 130
				elseif h == 1 and w == M.chunk_width then
					tile = 130
				elseif h == M.chunk_height and w == 1 then
					tile = 130
				elseif h == M.chunk_height and w == M.chunk_width then
					tile = 130
				end

				chunk.layers[z][h][w] = tile
			end
		end
	end

	-- for h = 1, M.chunk_height do
	-- 	chunk.tiles[h] = {}
	-- 	chunk.heights[h] = {}
	-- 	for w = 1, M.chunk_width do
	-- 		chunk.tiles[h][w] = 1
	-- 		chunk.heights[h][w] = 0
	-- 	end
	-- end

	M.chunks[M.get_chunk_key(x, y)] = chunk

	return chunk
end

function M.get_chunk(x, y)
	local chunk = M.chunks[M.get_chunk_key(x, y)]

	if chunk then
		return chunk
	end

	-- if we're here, a chunk for this x and y doesn't exist.
	return M.create_chunk(x, y)
end

function M.fill_layer(chunk, z)
	chunk.layers[z] = {}

	for y = 1, M.chunk_height do
		chunk.layers[z][y] = {}
		
		for x = 1, M.chunk_width do
			chunk.layers[z][y][x] = 0
		end
	end
end

function M.erase_tile(chunk_x, chunk_y, x, y, z)
	local chunk = M.get_chunk(chunk_x, chunk_y)

	local target_height = z + 1

	-- if this layer doesn't exist we shouldn't need to erase anything
	if not chunk.layers[target_height] then
		M.fill_layer(chunk, target_height)
	end

	chunk.layers[target_height][y][x] = 0
end

function M.place_tile(chunk_x, chunk_y, x, y, z, tile_id)
	local chunk = M.get_chunk(chunk_x, chunk_y)

	local target_height = z + 1

	-- if this layer doesn't exist we should make an empty one.
	if not chunk.layers[target_height] then
		M.fill_layer(chunk, target_height)
	end

	chunk.layers[target_height][y][x] = tile_id
end

return M