local server = {}

---@type table<number, string>
server.playerNames = {}

---@param name string
---@return number
local function findID(name)
    -- find who's hosting this fuck
    for id, name1 in pairs(server.playerNames) do
        if name == name1 then
            return id
        end
    end
    return -1
end

---@class game.player
---@field x number
---@field y number
---@field health number
---@field flipped boolean
---@field lastUpdate number

---@class game.bullet
---@field owner string
---@field x number
---@field y number
---@field speedX number
---@field speedY number

---@return game.player
local function createPlayer()
    return {
        x = 0,
        y = 0,
        health = 3,
        flipped = false,
        lastUpdate = os.epoch("local"),
    }
end

local function createBullet(x, y, speedX, speedY, owner)
    return {
        x = x,
        y = y,
        speedX = speedX,
        speedY = speedY,
        owner = owner,
    }
end

---@type table<string, game.player>
server.players = {}
---@type game.bullet[]
server.bullets = {}

---@param port number?
---@param protocol string?
---@param name string
function server.start(port, protocol, name)
    rednet.CHANNEL_BROADCAST = port or rednet.CHANNEL_BROADCAST
    server.protocol = protocol or "OBSI-GAME-TEST"

    for _, v in ipairs(peripheral.getNames()) do
        if peripheral.getType(v) == "modem" then
            server.modemSide = v
            rednet.open(v)
            rednet.host(server.protocol, name)
        end
    end
end

---@param sender integer
---@param message table?
function server.recieveMessage(sender, message)
    if type(message) ~= "table" then
        return
    end

    if message.type == "connect" then
        -- check if player with same name already exists
        for k, v in pairs(server.playerNames) do
            if v == message.name then
                rednet.send(sender, {type = "connection error", text = "Player with the same name already connected."}, server.protocol)
                return
            end
        end
        -- if not, add them!
        rednet.send(sender, {type = "connection success", text = ""}, server.protocol)
        server.playerNames[sender] = message.name
        server.players[message.name] = createPlayer()
    elseif message.type == "update player" then
        if server.playerNames[sender] == message.name then
            local player = server.players[message.name]
            if player.health <= message.health then
                player.x = message.x
                player.y = message.y
                player.flipped = message.flipped
                player.lastUpdate = os.epoch("local")
            end
        end
    elseif message.type == "fire bullet" then
        if server.playerNames[sender] == message.name then
            local player = server.players[message.name]
            server.bullets[#server.bullets+1] = createBullet(player.x+(message.direction > 0 and 3 or 0), player.y+1, message.direction, 0, message.name)
        end
    elseif message.type == "fire triple" then
        if server.playerNames[sender] == message.name then
            local player = server.players[message.name]
            server.bullets[#server.bullets+1] = createBullet(player.x+(message.direction > 0 and 3 or 0), player.y+1, message.direction, 1, message.name)
            server.bullets[#server.bullets+1] = createBullet(player.x+(message.direction > 0 and 3 or 0), player.y+1, message.direction, 0, message.name)
            server.bullets[#server.bullets+1] = createBullet(player.x+(message.direction > 0 and 3 or 0), player.y+1, message.direction, -1, message.name)
        end
    end
end

function server.update(dt)
    do
        -- check if bullet too far away from anyone
        local i = 1
        local maxDistance = 256
        while i <= #server.bullets do
            local b = server.bullets[i]
            local minD = 0
            for _, p in pairs(server.players) do
                minD = math.min(minD, ((p.x-b.x)^2 + (p.y-b.y)^2)^0.5)
            end
            if minD >= maxDistance then
                table.remove(server.bullets, i)
            else
                i = i + 1
            end
        end
    end
    for name, p in pairs(server.players) do
        local i = 1
        while i <= #server.bullets do
            local hit = false
            local b = server.bullets[i]
            b.x = b.x + b.speedX
            b.y = b.y + b.speedY
            if b.x >= p.x and b.x < p.x+3 then
                if b.y >= p.y-1 and b.y < p.y+3 then
                    -- hit!
                    if name ~= b.owner then
                        hit = true
                        p.health = p.health - 1
                        table.remove(server.bullets, i)
                        if p.health == 0 then
                            p.health = 3
                            p.x = math.random(-12, 12)
                            p.y = math.random(-12, 12)
                            p.lastUpdate = os.epoch("local")
                            rednet.send(findID(name), {type = "force update player", player = p}, server.protocol)
                        end
                        break
                    end
                end
            end
            if not hit then
                i = i + 1
            end
        end
    end

    -- You shouldn't really pass the table itself, but like, it's just a demo...
    rednet.broadcast({type = "update players", players = server.players}, server.protocol)
    rednet.broadcast({type = "update bullets", bullets = server.bullets}, server.protocol)

    for name, player in pairs(server.players) do
        if (os.epoch("local") - player.lastUpdate)/1000 > 3 then
            -- find who's hosting this fuck
            for id, name1 in pairs(server.playerNames) do
                if name == name1 then
                    rednet.send(id, {type = "connection error", text = "Timeout."}, server.protocol)
                    server.players[server.playerNames[id]] = nil
                    server.playerNames[id] = nil
                    break
                end
            end
        end
    end
end

return server