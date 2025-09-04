components {
  id: "placement"
  component: "/screens/buildmenu/placement.script"
}
embedded_components {
  id: "cancel"
  type: "sprite"
  data: "default_animation: \"cancel\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/icons/icons.atlas\"\n"
  "}\n"
  ""
  position {
    x: -250.0
    y: 350.0
    z: 1.0
  }
  scale {
    x: 3.0
    y: 3.0
  }
}
embedded_components {
  id: "confirm"
  type: "sprite"
  data: "default_animation: \"confirm\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/icons/icons.atlas\"\n"
  "}\n"
  ""
  position {
    x: 250.0
    y: 350.0
    z: 1.0
  }
  scale {
    x: 3.0
    y: 3.0
  }
}
embedded_components {
  id: "tile"
  type: "sprite"
  data: "default_animation: \"blackwhite_BlankFloor_Sides2\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/tiles/tiles.atlas\"\n"
  "}\n"
  ""
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_KINEMATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"interactive\"\n"
  "mask: \"cursor\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"drag_box\"\n"
  "  }\n"
  "  data: 10.0\n"
  "  data: 10.0\n"
  "  data: 10.0\n"
  "}\n"
  "locked_rotation: true\n"
  ""
}
embedded_components {
  id: "decoration"
  type: "sprite"
  data: "default_animation: \"1x1_KitchenCookerOff_Olive\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/decorations/kitchen.atlas\"\n"
  "}\n"
  ""
  position {
    x: -32.0
    y: 89.0
    z: 0.1
  }
}
