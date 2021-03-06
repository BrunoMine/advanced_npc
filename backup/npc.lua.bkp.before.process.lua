--
-- Created by IntelliJ IDEA.
-- User: hfranqui
-- Date: 3/8/18
-- Time: 9:21 AM
-- To change this template use File | Settings | File Templates.
--

-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1

local S = mobs.intllib

npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"

npc.age = {
    adult = "adult",
    child = "child"
}

npc.INVENTORY_ITEM_MAX_STACK = 99

npc.ANIMATION_STAND_START = 0
npc.ANIMATION_STAND_END = 79
npc.ANIMATION_SIT_START = 81
npc.ANIMATION_SIT_END = 160
npc.ANIMATION_LAY_START = 162
npc.ANIMATION_LAY_END = 166
npc.ANIMATION_WALK_START = 168
npc.ANIMATION_WALK_END = 187
npc.ANIMATION_MINE_START = 189
npc.ANIMATION_MINE_END =198

npc.direction = {
    north = 0,
    east  = 1,
    south = 2,
    west  = 3,
    north_east = 4,
    north_west = 5,
    south_east = 6,
    south_west = 7
}

npc.action_state = {
    none = 0,
    executing = 1,
    interrupted = 2
}

npc.log_level = {
    INFO = true,
    WARNING = true,
    ERROR = true,
    DEBUG = false,
    DEBUG_ACTION = false,
    DEBUG_SCHEDULE = false
}

npc.texture_check = {
    timer = 0,
    interval = 2
}

---------------------------------------------------------------------------------------
-- General functions
---------------------------------------------------------------------------------------
-- Logging
function npc.log(level, message)
    if npc.log_level[level] then
        minetest.log("[advanced_npc] "..level..": "..message)
    end
end

-- NPC chat
function npc.chat(npc_name, player_name, message)
    minetest.chat_send_player(player_name, npc_name..": "..message)
end

-- Simple wrapper over minetest.add_particle()
-- Copied from mobs_redo/api.lua
function npc.effect(pos, amount, texture, min_size, max_size, radius, gravity, glow)

    radius = radius or 2
    min_size = min_size or 0.5
    max_size = max_size or 1
    gravity = gravity or -10
    glow = glow or 0

    minetest.add_particlespawner({
        amount = amount,
        time = 0.25,
        minpos = pos,
        maxpos = pos,
        minvel = {x = -radius, y = -radius, z = -radius},
        maxvel = {x = radius, y = radius, z = radius},
        minacc = {x = 0, y = gravity, z = 0},
        maxacc = {x = 0, y = gravity, z = 0},
        minexptime = 0.1,
        maxexptime = 1,
        minsize = min_size,
        maxsize = max_size,
        texture = texture,
        glow = glow,
    })
end

-- Gets name of player or NPC
function npc.get_entity_name(entity)
    if entity:is_player() then
        return entity:get_player_name()
    else
        return entity:get_luaentity().name
    end
end

-- Returns the item "wielded" by player or NPC
-- TODO: Implement NPC
function npc.get_entity_wielded_item(entity)
    if entity:is_player() then
        return entity:get_wielded_item()
    end
end

---------------------------------------------------------------------------------------
-- Spawning functions
---------------------------------------------------------------------------------------
-- These functions are used at spawn time to determine several
-- random attributes for the NPC in case they are not already
-- defined. On a later phase, pre-defining many of the NPC values
-- will be allowed.

