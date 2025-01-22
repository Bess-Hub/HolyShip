-- Define some variables for the game
local mapImage  -- This will hold the map image
local questions = {}  -- Library of questions
local currentQuestion  -- The current question being asked
local score = {correct = 0, total = -1}  -- Score tracking
local questionText = ""
local showCorrectAnswer = false  -- Flag to indicate if the correct answer should be shown
local showAnswerTimer = 0  -- Timer to control how long the correct answer is shown
local answerDisplayDuration = 1.5  -- Duration to display the correct answer (in seconds)
local isMobileDevice = false  -- Variable to check if it's a mobile device
local padding = -20  -- Padding around the map for margins
local scaleX, scaleY  -- Scale factors for resizing map

-- Menu variables
local showMenu = true  -- Flag to show/hide menu
local selectedCategory = "All"  -- Current selected category
local categories = {"All", "Oceans, Seas, Straits, Canals/Channels", "Ports in Asia", "Ports in Middle East", "Ports in America","Ports in Africa", "Ports in Europe"}

-- Timer variables
local startTime = 0  -- Start time for the quiz
local totalTime = 0  -- Total time taken to complete the quiz
local returnToMenu = true  -- Flag to show return-to-menu option after game ends

-- Initialize the game
function love.load()
    questions = require("questions")
    sounds = {}
    sounds.correct = love.audio.newSource("sounds/right.mp3", "static")
    sounds.incorrect = love.audio.newSource("sounds/wrong.mp3", "static")
    love.window.setTitle("Holy Ship!")
    math.randomseed(os.time())
    ship = love.graphics.newImage("images/ship.png")

    -- Load the map image
    map = love.graphics.newImage("images/map.png")
    local mapWidth = map:getWidth()
    local mapHeight = map:getHeight()
    scaleX, scaleY = 1, 1  -- Default values, ensure they're initialized

    -- Check if the device supports touch, indicating a mobile device
    if love.touch then
        local touches = love.touch.getTouches()
        if #touches > 0 then
            isMobileDevice = true
        end
    end

    -- Set the window size based on whether it's a mobile device or not
    if isMobileDevice then
        local screenWidth, screenHeight = love.graphics.getDimensions()
        -- Force landscape orientation (width > height)
        if screenHeight > screenWidth then
            love.window.setMode(screenHeight, screenWidth, {resizable = true})  -- Swap width and height
        else
            love.window.setMode(screenWidth, screenHeight, {resizable = true})
        end
    else
        -- Desktop mode: set window size based on the map size
        love.window.setMode(mapWidth, mapHeight, {resizable = true})
    end

    -- Start the timer and generate the first question
    startTime = love.timer.getTime()
    generateQuestion()
end

function love.resize(w, h)
    local mapWidth = map:getWidth()
    local mapHeight = map:getHeight()

    -- Check if we are on a mobile device
    if isMobileDevice then
        -- Force landscape mode on resize (width > height)
        if h > w then
            love.window.setMode(h, w, {resizable = true})  -- Swap width and height
        else
            love.window.setMode(w, h, {resizable = true})
        end

        -- Adjust scale based on the resized window
        scaleX = (w - 2 * padding) / mapWidth
        scaleY = (h - 2 * padding) / mapHeight
        local scale = math.min(scaleX, scaleY)
        scaleX, scaleY = scale, scale
    else
        -- Non-mobile (desktop): scale based on map size
        scaleX = (w - 2 * padding) / mapWidth
        scaleY = (h - 2 * padding) / mapHeight
        local scale = math.min(scaleX, scaleY)
        scaleX, scaleY = scale, scale
    end
end

-- Generate a random question from the list
function generateQuestion()
    local availableQuestions = {}

    -- Filter questions based on the selected category
    for _, question in ipairs(questions) do
        if selectedCategory == "All" or question.category == selectedCategory then
            table.insert(availableQuestions, question)
        end
    end

    -- If there are no more questions, transition to quiz completion

