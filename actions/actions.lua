-- Actions code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Action functionality
---------------------------------------------------------------------------------------
-- The NPCs will be able to perform five fundamental actions that will allow
-- for them to perform any other kind of interaction in the world. These
-- fundamental actions are: place a node, dig a node, put items on an inventory,
-- take items from an inventory, find a node closeby (radius 3) and
-- walk a step on specific direction. These actions will be set on an action queue. 
-- The queue will have the specific steps, in order, for the NPC to be able to do 
-- something (example, go to a specific place and put a chest there). The 
-- fundamental actions are added to the action queue to make a complete task for the NPC.

npc.actions = {}

-- Describes actions with doors or openable nodes
npc.actions.const = {
  doors = {
    action = {
      OPEN = 1,
      CLOSE = 2
    },
    state = {
      OPEN = 1,
      CLOSED = 2
    }
  },
  beds = {
    LAY = 1,
    GET_UP = 2
  },
  sittable = {
    SIT = 1,
    GET_UP = 2
  }
}

function npc.actions.rotate(args)
  local self = args.self
  local dir = args.dir
  local yaw = 0
  self.rotate = 0
  if dir == npc.direction.north then
    yaw = 0
  elseif dir == npc.direction.north_east then
    yaw = (7 * math.pi) / 4
  elseif dir == npc.direction.east then
    yaw = (3 * math.pi) / 2
  elseif dir == npc.direction.south_east then
    yaw = (5 * math.pi) / 4
  elseif dir == npc.direction.south then
    yaw = math.pi
  elseif dir == npc.direction.south_west then
    yaw = (3 * math.pi) / 4
  elseif dir == npc.direction.west then
    yaw = math.pi / 2
  elseif dir == npc.direction.north_west then
    yaw = math.pi / 4
  end
  self.object:setyaw(yaw)
end

-- This function will make the NPC walk one step on a 
-- specifc direction. One step means one node. It returns 
-- true if it can move on that direction, and false if there is an obstacle
function npc.actions.walk_step(args)
  local self = args.self
  local dir = args.dir
  local vel = {}
  if dir == npc.direction.north then
    vel = {x=0, y=0, z=0.98}
  elseif dir == npc.direction.east then
    vel = {x=0.98, y=0, z=0}
  elseif dir == npc.direction.south then
    vel = {x=0, y=0, z=-0.98}
  elseif dir == npc.direction.west then
    vel = {x=-0.98, y=0, z=0}
  end
  -- Rotate NPC
  npc.actions.rotate({self=self, dir=dir})
  -- Set velocity so that NPC walks
  self.object:setvelocity(vel)
  -- Set walk animation
  self.object:set_animation({
      x = npc.ANIMATION_WALK_START,
      y = npc.ANIMATION_WALK_END},
      self.animation.speed_normal, 0)
end

-- This action makes the NPC stand and remain like that
function npc.actions.stand(args)
  local self = args.self
  local pos = args.pos
  local dir = args.dir
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- If position given, set to that position
  if pos ~= nil then
    self.object:moveto(pos)
  end
    -- If dir given, set to that dir
  if dir ~= nil then
    npc.actions.rotate({self=self, dir=dir})
  end
  -- Set stand animation
  self.object:set_animation({
        x = npc.ANIMATION_STAND_START,
        y = npc.ANIMATION_STAND_END},
        self.animation.speed_normal, 0)
end

-- This action makes the NPC sit on the node where it is
function npc.actions.sit(args)
  local self = args.self
  local pos = args.pos 
  local dir = args.dir
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- If position given, set to that position
  if pos ~= nil then
    self.object:moveto(pos)
  end
  -- If dir given, set to that dir
  if dir ~= nil then
    npc.actions.rotate({self=self, dir=dir})
  end
  -- Set sit animation
  self.object:set_animation({
        x = npc.ANIMATION_SIT_START,
        y = npc.ANIMATION_SIT_END},
        self.animation.speed_normal, 0)
end

