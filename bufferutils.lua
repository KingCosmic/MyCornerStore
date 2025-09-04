local M = {}

function M.fill_stream(stream, data)
	for key, value in ipairs(data) do
		stream[key] = data[key]
	end
end

function M.render_mesh(data, mesh_url)
	-- Number of vertices is just the length of utils.vertices
	local vertex_count = #data.vertices / 3

	-- Create a vertex buffer with position and texcoord attributes
	local buf = buffer.create(vertex_count, {
		{ name = hash('position'), type = buffer.VALUE_TYPE_FLOAT32, count = 3 },
		{ name = hash('normal'), type = buffer.VALUE_TYPE_FLOAT32, count = 3 },
		{ name = hash('texcoord0'), type = buffer.VALUE_TYPE_FLOAT32, count = 2 },
		{ name = hash('color0'), type = buffer.VALUE_TYPE_FLOAT32, count = 4 },
	})

	-- Get vertex attribute streams
	local pos_stream = buffer.get_stream(buf, hash("position"))
	local norm_stream = buffer.get_stream(buf, hash('normal'))
	local uv_stream  = buffer.get_stream(buf, hash("texcoord0"))
	local col_stream = buffer.get_stream(buf, hash('color0'))

	M.fill_stream(pos_stream, data.vertices)
	M.fill_stream(norm_stream, data.normals)
	M.fill_stream(uv_stream, data.uvs)
	M.fill_stream(col_stream, data.colors)

	-- Push new vertex buffer into the mesh resource
	local v_res = go.get(mesh_url, 'vertices')
	resource.set_buffer(v_res, buf)
end

return M