inputCount = 250000
maxGenerations = 1000
initialSize = 20

breedChance = 0.1

mutateSubjectChance = 0.2
mutateInputChance = 0.2

cullFinalAmount = 15

generation = 0

iteration = 1
totalIterations = 0
fitness = 0
currentInput = 0

bestFitnesses = {}

screenPos = 0
health = 32
lives = 3
robotsBeaten = 0
xPos = 0
yPos = 0
horizScroll = 0

textForegroundColor = 0xFF0050FF
textBackgroundColor = 0xFFFFFFFF
screenBorderColor = 0xA050FFFF
pointColor = 0xFF000000

memoized_inputs = {}

JSON = (loadfile "JSON.lua")()
saveFileBase = "save_file"
lastInput = {}
loadingFile = false

resetCommand = {["Reset"] = true}

ramAddresses = {["X Pos"] = 0x0460, ["Y Pos"] = 0x04A0,
    ["Health"] = 0x06C0, ["Lives"] = 0x00A8,
    ["Screen Pos"] = 0x0440, ["Robot Masters Beaten"] = 0x009A,
    ["Horiz Scroll"] = 0x001F}

states = {"Initial Generation", "Breeding", "Mutating"}
currentState = 1

memory.usememorydomain("RAM")
buttons = joypad.getimmediate()

gui.defaultBackground(0xFFFFFFFF)

function main()
    console.clear()

    herd = generateHerd(initialSize)

    processHerd(generation)
end

function processHerd(startGeneration)
    for i=startGeneration,maxGenerations do
        herd = sortHerd(herd)

        herd = cullHerd(herd)

        currentState = 2
        herd = breedHerd(herd)

        currentState = 3
        herd = mutateHerd(herd)

        if loadingFile then
            loadingFile = false

            memoized_inputs = {}

            processHerd(generation)

            return
        end

        print("End of generation " .. generation + 1 .. ".  Best fitness: " .. herd[1][2][1])

        iteration = 0
        generation = generation + 1

        if generation % 10 == 0 then saveData() end
    end
end

-- Recursive print courtesy of stuby
-- https://gist.github.com/stuby/5445834#file-rprint-lua
--[[ rPrint(struct, [limit], [indent])   Recursively print arbitrary data.
	Set limit (default 100) to stanch infinite loops.
	Indents tables as [KEY] VALUE, nested tables as [KEY] [KEY]...[KEY] VALUE
	Set indent ("") to prefix each line:    Mytable [KEY] [KEY]...[KEY] VALUE
--]]
function rPrint(s, l, i) -- recursive Print (structure, limit, indent)
    l = (l) or 100; i = i or "";	-- default item limit, indent string

    if (l<1) then print "ERROR: Item limit reached."; return l-1 end;

    local ts = type(s);

    if (ts ~= "table") then print (i,ts,s); return l-1 end

    print (i,ts);           -- print "table"

    for k,v in pairs(s) do  -- print "[KEY] VALUE"
        l = rPrint(v, l, i.."\t["..tostring(k).."]");

        if (l < 0) then break end
    end

    return l
end

-- From lhf
-- http://stackoverflow.com/a/4991602
function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

function saveData()
    for i=1,100 do
        local fileName = saveFileBase .. i .. ".json"

        if not file_exists(fileName) then
            local outfile = io.open(fileName, 'w')

            local jsonData = {['inputCount'] = inputCount, ['maxGenerations'] = maxGenerations,
                ['breedChance'] = breedChance, ['mutateSubjectChance'] = mutateSubjectChance,
                ['mutateInputChance'] = mutateInputChance, ['cullFinalAmount'] = cullFinalAmount,
                ['generation'] = generation, ['iteration'] = iteration,
                ['totalIterations'] = totalIterations, ['currentState'] = currentState,
                ['herd'] = herd }

            print("Saved data to " .. fileName)
            gui.addmessage("Saved data to " .. fileName)

            outfile:write(JSON:encode(jsonData))
            io.close(outfile)

            return
        end

        if i == 100 then
            print("Failed to save file after 100 attempts.")
            gui.addmessage("Failed to save file after 100 attempts.")
        end
    end
end

function loadData()
    for i=1,100 do
        local fileName = saveFileBase .. i ..".json"

        if file_exists(fileName) then
            local infile = io.open(fileName, 'r')

            local jsonString = infile:read("*all")
            local jsonData = JSON:decode(jsonString)

            inputCount = jsonData['inputCount']
            maxGenerations = jsonData['maxGenerations']
            breedChance = jsonData['breedChance']
            mutateSubjectChance = jsonData['mutateSubjectChance']
            mutateInputChance = jsonData['mutateInputChance']
            cullFinalAmount = jsonData['cullFinalAmount']
            generation = jsonData['generation']
            iteration = jsonData['iteration']
            totalIterations = jsonData['totalIterations']
            currentState = jsonData['currentState']
            herd = jsonData['herd']

            print("Loaded data from " .. fileName)
            gui.addmessage("Loaded data from " .. fileName)

            io.close(infile)

            return
        end

        if i > 100 then
            print("Failed to load file after 100 attempts.")
            gui.addmessage("Failed to load file after 100 attempts.")
        end
    end
