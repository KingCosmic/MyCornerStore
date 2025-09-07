components {
  id: "player"
  component: "/player/player.script"
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
    y: 9.0
  }
  rotation {
    y: -0.38268343
    w: 0.9238795
  }
  scale {
    x: 0.05
    y: 0.05
    z: 0.05
  }
}
