local world = require 'newiso.world'

local M = {}

M.TILE_WIDTH = 16
M.TILE_HEIGHT = 16

M.tiles_per_row = 32
M.tiles_per_col = 32

-- 3D Raycast function that goes from start position to a specific z value
-- Returns the end position where the ray hits the target z
local function raycast_to_y(startPos, throughPos, targetY)
	-- Extract coordinates
	local x1, y1, z1 = startPos.x, startPos.y, startPos.z
	local x2, y2, z2 = throughPos.x, throughPos.y, throughPos.z

	-- Calculate direction vector (normalized direction from start through the through point)
	local dx = x2 - x1
	local dy = y2 - y1  
	local dz = z2 - z1

	-- Check if ray direction is valid for reaching the target Z
	if dy == 0 then
		error("Ray is parallel to target y plane - no intersection possible")
	end

	-- Check if ray is going in the wrong direction
	if (targetY < y1 and dy >= 0) or (targetY > y1 and dy <= 0) then
		error("Ray is pointing away from target Y plane")
	end

	-- Calculate parameter t where ray intersects targetY
	-- Ray equation: P(t) = start + t * direction
	-- For targetY: y1 + t * dy = targetY
	-- So: t = (targetY - y1) / dy
	local t = (targetY - y1) / dy

	-- Calculate intersection point
	local endX = x1 + t * dx
	local endY = targetY -- This will be exactly targetY
	local endZ = z1 + t * dz

	-- Calculate the actual distance traveled
	local distance = math.sqrt(
		(endX - x1)^2 + 
		(endY - y1)^2 + 
		(endZ - z1)^2
	)

	return {
		x = endX,
		y = endY,
		z = endZ,
		distance = distance,
		t = t
	}
end

-- convert mouse pos to world point, then shoot ray from camera postion to mouse position
-- useful for 3d cameras that have rotations applied
function M.ray_to_tile(near, far, target_y)
	local result = raycast_to_y(near, far, target_y)

	-- Convert to tile coordinates
	return M.world_to_tile(result.x, result.y, result.z)
end

function M.get_tile_uv(tile_id)
	if tile_id == 0 then
		return { u1 = 0, v1 = 0, u2 = 1, v2 = 1 }
	end

	local tile_index = (tile_id - 1) % (M.tiles_per_row * M.tiles_per_col)
	local tile_x = tile_index % M.tiles_per_row
	local tile_y = math.floor(tile_index / M.tiles_per_row)

	local tile_size_u = 1.0 / M.tiles_per_row
	local tile_size_v = 1.0 / M.tiles_per_col

	local padding = 0.001
	local u1 = tile_x * tile_size_u + padding
	local u2 = (tile_x + 1) * tile_size_u - padding

	-- FLIP Y
	local v2 = 1.0 - (tile_y * tile_size_v + padding)
	local v1 = 1.0 - ((tile_y + 1) * tile_size_v - padding)

	return { u1 = u1, v1 = v1, u2 = u2, v2 = v2 }
end


-- Push vertices (x, y, z, u, v) in a flat array
local function push_vertex(chunk, x, y, z, u, v)
	table.insert(chunk.vertices, x)
	table.insert(chunk.vertices, y)
	table.insert(chunk.vertices, z)
	table.insert(chunk.uvs, u)
	table.insert(chunk.uvs, v)
	table.insert(chunk.normals, -1)
	table.insert(chunk.normals, -1)
	table.insert(chunk.normals, -1)
	table.insert(chunk.colors, 1)
	table.insert(chunk.colors, 1)
	table.insert(chunk.colors, 1)
	table.insert(chunk.colors, 1)
end

function M.add_terrain_quad(chunk, grid_x, grid_y, grid_z)
	local height = grid_y
	local tile_id = chunk.layers[grid_y][grid_z][grid_x]

	-- tile_id 0 represents air
	if tile_id == 0 then
		return
	end

	local uv = M.get_tile_uv(tile_id)
	local depth = height * M.TILE_HEIGHT

	-- Convert grid coordinates to world space
	local iso_x = grid_x * M.TILE_WIDTH
	local iso_z = grid_z * M.TILE_HEIGHT

	-- Define corners (clockwise)
	local bl_x, bl_z = iso_x, iso_z
	local br_x, br_z = iso_x + M.TILE_WIDTH, iso_z
	local tl_x, tl_z = iso_x, iso_z + M.TILE_HEIGHT
	local tr_x, tr_z = iso_x + M.TILE_WIDTH, iso_z + M.TILE_HEIGHT

	-- check for a tile directly above us
	-- if one exists don't render our top face
	local above_y = grid_y + 1
	local covering_tile = chunk.layers[above_y] and chunk.layers[above_y][grid_z][grid_x]

	-- if tile doesn't exist or it's air we can render.
	if not covering_tile or covering_tile == 0 then
		-- Triangle 1
		push_vertex(chunk, bl_x, depth, bl_z, uv.u1, uv.v1)
		push_vertex(chunk, tl_x, depth, tl_z, uv.u1, uv.v2)
		push_vertex(chunk, br_x, depth, br_z, uv.u2, uv.v1)
		-- Triangle 2
		push_vertex(chunk, tl_x, depth, tl_z, uv.u1, uv.v2)
		push_vertex(chunk, tr_x, depth, tr_z, uv.u2, uv.v2)
		push_vertex(chunk, br_x, depth, br_z, uv.u2, uv.v1)
	end

	-- add possible cliff faces
	M.add_cliff_faces(chunk, grid_x, grid_y, grid_z, depth, uv)
