------------------------------------------------------------------------------
-- Distant Multiplayer Start mod for Civilization VI
--
-- Steam Workshop: steamcommunity.com/sharedfiles/filedetails/?id=948411364
-- GitHub project: github.com/kevincoghlan/distant-multiplayer-start
------------------------------------------------------------------------------

function DistantMultiplayerStart( playerIDList )
	local allPlayerList, humanPlayerList, aiPlayerList = GeneratePlayerLists( playerIDList )

	if #humanPlayerList == 2 then
		PrintStartingPlotsWithMessage( "Initial starting plots, before the mod makes any changes:", humanPlayerList, aiPlayerList )
		MaximizeDistanceBetweenHumanPlayers( allPlayerList, humanPlayerList )
		PrintStartingPlotsWithMessage( "Final starting plots:", humanPlayerList, aiPlayerList )
	elseif #humanPlayerList == #allPlayerList then
		PrintAllPlayersAreHumanMessage()
	elseif #humanPlayerList > 2 then
		PrintTooManyHumanPlayersMessage( #humanPlayerList )
	end
end

function GeneratePlayerLists( playerIDList )
	local allPlayerList, humanPlayerList, aiPlayerList = {}, {}, {}

	for i = 1, #playerIDList do
		local playerID = playerIDList[i]
		local player = Players[playerID]
		if player:IsHuman() then
			table.insert(humanPlayerList, player)
			local playerConfig = PlayerConfigurations[playerID]
			print ("Human Player " .. #humanPlayerList .. " found: " .. playerConfig:GetCivilizationTypeName())
		else
			table.insert(aiPlayerList, player)
			print ("AI Player " .. #aiPlayerList .. " found.")
		end
		table.insert(allPlayerList, player)
	end

	return allPlayerList, humanPlayerList, aiPlayerList
end

function PrintStartingPlotsWithMessage( message, humanPlayerList, aiPlayerList )
	PrintSeparatorLine()
	print(message)
	PrintStartingPlots( "Human Player", humanPlayerList )
	PrintStartingPlots( "AI Player", aiPlayerList )
end

function PrintSeparatorLine()
	print ("------------------------------------------------------------------")
end

function PrintStartingPlots( playerType, playerList )
	for i = 1, #playerList do
		local plot = playerList[i]:GetStartingPlot()
		print (playerType .. " " .. i .. " starting plot index: " .. plot:GetIndex())
	end
end

function PrintAllPlayersAreHumanMessage()
	print ("All players in this game are human.")
	print ("This mod functions by swapping human and AI starting positions to place the humans further apart.")
	print ("Since there are no AIs in the game, the mod will have no effect.")
end

function PrintTooManyHumanPlayersMessage( humanPlayerCount )
	print (humanPlayerCount .. " human players detected.")
	print ("This mod currently only supports two human players.")
	print ("Doing nothing!")
end

function MaximizeDistanceBetweenHumanPlayers( allPlayerList, humanPlayerList )
	--The following buffer contains the players (human and/or AI) who occupy the 'most distant' starting plots after Civ VI's initial starting plot allocation.
	--AI players will be removed from the buffer after their 'most distant' starting plot has been swapped with a human player.
	--Human players will be removed upon detection, since no further processing is required in that case.
	local mostDistantPlayerBuffer = FindMostDistantPlayers( allPlayerList )

	--The following buffer contains all human players in the game.
	--Players will be removed from the buffer when they occupy a 'most distant' starting plot.
	local humanPlayerBuffer = ShallowCopy( humanPlayerList )

	ExcludeHumanPlayersWhoAlreadyOccupyMostDistantPlots( mostDistantPlayerBuffer, humanPlayerBuffer )

	--Any players left in 'mostDistantPlayerBuffer' after the above processing must be AI players.
	--Swap their starting plots with human players from the 'humanPlayerBuffer'.
	SwapStartingPlots( mostDistantPlayerBuffer, humanPlayerBuffer )
end

function FindMostDistantPlayers( allPlayerList )
	local mostDistantPlayerList = {}

	--Highest distance between any two starting plots that has been found so far.
	local maxDistance = 0

	PrintSeparatorLine()
	print ("Finding the most distant starting plots...")
	for i = 1, #allPlayerList do
		local player1    = allPlayerList[i]
		local plot1Index = player1:GetStartingPlot():GetIndex()
		for j = i + 1, #allPlayerList do
			local player2    = allPlayerList[j]
			local plot2Index = player2:GetStartingPlot():GetIndex()

			local distance = Map.GetPlotDistance(plot1Index, plot2Index)
			if distance > maxDistance then
				maxDistance = distance
				mostDistantPlayerList[1] = player1
				mostDistantPlayerList[2] = player2
			end
		end
	end

	--Print the most distant plots.
	local distantPlotsString = ""
	for i = 1, #mostDistantPlayerList do
		distantPlotsString = distantPlotsString .. mostDistantPlayerList[i]:GetStartingPlot():GetIndex()
		if i < #mostDistantPlayerList then
			distantPlotsString = distantPlotsString .. ", "
		end
	end
	print ("Most distant starting plots: " .. distantPlotsString)

	return mostDistantPlayerList
end

function ShallowCopy(origTable)
	local newTable = {}
	for key, value in pairs(origTable) do
		newTable[key] = value
	end
	return newTable
end

function ExcludeHumanPlayersWhoAlreadyOccupyMostDistantPlots( mostDistantPlayerBuffer, humanPlayerBuffer )
	PrintSeparatorLine()
	print ("Checking if any of the most distant plots are already occupied by human players...")

	for i = #humanPlayerBuffer, 1, -1 do		--Iterate backwards so that players can safely be removed from the buffer during iteration.
		local humanStartingPlot = humanPlayerBuffer[i]:GetStartingPlot()
		for j = 1, #mostDistantPlayerBuffer do		--No need to iterate backwards here, since 'break' is invoked upon deletion of an element.
			local mostDistantStartingPlot = mostDistantPlayerBuffer[j]:GetStartingPlot()
			if humanStartingPlot == mostDistantStartingPlot then
				print("Plot " .. mostDistantStartingPlot:GetIndex() .. " is occupied by a human player. This player does not need to be repositioned.")
				--Remove the human player from both processing buffers, since repositioning of this player will not be required.
				table.remove(humanPlayerBuffer, i)
				table.remove(mostDistantPlayerBuffer, j)
				break
			end
		end
	end
end

function SwapStartingPlots( mostDistantPlayerBuffer, humanPlayerBuffer )
	PrintSeparatorLine()
	print ("Number of human players to be repositioned: " .. #humanPlayerBuffer)

	--(Sanity check) The number of players to be repositioned should equal the number of AI players who currently hold 'most distant' starting plots.
	assert( #humanPlayerBuffer == #mostDistantPlayerBuffer,
					"Unexpected 'humanPlayerBuffer' and 'mostDistantPlayerBuffer' size values: " .. #humanPlayerBuffer .. ", " .. #mostDistantPlayerBuffer)

	while #humanPlayerBuffer > 0 do
		--Take the next player from each buffer and swap their starting positions, leaving the human player with a 'most distant' starting plot.
		local humanPlayer = table.remove(humanPlayerBuffer, 1)
		local aiPlayer    = table.remove(mostDistantPlayerBuffer, 1)

		local humanPlayerStartingPlot = humanPlayer:GetStartingPlot()
		local aiPlayerStartingPlot    = aiPlayer:GetStartingPlot()

		humanPlayer:SetStartingPlot( aiPlayerStartingPlot )
		aiPlayer:SetStartingPlot( humanPlayerStartingPlot )

		print ("Reassigned starting plot " .. humanPlayer:GetStartingPlot():GetIndex() .. " from an AI player to a human player.")
	end
end
