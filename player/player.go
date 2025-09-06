components {
  id: "player"
  component: "/player/player.script"
}
embedded_components {
  id: "mesh"
  type: "mesh"
  data: "material: \"/newiso/chunk/chunk.material\"\n"
  "vertices: \"/player/player.buffer\"\n"
  "textures: \"/assets/people/blank/idle.png\"\n"
  ""
  rotation {
    z: 0.38268343
    w: 0.9238795
  }
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"down\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/people/blank/blank_idle.tilesource\"\n"
  "}\n"
  ""
  position {
    y: 20.0
  }
  scale {
    x: 0.1
    y: 0.1
    z: 0.1
  }
}