end

function M.add_cliff_faces(chunk, grid_x, grid_y, grid_z, depth, uv)
	-- Check adjacent tiles and add vertical faces where there's a drop
	local directions = {
		{ 0,  1, "N" },  -- North
		{ 1,  0, "E" },  -- East
		{ 0, -1, "S" },  -- South
		{ -1, 0, "W" }   -- West
	}

	for _, dir in ipairs(directions) do
		local adj_x = grid_x + dir[1]
		local adj_z = grid_z + dir[2]

		local adj_tile
		if M.is_within_chunk(adj_x, adj_z) then
			adj_tile = chunk.layers[grid_y][adj_z][adj_x]
		end

		-- we only render cliff faces for "open" sides.
		-- no point for rendering hidden geometry.
		if adj_tile == 0 then
			M.add_cliff_face(chunk, grid_x, grid_y, grid_z, dir[3], grid_y * M.TILE_HEIGHT, uv)
		end
	end
end

function M.add_cliff_face(chunk, grid_x, grid_y, grid_z, dir, depth, uv)
	-- World position of tile center
	local world_x = grid_x * M.TILE_WIDTH
	local world_z = grid_z * M.TILE_HEIGHT

	local hw = M.TILE_WIDTH 
	local hh = M.TILE_HEIGHT
	local hdrop = M.TILE_HEIGHT

	local verts = {}

	if dir == 'N' then
		verts = {
			-- bottom left
			{ world_x, depth - hdrop, world_z + hh, },
			-- top left  
			{ world_x, depth, world_z + hh },
			-- bottom right
			{ world_x + hw, depth - hdrop, world_z + hh },
			-- top right
			{ world_x + hw, depth, world_z + hh }
		}
	elseif dir == 'E' then
		verts = {
			-- bottom left
			{ world_x + hw, depth - hdrop, world_z },
			-- bottom right  
			{ world_x + hw, depth - hdrop, world_z + hh },
			-- top left
			{ world_x + hw, depth, world_z },
			-- top right
			{ world_x + hw, depth, world_z + hh }
		}
	elseif dir == 'S' then
		verts = {
			-- bottom left
			{ world_x, depth - hdrop, world_z },
			-- bottom right
			{ world_x + hw, depth - hdrop, world_z },
			-- top left
			{ world_x, depth, world_z },
			-- top right
			{ world_x + hw, depth, world_z }
		}
	elseif dir == 'W' then
		verts = {
			-- bottom left
			{ world_x, depth - hdrop, world_z + hh },
			-- bottom right
			{ world_x, depth - hdrop, world_z },
			-- top left
			{ world_x, depth, world_z + hh },
			-- top right
			{ world_x, depth, world_z }
		}
	end

	-- Triangle 1 (reversed winding)
	push_vertex(chunk, verts[1][1], verts[1][2], verts[1][3], uv.u1, uv.v1)
	push_vertex(chunk, verts[3][1], verts[3][2], verts[3][3], uv.u1, uv.v2)
	push_vertex(chunk, verts[2][1], verts[2][2], verts[2][3], uv.u2, uv.v1)

	-- Triangle 2 (reversed winding)
	push_vertex(chunk, verts[3][1], verts[3][2], verts[3][3], uv.u1, uv.v2)
	push_vertex(chunk, verts[4][1], verts[4][2], verts[4][3], uv.u2, uv.v2)
	push_vertex(chunk, verts[2][1], verts[2][2], verts[2][3], uv.u2, uv.v1)
end

-- Animal Crossing style terrain editing
function M.raise_terrain(chunk, grid_x, grid_z)
	if M.is_within_chunk(grid_x, grid_z) then
		chunk.heights[grid_z][grid_x] = chunk.heights[grid_z][grid_x] + 1
	end
end

function M.lower_terrain(chunk, grid_x, grid_z)
	if M.is_within_chunk(grid_x, grid_z) then
		chunk.heights[grid_z][grid_x] = math.max(0, chunk.heights[grid_z][grid_x] - 1)
	end