end

function readUserInput()
    inputKeys = input.get()

    if inputKeys["S"] and not lastInput["S"] then saveData() end
    if inputKeys["L"] and not lastInput["L"] then loadData() end

    lastInput = inputKeys
end

function drawData()
    gui.text(0, 16, "Fitness: " .. fitness, textBackgroundColor, textForegroundColor)
    gui.text(0, 64, "Screen position: " .. screenPos, textBackgroundColor, textForegroundColor)
    gui.text(0, 80, "Health: " .. health, textBackgroundColor, textForegroundColor)
    gui.text(0, 96, "Lives: " .. lives, textBackgroundColor, textForegroundColor)
    gui.text(0, 112, "Robot Masters beaten: " .. robotsBeaten, textBackgroundColor, textForegroundColor)
    gui.text(0, 128, "(" .. xPos .. ", " .. yPos .. ")", textBackgroundColor, textForegroundColor)

    gui.text(0, 160, "State: " .. states[currentState], textBackgroundColor, textForegroundColor)
    gui.text(0, 176, "Generation " .. generation + 1 .. " - Iteration " .. iteration, textBackgroundColor, textForegroundColor)
    gui.text(0, 192, currentInput .. "/" .. inputCount .. " inputs", textBackgroundColor, textForegroundColor)
    gui.text(0, 208, totalIterations .. " total candidates", textBackgroundColor, textForegroundColor)

    if horizScroll == 0 then gui.drawLine(0, 0, 0, 255, screenBorderColor) end
    gui.drawLine(255 - horizScroll, 0, 255 - horizScroll, 255, screenBorderColor)

    local fitnessesToGraph = table.getn(bestFitnesses)
    if fitnessesToGraph > 0 then
        local maxFitness = math.max(unpack(bestFitnesses))

        if maxFitness == 0 then maxFitness = 1 end -- prevent divide by 0

        local maxOffset = 0

        if maxFitness > 0 then
            maxOffset = 16 * (math.ceil(math.log10(maxFitness)) - 3)
        end

        gui.drawBox(140, 100, 230, 20, 0x00000000, screenBorderColor)
        gui.drawLine(140, 100, 140, 20)
        gui.drawLine(140, 100, 230, 100)
        gui.text(900, 32, "Last 20 Fitnesses")
        gui.text(800 - maxOffset, 64, maxFitness)
        gui.text(816, 240, "0")

        for i=1,fitnessesToGraph - 1 do
            gui.drawLine(140 + (4.5 * (i - 1)), 100 - (80 * bestFitnesses[i] / maxFitness),
                140 + (4.5 * i), 100 - (80 * bestFitnesses[i + 1] / maxFitness), pointColor)

            i = i + 1
        end
    end
end

function calculateBeatenRobotMasters()
    local robotMasterFlags = memory.readbyte(ramAddresses["Robot Masters Beaten"])
    local count = 0

    for i=1,9 do
        count = count + (bit.band(bit.rshift(robotMasterFlags, i), 1))
    end

    return count
end

function calculateFitness()
    screenPos = memory.readbyte(ramAddresses["Screen Pos"])
    health = memory.readbyte(ramAddresses["Health"])
    lives = memory.readbyte(ramAddresses["Lives"])
    robotsBeaten = calculateBeatenRobotMasters()
    xPos = memory.readbyte(ramAddresses["X Pos"])
    yPos = memory.readbyte(ramAddresses["Y Pos"])
    horizScroll = memory.readbyte(ramAddresses["Horiz Scroll"])

    return (screenPos + 1) * health * lives * math.pow((robotsBeaten + 1), 3)  + horizScroll
end

function byteToInputs(byte)
    local inputs = {}

    inputs["P1 A"] =      bit.band(byte, 0x01) == 0x01
    inputs["P1 B"] =      bit.band(byte, 0x02) == 0x02
    inputs["P1 Down"] =   bit.band(byte, 0x04) == 0x04
    inputs["P1 Left"] =   bit.band(byte, 0x08) == 0x08
    inputs["P1 Right"] =  bit.band(byte, 0x10) == 0x10
    inputs["P1 Up"] =     bit.band(byte, 0x20) == 0x20
    inputs["P1 Start"] =  bit.band(byte, 0x40) == 0x40
    inputs["P1 Select"] = bit.band(byte, 0x80) == 0x80

    return inputs
end

