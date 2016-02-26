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

screenPos = 0
health = 32
lives = 3
robotsBeaten = 0
xPos = 0
yPos = 0


memoized_inputs = {}

resetCommand = {["Reset"] = true}

ramAddresses = {["X Pos"] = 0x0460, ["Y Pos"] = 0x04A0,
    ["Health"] = 0x06C0, ["Lives"] = 0x00A8,
    ["Screen Pos"] = 0x0440, ["Robot Masters Beaten"] = 0x009A }

states = {"Initial Generation", "Breeding", "Mutating"}
currentState = 1

memory.usememorydomain("RAM")
buttons = joypad.getimmediate()

gui.defaultBackground(0xFFFFFFFF)

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

    gui.drawText(0, 0, "Screen position: " .. screenPos, 0xFFFFFFFF, 0xFFFFFFFF, 12)
    gui.text(0, 64, "Health: " .. health)
    gui.text(0, 80, "Lives: " .. lives)
    gui.text(0, 96, "Robot Masters beaten: " .. robotsBeaten)
    gui.text(0, 112, "(" .. xPos .. ", " .. yPos .. ")")

    return (screenPos + 1) * health * lives * math.pow((robotsBeaten + 1), 3)
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

        gui.text(0, 0, "Skipping repeated input pattern.")
        gui.text(0, 144, "State: " .. states[currentState])
        gui.text(0, 160, "Gen " .. generation + 1 .. " - Iter " .. iteration)
        gui.text(0, 192, totalIterations .. " total candidates")

        iteration = iteration + 1

        emu.frameadvance()

        return memoized_inputs[repeatIndex][2]
    end

    local totalFitness = 0
    joypad.set(resetCommand)

    for _=1,10 do
        emu.frameadvance() --ensure the game resets before we start reading data
    end

    for i=1, inputCount do
        local fitness = calculateFitness()
        totalFitness = totalFitness + fitness

        gui.text(0, 0, "Fitness: " .. fitness)
        gui.text(0, 144, "State: " .. states[currentState])
        gui.text(0, 160, "Gen " .. generation + 1 .. " - Iter " .. iteration)
        gui.text(0, 176, i .. "/" .. inputCount .. " inputs")
        gui.text(0, 192, totalIterations .. " total candidates")

        if lives == 0 or inputs[i] == nil then
            break
        end

        buttons = byteToInputs(inputs[i])

        joypad.set(buttons)

        emu.frameadvance()
    end

    print("Fitness for " .. generation + 1 .. "-" .. iteration .. ": " .. totalFitness)

    table.insert(memoized_inputs, {inputs, totalFitness})

    iteration = iteration + 1
    return totalFitness
end

function sortHerd(herd)
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

herd = generateHerd(initialSize)

for _=1,maxGenerations do
    herd = sortHerd(herd)

    herd = cullHerd(herd)

    currentState = 2
    herd = breedHerd(herd)

    currentState = 3
    herd = mutateHerd(herd)

    print("End of generation " .. generation + 1 .. ".  Best fitness: " .. herd[1][2][1])

    iteration = 0
    generation = generation + 1
end