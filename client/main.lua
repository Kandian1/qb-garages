local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local PlayerGang = {}
local PlayerJob = {}
local currentHouseGarage = nil
local inGarageRange = false
local OutsideVehicles = {}

--Menus
local function MenuGarage(type, garage, indexgarage)
    local header
    local leave
    if type == "house" then
        header = Lang:t("menu.header."..type.."_car", {value = garage.label})
        leave = Lang:t("menu.leave.car")
    else 
        header = Lang:t("menu.header."..type.."_"..garage.vehicle, {value = garage.label})
        leave = Lang:t("menu.leave."..garage.vehicle)
    end

    exports['qb-menu']:openMenu({
        {
            header = header,
            isMenuHeader = true
        },
        {
            header = Lang:t("menu.header.vehicles"),
            txt = Lang:t("menu.text.vehicles"),
            params = {
                event = "qb-garages:client:VehicleList",
                args = {
                    type = type,
                    garage = garage,
                    index = indexgarage,
                }
            }
        },
        {
            header = leave,
            txt = "",
            params = {
                event = "qb-menu:closeMenu"
            }
        },
    })
end

local function ClearMenu()
	TriggerEvent("qb-menu:closeMenu")
end

local function closeMenuFull()
    ClearMenu()
end

local function CheckPlayers(vehicle, garage)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
            if garage then
                SetEntityCoords(seat, garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
            end
        end
    end
    SetVehicleDoorsLocked(vehicle)
    Wait(1500)
    QBCore.Functions.DeleteVehicle(vehicle)
end

local function GetVehicleProperties(vehicle)
    if DoesEntityExist(vehicle) then
        local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)

        vehicleProps["tyres"] = {}
        vehicleProps["windows"] = {}
        vehicleProps["doors"] = {}
        vehicleProps["windowsBroken"] = AreAllVehicleWindowsIntact(vehicle)

        --  tyres
        for id = 1, 7 do
            local tyreId = IsVehicleTyreBurst(vehicle, id, false)
        
            if tyreId then
                vehicleProps["tyres"][#vehicleProps["tyres"] + 1] = tyreId
        
                if tyreId == false then
                    tyreId = IsVehicleTyreBurst(vehicle, id, true)
                    vehicleProps["tyres"][ #vehicleProps["tyres"]] = tyreId
                end
            else
                vehicleProps["tyres"][#vehicleProps["tyres"] + 1] = false
            end
        end

        --  window
        local windowId = 0
        for i = 1, 8 do
            if IsVehicleWindowIntact(vehicle, windowId) then
                vehicleProps["windows"][i] = false
            else
                vehicleProps["windows"][i] = true
            end
            windowId = windowId + 1
        end
        
        for id = 0, 5 do
            local doorId = IsVehicleDoorDamaged(vehicle, id)
        
            if doorId then
                vehicleProps["doors"][#vehicleProps["doors"] + 1] = doorId
            else
                vehicleProps["doors"][#vehicleProps["doors"] + 1] = false
            end
        end

        vehicleProps["engineHealth"] = GetVehicleEngineHealth(vehicle)
        vehicleProps["bodyHealth"] = GetVehicleBodyHealth(vehicle)
        vehicleProps["fuelLevel"] = GetVehicleFuelLevel(vehicle)
        return vehicleProps
    end
end

-- Functions
local DrawText3Ds = function(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

RegisterNetEvent("qb-garages:client:VehicleList", function(data)
    local type = data.type
    local garage = data.garage
    local indexgarage = data.index
    local header
    local leave
    if type == "house" then
        header = Lang:t("menu.header."..type.."_car", {value = garage.label})
        leave = Lang:t("menu.leave.car")
    else 
        header = Lang:t("menu.header."..type.."_"..garage.vehicle, {value = garage.label})
        leave = Lang:t("menu.leave."..garage.vehicle)
    end

    QBCore.Functions.TriggerCallback("qb-garage:server:GetGarageVehicles", function(result)
        if result == nil then
            QBCore.Functions.Notify(Lang:t("error.no_vehicles"), "error", 5000)
        else
            local MenuGarageOptions = {
                {
                    header = header,
                    isMenuHeader = true
                },
            }
            for k, v in pairs(result) do
                local enginePercent = round(v.engine / 10, 0)
                local bodyPercent = round(v.body / 10, 0)
                local currentFuel = v.fuel
                local vname = QBCore.Shared.Vehicles[v.vehicle].name

                if v.state == 0 then
                    v.state = Lang:t("status.out")
                elseif v.state == 1 then
                    v.state = Lang:t("status.garaged")
                elseif v.state == 2 then
                    v.state = Lang:t("status.impound")
                end
                if type == "depot" then
                    MenuGarageOptions[#MenuGarageOptions+1] = {
                        header = Lang:t('menu.header.depot', {value = vname, value2 = v.depotprice}),
                        txt = Lang:t('menu.text.depot', {value = v.plate, value2 = currentFuel, value3 = enginePercent, value4 = bodyPercent}),
                        params = {
                            event = "qb-garages:client:TakeOutDepot",
                            args = {
                                vehicle = v,
                                type = type,
                                garage = garage,
                                index = indexgarage,
                            }
                        }
                    }
                else
                    MenuGarageOptions[#MenuGarageOptions+1] = {
                        header = Lang:t('menu.header.garage', {value = vname, value2 = v.plate}),
                        txt = Lang:t('menu.text.garage', {value = v.state, value2 = currentFuel, value3 = enginePercent, value4 = bodyPercent}),
                        params = {
                            event = "qb-garages:client:takeOutGarage",
                            args = {
                                vehicle = v,
                                type = type,
                                garage = garage,
                                index = indexgarage,
                            }
                        }
                    }
                end
            end

            MenuGarageOptions[#MenuGarageOptions+1] = {
                header = leave,
                txt = "",
                params = {
                    event = "qb-menu:closeMenu",
                }
            }
            exports['qb-menu']:openMenu(MenuGarageOptions)
        end
    end, indexgarage, type, garage.vehicle)
end)

RegisterNetEvent('qb-garages:client:takeOutGarage', function(data)
    local type = data.type
    local vehicle = data.vehicle
    local garage = data.garage
    local indexgarage = data.index
    local spawn = false

    if type == "depot" then         --If depot, check if vehicle is not already spawned on the map
        local VehExists = DoesEntityExist(OutsideVehicles[vehicle.plate])        
        if not VehExists then
            spawn = true
        else
            QBCore.Functions.Notify(Lang:t("error.not_impound"), "error", 5000)
            spawn = false
        end
    else
        spawn = true
    end
    if spawn then
        local enginePercent = round(vehicle.engine / 10, 1)
        local bodyPercent = round(vehicle.body / 10, 1)
        local currentFuel = vehicle.fuel
        local location = nil
        local heading
        if type == "house" then
            location = garage.takeVehicle
            heading = garage.takeVehicle.h
        else
            for i = 1, #garage.spawnPoints do
                if not IsAnyVehicleNearPoint(vector3(garage.spawnPoints[i].x, garage.spawnPoints[i].y, garage.spawnPoints[i].z), 3.0) then
                    location = garage.spawnPoints[i]
                    heading = garage.spawnPoints[i].w
                    break
                end
            end
        end
    
        if location then
            QBCore.Functions.SpawnVehicle(vehicle.vehicle, function(veh)
                QBCore.Functions.TriggerCallback('qb-garage:server:GetVehicleProperties', function(properties)
                    if vehicle.plate then
                        OutsideVehicles[vehicle.plate] = veh
                        TriggerServerEvent('qb-garages:server:UpdateOutsideVehicles', OutsideVehicles)
                    end
                    QBCore.Functions.SetVehicleProperties(veh, properties)
                    SetVehicleNumberPlateText(veh, vehicle.plate)
                    SetEntityHeading(veh, heading)
                    exports['LegacyFuel']:SetFuel(veh, vehicle.fuel)
                    TriggerEvent('qb-garage:client:InitiateDamageSimulation', veh, properties)
                    SetEntityAsMissionEntity(veh, true, true)
                    TriggerServerEvent('qb-garage:server:updateVehicleState', 0, vehicle.plate, vehicle.garage)
                    closeMenuFull()
                    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                    if WrapIntoVehicle then
                        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                        SetVehicleEngineOn(veh, true, true)
                    end
                end, vehicle.plate)
            end, location, true)
        else
            QBCore.Functions.Notify(Lang:t("error.not_enough_space"), "error", 5000)
        end
    end
end)

--Check distances
local function checkTakeDist(pos, loc, garage, ped, type, indexgarage)
    local takeDist = #(pos - vector3(loc.x, loc.y, loc.z))
    if takeDist <= 15 then
        inGarageRange = true
        DrawMarker(2, loc.x, loc.y, loc.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, false, true, false, false, false)
        if takeDist <= 1.5 then
            if not IsPedInAnyVehicle(ped) then
                if type == "house" then
                    DrawText3Ds(loc.x, loc.y, loc.z + 0.5, Lang:t("info.car_e"))
                else
                    DrawText3Ds(loc.x, loc.y, loc.z + 0.5, Lang:t("info."..garage.vehicle.."_e"))
                end
                if IsControlJustPressed(0, 38) then
                    MenuGarage(type, garage, indexgarage)
                end
            end
        end
        if takeDist >= 4 then
            closeMenuFull()
        end
    end
end

local function enterVehicle(veh, indexgarage, type, garage)
    local plate = QBCore.Functions.GetPlate(veh)
    QBCore.Functions.TriggerCallback('qb-garage:server:checkOwnership', function(owned)
        if owned then
            local bodyDamage = math.ceil(GetVehicleBodyHealth(veh))
            local engineDamage = math.ceil(GetVehicleEngineHealth(veh))
            local totalFuel = exports['LegacyFuel']:GetFuel(veh)
            local vehProperties = GetVehicleProperties(veh)
            TriggerServerEvent('qb-garage:server:updateVehicle', 1, totalFuel, engineDamage, bodyDamage, vehProperties, plate, indexgarage)
            CheckPlayers(veh, garage)
            if plate then
                OutsideVehicles[plate] = nil
                TriggerServerEvent('qb-garages:server:UpdateOutsideVehicles', OutsideVehicles)
            end
            QBCore.Functions.Notify(Lang:t("success.vehicle_parked"), "primary", 4500)
        else
            QBCore.Functions.Notify(Lang:t("error.not_owned"), "error", 3500)
        end
    end, plate, type, indexgarage, PlayerGang.name)
end

local function checkPutDist(pos, loc, garage, ped, type, indexgarage)
    local putDist = #(pos - vector3(loc.x, loc.y, loc.z))
    local dist
    if putDist <= 25 and IsPedInAnyVehicle(ped) then
        inGarageRange = true
        DrawMarker(2, loc.x, loc.y, loc.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 255, 255, 255, 255, false, false, false, true, false, false, false)
        if garage.vehicle == "air" then                     --Give a little more room to air vehicles to be stored
            dist = 3.0
        else
            dist = 1.5
        end
        if putDist <= dist then
            DrawText3Ds(loc.x, loc.y, loc.z + 0.5, Lang:t("info.park_e"))
            DrawText3Ds(loc.x, loc.y, loc.z, garage.label)
            if IsControlJustPressed(0, 38) then
                local curVeh = GetVehiclePedIsIn(ped)
                local vehClass = GetVehicleClass(curVeh)
                --Check vehicle type for garage
                if garage.vehicle == "car" or not garage.vehicle then
                    if vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16 then
                        enterVehicle(curVeh, indexgarage, type)
                    else
                        QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                    end
                elseif garage.vehicle == "air" then
                    if vehClass == 15 or vehClass == 16 then
                        enterVehicle(curVeh, indexgarage, type)
                    else
                        QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                    end
                elseif garage.vehicle == "sea" then
                    if vehClass == 14 then
                        enterVehicle(curVeh, indexgarage, type, garage)
                    else
                        QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                    end
                end
            end
        end
    end
end

CreateThread(function()
    Wait(1000)
    while true do
        Wait(5)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        inGarageRange = false
        for index, garage in pairs(Garages) do
            if garage.type == "public" then
                checkTakeDist(pos, garage.takeVehicle, garage, ped, garage.type, index)
                checkPutDist(pos, garage.putVehicle, garage, ped, garage.type, index)
            elseif garage.type == "job" then
                if PlayerJob.name == garage.job then
                    checkTakeDist(pos, garage.takeVehicle, garage, ped, garage.type, index)
                    checkPutDist(pos, garage.putVehicle, garage, ped, garage.type, index)
                end
            elseif garage.type == "gang" then
                if PlayerGang.name == garage.job then
                    checkTakeDist(pos, garage.takeVehicle, garage, ped, garage.type, index)
                    checkPutDist(pos, garage.putVehicle, garage, ped, garage.type, index)
                end
            elseif garage.type == "depot" then
                checkTakeDist(pos, garage.takeVehicle, garage, ped, garage.type, index)
            end
        end
        if HouseGarages and currentHouseGarage then
            if hasGarageKey and HouseGarages[currentHouseGarage] and HouseGarages[currentHouseGarage].takeVehicle and HouseGarages[currentHouseGarage].takeVehicle.x then
                checkTakeDist(pos, HouseGarages[currentHouseGarage].takeVehicle, HouseGarages[currentHouseGarage], ped, "house", currentHouseGarage)
                checkPutDist(pos, HouseGarages[currentHouseGarage].takeVehicle, HouseGarages[currentHouseGarage], ped, "house", currentHouseGarage)
            end
        end

        if not inGarageRange then
            Wait(1000)
        end
    end
end)

RegisterNetEvent('qb-garages:client:setHouseGarage', function(house, hasKey)
    currentHouseGarage = house
    hasGarageKey = hasKey
end)

RegisterNetEvent('qb-garages:client:houseGarageConfig', function(garageConfig)
    HouseGarages = garageConfig
end)

RegisterNetEvent('qb-garages:client:addHouseGarage', function(house, garageInfo)
    HouseGarages[house] = garageInfo
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerGang = PlayerData.gang
    PlayerJob = PlayerData.job
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    PlayerGang = gang
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job
end)

CreateThread(function()
    for _, garage in pairs(Garages) do
        if garage.showBlip then
            local Garage = AddBlipForCoord(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
            SetBlipSprite (Garage, garage.blipNumber)
            SetBlipDisplay(Garage, 4)
            SetBlipScale  (Garage, 0.60)
            SetBlipAsShortRange(Garage, true)
            SetBlipColour(Garage, 3)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(garage.blipName)
            EndTextCommandSetBlipName(Garage)
        end
    end
end)

RegisterNetEvent('qb-garages:client:TakeOutDepot', function(data)
    local vehicle = data.vehicle

    if vehicle.depotprice ~= 0 then
        TriggerServerEvent("qb-garage:server:PayDepotPrice", data)
    else
        TriggerEvent("qb-garages:client:takeOutGarage", data)
    end
end)

RegisterNetEvent('qb-garage:client:InitiateDamageSimulation', function(vehicle, vehicleProps)
    if vehicle then

        -- windows
        local windowsBroken = 0
        if vehicleProps["windows"] then
            for i = 1, #vehicleProps["windows"] do
                if vehicleProps["windows"][i] then
                    RemoveVehicleWindow(vehicle, i - 1)
                    windowsBroken = windowsBroken + 1
                end
            end
            if windowsBroken >= 5 then
                PopOutVehicleWindscreen(vehicle)
            end
        end

        --  tyres
        if vehicleProps["tyres"] then
            for i = 1, #vehicleProps["tyres"] do
                if vehicleProps["tyres"][i] ~= false then
                    SetVehicleTyreBurst(vehicle, i, true, 1000)
                end
            end
        end

        --  doors
        if vehicleProps["doors"] then
            for i = 1, #vehicleProps["doors"] do
                if vehicleProps["doors"][i] then
                    SetVehicleDoorBroken(vehicle, i - 1, true)
                end
            end
        end

        --engineHealth
        if vehicleProps["engineHealth"] then
            SetVehicleEngineHealth(vehicle, vehicleProps["engineHealth"])
        end

        --bodyHealth
        if vehicleProps["bodyHealth"] then
            SetVehicleBodyHealth(vehicle, vehicleProps["bodyHealth"])
        end

        --fuel
        if vehicleProps["fuelLevel"] then
            exports["LegacyFuel"]:SetFuel(vehicle, tonumber(vehicleProps["fuelLevel"]))
        end
    end
end)