-- This action makes the NPC lay on the node where it is
function npc.actions.lay(args)
  local self = args.self
  local pos = args.pos
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- If position give, set to that position
  if pos ~= nil then
    self.object:moveto(pos)
  end
  -- Set sit animation
  self.object:set_animation({
        x = npc.ANIMATION_LAY_START,
        y = npc.ANIMATION_LAY_END},
        self.animation.speed_normal, 0)
end

-- Inventory functions for players and for nodes
-- This function is a convenience function to make it easy to put
-- and get items from another inventory (be it a player inv or 
-- a node inv)
function npc.actions.put_item_on_external_inventory(args)
  local self = args.self
  local player = args.player
  local pos = args.pos
  local inv_list = args.inv_list
  local item_name = args.item_name
  local count = args.count
  local is_furnace = args.is_furnace
  local inv
  if player ~= nil then
    inv = minetest.get_inventory({type="player", name=player})
  else
    inv = minetest.get_inventory({type="node", pos=pos})
  end

  -- Create ItemStack to put on external inventory
  local item = ItemStack(item_name.." "..count)
  -- Check if there is enough room to add the item on external invenotry
  if inv:room_for_item(inv_list, item) then
    -- Take item from NPC's inventory
    if npc.take_item_from_inventory_itemstring(self, item) then
      -- NPC doesn't have item and/or specified quantity
      return false
    end
    -- Add items to external inventory
    inv:add_item(inv_list, item)
    
    -- If this is a furnace, start furnace timer
    if is_furnace == true then
      minetest.get_node_timer(pos):start(1.0)
    end

    return true
  end
  -- Not able to put on external inventory
  return false
end

function npc.actions.take_item_from_external_inventory(args)
  local self = args.self
  local player = args.player
  local pos = args.pos
  local inv_list = args.inv_list
  local item_name = args.item_name
  local count = args.count
  local inv
  if player ~= nil then
    inv = minetest.get_inventory({type="player", name=player})
  else
    inv = minetest.get_inventory({type="node", pos})
  end
  -- Create ItemSTack to take from external inventory
  local item = ItemStack(item_name.." "..count)
  -- Check if there is enough of the item to take
  if inv:contains_item(inv_list, item) then
    -- Add item to NPC's inventory
    npc.add_item_to_inventory_itemstring(self, item)
    -- Add items to external inventory
    inv:remove_item(inv_list, item)
    return true
  end
  -- Not able to put on external inventory
  return false
end

function npc.actions.check_external_inventory_contains_item(args)
  local self = args.self
  local player = args.player
  local pos = args.pos
  local inv_list = args.inv_list
  local item_name = args.item_name
  local count = args.count
  local inv
  if player ~= nil then
    inv = minetest.get_inventory({type="player", name=player})
  else
    inv = minetest.get_inventory({type="node", pos})
  end

  -- Create ItemStack for checking the external inventory
  local item = ItemStack(item_name.." "..count)
  -- Check if inventory contains item
  return inv:contains_item(inv_list, item)
end

-- TODO: Refactor this function so that it uses a table to check
-- for doors instead of having separate logic for each door type
function npc.actions.get_openable_node_state(node, npc_dir)
  minetest.log("Node name: "..dump(node.name))
  local state = npc.actions.const.doors.state.CLOSED
  -- Check for default doors and gates
  local a_i1, a_i2 = string.find(node.name, "_a")
  -- Check for cottages gates
  local open_i1, open_i2 = string.find(node.name, "_close")
  -- Check for cottages half door
  local half_door_is_closed = false
  if node.name == "cottages:half_door" then
    half_door_is_closed = (node.param2 + 2) % 4 == npc_dir
  end
  if a_i1 == nil and open_i1 == nil and not half_door_is_closed then
    state = npc.actions.const.doors.state.OPEN
  end
  minetest.log("Door state: "..dump(state))
  return state
end

-- This function is used to open or close openable nodes.
-- Currently supported openable nodes are: any doors using the
-- default doors API, and the cottages mod gates and doors. 
function npc.actions.use_door(args)
  local self = args.self
  local pos = args.pos
  local action = args.action
  local dir = args.dir
  local node = minetest.get_node(pos)
  local state = npc.actions.get_openable_node_state(node, dir)

  local clicker = self.object
  if action ~= state then
    minetest.registered_nodes[node.name].on_rightclick(pos, node, clicker, nil, nil)
  end