function generateInputs(inputCount)
    local inputs = {}
    for i=1, inputCount do
        local dieRoll = math.random()
        local input = 0

        if dieRoll < 0.90 and dieRoll > 0.30 then input = bit.bor(input, 0x01) end
        if dieRoll < 0.60 and dieRoll > 0.00 then input = bit.bor(input, 0x02) end
        if dieRoll < 1.00 and dieRoll > 0.75 then input = bit.bor(input, 0x04) end
        if dieRoll < 0.75 and dieRoll > 0.50 then input = bit.bor(input, 0x08) end
        if dieRoll < 0.50 and dieRoll > 0.25 then input = bit.bor(input, 0x10) end
        if dieRoll < 0.25 and dieRoll > 0.00 then input = bit.bor(input, 0x20) end
        if dieRoll < 1.00 and dieRoll > 0.99 then input = bit.bor(input, 0x40) end
        if dieRoll < 1.00 and dieRoll > 0.99 then input = bit.bor(input, 0x80) end

        inputs[i] = input
    end

    return inputs
end

function generateHerd(herdSize)
    local herd = {}

    for i=1,herdSize do
        local inputs = generateInputs(inputCount)
        local averageFitness = testInputs(inputs, inputCount)

        herd[i] = {averageFitness, inputs}

        totalIterations = totalIterations + 1
    end

    local herdTable = {}

    for fitness, inputs in pairs(herd) do
        table.insert(herdTable, {fitness, inputs})
    end

    return herdTable
end

function compareFitness(a, b)
    return a[2][1] > b[2][1]
end

function testInputs(inputs, inputCount)
    local repeatedInputs = false
    local repeatIndex = -1

    for i=1, table.getn(memoized_inputs) do
        if memoized_inputs[i][1] == inputs then
            repeatedInputs = true
            repeatIndex = i
        end
    end

    if repeatedInputs then
        print("Skipping repeated input pattern.")

        iteration = iteration + 1

        emu.frameadvance()

        return memoized_inputs[repeatIndex][2]
    end

    local totalFitness = 0
    joypad.set(resetCommand)

    for _=1,10 do
        emu.frameadvance() --ensure the game resets before we start reading data
    end

    for i =1, inputCount do
        currentInput = i

        fitness = calculateFitness()
        totalFitness = totalFitness + fitness

        drawData()
        readUserInput()

        if lives == 0 or inputs[i] == nil then
            break
        end

        local buttons = byteToInputs(inputs[i])

        joypad.set(buttons)

        emu.frameadvance()
    end

    print("Fitness for " .. generation + 1 .. "-" .. iteration .. ": " .. totalFitness)

    local fitnessGraphCount = table.getn(bestFitnesses)

    if fitnessGraphCount < 20 then
        bestFitnesses[fitnessGraphCount + 1] = totalFitness
    else
        for i=1,fitnessGraphCount - 1 do
            bestFitnesses[i] = bestFitnesses[i + 1]
        end

        bestFitnesses[20] = totalFitness
    end

    table.insert(memoized_inputs, {inputs, totalFitness})

    iteration = iteration + 1
    return totalFitness
end

function sortHerd(herd)
    if loadingFile then return herd end

    table.sort(herd, compareFitness)

    return herd
end

function cullHerd(herd)
    local culledHerd = {}

    for i=0, cullFinalAmount do
        culledHerd[i] = herd[i]
    end

    totalIterations = cullFinalAmount

    herd = nil

    return culledHerd
end

function breedHerd(herd)

    local children = {}
    local childCount = 1
    local herdLength = table.getn(herd)

    for i=1, herdLength do
        for j=1,herdLength do
            if loadingFile then return herd end

            if i ~= j and math.random() < breedChance then
                local pivot = math.random(inputCount / 3, inputCount * 2 / 3)
                local newInputs = {}

                for k=1,pivot do
                    newInputs[k] = herd[i][2][2][k]
                end
                for k=pivot,inputCount do
                    newInputs[k] = herd[j][2][2][k]
                end

                local fitness = testInputs(newInputs, inputCount)

                totalIterations = totalIterations + 1

                children[childCount] = {fitness, newInputs}
                childCount = childCount + 1
            end
        end
    end

    for fitness, inputs in pairs(children) do
        table.insert(herd, {fitness, inputs})
    end

    totalIterations = totalIterations + childCount

    return herd
end

function mutateHerd(herd)
    local herdLength = table.getn(herd)

    for i=1, herdLength do
        if loadingFile then return herd end

        if math.random() < mutateSubjectChance then
            for j=1, inputCount do
                if math.random() < mutateInputChance then
                    herd[i][2][2][j] = math.random(0x00, 0xFF)
                end
            end

            herd[i][1] = testInputs(herd[i][2][2], inputCount)
        end
    end

    return herd
end

main()