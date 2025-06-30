local args = {...}
local argParse = require("argumentParser")
args = argParse(args)
if not args["--name"] then
    error("Please provide the name with `--name str` argument!")
end
local server
local idServer
local name = args["--name"]
local protocol = args["--protocol"] or "OBSI-GAME-TEST"

if args["--host"] then
    server = require("server")
    server.start(args["--port"], protocol, name)
    server.recieveMessage(os.getComputerID(), {type = "connect", name = args["--hostname"] or args["--name"]})
else
    rednet.CHANNEL_BROADCAST = args["--port"] or rednet.CHANNEL_BROADCAST

    for _, v in ipairs(peripheral.getNames()) do
        if peripheral.getType(v) == "modem" then
            rednet.open(v)
            idServer = rednet.lookup(protocol, args["--hostname"])
            if not idServer then
                error(("No server with protocol %s found!"):format(protocol))
            end
            print("Found server #" .. idServer)
            rednet.send(idServer, {type = "connect", name = name}, protocol)
            local idTimer = os.startTimer(5) -- will wait for some time before timing out
            while true do
                local ev = {os.pullEvent()}
                if ev[1] == "timer" and ev[2] == idTimer then
                    error("Server time out.")
                elseif ev[1] == "rednet_message" then
                    if ev[2] == idServer and ev[4] == protocol then
                        -- print(textutils.serialise(ev))
                        if ev[3].type == "connection error" then
                            error(ev[3].text)
                        elseif ev[3].type == "connection success" then
                            print("Connected!")
                            break
                        end
                    end
                end
            end
            os.cancelTimer(idTimer)
        end
    end
end

---@type game.player
local selfPlayer = {
    x = 0,
    y = 0,
    health = 3,
    flipped = false,
    lastUpdate = 0 -- useless in client but whatever
}

---@type table<string, game.player>
local players = {}
---@type game.bullet[]
local bullets = {}

local obsi = require("obsi2")
local playerImage = obsi.graphics.newImage("player.nfp")

function obsi.load()
    obsi.graphics.setRenderer("neat")
end

function obsi.update(dt)
    if obsi.keyboard.isDown("right") then
        selfPlayer.flipped = false
        selfPlayer.x = selfPlayer.x + dt*10
    end
    if obsi.keyboard.isDown("left") then
        selfPlayer.flipped = true
        selfPlayer.x = selfPlayer.x - dt*10
    end
    if obsi.keyboard.isDown("down") then
        selfPlayer.y = selfPlayer.y + dt*10
    end
    if obsi.keyboard.isDown("up") then
        selfPlayer.y = selfPlayer.y - dt*10
    end
    if server then
        server.recieveMessage(os.getComputerID(), {type = "update player", name = name, x = selfPlayer.x, y = selfPlayer.y, flipped = selfPlayer.flipped, health = selfPlayer.health})
        server.update(dt)
    else
        rednet.send(idServer, {type = "update player", name = name, x = selfPlayer.x, y = selfPlayer.y, flipped = selfPlayer.flipped, health = selfPlayer.health}, protocol)
    end
end

function obsi.onKeyPress(key)
    if key == keys.z then
        if server then
            server.recieveMessage(os.getComputerID(), {type = "fire bullet", name = name, direction = selfPlayer.flipped and -1 or 1})
        else
            rednet.send(idServer, {type = "fire bullet", name = name, direction = selfPlayer.flipped and -1 or 1}, protocol)
        end
    elseif key == keys.x then
        if server then
            server.recieveMessage(os.getComputerID(), {type = "fire triple", name = name, direction = selfPlayer.flipped and -1 or 1})
        else
            rednet.send(idServer, {type = "fire triple", name = name, direction = selfPlayer.flipped and -1 or 1}, protocol)
        end
    end
end

function obsi.draw()
    obsi.graphics.setOrigin(math.floor(selfPlayer.x-obsi.graphics.getPixelWidth()/2+2.5), math.floor(selfPlayer.y-obsi.graphics.getPixelHeight()/2+2))
    -- background
    local c = obsi.graphics.getForegroundColor()
    obsi.graphics.setForegroundColor(colors.gray)
    for y = math.floor(obsi.graphics.originY/4)*4, math.floor((obsi.graphics.originY+obsi.graphics.getPixelHeight())/4)*4, 2 do
        if y % 4 == 0 then
            for x = math.floor(obsi.graphics.originX/4)*4, math.floor((obsi.graphics.originX+obsi.graphics.getPixelWidth())/4)*4+4, 4 do
                obsi.graphics.point(x, y)
                obsi.graphics.point(x+1, y)
                obsi.graphics.point(x, y+1)
                obsi.graphics.point(x+1, y+1)
            end
        else
            for x = math.floor(obsi.graphics.originX/4)*4, math.floor((obsi.graphics.originX+obsi.graphics.getPixelWidth())/4)*4+4, 4 do
                obsi.graphics.point(x-2, y)
                obsi.graphics.point(x+1-2, y)
                obsi.graphics.point(x-2, y+1)
                obsi.graphics.point(x+1-2, y+1)
            end
        end
    end
    obsi.graphics.setForegroundColor(c)
    obsi.graphics.draw(playerImage, math.floor((selfPlayer.flipped and selfPlayer.x + playerImage.width-1 or selfPlayer.x)+0.5), selfPlayer.y, selfPlayer.flipped and -1 or 1)
    obsi.graphics.write("YOU", obsi.graphics.getWidth()/2, obsi.graphics.getHeight()/2)
    for pname, player in pairs(players) do
        if pname ~= name then
            obsi.graphics.draw(playerImage, player.flipped and player.x + playerImage.width-1 or player.x, player.y, player.flipped and -1 or 1)
            obsi.graphics.write(pname, obsi.graphics.pixelToTermCoordinates(player.x-obsi.graphics.originX+playerImage.width/2+2-#pname/2, player.y-obsi.graphics.originY))
            obsi.graphics.write("HP: "..tostring(player.health), obsi.graphics.pixelToTermCoordinates(player.x-obsi.graphics.originX+playerImage.width/2-1, player.y-obsi.graphics.originY+playerImage.height+1))
        end
    end

    for i = 1, #bullets do
        local b = bullets[i]
        obsi.graphics.point(b.x, b.y)
    end

    local playerCount = 0
    for k, v in pairs(players) do
        playerCount = playerCount + 1
    end
    obsi.graphics.write(("Name: %s"):format(name), 1, 1)
    obsi.graphics.write(("Health: %s"):format(selfPlayer.health), 1, 2)
    obsi.graphics.write(("Players: %s"):format(playerCount), obsi.graphics.getWidth()-10, 1)
end

function obsi.onEvent(ev)
    if ev[1] == "rednet_message" and ev[4] == protocol then
        if server then
            server.recieveMessage(ev[2], ev[3])
            players = server.players
            bullets = server.bullets
            selfPlayer.health = players[name].health
            selfPlayer.x = players[name].x
            selfPlayer.y = players[name].y
        elseif ev[2] == idServer then
            local m = ev[3]
            if m.type == "update players" then
                players = m.players
                selfPlayer.health = players[name].health
            elseif m.type == "force update player" then
                selfPlayer = m.player
            elseif m.type == "update bullets" then
                bullets = m.bullets
            elseif m.type == "connection error" then
                error(m.text)
            end
        end
    end
end

obsi.init()