end


---------------------------------------------------------------------------------------
-- Tasks functionality
---------------------------------------------------------------------------------------
-- Tasks are operations that require many actions to perform. Basic tasks, like
-- walking from one place to another, operating a furnace, storing or taking
-- items from a chest, are provided here.

-- This function allows a NPC to use a furnace using only items from
-- its own inventory. Fuel is not provided. Once the furnace is finished
-- with the fuel items the NPC will take whatever was cooked and whatever
-- remained to cook. The function received the position of the furnace
-- to use, and the item to cook in furnace. Item is an itemstring
function npc.actions.use_furnace(self, pos, item)
  -- Check if any item in the NPC inventory serve as fuel
  -- For now, just use some specific items as fuels
  local fuels = {"default:leaves", "default:tree", ""}
  -- Check if NPC has a fuel item
  for i = 1,2 do
    local fuel_item = npc.inventory_contains(self, fuels[i]) 
    local src_item = npc.inventory_contains(self, item)

    if fuel_item ~= nil and src_item ~= nil then
      -- Put this item on the fuel inventory list of the furnace
      local args = {
         self = self,
         player = nil, 
         pos = pos, 
         inv_list = "fuel",
         item_name = npc.get_item_name(fuel_item.item_string),
         count = npc.get_item_count(fuel_item.item_string)
      }
      npc.add_action(self, npc.actions.put_item_on_external_inventory, args)
      -- Put the item that we want to cook on the furnace
      args = {
         self = self,
         player = nil, 
         pos = pos, 
         inv_list = "src",
         item_name = npc.get_item_name(src_item.item_string),
         count = npc.get_item_count(src_item.item_string),
         is_furnace = true
      }
      npc.add_action(self, npc.actions.put_item_on_external_inventory, args)

      -- TODO: Need to add a way to calculate how many seconds will pass
      -- until the furnace is done, or at least the items that we expect
      -- to get (assume all items to be cooked are the ones ewe expect back)
      -- Then, add that many stand actions, then an action to take the items.


      return true
    end
  end
  -- Couldn't use the furnace due to lack of items
  return false
