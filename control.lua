
require("util")

--define some parameters, will move these to mod settings parameters at some point.
local factionCount = 5 -- number of biter factions to distribute evenly among each new chunk generated and the biters which spawn on it. 
local attackWaveChance = 0.10 --baseline chance for sending an attack to nearest detected units of an enemy faction.  
local playerAttackChanceReduction = 0.25  -- modifier to units' chance of attack if the detected nearest enemy is player' forces. 25% less likely to launch an attack against a player than against other forces. 
local attackWavePeriod = 3000 -- baseline attack period/cooldown, to then check attack chances. 
local evoPeriodModifier = 0.5  -- adjustment to attack wave period/frequency, based on evolution percent. current evo * modifier = REDUCTION of attack cooldown period.
local evoChanceModifier = 0.1  -- additional chance based on evolution percent.  current evo % * modifier = additional chance to send attack.
local periodDither = 600 --random amount to dither each faction's next attack by, so they don't all line up on the same tick.

local debugMode = nil  --make this nil or non-nil, to disable or enable debug mode.

function initHandler(event)

    global.factionList = global.factionList or  {}
    global.nextAttackTick = global.nextAttackTick or {}
    global.nests = global.nests or {}
    createForces()

end

--generates the biter action forces, with generic names, based on the factioncount parameter. inits them with the current state of the 'enemy' force.
function createForces()
    
    for i=1,factionCount do
        
        if not global.factionList[i] then

            if not game.forces["biter_faction_"..i] then 

                global.factionList[i] = game.create_force("biter_faction_"..i)
                global.nests[i] = {}
                local forcecreated = global.factionList[i] 
                if debugMode then game.print("created biter faction: "..forcecreated.name) end
                forcecreated.ai_controllable = true
                forcecreated.evolution_factor = game.forces["enemy"].evolution_factor
                forcecreated.evolution_factor_by_pollution  = game.forces["enemy"].evolution_factor_by_pollution 
                forcecreated.evolution_factor_by_time  = game.forces["enemy"].evolution_factor_by_time 
                forcecreated.evolution_factor_by_killing_spawners  = game.forces["enemy"].evolution_factor_by_killing_spawners 
                
                --init the values for last attack tick and the next expected attack ticks, with no modifiers used yet.
                global.nextAttackTick[i] = game.tick + attackWavePeriod + math.random(periodDither)
            end

        end

    end

end


