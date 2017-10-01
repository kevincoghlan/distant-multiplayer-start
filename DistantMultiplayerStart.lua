------------------------------------------------------------------------------
-- Distant Multiplayer Start mod for Civilization VI
-- Kevin Coghlan, 2017
--
-- Steam Workshop: steamcommunity.com/sharedfiles/filedetails/?id=948411364
-- GitHub project: github.com/kevincoghlan/distant-multiplayer-start
------------------------------------------------------------------------------

--Official number of supported players in Civ VI base game is 12. The mod currently matches this.
--Higher player counts could result in a combinatorial explosion in this mod as the number of
--possible starting plot combinations increases dramatically. In the future, algorithmic
--adjustments to the mod may make it possible to increase the supported player count.
local supportedPlayerCount = 12

--- Maximizes starting distance between all human players in the game.
-- Called from a modified version of Civ VI's 'AssignStartingPlots.lua' script.
-- @param playerIDList The IDs of all players in the game (both human and AI).
function DistantMultiplayerStart( playerIDList )
	local allPlayerList, humanPlayerList, aiPlayerList = GeneratePlayerLists( playerIDList )

	if #allPlayerList > supportedPlayerCount then
		PrintTooManyPlayersMessage( #allPlayerList )
	elseif #humanPlayerList == #allPlayerList then
		PrintAllPlayersAreHumanMessage()
	else
		print("Distant Multiplayer Start processing started at " .. GenerateTimestamp())
		PrintSeparatorLine()
		print("Initial starting plots, before the mod makes any changes:")
		PrintAllStartingPlots( humanPlayerList, aiPlayerList )

		MaximizeDistanceBetweenHumanPlayers( allPlayerList, humanPlayerList )

		PrintSeparatorLine()
		print("Final starting plots:")
		PrintAllStartingPlots( humanPlayerList, aiPlayerList )
		print("Distant Multiplayer Start processing finished at " .. GenerateTimestamp())
	end
end

--- Generates a timestamp in hour:minute:second format.
-- @return the generated timestamp.
function GenerateTimestamp()
	return os.date("!%H:%M:%S")
end

--- Generates categorized lists of Player objects.
-- @param playerIDList A list of player IDs.
-- @return three lists of Players: all players, human players, and AI players.
function GeneratePlayerLists( playerIDList )
	local allPlayerList, humanPlayerList, aiPlayerList = {}, {}, {}

	for i = 1, #playerIDList do
		local playerID = playerIDList[i]
		local player = Players[playerID]
		if player:IsHuman() then
			table.insert(humanPlayerList, player)
			local playerConfig = PlayerConfigurations[playerID]
			print("Human Player " .. #humanPlayerList .. " found: " .. playerConfig:GetCivilizationTypeName())
		else
			table.insert(aiPlayerList, player)
			print("AI Player " .. #aiPlayerList .. " found.")
		end
		table.insert(allPlayerList, player)
	end

	return allPlayerList, humanPlayerList, aiPlayerList
end

function PrintAllStartingPlots( humanPlayerList, aiPlayerList )
	PrintStartingPlots( humanPlayerList, "Human Player" )
	PrintStartingPlots( aiPlayerList, "AI Player" )
end

--- Prints a separator line.
-- This can be used to separate log entries into logical sections.
function PrintSeparatorLine()
	print("------------------------------------------------------------------")
end

--- Prints starting plots for individual players of a given type (human or AI).
-- @param playerList The list of Players whose starting plots will be printed.
-- @param playerTypeDescription Indicates the player type (human or AI).
function PrintStartingPlots( playerList, playerTypeDescription )
	for i = 1, #playerList do
		local plot = playerList[i]:GetStartingPlot()
		print(playerTypeDescription .. " " .. i .. " starting plot index: " .. plot:GetIndex())
	end
end

--- Explains that the mod will have no effect in a game with too many players.
function PrintTooManyPlayersMessage( playerCount )
	print("The number of players in this game (" .. playerCount .. ") exceeds the max number of " ..
	  "supported players (" .. supportedPlayerCount .. "). The mod will have no effect.")
	print("Higher player numbers may be supported in a future version.")
end

--- Explains that the mod will have no effect in a game with no AI players.
function PrintAllPlayersAreHumanMessage()
	print("All players in this game are human.")
	print("This mod works by swapping human and AI start positions to place the " ..
		"humans as far apart as possible.")
	print("Since there are no AIs in the game, the mod will have no effect.")
end

--- Maximizes starting distance between all human players in the game.
-- Returns nothing; this function mutates Player objects within the given lists.
-- @param allPlayerList All players in the game (both human and AI).
-- @param humanPlayerList All human players in the game.
function MaximizeDistanceBetweenHumanPlayers( allPlayerList, humanPlayerList )
	--The following buffer contains players (human and/or AI) who occupy the
	--'most distant' starting plots after Civ VI's initial plot allocation.
	local distantPlayerBuffer = FindMostDistantPlayers( allPlayerList, #humanPlayerList )

	PrintSeparatorLine()
	plots = GenerateStartingPlotsString( distantPlayerBuffer )
	print("Most distant starting plots: " .. plots)

	--The following buffer initially contains all human players in the game.
	local humanPlayerBuffer = ShallowCopy( humanPlayerList )

	ExcludeHumansWhoAlreadyOccupyDistantPlots( distantPlayerBuffer, humanPlayerBuffer )

	--Any players left in the 'distantPlayerBuffer' must be AI players.
	--Swap their starting plots with human players from the 'humanPlayerBuffer'.
	PrintSeparatorLine()
	print("Number of human players to be repositioned: " .. #humanPlayerBuffer)
	if #humanPlayerBuffer > 0 then
		SwapStartingPlots( distantPlayerBuffer, humanPlayerBuffer )
	end
end

--- Finds the players who are currently most distant from each other.
-- These players may be human and/or AI.
-- @param allPlayerList All players in the game (both human and AI).
-- @param humanPlayerCount The number of human players in the game.
-- @return a table containing the Players who are most distant from each other.
function FindMostDistantPlayers( allPlayerList, humanPlayerCount )
	local mostDistantPlayerList

	--The algorithm to be used depends upon the number of human players.
	if humanPlayerCount == 2 then
		mostDistantPlayerList = FindTwoMostDistantPlayers( allPlayerList )
	else
		assert( humanPlayerCount >= 3 )
		PrintSeparatorLine()
		print("Determining all possible combinations of " .. humanPlayerCount .. " players...")
		local playerComboList = FindPlayerCombos( allPlayerList, humanPlayerCount )
		PrintSeparatorLine()
		print("Analysing player combinations to find the most distant combination...")
		mostDistantPlayerList = FindSeveralMostDistantPlayers( playerComboList )
	end

	return mostDistantPlayerList
end

--- Finds the two players who are currently most distant from each other.
-- @param allPlayerList All players in the game (both human and AI).
-- @return a table containing the two Players who are most distant from each other.
function FindTwoMostDistantPlayers( allPlayerList )
	--The list of players to be returned.
	local mostDistantPlayerList = {}

	--Highest distance between any two starting plots that has been found so far.
	local maxDistance = 0

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

	assert( #mostDistantPlayerList == 2 )
	return mostDistantPlayerList
end

--- Finds all possible combinations of k players.
-- @param allPlayerList All players in the game (both human and AI).
-- @param k All possible combinations of k players will be found.
--          (Name comes from 'n choose k' in mathematics)
-- @return a table containing all possible combinations of k players. Each entry
--         in the table is itself a table, since each possible combination is
--         stored as a table of Players.
function FindPlayerCombos( allPlayerList, k )
	local playerComboList = {}

	local function Loop( i, playerCombo, k )
		if k == 0 then
			table.insert(playerComboList, playerCombo)
		else
			while i <= #allPlayerList do
				local player = allPlayerList[i]
				local copiedPlayerCombo = ShallowCopy(playerCombo)
				table.insert(copiedPlayerCombo, player)
				i = i + 1
				Loop(i, copiedPlayerCombo, k - 1)
			end
		end
	end

	Loop( 1, {}, k )

	return playerComboList
end

--- Finds the players which are currently most distant from each other.
-- @param playerComboList All player combinations to be examined. A table of
--                        tables, where each subtable is a list of Players.
--                        These lists should be equal in length.
-- @return a single table of Players.
function FindSeveralMostDistantPlayers( playerComboList )
	assert( #playerComboList[1] >= 3,
		"This function is intended to be used with combinations of 3+ players" )

	--Index of the most spread apart combination of players found so far.
	--This may be mutated several times as more optimal combinations are found.
	local leadCandidateIndex

	--Highest minimum distance that has been found in any combination so far.
	--(Primary metric for determining the optimal player combination)
	local highestMinDistance = 0

	--Whenever a new 'highestMinDistance' is found in a particular combination,
	--the sum distance of that combination is also recorded in this variable.
	--This way, if another combination is found with an EQUAL minimum distance to
	--'highestMinDistance', sum distances can be used as a tiebreaking metric to
	--determine which combination is more optimal.
	local tiebreakerSumDistance

	for i = 1, #playerComboList do
		print("Computing distances for player combination " .. i .. "...")
		local currentPlayerCombo = playerComboList[i]

		--Store the distances between all starting plots in the current combination.
		local distanceList =
		  ConditionallyGenerateDistanceList(currentPlayerCombo, highestMinDistance)

		--If nil was returned, the starting plots in this combination are too close
		--together and the combination can be discarded. Otherwise, examine the
		--returned distance cache to determine whether this player combination is
		--more optimal than the current lead candidate.
		if distanceList ~= nil then
			local minDistance = FindMinDistance( distanceList )
			print("Minimum distance in player combination " .. i .. ": " .. minDistance)

			if minDistance > highestMinDistance then
				local message = "Player combination " .. i .. " is now the lead candidate."
				if leadCandidateIndex ~= nil then
					message = message .. " (Previous lead candidate was player combination " ..
						leadCandidateIndex .. " with minimum distance: " .. highestMinDistance .. ")"
				end
				print(message)
				highestMinDistance = minDistance
				leadCandidateIndex = i
				tiebreakerSumDistance = ComputeSumDistance( distanceList )
			elseif minDistance == highestMinDistance then
				print("Tie found between player combination " .. i .. " and leading player combination " ..
					leadCandidateIndex .. ". Using sum distance as a tiebreaker...")
				local currentSumDistance = ComputeSumDistance( distanceList )
				if currentSumDistance > tiebreakerSumDistance then
					print("Sum distance (" .. currentSumDistance .. ") of player combination " ..
						i .. " is higher than the previous lead candidate's sum distance (" ..
						tiebreakerSumDistance .. "). Player combination " .. i .. " is now the lead candidate.")
					leadCandidateIndex = i
					tiebreakerSumDistance = currentSumDistance
				else
					print("Sum distance (" .. currentSumDistance .. ") of player combination " ..
					  i .. " is not higher than the lead candidate's sum distance (" ..
					  tiebreakerSumDistance .. "). No change in lead candidate.")
				end
			end
		end
	end

	PrintSeparatorLine()
	print("Analysis complete. Player combination " ..
		leadCandidateIndex .. " contains the most distant starting plots.")
	return playerComboList[leadCandidateIndex]
end

--- Generates a list of distances between all players in the given combination.
-- @param playerCombo A table of Players.
-- @param requiredMinDistance If any distance within the combination is less
--                            than this parameter, nil will be returned.
-- @return a table of distance integers, or nil if any distance is found which
--         is below the requiredMinDistance.
function ConditionallyGenerateDistanceList( playerCombo, requiredMinDistance )
	local distanceList = {}

	for j = 1, #playerCombo do
		local startingPlot1Index = playerCombo[j]:GetStartingPlot():GetIndex()
		for k = j + 1, #playerCombo do
			local startingPlot2Index = playerCombo[k]:GetStartingPlot():GetIndex()
			local distance = Map.GetPlotDistance(startingPlot1Index, startingPlot2Index)
			print("Distance between plot " .. startingPlot1Index .. " and plot " ..
				startingPlot2Index .. " is: " .. distance)

			if distance < requiredMinDistance then
				print("Suboptimal distance found (lower than " ..
					requiredMinDistance .. "). Discarding combination.")
				return nil
			end

			table.insert(distanceList, distance)
		end
	end

	return distanceList
end

--- Finds the minimum distance from the given list of distances.
-- @param distanceList A table of integers.
-- @return the minimum distance from the given list.
function FindMinDistance( distanceList )
	local minDistance = nil
	for i = 1, #distanceList do
		local distance = distanceList[i]
		if minDistance == nil or distance < minDistance then
			minDistance = distance
		end
	end
	return minDistance
end

--- Computes the sum of all distances in the given list of distances.
-- @param distanceList A table of integers.
-- @return the sum of all distances from the given list.
function ComputeSumDistance( distanceList )
	local sumDistance = 0
	for i = 1, #distanceList do
		sumDistance = sumDistance + distanceList[i]
	end
	return sumDistance
end

--- Generates a formatted string of player starting plots.
-- @param playerList A list of Players.
-- @return a comma-separated string of starting plots for each player in the list.
function GenerateStartingPlotsString( playerList )
	local result = ""
	for i = 1, #playerList do
		result = result .. playerList[i]:GetStartingPlot():GetIndex()
		if i < #playerList then
			result = result .. ", "
		end
	end
	return result
end

--- Returns a shallow copy of a table.
-- @param origTable The table to be copied.
-- @return a shallow copy of 'origTable'.
function ShallowCopy(origTable)
	local newTable = {}
	for key, value in pairs(origTable) do
		newTable[key] = value
	end
	return newTable
end

--- Removes human players from processing buffers if they already occupy a distant starting plot.
-- Returns nothing; this function simply mutates the given buffers.
-- @param distantPlayerBuffer Initially contains the players who currently
--                            occupy the most distant starting plots.
-- @param humanPlayerBuffer Initially contains all human players in the game.
function ExcludeHumansWhoAlreadyOccupyDistantPlots( distantPlayerBuffer, humanPlayerBuffer )
	PrintSeparatorLine()
	print("Checking if any of the most distant plots are already occupied by human players...")

	--Iterate backwards so that players can safely be removed while iterating.
	for i = #humanPlayerBuffer, 1, -1 do
		local humanStartingPlot = humanPlayerBuffer[i]:GetStartingPlot()
		for j = 1, #distantPlayerBuffer do
			local mostDistantStartingPlot = distantPlayerBuffer[j]:GetStartingPlot()
			if humanStartingPlot == mostDistantStartingPlot then
				print("Plot " .. mostDistantStartingPlot:GetIndex() ..
					" is occupied by a human player. This player does not need to be repositioned.")
				table.remove(humanPlayerBuffer, i)
				table.remove(distantPlayerBuffer, j)
				break
			end
		end
	end
end

--- Swaps distant starting plots from AI players to human players.
-- Returns nothing; this function simply mutates the given buffers.
-- @param distantPlayerBuffer Should currently contain only AI players who
--                            currently occupy the most distant starting plots.
-- @param humanPlayerBuffer Should currently contain only the human players who
--                          do yet not occupy a most distant starting plot.
function SwapStartingPlots( distantPlayerBuffer, humanPlayerBuffer )
	--The number of human players to be repositioned should equal the number
	--of AI players who currently hold 'most distant' starting plots.
	assert( #humanPlayerBuffer == #distantPlayerBuffer )

	while #humanPlayerBuffer > 0 do
		--Take the next player from each buffer and swap their starting positions,
		--leaving the human player with a 'most distant' starting plot.
		local humanPlayer = table.remove(humanPlayerBuffer, 1)
		local aiPlayer    = table.remove(distantPlayerBuffer, 1)

		local humanPlayerStartingPlot = humanPlayer:GetStartingPlot()
		local aiPlayerStartingPlot    = aiPlayer:GetStartingPlot()

		humanPlayer:SetStartingPlot( aiPlayerStartingPlot )
		aiPlayer:SetStartingPlot( humanPlayerStartingPlot )

		print("Reassigned starting plot " .. humanPlayer:GetStartingPlot():GetIndex() ..
			" from an AI player to a human player.")
	end
end