end

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, action can be lay or get up
function npc.actions.use_bed(self, pos, action)
  local node = minetest.get_node(pos)
  minetest.log(dump(node))
  local dir = minetest.facedir_to_dir(node.param2)

  if action == npc.actions.const.beds.LAY then
    -- Get position
    local bed_pos = npc.actions.nodes.beds[node.name].get_lay_pos(pos)
    -- Sit down on bed, rotate to correct direction
    npc.add_action(self, npc.actions.sit, {self=self, pos=bed_pos, dir=(node.param2 + 2) % 4})
    -- Lay down 
    npc.add_action(self, npc.actions.lay, {self=self})
  else
    -- Calculate position to get up
    local bed_pos = {x = pos.x, y = pos.y + 1, z = pos.z} 
    -- Sit up
    npc.add_action(self, npc.actions.sit, {self=self, pos=bed_pos})
    -- Initialize direction: Default is front of bottom of bed
    local dir = (node.param2 + 2) % 4
    -- Find empty node around node
    local empty_nodes = npc.places.find_node_orthogonally(bed_pos, {"air", "cottages:bench"}, -1)
    if empty_nodes ~= nil then
      -- Get direction to the empty node
      dir = npc.actions.get_direction(bed_pos, empty_nodes[1].pos)
    end
    -- Calculate position to get out of bed
    local pos_out_of_bed =
      {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
    -- Account for benches if they are present to avoid standing over them
    if empty_nodes[1].name == "cottages:bench" then
      pos_out_of_bed = {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
      if empty_nodes[1].param2 == 0 then
        pos_out_of_bed.z = pos_out_of_bed.z - 0.3
      elseif empty_nodes[1].param2 == 1 then
        pos_out_of_bed.x = pos_out_of_bed.x - 0.3
      elseif empty_nodes[1].param2 == 2 then
        pos_out_of_bed.z = pos_out_of_bed.z + 0.3
      elseif empty_nodes[1].param2 == 3 then
        pos_out_of_bed.x = pos_out_of_bed.x + 0.3
      end
    end
    -- Stand out of bed
    npc.add_action(self, npc.actions.stand, {self=self, pos=pos_out_of_bed, dir=dir})
  end
end

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, action can be lay or get up
function npc.actions.use_sittable(self, pos, action)
  local node = minetest.get_node(pos)

  if action == npc.actions.const.sittable.SIT then
    -- Calculate position depending on bench
    -- For cottages bench (code taken from Sokomine's cottages mod):
    local p2 = {x=pos.x, y=pos.y, z=pos.z};
    if not( node ) or node.param2 == 0 then
      p2.z = p2.z+0.3;
    elseif node.param2 == 1 then
      p2.x = p2.x+0.3;
    elseif node.param2 == 2 then
      p2.z = p2.z-0.3;
    elseif node.param2 == 3 then
      p2.x = p2.x-0.3;
    end
    -- For stairs (based on the above code):
    local p2 = {x=pos.x, y=pos.y, z=pos.z};
    if not( node ) or node.param2 == 0 then
      p2.z = p2.z-0.2;
    elseif node.param2 == 1 then
      p2.x = p2.x-0.2;
    elseif node.param2 == 2 then
      p2.z = p2.z+0.2;
    elseif node.param2 == 3 then
      p2.x = p2.x+0.2;
    end
    -- Sit down on bench/chair/stairs
    npc.add_action(self, npc.actions.sit, {self=self, pos=p2})
    -- Rotate to the correct position
    npc.add_action(self, npc.actions.rotate, {self=self, dir=node.param2 + 2 % 4})
  else
    -- Walk up from bed
    npc.add_action(self, npc.actions.walk_step, {self=self, dir=param2.param2 + 2 % 4})
    -- Stand
    npc.add_action(self, npc.actions.stand, {self=self})
  end
end

-- This function returns the direction enum
-- for the moving from v1 to v2
function npc.actions.get_direction(v1, v2)
  local dir = vector.subtract(v2, v1)
  if dir.x ~= 0 then
    if dir.x > 0 then
      return npc.direction.east
    else
      return npc.direction.west
    end
  elseif dir.z ~= 0 then
    if dir.z > 0 then
      return npc.direction.north
    else
      return npc.direction.south
    end
  end
end

-- This function can be used to make the NPC walk from one
-- position to another. If the optional parameter walkable_nodes
-- is included, which is a table of node names, these nodes are
-- going to be considered walkable for the algorithm to find a
-- path.
function npc.actions.walk_to_pos(self, end_pos, walkable_nodes)

  local start_pos = self.object:getpos()

  -- Set walkable nodes to empty if the parameter hasn't been used
  if walkable_nodes == nil then
    walkable_nodes = {}
  end

  -- Find path
  local path = pathfinder.find_path(start_pos, end_pos, 20, walkable_nodes)

  if path ~= nil then
    minetest.log("Found path to node: "..dump(end_pos))

    local door_opened = false

    -- Add steps to path
    for i = 1, #path do
      -- Do not add an extra step if reached the goal node
      if (i+1) == #path then
        -- Add direction to last node
        local dir = npc.actions.get_direction(path[i].pos, end_pos)
        -- Add stand animation at end
        npc.add_action(self, npc.actions.stand, {self = self, dir = dir})
        break
      end
      -- Get direction to move from path[i] to path[i+1]
      local dir = npc.actions.get_direction(path[i].pos, path[i+1].pos)
      -- Check if next node is a door, if it is, open it, then walk
      if path[i+1].type == pathfinder.node_types.openable then
        -- Check if door is already open
        local node = minetest.get_node(path[i+1].pos)
        if npc.actions.get_openable_node_state(node, dir) == npc.actions.const.doors.state.CLOSED then
          minetest.log("Opening action to open door")
          -- Stop to open door, this avoids misplaced movements later on
          npc.add_action(self, npc.actions.stand, {self=self, dir=dir})
          -- Open door
          npc.add_action(self, npc.actions.use_door, {self=self, pos=path[i+1].pos, dir=dir, action=npc.actions.const.doors.action.OPEN})

          door_opened = true
        end
      end
      -- Add walk action to action queue
      npc.add_action(self, npc.actions.walk_step, {self = self, dir = dir})

      if door_opened then
          -- Stop to close door, this avoids misplaced movements later on
          npc.add_action(self, npc.actions.stand, {self=self, dir=(dir + 2)% 4})
          -- Close door
          npc.add_action(self, npc.actions.use_door, {self=self, pos=path[i+1].pos, action=npc.actions.const.doors.action.CLOSE})

          door_opened = false
      end

    end
  else
    minetest.log("Unable to find path.")
  end
end


-- ATTENTION:
-- Old, deprecated, non-functional code below:
---------------------------------------------------------------------------------------
-- Path-finding code
---------------------------------------------------------------------------------------
-- This is the limit to search for a path based on the goal node.
-- If the path finder code goes beyond this limit in nodes away 
-- on the x or z plane, it will stop looking for a path
-- npc.actions.PATH_DIFF_LIMIT = 125

-- -- Returns the opposite of a vector (scalar multiplication by -1)
-- local function vector_opposite(v)
--   return vector.multiply(v, -1)
-- end

-- -- Returns a unit direction vector based on the largest coordinate
-- local function get_unit_dir_vector_based_on_diff(v)
--   if math.abs(v.x) > math.abs(v.z) then
--     return {x=(v.x/math.abs(v.x)) * -1, y=0, z=0}
--   elseif math.abs(v.z) > math.abs(v.x) then
--     return {x=0, y=0, z=(v.z/math.abs(v.z)) * -1}
--   elseif math.abs(v.x) == math.abs(v.z) then
--     return {x=(v.x/math.abs(v.x)) * -1, y=0, z=(v.z/math.abs(v.z)) * -1}
--   end
-- end

-- -- This function is used to determine if a node is walkable
-- -- or openable, in which case is good to use when finding a path
-- local function is_good_node(node)
--   -- Is openable is to support doors, fence gates and other
--   -- doors from other mods. Currently, default doors and gates
--   -- will be supported. Cottages doors should also be supported.
--   --minetest.log("Node name: "..dump(node.name))
--   local is_openable = false
--   local start_i,end_i = string.find(node.name, "doors:")
--   is_openable = start_i ~= nil
--   --minetest.log("Is node openable: "..dump(is_openable))
--   --minetest.log("Is node walkable: "..dump(not minetest.registered_nodes[node.name].walkable))
--   if not minetest.registered_nodes[node.name].walkable then
--     return "W"
--   elseif is_openable then
--     return "O"
--   else
--     return "N"
--   end
-- end

-- -- Finds paths ignoring vertical obstacles
-- -- This function is recursive and attempts to move all the time on
-- -- the direction that will definetely lead to the end position.
-- local function find_path_recursive(start_pos, end_pos, path_nodes, last_dir, last_good_dir, last_good_try)
--   minetest.log("Start pos: "..dump(start_pos))

--   -- Find difference. The purpose of this is to weigh movement, attempting
--   -- the largest difference first, or both if equal.
--   local diff = vector.subtract(start_pos, end_pos)

--   minetest.log("Difference: "..dump(diff))

--   -- End if difference is larger than max difference possible (limit)
--   if math.abs(diff.x) > npc.actions.PATH_DIFF_LIMIT 
--     or math.abs(diff.z) > npc.actions.PATH_DIFF_LIMIT then
--     minetest.log("Can't find feasable path.")
--     -- Cannot find feasable path
--     return nil
--   end
--   -- Determine direction to move
--   local dir_vector = get_unit_dir_vector_based_on_diff(diff)

--   minetest.log("Direction vector: "..dump(dir_vector))

--   if last_dir ~= nil then
--     if last_good_try == 4 
--       or (dir_vector.x ~= 0 and dir_vector.z ~=0)
--       -- Attention: Hacks below! The magic number 3 could be just extremely wrong.
--       -- This is a terrible hack based on experimentations :(
--       or (dir_vector.x ~= 0 and last_dir.x == 0 and math.abs(diff.x) > math.abs(diff.z) and math.abs(diff.z) < 3)
--       or (dir_vector.z ~= 0 and last_dir.z == 0 and math.abs(diff.z) > math.abs(diff.x) and math.abs(diff.x) < 3) then
--       if last_dir.x ~= 0 and diff.x ~= 0 
--         or last_dir.z ~= 0 and diff.z ~= 0 then
--         minetest.log("Using last dir as direction vector: "..dump(last_dir))
--         dir_vector = last_dir
--       end
--     end
--   end

--   if last_good_dir ~= nil then
--     minetest.log("Using last good dir as direction vector: "..dump(last_good_dir))
--     dir_vector = last_good_dir
--   end

--   -- Get next position based on direction
--   local next_pos = vector.add(start_pos, dir_vector)

--   minetest.log("Next pos: "..dump(next_pos))

--   -- Check if next_pos is actually within one block from the
--   -- expected position. If so, finish
--   local diff_to_end = vector.subtract(next_pos, end_pos)
--   if math.abs(diff_to_end.x) < 1 and math.abs(diff_to_end.y) < 1 and math.abs(diff_to_end.z) < 1 then
--     minetest.log("Diff to end: "..dump(diff_to_end))
--     table.insert(path_nodes, {pos=next_pos, type="E"})
--     minetest.log("Found path to end.")
--     return path_nodes
--   end
--   -- Check if movement is possible on the calculated direction
--   local next_node = minetest.get_node(next_pos)
--   -- If direction vector is opposite to the last dir, then do not attempt to walk into it
--   minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
--   local attempted_to_go_opposite = false
--   if last_dir ~= nil and vector.equals(dir_vector, vector_opposite(last_dir)) then
--     attempted_to_go_opposite = true
--     minetest.log("Last dir: "..dump(last_dir))
--     minetest.log("Calculated dir vector is the opposite of last dir: "..dump(vector.equals(dir_vector, vector_opposite(last_dir))))
--   end

--   local node_type = is_good_node(next_node)
--   if node_type ~= "N" and (not attempted_to_go_opposite) then
--     table.insert(path_nodes, {pos=next_pos, type=node_type})
--     return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, nil, 1)
--   else
--     minetest.log("------------ Second attempt ------------")
    
--     -- If not walkable, attempt turn into the other coordinate
--     -- Determine this coordinate based on what was the last calculated direction
--     -- that didn't needed correction (last good dir). If this doesn't exists (e.g.
--     -- there has been no correction for a while) then select the direction by
--     -- trying to shorten the distance between NPC and the end node.



--     minetest.log("Last known good dir: "..dump(last_good_dir))
--     local step = 0
--     if last_good_dir == nil then
--       -- Store the current direction vector as the last non-corrected
--       -- calculated direction
--       last_good_dir = dir_vector

--       -- Determine which direction to move 
--       if dir_vector.x == 0 then
--         minetest.log("Choosing x direction")
--         step = diff.x/math.abs(diff.x) * -1
--         if diff.x == 0 then
--           if last_dir ~= nil and last_dir.x ~= 0 then--and last_good_try == 2 then
--             step = last_dir.x
--           else
--             -- Set a default step to avoid locks
--             step = 1
--           end
--         end
--         dir_vector = {x = step, y = 0, z = 0}
--       elseif dir_vector.z == 0 then
--         step = diff.z/math.abs(diff.z) * -1
--         if diff.z == 0 then
--           if last_dir ~= nil and last_dir.z ~= 0 then -- and last_good_try == 2 then
--             step = last_dir.z
--           else
--             -- Set a default step to avoid locks
--             step = 1
--           end
--         end
--         dir_vector = {x = 0, y = 0, z = step}
--       end
--       minetest.log("Re-calculated dir vector: "..dump(dir_vector))
--       next_pos = vector.add(start_pos, dir_vector)
--     else
--       dir_vector = last_good_dir
--       if dir_vector.x == 0 then
--         minetest.log("Moving into x direction")
--         step = last_dir.x
--       elseif dir_vector.z == 0 then
--         minetest.log("Moving into z direction")
--         step = last_dir.z
--       end
--       dir_vector = last_dir
--       next_pos = vector.add(start_pos, dir_vector)
--     end

--     -- Check if new node is walkable
--     next_node = minetest.get_node(next_pos)

--     minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))

--     local node_type = is_good_node(next_node)
--     if node_type ~= "N" then
--       table.insert(path_nodes, {pos=next_pos, type=node_type})
--       return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, last_good_dir, 2)
--     else

