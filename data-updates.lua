

data.raw["unit"]["small-biter"].resistances = { { type = "acid", percent = 50 } }

for i,res in pairs(data.raw["turret"]["small-worm-turret"].resistances) do
    
    if (res.type and res.type == "acid") then
        res.percent = 50
    end

end

for i,res in pairs(data.raw["turret"]["medium-worm-turret"].resistances) do
    
    if(res.type == "acid") then
        res.percent = 50
    end

end

for i,res in pairs(data.raw["turret"]["big-worm-turret"].resistances) do
    
    if(res.type == "acid") then
        res.percent = 50
    end

end

for i,res in pairs(data.raw["turret"]["behemoth-worm-turret"].resistances) do
    
    if(res.type == "acid") then
        res.percent = 50
    end

end