local function get_random_name(sex)
    local i = math.random(#npc.data.FIRST_NAMES[sex])
    return npc.data.FIRST_NAMES[sex][i]
end

local function initialize_inventory()
    return {
        [1] = "",  [2] = "",  [3] = "",  [4] = "",
        [5] = "",  [6] = "",  [7] = "",  [8] = "",
        [9] = "",  [10] = "", [11] = "", [12] = "",
        [13] = "", [14] = "", [15] = "", [16] = "",
    }
end

-- This function checks for "female" text on the texture name
local function is_female_texture(textures)
    for i = 1, #textures do
        if string.find(textures[i], "female") ~= nil then
            return true
        end
    end
    return false
end

function npc.assign_sex_from_texture(self)
    if is_female_texture(self.base_texture) then
        return npc.FEMALE
    else
        return npc.MALE
    end
end

local function get_random_texture(sex, age)
    local textures = {}
    local filtered_textures = {}
    -- Find textures by sex and age
    if age == npc.age.adult then
        --minetest.log("Registered: "..dump(minetest.registered_entities["advanced_npc:npc"]))
        textures = minetest.registered_entities["advanced_npc:npc"].texture_list
    elseif age == npc.age.child then
        textures = minetest.registered_entities["advanced_npc:npc"].child_texture
    end

    for i = 1, #textures do
        local current_texture = textures[i][1]
        if (sex == npc.MALE
                and string.find(current_texture, sex)
                and not string.find(current_texture, npc.FEMALE))
                or (sex == npc.FEMALE
                and string.find(current_texture, sex)) then
            table.insert(filtered_textures, current_texture)
        end
    end

    -- Check if filtered textures is empty
    if filtered_textures == {} then
        return textures[1][1]
    end

    return filtered_textures[math.random(1,#filtered_textures)]
end

function npc.get_random_texture_from_array(age, sex, textures)
    local filtered_textures = {}

    for i = 1, #textures do
        local current_texture = textures[i]
        -- Filter by age
        if (sex == npc.MALE
                and string.find(current_texture, sex)
                and not string.find(current_texture, npc.FEMALE)
                and ((age == npc.age.adult
                and not string.find(current_texture, npc.age.child))
                or (age == npc.age.child
                and string.find(current_texture, npc.age.child))
        )
        )
                or (sex == npc.FEMALE
                and string.find(current_texture, sex)
                and ((age == npc.age.adult
                and not string.find(current_texture, npc.age.child))
                or (age == npc.age.child
                and string.find(current_texture, npc.age.child))
        )
        ) then
            table.insert(filtered_textures, current_texture)
        end
    end

    -- Check if there are no textures
    if #filtered_textures == 0 then
        -- Return whole array for re-evaluation
        npc.log("DEBUG", "No textures found, returning original array")
        return textures
    end

    return filtered_textures[math.random(1, #filtered_textures)]
end

-- Choose whether NPC can have relationships. Only 30% of NPCs
-- cannot have relationships
local function can_have_relationships(is_child)
    -- Children can't have relationships
    if is_child then
        return false
    end
    local chance = math.random(1,10)
    return chance > 3
end

-- Choose a maximum of two items that the NPC will have at spawn time
-- These items are chosen from the favorite items list.
local function choose_spawn_items(self)
    local number_of_items_to_add = math.random(1, 2)
    local number_of_items = #npc.FAVORITE_ITEMS[self.sex].phase1

    for i = 1, number_of_items_to_add do
        npc.add_item_to_inventory(
            self,
            npc.FAVORITE_ITEMS[self.sex].phase1[math.random(1, number_of_items)].item,
            math.random(1,5)
        )
    end
    -- Add currency to the items spawned with. Will add 5-10 tier 3
    -- currency items
    local currency_item_count = math.random(5, 10)
    npc.add_item_to_inventory(self, npc.trade.prices.currency.tier3.string, currency_item_count)

    -- For test
    --npc.add_item_to_inventory(self, "default:tree", 10)
    --npc.add_item_to_inventory(self, "default:cobble", 10)
    --npc.add_item_to_inventory(self, "default:diamond", 2)
    --npc.add_item_to_inventory(self, "default:mese_crystal", 2)
    --npc.add_item_to_inventory(self, "flowers:rose", 2)
    --npc.add_item_to_inventory(self, "advanced_npc:marriage_ring", 2)
    --npc.add_item_to_inventory(self, "flowers:geranium", 2)
    --npc.add_item_to_inventory(self, "mobs:meat", 2)
    --npc.add_item_to_inventory(self, "mobs:leather", 2)
    --npc.add_item_to_inventory(self, "default:sword_stone", 2)
    --npc.add_item_to_inventory(self, "default:shovel_stone", 2)
    --npc.add_item_to_inventory(self, "default:axe_stone", 2)

    --minetest.log("Initial inventory: "..dump(self.inventory))
end

-- Spawn function. Initializes all variables that the
-- NPC will have and choose random, starting values
function npc.initialize(entity, pos, is_lua_entity, npc_stats, occupation_name)
    npc.log("INFO", "Initializing NPC at "..minetest.pos_to_string(pos))

    -- Get variables
    local ent = entity
    if not is_lua_entity then
        ent = entity:get_luaentity()
    end

    -- Avoid NPC to be removed by mobs_redo API
    ent.remove_ok = false

    -- Flag that enables/disables right-click interaction - good for moments where NPC
    -- can't be disturbed
    ent.enable_rightclick_interaction = true

    -- Determine sex and age
    -- If there's no previous NPC data, sex and age will be randomly chosen.
    --   - Sex: Female or male will have each 50% of spawning
    --   - Age: 90% chance of spawning adults, 10% chance of spawning children.
    -- If there is previous data then:
    --   - Sex: The unbalanced sex will get a 75% chance of spawning
    --          - Example: If there's one male, then female will have 75% spawn chance.
    --          -          If there's male and female, then each have 50% spawn chance.
    --   - Age: For each two adults, the chance of spawning a child next will be 50%
    --          If there's a child for two adults, the chance of spawning a child goes to
    --          40% and keeps decreasing unless two adults have no child.
    -- Use NPC stats if provided
    if npc_stats then
        -- Default chances
        local male_s, male_e = 0, 50
        local female_s, female_e = 51, 100
        local adult_s, adult_e = 0, 85
        local child_s, child_e = 86, 100
        -- Determine sex probabilities
        if npc_stats[npc.FEMALE].total > npc_stats[npc.MALE].total then
            male_e = 75
            female_s, female_e = 76, 100
        elseif npc_stats[npc.FEMALE].total < npc_stats[npc.MALE].total then
            male_e = 25
            female_s, female_e = 26, 100
        end
        -- Determine age probabilities
        if npc_stats["adult_total"] >= 2 then
            if npc_stats["adult_total"] % 2 == 0
                    and (npc_stats["adult_total"] / 2 > npc_stats["child_total"]) then
                child_s,child_e = 26, 100
                adult_e = 25
            else
                child_s, child_e = 61, 100
                adult_e = 60
            end
        end
        -- Get sex and age based on the probabilities
        local sex_chance = math.random(1, 100)
        local age_chance = math.random(1, 100)
        local selected_sex = ""
        local selected_age = ""
        -- Select sex
        if male_s <= sex_chance and sex_chance <= male_e then
            selected_sex = npc.MALE
        elseif female_s <= sex_chance and sex_chance <= female_e then
            selected_sex = npc.FEMALE
        end
        -- Set sex for NPC
        ent.sex = selected_sex
        -- Select age
        if adult_s <= age_chance and age_chance <= adult_e then
            selected_age = npc.age.adult
        elseif child_s <= age_chance and age_chance <= child_e then
            selected_age = npc.age.child
            ent.visual_size = {
                x = 0.65,
                y = 0.65
            }
            ent.collisionbox = {-0.10,-0.50,-0.10, 0.10,0.40,0.10}
            ent.is_child = true
            -- For mobs_redo
            ent.child = true
        end
        -- Store the selected age
        ent.age = selected_age

        -- Set texture accordingly
        local selected_texture = get_random_texture(selected_sex, selected_age)
        --minetest.log("Selected texture: "..dump(selected_texture))
        -- Store selected texture due to the need to restore it later
        ent.selected_texture = selected_texture
        -- Set texture and base texture
        ent.textures = {selected_texture}
        ent.base_texture = {selected_texture}
    else
        -- Get sex based on texture. This is a 50% chance for
        -- each sex as there's same amount of textures for male and female.
        -- Do not spawn child as first NPC
        ent.sex = npc.assign_sex_from_texture(ent)
        ent.age = npc.age.adult
    end

    -- Initialize all gift data
    ent.gift_data = {
        -- Choose favorite items. Choose phase1 per default
        favorite_items = npc.relationships.select_random_favorite_items(ent.sex, "phase1"),
        -- Choose disliked items. Choose phase1 per default
        disliked_items = npc.relationships.select_random_disliked_items(ent.sex),
        -- Enable/disable gift item hints dialogue lines
        enable_gift_items_hints = true
    }

    -- Flag that determines if NPC can have a relationship
    ent.can_have_relationship = can_have_relationships(ent.is_child)

    --ent.infotext = "Interested in relationships: "..dump(ent.can_have_relationship)

    -- Flag to determine if NPC can receive gifts
    ent.can_receive_gifts = ent.can_have_relationship

    -- Initialize relationships object
    ent.relationships = {}

    -- Determines if NPC is married or not
    ent.is_married_to = nil

    -- Initialize dialogues
    ent.dialogues = npc.dialogue.select_random_dialogues_for_npc(ent, "phase1")

    -- Declare NPC inventory
    ent.inventory = initialize_inventory()

    -- Choose items to spawn with
    choose_spawn_items(ent)

    -- Flags: generic booleans or functions that help drive functionality
    ent.flags = {}

    -- Declare trade data
    ent.trader_data = {
        -- Type of trader
        trader_status = npc.trade.get_random_trade_status(),
        -- Current buy offers
        buy_offers = {},
        -- Current sell offers
        sell_offers = {},
        -- Items to buy change timer
        change_offers_timer = 0,
        -- Items to buy change timer interval
        change_offers_timer_interval = 60,
        -- Trading list: a list of item names the trader is expected to trade in.
        -- It is mostly related to its occupation.
        -- If empty, the NPC will revert to casual trading
        -- If not, it will try to sell those that it have, and buy the ones it not.
        trade_list = {},
        -- Custom trade allows to specify more than one payment
        -- and a custom prompt (instead of the usual buy or sell prompts)
        custom_trades = {}
    }

    -- Initialize trading offers for NPC
    --npc.trade.generate_trade_offers_by_status(ent)
    -- if ent.trader_data.trader_status == npc.trade.CASUAL then
    --   select_casual_trade_offers(ent)
    -- end

    --	-- Actions data
    --	ent.actions = {
    --		-- The queue is a queue of actions to be performed on each interval
    --		queue = {},
    --		-- Current value of the action timer
    --		action_timer = 0,
    --		-- Determines the interval for each action in the action queue
    --		-- Default is 1. This can be changed via actions
    --		action_interval = npc.commands.default_interval,
    --		-- Avoid the execution of the action timer
    --		action_timer_lock = false,
    --		-- Defines the state of the current action
    --		current_action_state = npc.action_state.none,
    --		-- Store information about action on state before lock
    --		state_before_lock = {
    --			-- State of the mobs_redo API
    --			freeze = false,
    --			-- State of execution
    --			action_state = npc.action_state.none,
    --			-- Action executed while on lock
    --			interrupted_action = {}
    --		},
    --		-- Variables that allows preserving the movement state and NPC animation
    --		move_state = {
    --			-- Whether a NPC is sitted or not
    --			is_sitting = false,
    --			-- Whether a NPC is laying or not
    --			is_laying = false
    --		},
    --		-- Walking variables -- required for implementing accurate movement code
    --		walking = {
    --			-- Defines whether NPC is walking to specific position or not
    --			is_walking = false,
    --			-- Path that the NPC is following
    --			path = {},
    --			-- Target position the NPC is supposed to walk to in this step. NOTE:
    --			-- This is NOT the end of the path, but the next position in the path
    --			-- relative to the last position
    --			target_pos = {}
    --		},
    --        -- Information about currently scripts being currently executed
    --        execution = {
    --            -- Unique ID for a executed script
    --            id = 0,
    --            -- Name of current script being executed
    --            current_script_name = "",
    --            -- Execution context - map of scripts and data associated to scripts
    --            -- The key is the script name and an ID, held in execution_id. The data
    --            -- is:
    --            --   {
    --            --      args = {}, -- Stores the arguments the script was called with
    --            --      data = {}, -- Map that stores custom variables created by script
    --            --      backup = {}, -- Queue of commands before script was executed
    --            --   }
    --            context = {},
    --            -- Execution options
    --            options = {
    --                allow_rightclick_interaction = true,
    --                allow_punch_interaction = true,
    --                allow_scheduler_interruption = true,
    --            },
    --            script_interruption = {
    --                interrupted_script_context_key = "",
    --                interrupted_script_name = "",
    --
    --                interrupted_execution_id = 0
    --            }
    --        },
    --	}

    -- To model and control behavior of a NPC, advanced_npc follows an OS model
    -- where it allows developers to create processes. These processes executes
    -- programs, or a group of instructions that together make the NPC do something,
    -- e.g. follow a player, use a furnace, etc. The model is:
    --   - Each process has:
    --     - An `execution context`, which is memory to store variables
    --     - An `instruction queue`, which is a queue with the program instructions
    --       to execute
    --     - A `state`, whether the process is running or is paused
    --   - Processes can specify whether they allow interruptions or not. They also
    --     can opt to handle the interruption with a callback. The possible
    --     interruptions are:
    --     - Punch interruption
    --     - Rightclick interruption
    --     - Schedule interruption
    --   - Only one process can run at a time. If another process is executed,
    --     the currently running process is paused, and restored when the other ends.
    --   - Processes can be enqueued, so once the executing process finishes, the
    --     next one in the queue can be started.
    --   - One process, called the `state` process, will run by default when no
    --     processes are executing.
    ent.execution = {
        -- Queue of processes
        process_queue = {},
        -- State process
        state_process = {},
        -- Whether to enable process execution or not
        enable = true,
        -- Interval to run process queue scheduler
        scheduler_interval = 1,
        -- Timer for next scheduler interval
        scheduler_timer = 0
    }

    ent.npc_state = {
        -- This table defines the types of interaction the NPC is performing
        interaction = {
            dialogues = {
                is_in_dialogue = false,
                in_dialogue_with = "",
                in_dialogue_with_name = ""
            },
        },
        movement = {
            is_idle = false,
            is_walking = false,
            is_sitting = false,
            is_laying = false,
        },
        following = {
            is_following = false,
            following_obj = "",
            following_obj_name = ""
        }
    }

    -- The state of a NPC is a process that will be run every time the
    -- execution queue and the process queue is empty.
    --    ent.npc_state = {
    --        -- The following is a script entry, set by npc.set_state_script()
    --        -- Note, this should be a blank table. Below option is temporary
    --        script = {command="advanced_npc:idle", args={acknowledge_nearby_objs=true}, is_script=true, is_state_script=true},
    --		-- Indicates whether the state script is exeucting or not
    --        is_state_script_executing = false,
    --		-- State script context key. Changes everytime the "npc.set_state_script()" function
    --		-- is called.
    --		context_key = "",
    --        -- This table defines the types of interaction the NPC is performing
    --        interaction = {
    --            dialogues = {
    --                is_in_dialogue = false,
    --                in_dialogue_with = "",
    --                in_dialogue_with_name = ""
    --            },
    --        },
    --        movement = {
    --            is_idle = false,
    --            is_walking = false,
    --            is_sitting = false,
    --            is_laying = false,
    --        },
    --        following = {
    --            is_following = false,
    --            following_obj = "",
    --            following_obj_name = ""
    --        }
    --    }

    -- This flag is checked on every step. If it is true, the rest of
    -- Mobs Redo API is not executed
    ent.freeze = nil

    -- This map will hold all the places for the NPC
    -- Map entries should be like: "bed" = {x=1, y=1, z=1}
    ent.places_map = {}

    -- Schedule data
    ent.schedules = {
        -- Flag to enable or disable the schedules functionality
        enabled = true,
        -- Lock for when executing a schedule
        lock = false,
        -- Queue of schedules executed
        -- Used to calculate dependencies
        temp_executed_queue = {},
        -- An array of schedules, meant to be one per day at some point
        -- when calendars are implemented. Allows for only 7 schedules,
        -- one for each day of the week
        generic = {},
        -- An array of schedules, meant to be for specific dates in the
        -- year. Can contain as many as possible. The keys will be strings
        -- in the format MM:DD
        date_based = {},
        -- The following holds the check parameters provided by the
        -- current schedule
        current_check_params = {}
    }

    -- If occupation name given, override properties with
    -- occupation values and initialize schedules
    if occupation_name and occupation_name ~= "" and ent.age == npc.age.adult then
        -- Set occupation name
        ent.occupation_name = occupation_name
        -- Override relevant values
        npc.occupations.initialize_occupation_values(ent, occupation_name)
    end

    -- Nametag is initialized to blank
    ent.nametag = ""

    -- Set name
    ent.npc_name = get_random_name(ent.sex)

    -- Set ID
    ent.npc_id = tostring(math.random(1000, 9999))..":"..ent.npc_name

    -- Generate trade offers
    npc.trade.generate_trade_offers_by_status(ent)

    -- Set initialized flag on
    ent.initialized = true
    --npc.log("WARNING", "Spawned entity: "..dump(ent))
    npc.log("INFO", "Successfully initialized NPC with name "..dump(ent.npc_name)
            ..", sex: "..ent.sex..", is child: "..dump(ent.is_child)
            ..", texture: "..dump(ent.textures))
    -- Refreshes entity
    ent.object:set_properties(ent)
end

---------------------------------------------------------------------------------------
-- Trading functions
---------------------------------------------------------------------------------------
function npc.generate_trade_list_from_inventory(self)
    local list = {}
    for i = 1, #self.inventory do
        list[npc.get_item_name(self.inventory[i])] = {}
    end
    self.trader_data.trade_list = list
end

function npc.set_trading_status(self, status)
    --minetest.log("Trader_data: "..dump(self.trader_data))
    -- Set status
    self.trader_data.trader_status = status
    -- Re-generate trade offers
    npc.trade.generate_trade_offers_by_status(self)
end

---------------------------------------------------------------------------------------
-- Inventory functions
---------------------------------------------------------------------------------------
-- NPCs inventories are restrained to 16 slots.
-- Each slot can hold one item up to 99 count.

-- Utility function to get item name from a string
function npc.get_item_name(item_string)
    return ItemStack(item_string):get_name()
end

-- Utility function to get item count from a string
function npc.get_item_count(item_string)
    return ItemStack(item_string):get_count()
end

-- Add an item to inventory. Returns true if add successful
-- These function can be used to give items to other NPCs
-- given that the "self" variable can be any NPC
function npc.add_item_to_inventory(self, item_name, count)
    -- Check if NPC already has item
    local existing_item = npc.inventory_contains(self, item_name)
    if existing_item ~= nil and existing_item.item_string ~= nil then
        -- NPC already has item. Get count and see
        local existing_count = npc.get_item_count(existing_item.item_string)
        if (existing_count + count) < npc.INVENTORY_ITEM_MAX_STACK then
            -- Set item here
            self.inventory[existing_item.slot] =
            npc.get_item_name(existing_item.item_string).." "..tostring(existing_count + count)
            return true
        else
            --Find next free slot
            for i = 1, #self.inventory do
                if self.inventory[i] == "" then
                    -- Found slot, set item
                    self.inventory[i] =
                    item_name.." "..tostring((existing_count + count) - npc.INVENTORY_ITEM_MAX_STACK)
                    return true
                end
            end
            -- No free slot found
            return false
        end
    else
        -- Find a free slot
        for i = 1, #self.inventory do
            if self.inventory[i] == "" then
                -- Found slot, set item
                self.inventory[i] = item_name.." "..tostring(count)
                return true
            end
        end
        -- No empty slot found
        return false
    end
end

-- Same add method but with itemstring for convenience
function npc.add_item_to_inventory_itemstring(self, item_string)
    local item_name = npc.get_item_name(item_string)
    local item_count = npc.get_item_count(item_string)
    npc.add_item_to_inventory(self, item_name, item_count)
end

-- Checks if an item is contained in the inventory. Returns
-- the item string or nil if not found
function npc.inventory_contains(self, item_name)
    for key,value in pairs(self.inventory) do
        if value ~= "" and string.find(value, item_name) then
            return {slot=key, item_string=value}
        end
    end
    -- Item not found
    return nil
end

-- Removes the item from an NPC inventory and returns the item
-- with its count (as a string, e.g. "default:apple 2"). Returns
-- nil if unable to get the item.
function npc.take_item_from_inventory(self, item_name, count)
    local existing_item = npc.inventory_contains(self, item_name)
    if existing_item ~= nil then
        -- Found item
        local existing_count = npc.get_item_count(existing_item.item_string)
        local new_count = existing_count
        if existing_count - count  < 0 then
            -- Remove item first
            self.inventory[existing_item.slot] = ""
            -- TODO: Support for retrieving from next stack. Too complicated
            -- and honestly might be unecessary.
            return item_name.." "..tostring(new_count)
        else
            new_count = existing_count - count
            if new_count == 0 then
                self.inventory[existing_item.slot] = ""
            else
                self.inventory[existing_item.slot] = item_name.." "..new_count
            end
            return item_name.." "..tostring(count)
        end
    else
        -- Not able to take item because not found
        return nil
    end
end

-- Same take method but with itemstring for convenience
function npc.take_item_from_inventory_itemstring(self, item_string)
    local item_name = npc.get_item_name(item_string)
    local item_count = npc.get_item_count(item_string)
    npc.take_item_from_inventory(self, item_name, item_count)
end

---------------------------------------------------------------------------------------
-- Flag functionality
---------------------------------------------------------------------------------------
-- TODO: Consider removing them as they are pretty simple and straight forward.
-- Generic variables or function that help drive some functionality for the NPC.
function npc.add_flag(self, flag_name, value)
    self.flags[flag_name] = value
end

function npc.update_flag(self, flag_name, value)
    self.flags[flag_name] = value
end

function npc.get_flag(self, flag_name)
    return self.flags[flag_name]
end

---------------------------------------------------------------------------------------
-- Dialogue functionality
---------------------------------------------------------------------------------------
function npc.start_dialogue(self, clicker, show_married_dialogue)

    -- Call dialogue function as normal
    npc.dialogue.start_dialogue(self, clicker, show_married_dialogue)

    -- Check and update relationship if needed
    npc.relationships.dialogue_relationship_update(self, clicker)

end

---------------------------------------------------------------------------------------
-- Execution API
---------------------------------------------------------------------------------------
-- Methods for:
--  - Enqueue a program
--  - Set a program as the `state` process
--  - Execute next process in queue
--  - Pause/restore current process
--  - Process scheduling
--  - Get the current process data
--  - Create, read, write and update variables in current process
--  - Enqueue and execute instructions for the current process


-- Global namespace
npc.exec = {
    var = {}
proc = {}
}
-- Private namespace
local _exec = {}

-- Process states
npc.exec.proc.state = {
    INACTIVE = "inactive",
    RUNNING = "running",
    PAUSED = "paused",
    BLOCKED = "blocked"
}

npc.exec.proc.instr.state = {
    INACTIVE = "inactive",
    EXECUTING = "executing",
    INTERRUPTED = "interrupted"
}

-- This function creates a process for the given program, and
-- places it into the process queue.
function npc.exec.enqueue_program(self, program_name, arguments, interrupt_options)

    local process_entry = {
        program_name = program_name,
        arguments = arguments,
        state = npc.exec.proc.state.INACTIVE,
        execution_context = {
            data = {},
            instr_interval = 1,
            instr_timer = 0
        },
        instruction_queue = {},
        current_instruction = {
            entry = {},
            state = npc.exec.proc.instr.state.INACTIVE,
            pos = {}
        },
        interrupt_options = interrupt_options,
        interrupted_process = {}
    }

    -- Enqueue process
    table.insert(self.execution.process_queue, process_entry)

end

-- Convenience function that enqueues the given process in the process queue
function _exec.enqueue_process(self, process_entry)
    table.insert(self.execution.process_queue, process_entry)
end

-- This function creates a state process. The state process will execute
-- everytime there's no other process executing
function npc.exec.set_state_program(self, program_name, arguments, interrupt_options)
    self.execution.state_process = {
        program_name = program_name,
        arguments = arguments,
        state = npc.exec.proc.state.INACTIVE,
        execution_context = {
            data = {},
            instr_interval = 1,
            instr_timer = 0
        },
        instruction_queue = {},
        current_instruction = {
            entry = {},
            state = npc.exec.proc.instr.state.INACTIVE,
            pos = {}
        },
        interrupt_options = interrupt_options,
        is_state_process = true
    }
end

-- Convenience function that returns first process in the queue
function npc.exec.get_current_process(self)
    return self.execution.process_queue[1]
end


-- This function always execute the process at the start of the process
-- queue. When a process is stopped (because its instruction queue is empty
-- or because the process itself stops), the entry is removed from the
-- process queue, and thus the next process to execute will be the first one
-- in the queue.
function npc.exec.execute_process(self)
    local current_process = npc.exec.get_current_process(self)
    -- Execute current process
    npc.programs.execute(current_process.program_name, current_process.arguments)
end


---------------------------------------------------------------------------------------
-- Interruption algorithm
---------------------------------------------------------------------------------------
-- Interruption of an executing process can come from three sources:
--   - NPC is left-clicked (or punch)
--   - NPC is right-clicked (or rightclick)
--   - Job scheduler has identified it is time to start a process
-- When an interrupt happens, and another process needs to be executed, the
-- workflow should be the following:
--   1. Enqueue the new process to be scheduled.
--      a. If for some reason the process queue *has more than one* process,
--         then the process will have to be enqueued with high priority,
--         meaning next to the current process.
--   2. Pause the current executing process using `npc.exec.pause_process(self)`
--      The new process will be executed by `npc.exec.pause_process()`.
--   3. The process finishes execution successfully, in which the scheduler
--      will notice that and restore the interrupted process properly
--
-- It is very important that a process is enqueued before pausing the current
-- process. The pause will not work itself if that condition is not met

-- This function handles a new process called by an interrupt.
-- Will execute steps 1 and 2 of the above algorithm. The scheduler
-- will take care of handling step 3.
function npc.exec.interrupt(self, new_program, new_arguments, interrupt_options)
    -- Check if the queue has more than one (current) process
    if table.getn(self.execution.process_queue) > 1 then
        -- Get current process entry
        local current_process = npc.exec.get_current_process(self)
        -- Backup the current process queue
        local backup_queue = self.execution.process_queue
        -- Remove current process from backup_queue
        table.remove(backup_queue, 1)
        -- Recreate queue, enqueue new process with high priority
        _exec.enqueue_process(self, current_process)
        npc.exec.enqueue_process(self, new_program, new_arguments, interrupt_options)
        -- Enqueue the rest of the processes
        for _,process_entry in pairs(backup_queue) do
            table.insert(self.execution.process_queue, process_entry)
        end
    end
    -- Pause current process
    _exec.pause_process(self)
    -- Dequeue process
    local interrupted_process = npc.exec.get_current_process(self)
    table.remove(self.execution.process_queue, 1)
    -- Store interrupted process
    local current_process = npc.exec.get_current_process(self)
    current_process.interrupted_process = interrupted_process
    -- Execute current process
    npc.exec.execute_process(self)
end

-- If there is another process in the queue, this function pauses a
-- currently executing process, then executes the
function _exec.pause_process(self)
    if table.getn(self.execution.process_queue) == 1 then
        npc.log("ERROR", "Unable to pause current process without anoher process in queue.\nCurrent queue: "
                ..dump(self.execution.process_queue))
        return
    end

    local current_process = npc.exec.get_current_process(self)
    if current_process then
        -- Check if there are instructions in the instruction queue
        if table.getn(current_process.instruction_queue) > 0 then
            -- Check current instruction
            if current_process.current_instruction.entry
                    and current_process.current_instruction.state == npc.exec.proc.instr.state.EXECUTING then
                -- Change instruction state
                current_process.current_instruction.state = npc.exec.proc.instr.state.INTERRUPTED
            end
        end
        -- Change process state
        current_process.state = npc.exec.proc.state.PAUSED
    end
end

-- This function restores the process that was running before the
-- current one (the interrupted process).
-- As it can only be runned with the interrupted process being enqueued
-- before calling this function, this function is private and only
-- used by the scheduler (which will enqueue the interrupted process before
-- calling this)
function _exec.restore_process(self)
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        -- Change process state
        current_process.state = npc.exec.proc.state.RUNNING
        -- Check if any instruction was interrupted
        if current_process.current_instruction.entry
                and current_process.current_instruction.state == npc.exec.proc.instr.state.INTERRUPTED then
            -- Restore position
            self:setpos(current_process.current_instruction.pos)
            -- Execute instruction
            _exec.proc.execute(self, current_process.current_instruction.entry)
        end
    end
end

---------------------------------------------------------------------------------------
-- Scheduler algorithm
---------------------------------------------------------------------------------------
-- This function will manage how processes are executed. This function needs
-- to be called on a one second interval. The function will check:
--   - If the process queue is emtpy and there is a state process, enqueue the
--     the state process and execute
--   - If the current process' instruction queue is empty:
--     - If the process is a `state` process, and no other process is in queue,
--       re-execute `state` process.
--     - If the process is a `state` process and there is a process in queue,
--       - Remove current process from queue
-- 		 - Store the current process entry into the `interrupted_process` field of
--         the next process in queue.
--       - Execute next process in queue
--     - If the process is *not* a `state` process and there is a process entry in
--       the `interrupted_process` field:
--       - Remove current process from queue
--       - Enqueue the entry in the `interrupted_process` field
--       - Execute next process in the queue
--   - If the instruction queue is not empty, continue
function npc.exec.process_scheduler(self)
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        -- Check if instruction queue is empty
        if table.getn(current_process.instruction_queue) == 0 then
            -- Check if this is a state process
            if current_process.is_state_process == true then
                -- Check if the process queue only has this process
                if table.getn(self.execution.process_queue) == 1 then
                    -- Since this is a state process, re-execute
                    npc.exec.execute_process(self)
                else
                    -- Pause current process
                    current_process.state = npc.exec.process.state.PAUSED
                    -- Dequeue process
                    table.remove(self.exection.process_queue, 1)
                    -- Get next process in queue
                    local next_process = npc.exec.get_current_process(self)
                    -- Store the interrupted process in the next process
                    next_process.interrupted_process = current_process
                    -- Execute next process
                    npc.exec.execute_process(self)
                end
            else
                -- This is not a state process, check the interrupted process field
                if current_process.interrupted_process ~= {} then
                    -- Dequeue process
                    table.remove(self.exection.process_queue, 1)
                    -- Re-enqueue the interrupted process
                    _exec.enqueue_process(self, current_process.interrupted_process)
                    -- Restore the interrupted process
                    _exec.restore_process(self)
                end

            end
        end
    else
        -- Process queue is empty, enqueue state process
        _exec.enqueue_process(self, self.execution.state_process)
        -- Execute state process
        npc.exec.execute_process(self)
    end
end

---------------------------------------------------------------------------------------
-- Process instructions functionality - enqueue and execute instructions
-- for the currently executing process
---------------------------------------------------------------------------------------
-- This function enqueues a given instruction with its arguments
-- in the current process' instruction queue
function npc.exec.proc.enqueue(self, name, args)
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        -- Create queue entry
        local instruction_entry = {instr=name, args=args}
        -- Enqueue entry
        table.insert(current_process.instruction_queue, instruction_entry)
    end
end

-- Private function to execute a given instruction entry
function _exec.proc.execute(self, entry)
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        -- Set current instruction params
        current_process.current_instruction.entry = entry
        current_process.current_instruction.pos = self:getpos()
        current_process.current_instruction.state = npc.exec.proc.instr.state.EXECUTING
        -- Execute current instruction
        npc.programs.instr.execute(entry.name, entry.args)
        -- Dequeue from instruction queue
        table.remove(current_process.instruction_queue, 1)
    end
end

-- This function executes the next instruction entry in the current
-- process' instruction queue
function npc.exec.proc.execute(self)
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        -- Get next instruction entry in queue
        local entry = current_process.instruction_queue[1]
        -- Execute instruction
        _exec.proc.execute(self, entry)
    end
end

---------------------------------------------------------------------------------------
-- Variable functionality - create, read, update and delete variables in the
-- current process
---------------------------------------------------------------------------------------
-- This function adds a value to the execution context of the
-- current process.
-- Readonly defaults to false. Returns false if failed due to
-- key-name conflict, or returns true if successful
function npc.exec.var.put(self, name, value, readonly)
    -- Retrieve current process execution context
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        local context = current_process.execution_context
        -- Check if variable exists
        if context[name] ~= nil then
            npc.log("ERROR", "Attempt to create new variable with name "..name.." failed"..
                    "due to variable already existing: "..dump(context[name]))
            return false
        end
        context[name] = {value = value, readonly = readonly}
        return true
    end
end

-- Returns the value of a given key. If not found returns nil.
function npc.exec.var.get(self, name)
    -- Retrieve current process execution context
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        local context = current_process.execution_context
        local result = context[name]
        if result == nil then
            return nil
        else
            return result.value
        end
    end
end

-- This function updates a value in the execution context.
-- Returns false if the value is read-only or if key isn't found.
-- Returns true if able to update value
function npc.exec.var.set(self, name, new_value)
    -- Retrieve current process execution context
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        local context = current_process.execution_context
        local var = context[name]
        if var == nil then
            return false
        else
            if var.readonly == true then
                npc.log("ERROR", "Attempt to set value of readonly variable: "..name)
                return false
            end
            var.value = new_value
        end
        return true
    end
end

-- This function removes a variable from the execution context.
-- If the key doesn't exist, returns nil, otherwise, returns
-- the value removed.
function npc.exec.var.remove(self, name)
    -- Retrieve current process execution context
    local current_process = npc.exec.get_current_process(self)
    if current_process then
        local context = current_process.execution_context
        local result = context[name]
        if result == nil then
            return nil
        else
            -- Clear variable
            npc.exec.get_current_process(self).execution_context[name] = nil
            return result
        end
    end
end

-- TODO: Private timer API that can be accessed only by internal functionality
-- TODO:

---------------------------------------------------------------------------------------
-- Command and scripts execution functionality
---------------------------------------------------------------------------------------
-- This function sets the execution options given the table of parameters
-- function npc.set_execution_params(self, execution_options)
-- 	if execution_options.allow_rightclick then
-- 		self.actions.execution_options.allow_rightclick_interaction = execution_options.allow_rightclick
-- 	end
-- 	if execution_options.allow_punch then
-- 		self.actions.execution_options.allow_punch_interaction = execution_options.allow_punch
-- 	end
-- 	if execution_options.allow_scheduler_interruption then
-- 		self.actions.execution_options.allow_scheduler_interruption = execution_options.allow_scheduler_interruption
-- 	end
-- end

-- -- This function adds a command to the action queue.
-- -- Commands should be added in strict order for everything to work as expected.
-- function npc.enqueue_command(self, command, arguments)
-- 	local cmd_entry = {command=command, args=arguments, is_script=false}
-- 	table.insert(self.actions.queue, cmd_entry)
-- end

-- -- This function adds script commands in-place, as opposed to
-- -- at the end of the queue. This allows for continued order
-- function npc.enqueue_script(self, script, args, execution_options)
-- 	local cmd_entry = {command=script, args=args, is_script=true }
-- 	if execution_options then
-- 		npc.set_execution_params(execution_options)
-- 	end
-- 	table.insert(self.actions.queue, cmd_entry)
-- end

-- -- This function adds a function that will execute commands in-place, as opposed to
-- -- at the end of the queue. This allows for continued order
-- function npc.enqueue_function(self, script_name, func_name, args, key)
-- 	local cmd_entry = {
-- 		command=func_name,
-- 		script_name=script_name,
-- 		args=args,
-- 		is_script_function=true,
-- 		results_key = key
-- 	}
-- 	table.insert(self.actions.queue, cmd_entry)
-- end

-- function npc.set_state_script(self, name, args, execution_options)
-- 	local cmd_entry = {command=name, args=args, is_script=true, is_state_script=true}
-- 	if execution_options then
-- 		npc.set_execution_params(execution_options)
-- 	end
-- 	self.npc_state.script = cmd_entry
-- 	self.npc_state.context_key = cmd_entry.command..self.actions.execution.id
-- end

-- -- This function removes the first action in the action queue
-- -- and then executes it
-- function npc.execute_command(self)
-- 	if #self.actions.queue > 0 then
-- 		npc.log("INFO", "Current actions queue: "..dump(self.actions.queue))
-- 	end
-- 	--npc.log("INFO", "Execution context: "..dump(self.actions.execution.context[context_key].data))
-- 	-- Check if an action was interrupted
-- 	if self.actions.current_action_state == npc.action_state.interrupted then
-- 		npc.log("DEBUG_ACTION", "Re-inserting interrupted action for NPC: '"..dump(self.npc_name).."': "..dump(self.actions.state_before_lock.interrupted_action))
-- 		-- Insert into queue the interrupted action
-- 		table.insert(self.actions.queue, 1, self.actions.state_before_lock.interrupted_action)
-- 		-- Clear the action
-- 		self.actions.state_before_lock.interrupted_action = {}
-- 		-- Clear the position
-- 		self.actions.state_before_lock.pos = {}
-- 	end
-- 	local result
-- 	if table.getn(self.actions.queue) == 0 then
-- 		-- Set command state to none
-- 		self.actions.current_action_state = npc.action_state.none
-- 		-- Execute the state if script if set
-- 		if self.npc_state and self.npc_state.script ~= {} then
-- 			npc.log("INFO", "Executing state script...")
-- 			-- Set state script as execution
-- 			self.npc_state.is_state_script_executing = true
-- 			-- Execute script
-- 			npc.execution.execute_script(self, self.npc_state.script)
-- 			-- Do NOT run mobs_redo step
-- 			return false
-- 		else
-- 			-- Keep state the same if there are no more actions in actions queue
-- 			return self.freeze
-- 		end
-- 	end
-- 	local cmd_entry = self.actions.queue[1]
-- 	-- Check if action is null
-- 	if cmd_entry.command == nil then
-- 		return
-- 	end
-- 	-- Check if we have an enqueued function
-- 	if cmd_entry.is_script_function == true then
-- 		npc.log("INFO", "Executing enqueued function...")
-- 		-- Backup current queue
-- 		local backup_queue = self.actions.queue
-- 		-- Remove this script entry from queue
-- 		table.remove(self.actions.queue, 1)
-- 		-- Clear queue
-- 		self.actions.queue = {}

-- 		-- Execute function
-- 		local results = npc.commands.execute_script_function(self, cmd_entry.script_name, cmd_entry.command, cmd_entry.args)
-- 		-- Store results into execution context if key was given
-- 		if cmd_entry.results_key then
-- 			npc.execution.context.put(self, cmd_entry.results_key, results, false)
-- 		end
-- 		-- After all new commands has been added by script, add the previously
-- 		-- queued commands back
-- 		for i = 1, #backup_queue do
-- 			table.insert(self.actions.queue, backup_queue[i])
-- 		end

-- 		minetest.log("New actions queue: "..dump(self.actions.queue))
-- 		-- Return
-- 		return
-- 	end
-- 	-- Check if action is an schedule check
-- 	if cmd_entry.command == "schedule_check" then
-- 		-- Remove table entry
-- 		table.remove(self.actions.queue, 1)
-- 		-- Execute schedule check
-- 		npc.schedule_check(self)
-- 		-- Return
-- 		return false
-- 	end
-- 	-- If the entry is a script, then push all this new operations in
-- 	-- stack fashion
-- 	if cmd_entry.is_script == true then
-- 		npc.log("INFO", "Executing script with name "..cmd_entry.command)
-- 		-- Execute script
-- 		npc.execution.execute_script(self, cmd_entry)
-- 	else
-- 		npc.log("DEBUG_ACTION", "Executing command for NPC '"..dump(self.npc_name).."': "..dump(cmd_entry))
-- 		-- Store the action that is being executed
-- 		self.actions.state_before_lock.interrupted_action = cmd_entry
-- 		-- Store current position
-- 		self.actions.state_before_lock.pos = self.object:getpos()
-- 		-- Execute command as normal
-- 		result = npc.commands.execute(self, cmd_entry.command, cmd_entry.args)
-- 		-- Remove command from queue
-- 		table.remove(self.actions.queue, 1)
-- 		-- Set state
-- 		self.actions.current_action_state = npc.action_state.executing
-- 	end
-- 	return result
-- end

-- function npc.lock_actions(self)

-- 	-- Avoid re-locking if already locked
-- 	if self.actions.action_timer_lock == true then
-- 		return
-- 	end

-- 	local pos = self.object:getpos()

-- 	if self.freeze == false then
-- 		-- Round current pos to avoid the NPC being stopped on positions
-- 		-- where later on can't walk to the correct positions
-- 		-- Choose which position is to be taken as start position
-- 		if self.actions.state_before_lock.pos ~= nil and self.actions.state_before_lock.pos ~= {} then
-- 			pos = vector.round(self.actions.state_before_lock.pos)
--         else
--             minetest.log("Before rounding: "..dump(self.object:getpos()))
-- 			pos = vector.round(self.object:getpos())
-- 		end
-- 		pos.y = self.object:getpos().y
--         minetest.log("After: "..dump(pos))
-- 	end
-- 	-- Check if NPC is in unmovable state
-- 	if self.npc_state.movement
-- 			and self.npc_state.movement.is_sitting == false and self.npc_state.movement.is_laying == false then
-- 		-- Stop NPC
-- 		npc.commands.execute(self, npc.commands.cmd.STAND, {pos=pos})
-- 	end
-- 	-- Avoid all timer execution
-- 	self.actions.action_timer_lock = true
-- 	-- Reset timer so that it has some time after interaction is done
-- 	self.actions.action_timer = 0
-- 	-- Check if there are is an action executing
-- 	if self.actions.current_action_state == npc.action_state.executing
-- 			and self.freeze == false then
-- 		-- Store the current action state
-- 		self.actions.state_before_lock.action_state = self.actions.current_action_state
-- 		-- Set current action state to interrupted
-- 		self.actions.current_action_state = npc.action_state.interrupted
-- 	end
-- 	-- Store the current freeze variable
-- 	self.actions.state_before_lock.freeze = self.freeze
-- 	-- Freeze mobs_redo API
-- 	self.freeze = false

-- 	npc.log("DEBUG_ACTION", "Locking NPC "..dump(self.npc_id).." actions")
-- end

-- function npc.unlock_actions(self)
--     -- Restore NPC yaw
-- 	if self.yaw_before_interaction ~= nil then
-- 		minetest.after(1, function(ent, yaw)
-- 			ent.object:setyaw(yaw)
-- 		end, self, self.yaw_before_interaction)
-- 		self.yaw_before_interaction = nil
--     end

--     -- Check if the NPC is sitting or laying states
--     if self.npc_state.movement
--             and (self.npc_state.movement.is_sitting == true or self.npc_state.movement.is_laying == true) then
--         return
--     end

-- 	-- Allow command timers to execute
-- 	self.actions.action_timer_lock = false

-- 	-- Restore the value of self.freeze
-- 	self.freeze = self.actions.state_before_lock.freeze

-- 	if table.getn(self.actions.queue) == 0 then
--         -- Check if state script is running
--         if self.npc_state.is_state_script_executing == false then
-- 		    -- Allow mobs_redo API to execute since commands queue is empty
--             -- and there's no state script
-- 		    self.freeze = true
--         end
-- 	end

-- 	npc.log("DEBUG_ACTION", "Unlocked NPC "..dump(self.npc_id).." commands")
-- end

-- --------------------------------------------
-- --    Execution management functions      --
-- --------------------------------------------
-- -- These functions manage the execution context, where variables are
-- -- stored, whether internal (loops) or user-created.
-- -- The execution context is cleared at the end of each script.
-- npc.execution = {
--     context = {}
-- }

-- npc.execution.script_state = {
--     INACTIVE = 0,
--     RUNNING = 1,
--     PAUSED = 2,
--     STOPPED = 3
-- }

-- -- This function executes a script. It handles three possible scenarios
-- --   1. Run state script with no other script executing
-- --      Need to create new context, new context key
-- --   2. Run state script, with same script already executing
-- --      Reuse context and context key
-- --   3. Run state script with different state script executing
-- --      Stop current state script, create new context and context key
-- --   4. Run script, with another script running (either state or non-state)
-- --      Pause current script (state or non-state), create new context and context key
-- function npc.execution.execute_script(self, cmd_entry)
--     -- Check if there is a currently executing script
--     local context_key = npc.execution.get_context_key(self)
--     if context_key and self.actions.execution.context[context_key] then
--         local status = self.actions.execution.context[context_key].state
--         if status == npc.execution.script_state.RUNNING then
-- 			-- Check if this is state script, if it is not, pause currently executing script
-- 			if self.npc_state.is_state_script_executing == false and not cmd_entry.is_state_script then
-- 				-- Pause currently running script if it is not state script
-- 				npc.execution.pause_script(self)
-- 				-- May need to add condition to check for state script in running
-- 				-- state but no actions present in queue
-- 			end
--         end
--     end

--     npc.log("DEBUG_ACTION", "Executing script for NPC '"..dump(self.npc_name).."': "..dump(cmd_entry))
--     -- Remove script entry from queue
--     table.remove(self.actions.queue, 1)
--     -- Backup current queue
--     local backup_queue = self.actions.queue
--     -- Execution management
-- 	-- Check if we are to execute a state script
-- 	if cmd_entry.is_state_script and cmd_entry.is_state_script == true then
-- 		-- Check if there's a state script executing as-of now
-- 		if self.npc_state.is_state_script_executing == true then

-- 		else
-- 			-- Increase execution ID
-- 			self.actions.execution.id = self.actions.execution.id + 1
-- 			-- Set current execution ID
-- 			self.actions.execution.current_script_name = cmd_entry.command
-- 			-- Create new execution context key
-- 			local new_context_key = cmd_entry.command..self.actions.execution.id
-- 			-- Create entry in the execution context
-- 			self.actions.execution.context[new_context_key] = {
-- 				args = cmd_entry.args,
-- 				state = npc.execution.script_state.RUNNING,
-- 				data = {},
-- 				backup = backup_queue,
-- 				interrupt_backup = {}
-- 			}
-- 		end
-- 	else

-- 	end



--     -- Increase execution ID
--     self.actions.execution.id = self.actions.execution.id + 1
--     -- Set current execution ID
--     self.actions.execution.current_script_name = cmd_entry.command
--     -- Create new execution context key
-- 	local new_context_key = cmd_entry.command..self.actions.execution.id
-- 	-- Check if we are executing the same state script, if we are, reuse same
-- 	-- context key, else, set new state script's context key
-- 	if cmd_entry.is_state_script and self.npc_state.script.command == cmd_entry.command then
-- 		-- Reuse context key
-- 		new_context_key = self.npc_state.context_key
-- 	else
-- 		-- Set the new context key as the state script context key
-- 		self.npc_state.context_key = new_context_key
-- 	end
-- 	-- Create entry in the execution context
--     self.actions.execution.context[new_context_key] = {
--         args = cmd_entry.args,
--         state = npc.execution.script_state.RUNNING,
--         data = {},
--         backup = backup_queue,
--         interrupt_backup = {}
--     }
--     -- Clear queue
--     self.actions.queue = {}
-- 	-- Check if we are running state script and set execution status
-- 	if cmd_entry.is_state_script and cmd_entry.is_state_script == true then
-- 		self.npc_state.is_state_script_executing = true
-- 	else
-- 		self.npc_state.is_state_script_executing = false
-- 	end
--     -- Execute the script with its arguments
--     local result = npc.commands.execute_script(self, cmd_entry.command, cmd_entry.args)
--     -- Return
--     return result
-- end

-- -- Pauses the currently executed script.
-- function npc.execution.pause_script(self)
--     -- Get context key for current script
--     local context_key = npc.execution.get_context_key(self)
--     -- Backup the current command queue
--     self.actions.execution.context[context_key].interrupt_backup = self.actions.queue
--     -- Clear command queue
--     self.actions.queue = {}
--     -- Set paused status
--     self.actions.execution.context[context_key].state = npc.execution.script_state.PAUSED
-- 	-- If we are pausing state script, change the running state
-- 	if context_key == self.npc_state.context_key then
-- 		self.npc_state.is_state_script_executing = false
-- 	end
--     -- Store execution ID and context key at time of interruption
--     self.actions.execution.script_interruption.interrupted_execution_id = self.actions.execution.id
--     self.actions.execution.script_interruption.interrupted_script_name = self.actions.execution.current_script_name
--     self.actions.execution.script_interruption.interrupted_script_context_key = context_key
--     return
-- end

-- -- Re-starts execution of a paused script.
-- -- Restores command queue prior to pausing.
-- function npc.execution.restore_script(self)
--     -- Get context key for previously paused script
--     local context_key = self.actions.execution.script_interruption.interrupted_script_context_key
--     -- Check if context exists
--     if self.actions.execution.context[context_key] then
--         -- Restore execution ID and current context key interruption parameters
--         local execution_id = self.actions.execution.script_interruption.interrupted_execution_id
--         local script_name = self.actions.execution.script_interruption.interrupted_script_name
-- 		local backup_queue = self.actions.execution.context[context_key].interrupt_backup
--         -- Clear interrupted parameters
--         self.actions.execution.script_interruption.interrupted_execution_id = 0
--         self.actions.execution.script_interruption.interrupted_script_name = ""
--         self.actions.execution.script_interruption.interrupted_script_context_key = ""
--         -- Clear current command queue
-- 		self.actions.queue = {}
-- 		-- Restore queue backup
-- 		for i = 1, #backup_queue do
-- 			table.insert(self.actions.queue, backup_queue[i])
-- 		end
-- 		-- Set script as running
-- 		self.actions.execution.context[context_key].state = npc.execution.script_state.RUNNING
-- 		-- If we are restoring state script, set status
-- 		if context_key == self.npc_state.context_key then
-- 			self.npc_state.is_state_script_executing = true
-- 		end
--     end
-- end

-- function npc.execution.stop_script(self)
--     -- Clear queue
--     self.actions.queue = {}
--     -- Retrieve context key
--     local context_key = npc.execution.get_context_key(self)
--     -- Get queue backup
--     local backup_queue = self.actions.execution.context[context_key].backup
--     -- Check if there was an interrupted script
--     local interrupted_script_key = self.actions.execution.script_interruption.interrupted_script_context_key
--     if interrupted_script_key and self.actions.execution.context[interrupted_script_key] then
--         -- Restore interrupted script
--         npc.execution.restore_script(self)
--     else
--         -- Restore queue backup, no script to execute
--         for i = 1, #backup_queue do
--             table.insert(self.actions.queue, backup_queue[i])
-- 		end
-- 		-- Clear execution context entry
-- 		self.actions.execution.context[context_key] = nil
-- 		-- If we are stopping an state script, update context key and status
-- 		if context_key == self.npc_state.context_key then
-- 			self.npc_state.is_state_script_executing = false
-- 			self.npc_state.context_key = ""
-- 		end
--     end
--     return
-- end

-- -- Returns the *current* script execution ID if offset isn't given or it is 0.
-- -- If offset is given, it returns the n-previous execution of the script name, if
-- -- available. If not available
-- function npc.execution.get_context_key(self, offset)
--     if not offset or offset == 0 then
--         -- Return key for currently executed script
--         return self.actions.execution.current_script_name..self.actions.execution.id
--     else
--         -- Get all keys in execution context
--         local keys = npc.utils.get_map_keys(self.actions.execution.context)
--         -- Calculate key to be searched for
--         local offset_id = self.actions.execution.id - offset
--         for _,key in pairs(keys) do
--             local si,_ = string.find(key, offset_id)
--             if si ~= nil then
--                 -- Found, return key
--                 return key
--             end
--         end
--     end
-- end

---------------------------------------------------------------------------------------
-- Schedule functionality
---------------------------------------------------------------------------------------
-- Schedules allow the NPC to do different things depending on the time of the day.
-- The time of the day is in 24 hours and is consistent with the Minetest Game
-- /time command. Hours will be written as numbers: 1 for 1:00, 13 for 13:00 or 1:00 PM
-- The API is as following: a schedule can be created for a specific date or for a
-- day of the week. A date is a string in the format MM:DD
npc.schedule_types = {
    ["generic"] = "generic",
    ["date_based"] = "date_based"
}

npc.schedule_properties = {
    put_item = "put_item",
    put_multiple_items = "put_multiple_items",
    take_item = "take_item",
    trader_status = "trader_status",
    can_receive_gifts = "can_receive_gifts",
    flag = "flag",
    enable_gift_items_hints = "enable_gift_items_hints",
    set_trade_list = "set_trade_list"
}

local function get_time_in_hours()
    return minetest.get_timeofday() * 24
end

-- Create a schedule on a NPC.
-- Schedule types:
--  - Generic: Returns nil if there are already
--    seven schedules, one for each day of the
--    week or if the schedule attempting to add
--    already exists. The date parameter is the
--    day of the week it represents as follows:
--      - 1: Monday
--      - 2: Tuesday
--      - 3: Wednesday
--      - 4: Thursday
--      - 5: Friday
--      - 6: Saturday
--      - 7: Sunday
--  - Date-based: The date parameter should be a
--    string of the format "MM:DD". If it already
--    exists, function retuns nil
function npc.create_schedule(self, schedule_type, date)
    if schedule_type == npc.schedule_types.generic then
        -- Check that there are no more than 7 schedules
        if #self.schedules.generic == 7 then
            -- Unable to add schedule
            return nil
        elseif #self.schedules.generic < 7 then
            -- Check schedule doesn't exists already
            if self.schedules.generic[date] == nil then
                -- Add schedule
                self.schedules.generic[date] = {}
            else
                -- Schedule already present
                return nil
            end
        end
    elseif schedule_type == npc.schedule_types.date then
        -- Check schedule doesn't exists already
        if self.schedules.date_based[date] == nil then
            -- Add schedule
            self.schedules.date_based[date] = {}
        else
            -- Schedule already present
            return nil
        end
    end
end

function npc.delete_schedule(self, schedule_type, date)
    -- Delete schedule by setting entry to nil
    self.schedules[schedule_type][date] = nil
end

-- Schedule entries API
-- Allows to add, get, update and delete entries from each
-- schedule. Attempts to be as safe-fail as possible to avoid crashes.

-- Actions is an array of actions and tasks that the NPC
-- will perform at the scheduled time on the scheduled date
function npc.add_schedule_entry(self, schedule_type, date, time, check, actions)
    -- Check that schedule for date exists
    if self.schedules[schedule_type][date] ~= nil then
        -- Add schedule entry
        if check == nil then
            self.schedules[schedule_type][date][time] = actions
        else
            self.schedules[schedule_type][date][time].check = check
        end
    else
        -- No schedule found, need to be created for date
        return nil
    end
end

function npc.get_schedule_entry(self, schedule_type, date, time)
    -- Check if schedule for date exists
    if self.schedules[schedule_type][date] ~= nil then
        -- Return schedule
        return self.schedules[schedule_type][date][time]
    else
        -- Schedule for date not found
        return nil
    end
end

function npc.update_schedule_entry(self, schedule_type, date, time, check, actions)
    -- Check schedule for date exists
    if self.schedules[schedule_type][date] ~= nil then
        -- Check that a schedule entry for that time exists
        if self.schedules[schedule_type][date][time] ~= nil then
            -- Set the new actions
            if check == nil then
                self.schedules[schedule_type][date][time] = actions
            else
                self.schedules[schedule_type][date][time].check = check
            end
        else
            -- Schedule not found for specified time
            return nil
        end
    else
        -- Schedule not found for date
        return nil
    end
end

function npc.delete_schedule_entry(self, schedule_type, date, time)
    -- Check schedule for date exists
    if self.schedules[schedule_type][date] ~= nil then
        -- Remove schedule entry by setting to nil
        self.schedules[schedule_type][date][time] = nil
    else
        -- Schedule not found for date
        return nil
    end
end

function npc.schedule_change_property(self, property, args)
    if property == npc.schedule_properties.trader_status then
        -- Get status from args
        local status = args.status
        -- Set status to NPC
        npc.set_trading_status(self, status)
    elseif property == npc.schedule_properties.put_item then
        local itemstring = args.itemstring
        -- Add item
        npc.add_item_to_inventory_itemstring(self, itemstring)
    elseif property == npc.schedule_properties.put_multiple_items then
        local itemlist = args.itemlist
        for i = 1, #itemlist do
            local itemlist_entry = itemlist[i]
            local current_itemstring = itemlist[i].name
            if itemlist_entry.random == true then
                current_itemstring = current_itemstring
                        .." "..dump(math.random(itemlist_entry.min, itemlist_entry.max))
            else
                current_itemstring = current_itemstring.." "..tostring(itemlist_entry.count)
            end
            -- Add item to inventory
            npc.add_item_to_inventory_itemstring(self, current_itemstring)
        end
    elseif property == npc.schedule_properties.take_item then
        local itemstring = args.itemstring
        -- Add item
        npc.take_item_from_inventory_itemstring(self, itemstring)
    elseif property == npc.schedule_properties.can_receive_gifts then
        local value = args.can_receive_gifts
        -- Set status
        self.can_receive_gifts = value
    elseif property == npc.schedule_properties.flag then
        local action = args.action
        if action == "set" then
            -- Adds or overwrites an existing flag and sets it to the given value
            self.flags[args.flag_name] = args.flag_value
        elseif action == "reset" then
            -- Sets value of flag to false or to 0
            local flag_type = type(self.flags[args.flag_name])
            if flag_type == "number" then
                self.flags[args.flag_name] = 0
            elseif flag_type == "boolean" then
                self.flags[args.flag_name] = false
            end
        end
    elseif property == npc.schedule_properties.enable_gift_item_hints then
        self.gift_data.enable_gift_items_hints = args.value
    elseif property == npc.schedule_properties.set_trade_list then
        -- Insert items
        for i = 1, #args.items do
            -- Insert entry into trade list
            self.trader_data.trade_list[args.items[i].name] = {
                max_item_buy_count = args.items[i].buy,
                max_item_sell_count = args.items[i].sell,
                amount_to_keep = args.items[i].keep
            }

        end
    end
end

function npc.add_schedule_check(self)
    table.insert(self.actions.queue, {action="schedule_check", args={}, is_task=false})
end

function npc.enqueue_schedule_action(self, entry)
    if entry.task ~= nil then
        -- Add task
        npc.enqueue_script(self, entry.task, entry.args)
    elseif entry.action ~= nil then
        -- Add action
        npc.add_action(self, entry.action, entry.args)
    elseif entry.property ~= nil then
        -- Change NPC property
        npc.schedule_change_property(self, entry.property, entry.args)
    end
end

-- Range: integer, radius in which nodes will be searched. Recommended radius is
--		  between 1-3
-- Nodes: array of node names
-- Actions: map of node names to entries {action=<action_enum>, args={}}.
--			Arguments can be empty - the check function will try to determine most
--			arguments anyways (like pos and dir).
--			Special node "any" will execute those actions on any node except the
--			already specified ones.
-- None-action: array of entries {action=<action_enum>, args={}}.
--				Will be executed when no node is found.
function npc.schedule_check(self)
    npc.log("DEBUG_SCHEDULE", "Prev Actions queue: "..dump(self.actions.queue))
    local range = self.schedules.current_check_params.range
    local walkable_nodes = self.schedules.current_check_params.walkable_nodes
    local nodes = self.schedules.current_check_params.nodes
    local actions = self.schedules.current_check_params.actions
    local none_actions = self.schedules.current_check_params.none_actions
    -- Get NPC position
    local start_pos = self.object:getpos()
    -- Search nodes
    local found_nodes = npc.locations.find_node_nearby(start_pos, nodes, range)
    -- Check if any node was found
    npc.log("DEBUG_SCHEDULE", "Found nodes using radius: "..dump(found_nodes))
    if found_nodes and #found_nodes > 0 then
        local node_pos
        local node
        -- Check if there is preference to act on nodes already acted upon
        if self.schedules.current_check_params.prefer_last_acted_upon_node == true then
            -- Find a node other than the acted upon - try 3 times
            for i = 1, #found_nodes do
                node_pos = found_nodes[i]
                -- Get node info
                node = minetest.get_node(node_pos)
                if node.name == self.schedules.current_check_params.last_node_acted_upon then
                    break
                end
            end
        else
            -- Pick a random node to act upon
            node_pos = found_nodes[math.random(1, #found_nodes)]
            -- Get node info
            node = minetest.get_node(node_pos)
        end
        -- Save this node as the last acted upon
        self.schedules.current_check_params.last_node_acted_upon = node.name
        -- Set node as a place
        -- Note: Code below isn't *adding* a node, but overwriting the
        -- place with "schedule_target_pos" place type
        npc.log("DEBUG_SCHEDULE", "Found "..dump(node.name).." at pos: "..minetest.pos_to_string(node_pos))
        npc.locations.add_shared_accessible_place(
            self, {owner="", node_pos=node_pos}, npc.locations.PLACE_TYPE.SCHEDULE.TARGET, true, walkable_nodes)
        -- Get actions related to node and enqueue them
        for i = 1, #actions[node.name] do
            local args = {}
            local action
            -- Calculate arguments for the following supported actions:
            --   - Dig
            --   - Place
            --   - Walk step
            --   - Walk to position
            --   - Use furnace
            if actions[node.name][i].action == npc.commands.cmd.DIG then
                -- Defaults: items will be added to inventory if not specified
                -- otherwise, and protection will be respected, if not specified
                -- otherwise
                args = {
                    pos = node_pos,
                    add_to_inventory = actions[node.name][i].args.add_to_inventory or true,
                    bypass_protection = actions[node.name][i].args.bypass_protection or false
                }
                npc.add_action(self, actions[node.name][i].action, args)
            elseif actions[node.name][i].action == npc.commands.cmd.PLACE then
                -- Position: providing node_pos is because the currently planned
                -- behavior for placing nodes is replacing digged nodes. A NPC farmer,
                -- for instance, might dig a plant node and plant another one on the
                -- same position.
                -- Defaults: items will be taken from inventory if existing,
                -- if not will be force-placed (item comes from thin air)
                -- Protection will be respected
                args = {
                    pos = actions[node.name][i].args.pos or node_pos,
                    source = actions[node.name][i].args.source or npc.commands.take_from_inventory_forced,
                    node = actions[node.name][i].args.node,
                    bypass_protection =  actions[node.name][i].args.bypass_protection or false
                }
                --minetest.log("Enqueue dig action with args: "..dump(args))
                npc.add_action(self, actions[node.name][i].action, args)
            elseif actions[node.name][i].action == npc.commands.cmd.ROTATE then
                -- Set arguments
                args = {
                    dir = actions[node.name][i].dir,
                    start_pos = actions[node.name][i].start_pos
                            or {x=start_pos.x, y=node_pos.y, z=start_pos.z},
                    end_pos = actions[node.name][i].end_pos or node_pos
                }
                -- Enqueue action
                npc.add_action(self, actions[node.name][i].action, args)
            elseif actions[node.name][i].action == npc.commands.cmd.WALK_STEP then
                -- Defaults: direction is calculated from start node to node_pos.
                -- Speed is default wandering speed. Target pos is node_pos
                -- Calculate dir if dir is random
                local dir = npc.commands.get_direction(start_pos, node_pos)
                minetest.log("actions: "..dump(actions[node.name][i]))
                if actions[node.name][i].args.dir == "random" then
                    dir = math.random(0,7)
                elseif type(actions[node.name][i].args.dir) == "number" then
                    dir = actions[node.name][i].args.dir
                end
                args = {
                    dir = dir,
                    speed = actions[node.name][i].args.speed or npc.commands.one_nps_speed,
                    target_pos = actions[node.name][i].args.target_pos or node_pos
                }
                npc.add_action(self, actions[node.name][i].action, args)
            elseif actions[node.name][i].task == npc.commands.cmd.WALK_TO_POS then
                -- Optimize walking -- since distances can be really short,
                -- a simple walk_step() action can do most of the times. For
                -- this, however, we need to calculate direction
                -- First of all, check distance
                local distance = vector.distance(start_pos, node_pos)
                if distance < 3 then
                    -- Will do walk_step based instead
                    if distance > 1 then
                        args = {
                            dir = npc.commands.get_direction(start_pos, node_pos),
                            speed = npc.commands.one_nps_speed
                        }
                        -- Enqueue walk step
                        npc.add_action(self, npc.commands.cmd.WALK_STEP, args)
                    end
                    -- Add standing action to look at node
                    npc.add_action(self, npc.commands.cmd.STAND,
                        {dir = npc.commands.get_direction(self.object:getpos(), node_pos)}
                    )
                else
                    -- Set end pos to be node_pos
                    args = {
                        end_pos = actions[node.name][i].args.end_pos or node_pos,
                        walkable = actions[node.name][i].args.walkable or walkable_nodes or {}
                    }
                    -- Enqueue
                    npc.enqueue_script(self, actions[node.name][i].task, args)
                end
            elseif actions[node.name][i].task == npc.commands.cmd.USE_FURNACE then
                -- Defaults: pos is node_pos. Freeze is true
                args = {
                    pos = actions[node.name][i].args.pos or node_pos,
                    item = actions[node.name][i].args.item,
                    freeze = actions[node.name][i].args.freeze or true
                }
                npc.enqueue_script(self, actions[node.name][i].task, args)
            else
                -- Action or task that is not supported for value calculation
                npc.enqueue_schedule_action(self, actions[node.name][i])
            end
        end
        -- Increase execution count
        self.schedules.current_check_params.execution_count =
        self.schedules.current_check_params.execution_count + 1
        -- Enqueue next schedule check
        if self.schedules.current_check_params.execution_count
                < self.schedules.current_check_params.execution_times then
            npc.add_schedule_check(self)
        end
        npc.log("DEBUG_SCHEDULE", "Actions queue: "..dump(self.actions.queue))
    else
        -- No nodes found, enqueue none_actions
        for i = 1, #none_actions do
            -- Add start_pos to none_actions
            none_actions[i].args["start_pos"] = start_pos
            -- Enqueue actions
            npc.add_action(self, none_actions[i].action, none_actions[i].args)
        end
        -- Increase execution count
        self.schedules.current_check_params.execution_count =
        self.schedules.current_check_params.execution_count + 1
        -- Enqueue next schedule check
        if self.schedules.current_check_params.execution_count
                < self.schedules.current_check_params.execution_times then
            npc.add_schedule_check(self)
        end
        -- No nodes found
        npc.log("DEBUG_SCHEDULE", "Actions queue: "..dump(self.actions.queue))
    end
end

---------------------------------------------------------------------------------------
-- NPC Lua object functions
---------------------------------------------------------------------------------------
-- The following functions make up the definitions of on_rightclick(), do_custom()
-- and other functions that are assigned to the Lua entity definition
-- This function is executed each time the NPC is loaded
function npc.after_activate(self)
    minetest.log("Self: "..dump(self))
    if not self.actions then
        npc.log("WARNING", "Found NPC on bad initialization state: no 'self.actions' object.\nReinitializing...")
        npc.initialize(self, self.object:getpos(), true)
    end
    -- Reset animation
    if self.npc_state.movement then
        if self.npc_state.movement.is_sitting == true then
            npc.commands.execute(self, npc.commands.cmd.SIT, {pos=self.object:getpos()})
        elseif self.npc_state.movement.is_laying == true then
            npc.commands.execute(self, npc.commands.cmd.LAY, {pos=self.object:getpos()})
        end
        -- Reset yaw if available
        if self.yaw_before_interaction then
            self.object:setyaw(self.yaw_before_interaction)
        end
    else
        -- Temporary code - adds the new state variables
        self.npc_state = {
            movement = {
                is_sittig = false,
                is_laying = false
            }
        }
    end
end

-- This function is executed on right-click
function npc.rightclick_interaction(self, clicker)
    -- Disable right click interaction per execution options
    if self.actions.execution.options.allow_rightclick_interaction == false then
        npc.log("WARNING", "Attempted to right-click a NPC with disabled rightlick interaction")
        return
    end

    -- Store original yaw
    self.yaw_before_interaction = self.object:getyaw()

    -- Rotate NPC toward its clicker
    npc.dialogue.rotate_npc_to_player(self)

    -- Get information from clicker
    local item = clicker:get_wielded_item()
    local name = clicker:get_player_name()

    npc.log("INFO", "Right-clicked NPC: "..dump(self))

    -- Receive gift or start chat. If player has no item in hand
    -- then it is going to start chat directly
    --minetest.log("self.can_have_relationship: "..dump(self.can_have_relationship)..", self.can_receive_gifts: "..dump(self.can_receive_gifts)..", table: "..dump(item:to_table()))
    if self.can_have_relationship
            and self.can_receive_gifts
            and item:to_table() ~= nil then
        -- Get item name
        local item = minetest.registered_items[item:get_name()]
        local item_name = item.description

        -- Show dialogue to confirm that player is giving item as gift
        npc.dialogue.show_yes_no_dialogue(
            self,
            "Do you want to give "..item_name.." to "..self.npc_name.."?",
            npc.dialogue.POSITIVE_GIFT_ANSWER_PREFIX..item_name,
            function()
                npc.relationships.receive_gift(self, clicker)
            end,
            npc.dialogue.NEGATIVE_ANSWER_LABEL,
            function()
                npc.start_dialogue(self, clicker, true)
            end,
            name
        )
    else
        npc.start_dialogue(self, clicker, true)
    end
end

function npc.step(self, dtime)
    if self.initialized == nil then
        -- Initialize NPC if spawned using the spawn egg built in from
        -- mobs_redo. This functionality will be removed in the future in
        -- favor of a better manual spawning method with customization
        npc.log("WARNING", "Initializing NPC from entity step. This message should only be appearing if an NPC is being spawned from inventory with egg!")
        npc.initialize(self, self.object:getpos(), true)
        self.tamed = false
        self.owner = nil
    else
        -- NPC is initialized, check other variables
        -- Check child texture issues
        if self.is_child then
            -- Check texture
            npc.texture_check.timer = npc.texture_check.timer + dtime
            if npc.texture_check.timer > npc.texture_check.interval then
                -- Reset timer
                npc.texture_check.timer = 0
                -- Set hornytimer to zero every 60 seconds so that children
                -- don't grow automatically
                self.hornytimer = 0
                -- Set correct textures
                self.texture = {self.selected_texture}
                self.base_texture = {self.selected_texture}
                self.object:set_properties(self)
                npc.log("WARNING", "Corrected textures on NPC child "..dump(self.npc_name))
                -- Set interval to large interval so this code isn't called frequently
                npc.texture_check.interval = 60
            end
        end
    end

    -- Timer function for casual traders to reset their trade offers
    self.trader_data.change_offers_timer = self.trader_data.change_offers_timer + dtime
    -- Check if time has come to change offers
    if self.trader_data.trader_status == npc.trade.CASUAL and
            self.trader_data.change_offers_timer >= self.trader_data.change_offers_timer_interval then
        -- Reset timer
        self.trader_data.change_offers_timer = 0
        -- Re-select casual trade offers
        npc.trade.generate_trade_offers_by_status(self)
    end

    -- Timer function for gifts
    for i = 1, #self.relationships do
        local relationship = self.relationships[i]
        -- Gift timer check
        if relationship.gift_timer_value < relationship.gift_interval then
            relationship.gift_timer_value = relationship.gift_timer_value + dtime
        elseif relationship.talk_timer_value < relationship.gift_interval then
            -- Relationship talk timer - only allows players to increase relationship
            -- by talking on the same intervals as gifts
            relationship.talk_timer_value = relationship.talk_timer_value + dtime
        else
            -- Relationship decrease timer
            if relationship.relationship_decrease_timer_value
                    < relationship.relationship_decrease_interval then
                relationship.relationship_decrease_timer_value =
                relationship.relationship_decrease_timer_value + dtime
            else
                -- Check if married to decrease half
                if relationship.phase == "phase6" then
                    -- Avoid going below the marriage phase limit
                    if (relationship.points - 0.5) >=
                            npc.relationships.RELATIONSHIP_PHASE["phase5"].limit then
                        relationship.points = relationship.points - 0.5
                    end
                else
                    relationship.points = relationship.points - 1
                end
                relationship.relationship_decrease_timer_value = 0
                --minetest.log(dump(self))
            end
        end
    end

    -- Action queue timer
    -- Check if actions and timers aren't locked
    if self.actions.action_timer_lock == false then
        -- Increment action timer
        self.actions.action_timer = self.actions.action_timer + dtime
        if self.actions.action_timer >= self.actions.action_interval then
            -- Reset action timer
            self.actions.action_timer = 0
            -- Check if NPC is walking
            if self.actions.walking.is_walking == true then
                -- Move NPC to expected position to ensure not getting lost
                local pos = self.actions.walking.target_pos
                self.object:moveto({x=pos.x, y=pos.y, z=pos.z})
            end
            -- Execute action - this also executes state script if no
            -- command can be found in the commands queue
            self.freeze = npc.execute_command(self)
            -- Check if there are still remaining actions in the queue
            if self.freeze == nil and table.getn(self.actions.queue) > 0 then
                self.freeze = false
            end
        end
    end

    -- Schedule timer
    -- Check if schedules are enabled, and interruptions by scheduler allowed by
    -- current state/executing script
    if self.schedules.enabled == true
            and self.actions.execution.options.allow_scheduler_interruption == false then
        -- Get time of day
        local time = get_time_in_hours()
        -- Check if time is an hour
        if ((time % 1) < dtime) and self.schedules.lock == false then
            -- Activate lock to avoid more than one entry to this code
            self.schedules.lock = true
            -- Get integer part of time
            time = (time) - (time % 1)
            -- Check if there is a schedule entry for this time
            -- Note: Currently only one schedule is supported, for day 0
            npc.log("DEBUG_SCHEDULE", "Time: "..dump(time))
            local schedule = self.schedules.generic[0]
            if schedule ~= nil then
                -- Check if schedule for this time exists
                if schedule[time] ~= nil then
                    npc.log("DEBUG_SCHEDULE", "Adding actions to action queue")
                    -- Add to action queue all actions on schedule
                    for i = 1, #schedule[time] do
                        -- Check if schedule has a check function
                        if schedule[time][i].check then
                            -- Add parameters for check function and run for first time
                            npc.log("DEBUG", "NPC "..dump(self.npc_id).." is starting check on "..minetest.pos_to_string(self.object:getpos()))
                            local check_params = schedule[time][i]
                            -- Calculates how many times check will be executed
                            local execution_times = check_params.count
                            if check_params.random_execution_times then
                                execution_times = math.random(check_params.min_count, check_params.max_count)
                            end
                            -- Set current parameters
                            self.schedules.current_check_params = {
                                range = check_params.range,
                                walkable_nodes = check_params.walkable_nodes,
                                nodes = check_params.nodes,
                                actions = check_params.actions,
                                none_actions = check_params.none_actions,
                                prefer_last_acted_upon_node = check_params.prefer_last_acted_upon_node or false,
                                last_node_acted_upon = "",
                                execution_count = 0,
                                execution_times = execution_times
                            }
                            -- Enqueue the schedule check
                            npc.add_schedule_check(self)
                        else
                            npc.log("DEBUG_SCHEDULE", "Executing schedule entry for NPC "..dump(self.npc_id)..": "
                                    ..dump(schedule[time][i]))
                            -- Run usual schedule entry
                            -- Check chance
                            local execution_chance = math.random(1, 100)
                            if not schedule[time][i].chance or
                                    (schedule[time][i].chance and execution_chance <= schedule[time][i].chance) then
                                -- Check if entry has dependency on other entry
                                local dependencies_met = nil
                                if schedule[time][i].depends then
                                    dependencies_met = npc.utils.array_is_subset_of_array(
                                        self.schedules.temp_executed_queue,
                                        schedule[time][i].depends)
                                end

                                -- Check for dependencies being met
                                if dependencies_met == nil or dependencies_met == true then
                                    -- Add tasks
                                    if schedule[time][i].task ~= nil then
                                        -- Add task
                                        npc.enqueue_script(self, schedule[time][i].task, schedule[time][i].args)
                                    elseif schedule[time][i].action ~= nil then
                                        -- Add action
                                        npc.enqueue_command(self, schedule[time][i].action, schedule[time][i].args)
                                    elseif schedule[time][i].property ~= nil then
                                        -- Change NPC property
                                        npc.schedule_change_property(self, schedule[time][i].property, schedule[time][i].args)
                                    end
                                    -- Backward compatibility check
                                    if self.schedules.temp_executed_queue then
                                        -- Add into execution queue to meet dependency
                                        table.insert(self.schedules.temp_executed_queue, i)
                                    end
                                end
                            else
                                -- TODO: Change to debug
                                npc.log("DEBUG", "Skipping schedule entry for time "..dump(time)..": "..dump(schedule[time][i]))
                            end
                        end
                    end
                    -- Clear execution queue
                    self.schedules.temp_executed_queue = {}
                    npc.log("DEBUG", "New action queue: "..dump(self.actions.queue))
                end
            end
        else
            -- Check if lock can be released
            if (time % 1) > dtime + 0.1 then
                -- Release lock
                self.schedules.lock = false
            end
        end
    end

    return self.freeze
end


---------------------------------------------------------------------------------------
-- NPC Definition
---------------------------------------------------------------------------------------
mobs:register_mob("advanced_npc:npc", {
    type = "npc",
    passive = false,
    damage = 3,
    attack_type = "dogfight",
    attacks_monsters = true,
    -- Added group attack
    group_attack = true,
    -- Pathfinder = 2 to make NPCs more smart when attacking
    pathfinding = 2,
    hp_min = 10,
    hp_max = 20,
    armor = 100,
    collisionbox = {-0.20,0,-0.20, 0.20,1.8,0.20},
    --collisionbox = {-0.20,-1.0,-0.20, 0.20,0.8,0.20},
    --collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
    visual = "mesh",
    mesh = "character.b3d",
    drawtype = "front",
    textures = {
        {"npc_male1.png"},
        {"npc_male2.png"},
        {"npc_male3.png"},
        {"npc_male4.png"},
        {"npc_male5.png"},
        {"npc_male6.png"},
        {"npc_male7.png"},
        {"npc_male8.png"},
        {"npc_male9.png"},
        {"npc_male10.png"},
        {"npc_male11.png"},
        {"npc_male12.png"},
        {"npc_male13.png"},
        {"npc_male14.png"},
        {"npc_female1.png"}, -- female by nuttmeg20
        {"npc_female2.png"},
        {"npc_female3.png"},
        {"npc_female4.png"},
        {"npc_female5.png"},
        {"npc_female6.png"},
        {"npc_female7.png"},
        {"npc_female8.png"},
        {"npc_female9.png"},
        {"npc_female10.png"},
        {"npc_female11.png"},
    },
    child_texture = {
        {"npc_child_male1.png"},
        {"npc_child_female1.png"},
    },
    makes_footstep_sound = true,
    sounds = {},
    -- Added walk chance
    walk_chance = 20,
    -- Added stepheight
    stepheight = 0.6,
    walk_velocity = 1,
    run_velocity = 3,
    jump = false,
    drops = {
        {name = "default:wood", chance = 1, min = 1, max = 3},
        {name = "default:apple", chance = 2, min = 1, max = 2},
        {name = "default:axe_stone", chance = 5, min = 1, max = 1},
    },
    water_damage = 0,
    lava_damage = 2,
    light_damage = 0,
    --follow = {"farming:bread", "mobs:meat", "default:diamond"},
    view_range = 15,
    owner = "",
    order = "follow",
    --order = "stand",
    fear_height = 3,
    animation = {
        speed_normal = 30,
        speed_run = 30,
        stand_start = 0,
        stand_end = 79,
        walk_start = 168,
        walk_end = 187,
        run_start = 168,
        run_end = 187,
        punch_start = 200,
        punch_end = 219,
    },
    after_activate = function(self, staticdata, def, dtime)
        npc.after_activate(self)
    end,
    on_rightclick = function(self, clicker)
        -- Check if right-click interaction is enabled
        if self.enable_rightclick_interaction == true then
            npc.rightclick_interaction(self, clicker)
        end
    end,
    do_custom = function(self, dtime)
        return npc.step(self, dtime)
    end
})

-------------------------------------------------------------------------
-- Item definitions
-------------------------------------------------------------------------

--mobs:register_egg("advanced_npc:npc", S("NPC"), "default_brick.png", 1)

-- compatibility
mobs:alias_mob("mobs:npc", "advanced_npc:npc")

-- Marriage ring
minetest.register_craftitem("advanced_npc:marriage_ring", {
    description = S("Marriage Ring"),
    inventory_image = "marriage_ring.png",
})

-- Marriage ring craft recipe
minetest.register_craft({
    output = "advanced_npc:marriage_ring",
    recipe = { {"", "", ""},
        {"", "default:diamond", ""},
        {"", "default:gold_ingot", ""} },
})


