
--this is a desperate attempt to adjust the worms acid resistance to allow proper nest-battles during force transitions.
for key, turret in pairs(data.raw["turret"]) do 

    if string.match(turret.name, "worm") or string.match(turret.name, "Worm") then
        
        resTable = turret.resistances
        for _, resistance in pairs(resTable) do 
            if resistance.type == "acid" then
               
                resistance.percent = 50
                resistance.decrease = 5
            end
           
        end 
    end 
end 