--       minetest.log("Last known good dir: "..dump(last_good_dir))
--       -- Only pick the second attempt's dir if it was actually good (meaning,
--       -- it could step on that dir)
--       if last_good_try == 2 then
--         last_good_dir = dir_vector
--       end
--       minetest.log("------------ Third attempt ------------")

--       -- If not walkable, then try the next node by finding the original
--       -- direction vector, then choosing the opposite of that.

--       minetest.log("Last dir: "..dump(last_dir))
--       minetest.log("Last good try: "..dump(last_good_try))
--       minetest.log("Last attempted direction: "..dump(dir_vector))

--       if vector.equals(last_good_dir, last_dir) then
--         -- Go opposite the direction of second attempt
--         minetest.log("Moving opposite of last attempted")
--         dir_vector = vector.multiply(dir_vector, -1)
--       else
--         minetest.log("Moving opposite of last good dir")
--         dir_vector = vector.multiply(last_good_dir, -1)
--         last_good_dir = last_dir
--       end

  
--       -- if last_good_try > 1 or vector.equals(last_good_dir, last_dir) then
--       --   if dir_vector.x ~= 0 then
--       --     minetest.log("Move into opposite z dir")
--       --     dir_vector = get_unit_dir_vector_based_on_diff(diff)
--       --     dir_vector = vector.multiply(dir_vector, -1)
--       --   elseif dir_vector.z ~= 0 then
--       --     minetest.log("Move into opposite x dir")
--       --     dir_vector = get_unit_dir_vector_based_on_diff(diff)
--       --     dir_vector = vector.multiply(dir_vector, -1)
--       --   end
--       -- else
--       --   minetest.log("Stuck in corner, try to move out of corner")
--       --   dir_vector = vector.multiply(last_good_dir, -1)
--       --   last_good_dir = last_dir
--       -- end
--       minetest.log("New direction: "..dump(dir_vector))
--       minetest.log("New last good dir: "..dump(last_good_dir))