local minutes = math.floor(totalTime / 60) -- Calculate whole minutes
local seconds = totalTime % 60 -- Calculate remaining seconds

    if #availableQuestions == 0 then
        totalTime = love.timer.getTime() - startTime
        questionText = string.format(
            "Quiz complete! Final score: %d / %d. Time taken: %.2f seconds !! Press 'R' to return to menu",
            score.correct,
            score.total,
            totalTime
        )
        returnToMenu = true
    else
        -- Pick a random question
        currentQuestion = availableQuestions[math.random(1, #availableQuestions)]
        questionText = "Click on " .. currentQuestion.name
        score.total = score.total + 1
    end
end

-- Unified input handling for both mouse and touch
function handleInput(x, y)
    if not showCorrectAnswer then
        local isCorrect = false

        -- Adjust click coordinates to account for scaling and padding
        x = (x - padding) / scaleX
        y = (y - padding) / scaleY

        if currentQuestion.type == "point" then
            local tolerance = isMobileDevice and 13 or 10
            if math.abs(x - currentQuestion.x) <= tolerance and math.abs(y - currentQuestion.y) <= tolerance then
                isCorrect = true
            end
        elseif currentQuestion.type == "polygon" then
            if isPointInPolygon(currentQuestion.polygon, x, y) then
                isCorrect = true
            end
        elseif currentQuestion.type == "horizontalline" then
            local linetolerance = isMobileDevice and 13 or 10
            if x >= currentQuestion.x1 and x <= currentQuestion.x2 and
               y >= (currentQuestion.y1 - linetolerance) and y <= (currentQuestion.y1 + linetolerance) then
                isCorrect = true
            end
        elseif currentQuestion.type == "verticalline" then
            local linetolerance = isMobileDevice and 13 or 10
            if x >= (currentQuestion.x1 - linetolerance) and x <= (currentQuestion.x1 + linetolerance) and
               y >= currentQuestion.y1 and y <= currentQuestion.y2 then
                isCorrect = true
            end
        end

        clickX, clickY = x * scaleX + padding, y * scaleY + padding  -- Save clicked coordinates for display

        if isCorrect then
            sounds.correct:play()
            score.correct = score.correct + 1

            for i, question in ipairs(questions) do
                if question == currentQuestion then
                    table.remove(questions, i)
                    break
                end
            end

            if #questions > 0 then
                generateQuestion()
            else
                totalTime = love.timer.getTime() - startTime
                questionText = string.format(
                    "Quiz complete! Final score: %d / %d.\nTime taken: %d minutes %.2f seconds.\n\nPress 'R' to return to menu",
                    score.correct,
                    score.total,
                    minutes,
                    seconds
                )
                returnToMenu = true
            end
        else
            showCorrectAnswer = true
            showAnswerTimer = answerDisplayDuration
        end
    end
end

-- Mouse input for desktops
function love.mousepressed(x, y, button)
    if button == 1 then
        if showMenu then
            -- Check if clicked on the menu options
            for i, category in ipairs(categories) do
                local categoryYPos = 160 + (i - 1) * 60  -- Position of the category button
                if x >= 10 and x <= 200 and y >= categoryYPos and y < categoryYPos + 30 then
                    selectedCategory = category
                    showMenu = false  -- Hide menu after selection
                    generateQuestion()  -- Generate a question based on the selected category
                    break
                end
            end
        else
            handleInput(x, y)
        end
    end
end

-- Touch input for mobile devices
function love.touchpressed(id, x, y, dx, dy, pressure)
    if isMobileDevice then
        if showMenu then
            -- Check if touched on the menu options
            for i, category in ipairs(categories) do
                local categoryYPos = 160 + (i - 1) * 60  -- Position of the category button
                if x >= 10 and x <= 200 and y >= categoryYPos and y < categoryYPos + 30 then
                    selectedCategory = category
                    showMenu = false  -- Hide menu after selection
                    generateQuestion()  -- Generate a question based on the selected category
                    break
                end
            end
        else
            -- Adjust the input for touch scale
            local touchX = x * love.graphics.getWidth()
            local touchY = y * love.graphics.getHeight()
            handleInput(touchX, touchY)
        end
    end
end


-- Detect 'R' key to return to menu after game completion
function love.keypressed(key)
    if key == 'r' and returnToMenu then
        showMenu = true  -- Show the menu screen again
        returnToMenu = false
        score = {correct = 0, total = -1}  -- Reset score
        startTime = love.timer.getTime()  -- Reset timer
        generateQuestion()  -- Prepare a new set of questions
    end
end

-- Update function to manage timers and correct answer display
function love.update(dt)
    if showCorrectAnswer then
            sounds.incorrect:play()
        showAnswerTimer = showAnswerTimer - dt
        if showAnswerTimer <= 0 then
            showCorrectAnswer = false
            generateQuestion()
        end
    end
end

-- Initialize the score at the beginning of your code
score = {
    correct = 0,
    total = -2
}

-- Draw function to display the map, question, score, and click marker
function love.draw()
    if showMenu then
        -- Draw the menu background (dark gray)
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(1, 1, 1)  -- Set color to white for text

        -- Draw title (centered at the top)
        love.graphics.printf("Welcome to HOLY SHIP!", 0, 20, love.graphics.getWidth(), "center")
        love.graphics.printf("This is a simple point and click game where your objective is to click on the locations indicated in the top left corner, and that are relevant to the Maritime Industry", 0, 50, love.graphics.getWidth(), "center")
        love.graphics.printf("To start choose a category:", 0, 110, love.graphics.getWidth(), "center")
        love.graphics.printf("This little game is purely educational and the world map was obtained from the Institute of Chartered Shipbrokers.", 0, 700, love.graphics.getWidth(), "center")
        love.graphics.printf("If you detect an error or want to give feedback, please reach me out through LinkedIn.", 0, 730, love.graphics.getWidth(), "center")
        love.graphics.printf("Bessem Hamud :)", 0, 755, love.graphics.getWidth(), "center")

        -- Loop through categories and display them
        for i, category in ipairs(categories) do
            -- Adjust the color based on whether it's the selected category
            if category == selectedCategory then
                love.graphics.setColor(0, 1, 0)  -- Highlight selected category (green)
            else
                love.graphics.setColor(1, 1, 1)  -- Default color (white)
            end

            -- Draw the category name at the appropriate position
            -- Added extra padding (60) for better spacing between categories
            love.graphics.print(category, 10, 160 + (i - 1) * 60)  -- No justification argument
        end
    else
        love.graphics.setColor(1, 1, 1)  -- Reset color

        -- Draw the map image with scaling and padding
        love.graphics.draw(map, padding, padding, 0, scaleX, scaleY)

        -- Draw the question and score
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(questionText, 10, 20, love.graphics.getWidth(), "left")
        
        -- Ensure that score.correct and score.total are valid fields
        love.graphics.printf("Score: " .. score.correct .. " out of " .. score.total , 10, 40, love.graphics.getWidth(), "left")

        -- Show the correct answer if incorrect
        if showCorrectAnswer then
            if currentQuestion.type == "point" then
             love.graphics.circle("fill", currentQuestion.x * scaleX + padding, currentQuestion.y * scaleY + padding, 5)
            elseif currentQuestion.type == "polygon" then
                local vertices = {}
                for _, vertex in ipairs(currentQuestion.polygon) do
                    table.insert(vertices, vertex[1] * scaleX + padding)
                    table.insert(vertices, vertex[2] * scaleY + padding)
                end
                love.graphics.polygon("line", vertices)
            elseif currentQuestion.type == "horizontalline" then
                love.graphics.line(currentQuestion.x1 * scaleX + padding, currentQuestion.y1 * scaleY + padding,
                                   currentQuestion.x2 * scaleX + padding, currentQuestion.y2 * scaleY + padding)
            elseif currentQuestion.type == "verticalline" then
                love.graphics.line(currentQuestion.x1 * scaleX + padding, currentQuestion.y1 * scaleY + padding,
                                   currentQuestion.x2 * scaleX + padding, currentQuestion.y2 * scaleY + padding)
            end
        end

        -- Draw a marker where the player clicked
        if clickX and clickY then
            love.graphics.setColor(1, 0, 0)
            love.graphics.circle("fill", clickX, clickY, 5)
        end

        -- Show the option to return to the menu after quiz completion
        if returnToMenu then
            -- Calculate the width of the text to align it to the right
            local text = "Press 'R' to exit to menu"
            local textWidth = love.graphics.getFont():getWidth(text)
            
            -- Draw the text at the top right corner
            love.graphics.printf(text, love.graphics.getWidth() - textWidth - 30, 20, textWidth, "left")
        end
    end
end


-- Function to check if a point is inside a polygon (for polygon-based questions)
function isPointInPolygon(polygon, x, y)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end