end

function M.change_tile_texture(chunk, grid_x, grid_y, grid_z, new_tile_id)
	if M.is_within_chunk(grid_x, grid_z) then
		if chunk.layers[grid_y] then
			chunk.layers[grid_y][grid_z][grid_x] = new_tile_id
		end
	end
end

-- Get height at world position (for gameplay/collision)
function M.get_height_at(world_x, world_y)
	if M.is_within_world(world_x, world_y) then
		return M.world.heights[world_y][world_x]
	end

	return 0
end

-- Convert world coordinates to chunk coordinates
function M.world_to_chunk(world_x, world_z)
	local chunk_width_pixels = world.chunk_width * M.TILE_WIDTH
	local chunk_height_pixels = world.chunk_height * M.TILE_HEIGHT

	-- Correct handling for negative coordinates
	local function floor_div(a, b)
		local div = a / b
		if div >= 0 then
			return math.floor(div)
		else
			return math.ceil(div - 1)
		end
	end

	local chunk_world_x = floor_div(world_x, chunk_width_pixels)
	local chunk_world_z = floor_div(world_z, chunk_height_pixels)

	return chunk_world_x, chunk_world_z
end

-- Convert world coordinates to local tile coordinates within a chunk
function M.world_to_tile(world_x, world_y, world_z, offset)
	offset = offset or vmath.vector3(0, 0, 0)
	local local_x = world_x - offset.x
	local local_y = world_y - offset.y
	local local_z = world_z - offset.z

	-- Get which chunk we're in
	local chunk_x, chunk_z = M.world_to_chunk(local_x, local_z)

	-- Calculate the chunk's world position
	local chunk_world_x = chunk_x * world.chunk_width * M.TILE_WIDTH
	local chunk_world_z = chunk_z * world.chunk_height * M.TILE_HEIGHT

	-- Get local position within the chunk
	local chunk_local_x = local_x - chunk_world_x
	local chunk_local_z = local_z - chunk_world_z

	-- Convert to tile coordinates within the chunk (1-16)
	local tile_x = math.floor(chunk_local_x / M.TILE_WIDTH)
	local tile_y = math.floor(local_y / M.TILE_HEIGHT)
	local tile_z = math.floor(chunk_local_z / M.TILE_HEIGHT)

	-- Clamp to chunk bounds
	if tile_x == 0 then
		chunk_x = chunk_x - 1
		tile_x = world.chunk_width
	else
		tile_x = math.max(1, math.min(world.chunk_width, tile_x))
	end

	if tile_z == 0 then
		chunk_z = chunk_z - 1
		tile_z = world.chunk_height
	else
		tile_z = math.max(1, math.min(world.chunk_height, tile_z))
	end

	tile_z = math.max(1, tile_z)

	return tile_x, tile_y, tile_z, chunk_x, chunk_z
end

-- Check if a world position has an active chunk
function M.is_chunk_loaded(world_x, world_y)
	local chunk_x, chunk_y = M.world_to_chunk(world_x, world_y)
	local chunk_key = chunk_x .. "," .. chunk_y
	return M.active_chunks and M.active_chunks[chunk_key] ~= nil
end

-- Check if world coordinates are within any loaded chunk
function M.is_within_world(world_x, world_y)
	return M.is_chunk_loaded(world_x, world_y)
end

function M.is_within_chunk(grid_x, grid_y)
	return grid_x > 0 and grid_x <= world.chunk_width and grid_y > 0 and grid_y <= world.chunk_height
end

-- Get chunk key for storage/lookup
function M.get_chunk_key(chunk_x, chunk_z)
	if not chunk_x or not chunk_z then
		return ''
	end

	return chunk_x .. "," .. chunk_z
end

-- Convert chunk coordinates to world position (top-left corner of chunk)
function M.chunk_to_world(chunk_x, chunk_y)
	local world_x = chunk_x * M.CHUNK_SIZE * M.TILE_WIDTH
	local world_y = chunk_y * M.CHUNK_SIZE * M.TILE_HEIGHT
	return world_x, world_y
end

-- Get all chunk coordinates within a radius of a world position
function M.get_chunks_in_radius(center_world_x, center_world_z, radius_chunks)
	radius_chunks = radius_chunks or 2 -- Load chunks within 2 chunk radius

	local center_chunk_x, center_chunk_z = M.world_to_chunk(center_world_x, center_world_z)
	local chunks = {}

	for dx = -radius_chunks, radius_chunks do
		for dz = -radius_chunks, radius_chunks do
			local chunk_x = center_chunk_x + dx
			local chunk_z = center_chunk_z + dz
			chunks[M.get_chunk_key(chunk_x, chunk_z)] = { x = chunk_x, z = chunk_z }
		end
	end

	return chunks
end

return M