--       next_pos = vector.add(start_pos, dir_vector)
--       minetest.log("New next_pos: "..dump(next_pos))
--       next_node = minetest.get_node(next_pos)
--       minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
--       local node_type = is_good_node(next_node)
--       if node_type ~= "N" then
--         table.insert(path_nodes, {pos=next_pos, type=node_type})
--         return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, last_good_dir, 3)
--       else
--         -- Move into the opposite of last good dir
--         minetest.log("------------ Fourth attempt ------------")
--         minetest.log("Last known good dir: "..dump(old_last_good_dir))

--         local old_dir_vector = dir_vector
--         -- If not walkable, then try moving into the opposite of last good dir
--         dir_vector = vector.multiply(last_good_dir, -1)
--         minetest.log("New direction: "..dump(dir_vector))

--         next_pos = vector.add(start_pos, dir_vector)
--         minetest.log("New next_pos: "..dump(next_pos))
--         next_node = minetest.get_node(next_pos)
--         minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
--         local node_type = is_good_node(next_node)
--         if node_type ~= "N" then
--           table.insert(path_nodes, {pos=next_pos, type=node_type})
--           return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, old_dir_vector, 4)
--         else
--           minetest.log("Attempted to rotate 4 times, can't do anything else")
--           return nil
--         end
--       end
--     end
--   end

-- end

-- -- Calls the recursive function to calculate the path
-- function npc.actions.find_path(start_pos, end_pos)
--   return find_path_recursive(start_pos, end_pos, {}, nil, nil, 0)
-- end