--handles converting any "enemy" entities to one of the random factions when a chunk is generated (for the first time) or charted by radar.
--note this means there will basically never be an "enemy" force entities in the game map after this has run on all existing chunks and any new ones
--generated
function chunkGenHandler(event)
    
    local chunkarea = event.area
    local surface = event.surface
    
    if not surface then
        local surface = game.get_surface(event.surface_index) --means it was an on-charted event
    end
    
    if not surface then 
        return
    end
    
    local factionIndex = math.random(#global.factionList) 
    local force = global.factionList[factionIndex ]  --random force index from 1 to factionlist length
     
    local entitiesList = surface.find_entities_filtered{area = chunkarea, force = "enemy"}
 
    for i, entity in pairs(entitiesList) do

        if entity and entity.valid then

            entity.force = force  --change the entity's force. nest, worm, biters should all be affected.
        
            --if it's a spawner, add to the force's spawner list.
            if entity.name == "biter-spawner" or entity.name == "spitter-spawner" then 
                if not global.nests[i] then global.nests[i] = {} end
                global.nests[i][entity.unit_number] = entity --store the entity by its unit number in the force's list.
                if debugMode then game.print("Faction "..factionIndex.." has ".. table_size(global.nests[i]).." nests!") end
            end
        end

    end

end

--this runs logic to send waves of attacks from each biter factions base to nearby enemy units,  i.e other biter faction nests and the player's base, whichever is closer..
--once a biter faction becomes dominant, it will mostly send its armies to the player's base. Beware!
function runAttackHandler(event)

    global.factionList = global.factionList or {}
    global.nextAttackTick = global.nextAttackTick or {}
    global.nests = global.nests or {}

    if not global.factionList[1] then 
        createForces()
    end

    -- check each force for if it's their time to send an attack. each force has its own evolution % which will affect its aggression. 
    for i, force in pairs( global.factionList) do

        --compare tick 
        if not global.nextAttackTick[i] then global.nextAttackTick[i] = event.tick end
        if event.tick >= global.nextAttackTick[i] then
            
            -- calculate chance of attack this time around
            -- if attack should go ahead, then get list of spawners. 
            -- then iterate through list of spawners, and command all units within 64 tile radius to attack nearest enemies. 
            
            
            
            local evoChanceAdj = evoChanceModifier * force.evolution_factor   --the chance of triggering an attack. the playerAttackChanceReduction is used later during targeting, as a chance to just not go ahead with the attack.
            
            local shouldAttack = math.random() <= (attackWaveChance + evoChanceAdj)  -- random % value computed, if the generated % value is equal or less than the chance to trigger, it triggers. 
            
            if shouldAttack then 
                if debugMode then game.print("biter faction: "..force.name.." is launching an attack. Beware!") end
                --do the attack launch code.
                
                --ensure there is a list of nests. if there isn't quickly generate one to get started..
                if not global.nests[i] then 
                    global.nests[i] = {}
                    game.print("Bootstrapping faction "..force.name.." to set up nest lists")
                    local surf = game.surfaces[1]
                    local nestList = surf.find_entities_filtered{position={0,0}, radius= 15000, force = force.name, type ="unit-spawner"}
                    
                    game.print("Found "..#nestList.." nests!")
                    
                    for j, nestFound in pairs(nestList) do 
                        global.nests[i][nestFound.unit_number] = nestFound  --insert the nest to the nests table using its unit_number as the key.
                    end 
                    
                end

                --check and init tables as needed, to schedule an attack for this faction. 
                if not global.scheduledAttack then global.scheduledAttack = {} end
                global.scheduledAttack[i] = 1 --set this faction's index to start an attack. 

                if not global.attackProgress then global.attackProgress = {} end
                global.attackProgress[i] = 0  --set this faction's attack progress to 0, so it can be incremented in the proceeding ticks. 

            end --if should attack trigger

            

            --now calculate when this faction should check for another attack.
            local evoPeriodAdj = force.evolution_factor * evoPeriodModifier
            global.nextAttackTick[i] = event.tick + attackWavePeriod + math.random(periodDither) - evoPeriodAdj
            
        end --end of if next attack tick equal/exceeded

        --check for if attack is active for this faction, and initate the next wave of attacking nests.
        if (global.scheduledAttack and global.scheduledAttack[i] == 1) then
            local progress = 0
            for key, nest in pairs(global.nests[i]) do 
                progress = progress + 1
                if nest.valid and progress == global.attackProgress[i] then 
                    --find nearest enemy within 3k tiles.
                    local enemy = nest.surface.find_nearest_enemy({position= nest.position, max_distance = 3000, force=nest.force})
                    local keepAttacking = 1
                    if enemy.force.name == "player" then
                        keepAttacking = math.random() <= playerAttackChanceReduction --if random returns less than or equal to the chance to avoid attacking if target is player, then call off the attack!
                    end

                    if keepAttacking then 
                        --get list of nearby entities of type "unit" to give attack orders.
                        --alternatively... get the unit's owned directly from the spawner , regardless of position! :) Much more efficient. 
                        local unitList =  nest.units --nest.surface.find_entities_filtered{area = chunkarea, force = force.name, type ="unit"}
                        
                        --give the attack command!
                        for k, entity in pairs(unitList) do
                            entity.set_command({type=defines.command.attack_area, destination=enemy.position, radius=32, distraction=defines.distraction.by_anything}) 
                        end
                    end
                    
                else
                    if not nest.valid then
                        global.nests[key] = nil --wipe out this entry, it's dead/invalid now.
                    end
                    goto nextProgressDone
                end
            end
        

            ::nextProgressDone::

            --increment attack progress counter, and check for table end reached.
            global.attackProgress[i] = global.attackProgress[i] + 1 

            local maxCount = table_size(global.nests[i])
            if global.attackProgress[i] >= maxCount then  --if we've ticked up enough nests then we are done.
                if(debugMode) then game.print("Biter faction "..i.." finished attacking with "..global.attackProgress[i].." nests!") end
                if(debugMode) then game.print("Biter faction has "..table_size(global.nests[i]).." nests") end
                global.scheduledAttack[i] = 0
                global.attackProgress[i] = 0
            end
        end
    end -- end for each faction in faction list.

end

function expansionBaseHandler(event)

    local entity = event.entity
    if debugMode then game.print("Type of newly built expansion entity: "..entity.prototype.type) end
    if entity.prototype.type == "unit-spawner" then
        if debugMode then game.print("It's a spawner type entity!") end
        local force = entity.force

        if global.factionList and global.nests then
            for i, force in pairs(global.factionList) do 
                if global.nests[i] then 
                    global.nests[i][entity.unit_number] = entity
                end
            end
        end

    end

end


script.on_init(initHandler)
script.on_event(defines.events.on_chunk_charted, chunkGenHandler)
script.on_event(defines.events.on_chunk_generated, chunkGenHandler)
script.on_event(defines.events.on_biter_base_built, expansionBaseHandler )
script.on_event(defines.events.on_tick, runAttackHandler)