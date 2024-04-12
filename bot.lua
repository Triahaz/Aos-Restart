-- Initialize game agent
local Agent = {
    id = ao.id,
    energyThreshold = 5,
    attackRange = 1,
    laserEnergyCost = 20,
    shieldEnergyCost = 30,
    grabEnergyCost = 25,
    stealEnergyCost = 15  -- Energy cost for stealing opponent's energy
}

-- Function to check if a player is within attack range
local function isPlayerWithinRange(player1, player2, range)
    local distance = math.abs(player1.x - player2.x) + math.abs(player1.y - player2.y)
    return distance <= range
end

-- Function to randomly select a direction
local function getRandomDirection()
    local directions = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
    return directions[math.random(#directions)]
end

-- Function to shoot lasers at opponents
local function shootLaser(gameState)
    local player = gameState.Players[Agent.id]

    for playerId, state in pairs(gameState.Players) do
        if playerId ~= Agent.id and isPlayerWithinRange(player, state, Agent.attackRange) then
            if player.energy >= Agent.laserEnergyCost then
                ao.send({ Target = Game, Action = "PlayerAttack", Player = Agent.id, AttackEnergy = tostring(Agent.laserEnergyCost) })
                return true
            else
                -- Insufficient energy to shoot laser
                return false
            end
        end
    end

    -- No opponent within attack range
    return false
end

-- Function to activate shield if enough energy
local function activateShield()
    local player = LatestGameState.Players[Agent.id]
    if player.energy >= Agent.shieldEnergyCost then
        ao.send({ Target = Game, Action = "ActivateShield", Player = Agent.id })
        return true
    else
        -- Insufficient energy to activate shield
        return false
    end
end

-- Function to grab and throw opponents away or steal their energy
local function grabAndThrow(gameState)
    local player = gameState.Players[Agent.id]

    for playerId, state in pairs(gameState.Players) do
        if playerId ~= Agent.id and isPlayerWithinRange(player, state, Agent.attackRange) then
            if player.energy >= Agent.grabEnergyCost then
                -- Calculate direction to throw opponent away
                local deltaX = state.x - player.x
                local deltaY = state.y - player.y
                local throwDirection = ""
                if math.abs(deltaX) > math.abs(deltaY) then
                    throwDirection = deltaX > 0 and "Right" or "Left"
                else
                    throwDirection = deltaY > 0 and "Down" or "Up"
                end

                -- Send command to throw opponent away
                ao.send({ Target = Game, Action = "PlayerThrow", Player = Agent.id, Direction = throwDirection })
                return true
            elseif player.energy >= Agent.stealEnergyCost then
                -- Steal opponent's energy if enough energy available
                ao.send({ Target = Game, Action = "StealEnergy", Player = Agent.id, TargetPlayer = playerId })
                return true
            else
                -- Insufficient energy to grab or steal opponent
                return false
            end
        end
    end

    -- No opponent within attack range
    return false
end

-- Function to find cover among opponents
local function findCover(gameState)
    local player = gameState.Players[Agent.id]

    for playerId, state in pairs(gameState.Players) do
        if playerId ~= Agent.id then
            local opponent = gameState.Players[playerId]
            if isPlayerWithinRange(player, opponent, Agent.attackRange * 2) then
                -- Opponent can be used as cover
                return true, opponent
            end
        end
    end

    -- No cover found
    return false, nil
end

-- Function to decide the next action based on game state
local function decideNextAction(gameState)
    local player = gameState.Players[Agent.id]

    -- Check if shield can be activated
    if activateShield() then
        return
    end

    -- Check if shooting a laser is possible
    if shootLaser(gameState) then
        return
    end

    -- Check if grabbing, throwing opponent, or stealing energy is possible
    if grabAndThrow(gameState) then
        return
    end

    -- Check if using opponent as cover is possible
    local foundCover, coverOpponent = findCover(gameState)
    if foundCover then
        -- Move towards cover opponent
        local deltaX = coverOpponent.x - player.x
        local deltaY = coverOpponent.y - player.y
        local direction
        if math.abs(deltaX) > math.abs(deltaY) then
            direction = deltaX > 0 and "Right" or "Left"
        else
            direction = deltaY > 0 and "Down" or "Up"
        end
        ao.send({ Target = Game, Action = "PlayerMove", Player = Agent.id, Direction = direction })
        return
    end

    -- If no other action is possible, move randomly
    if player.energy > Agent.energyThreshold then
        ao.send({ Target = Game, Action = "PlayerMove", Player = Agent.id, Direction = getRandomDirection() })
    end
end

-- Handler to receive game state updates
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local gameState = json.decode(msg.Data)
        decideNextAction(gameState)
    end
)

-- Handler to trigger action decision on tick
Handlers.add(
    "TriggerActionDecision",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        ao.send({ Target = Game, Action = "GetGameState" })
    end
)
