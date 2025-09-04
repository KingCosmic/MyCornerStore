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
