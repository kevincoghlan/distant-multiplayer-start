------------------------------------------------------------------------------
-- Distant Multiplayer Start mod for Civilization VI
-- Kevin Coghlan, 2017
--
-- Steam Workshop: steamcommunity.com/sharedfiles/filedetails/?id=948411364
-- GitHub project: github.com/kevincoghlan/distant-multiplayer-start
------------------------------------------------------------------------------

--- Maximizes starting distance between all human players in the game.
-- Called from a modified version of Civ VI's 'AssignStartingPlots.lua' script.
-- @param playerIDList The IDs of all players in the game (both human and AI).
function DistantMultiplayerStart( playerIDList )
	local allPlayerList, humanPlayerList, aiPlayerList = GeneratePlayerLists( playerIDList )

	if #humanPlayerList < #allPlayerList then
		print("Distant Multiplayer Start processing has started at " .. GenerateTimestamp())
		PrintStartingPlotsWithMessage( "Initial starting plots, before the mod makes any changes:", humanPlayerList, aiPlayerList )
		MaximizeDistanceBetweenHumanPlayers( allPlayerList, humanPlayerList )
		PrintStartingPlotsWithMessage( "Final starting plots:", humanPlayerList, aiPlayerList )
		print("Distant Multiplayer Start processing has finished at " .. GenerateTimestamp())
	elseif #humanPlayerList == #allPlayerList then
		PrintAllPlayersAreHumanMessage()
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

function PrintStartingPlotsWithMessage( message, humanPlayerList, aiPlayerList )
	PrintBeneathSeparatorLine( message )
	PrintStartingPlots( humanPlayerList, "Human Player" )
	PrintStartingPlots( aiPlayerList, "AI Player" )
end

--- Prints the given message beneath a separator line.
function PrintBeneathSeparatorLine( message )
	PrintSeparatorLine()
	print( message )
end

--- Prints a separator line.
-- This can be used to separate log entries into logical sections.
function PrintSeparatorLine()
	print("------------------------------------------------------------------")
end

--- Prints starting plots for individual players of a given type (human or AI).
-- @param playerList The list of Players whose starting plots will be printed.
-- @param playerTypeDescription A short description which indicates the player type (human or AI).
function PrintStartingPlots( playerList, playerTypeDescription )
	for i = 1, #playerList do
		local plot = playerList[i]:GetStartingPlot()
		print(playerTypeDescription .. " " .. i .. " starting plot index: " .. plot:GetIndex())
	end
end

--- Explains why the mod will have no effect in a game with no AI players.
function PrintAllPlayersAreHumanMessage()
	print("All players in this game are human.")
	print("This mod works by swapping human and AI start positions to place the humans as far apart as possible.")
	print("Since there are no AIs in the game, the mod will have no effect.")
end

--- Maximizes starting distance between all human players in the game.
-- Nothing is returned; this function mutates Player objects within the given lists.
-- @param allPlayerList All players in the game (both human and AI).
-- @param humanPlayerList All human players in the game.
function MaximizeDistanceBetweenHumanPlayers( allPlayerList, humanPlayerList )
	--The following buffer will contain the players (human and/or AI) who occupy the 'most distant' starting plots after Civ VI's initial starting plot allocation.
	--AI players will be removed from the buffer after their 'most distant' starting plot has been swapped with a human player.
	--If human players are detected in this buffer, they will be removed from the buffer as no further processing is required (they are already in a most distant plot).
	local distantPlayerBuffer = FindMostDistantPlayers( allPlayerList, #humanPlayerList )
	PrintBeneathSeparatorLine("Most distant starting plots: " .. GenerateStartingPlotsString( distantPlayerBuffer ))

	--The following buffer contains all human players in the game.
	--Players will be removed from the buffer when they occupy a 'most distant' starting plot.
	local humanPlayerBuffer = ShallowCopy( humanPlayerList )

	ExcludeHumanPlayersWhoAlreadyOccupyMostDistantPlots( distantPlayerBuffer, humanPlayerBuffer )

	--Any players left in 'distantPlayerBuffer' after the above processing must be AI players.
	--Swap their starting plots with human players from the 'humanPlayerBuffer'.
	PrintBeneathSeparatorLine("Number of human players to be repositioned: " .. #humanPlayerBuffer)
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
	if (humanPlayerCount == 2) then
		mostDistantPlayerList = FindTwoMostDistantPlayers( allPlayerList )
	else
		assert( humanPlayerCount >= 3 )
		PrintBeneathSeparatorLine("Determining all possible combinations of " .. humanPlayerCount .. " players...")
		local playerComboList = FindPlayerCombos( allPlayerList, humanPlayerCount )
		PrintBeneathSeparatorLine("Analysing player combinations to find the most distant combination...")
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
-- @param k All possible combinations of k players will be found. This parameter is named from 'n choose k' in mathematics.
-- @return a table containing all possible combinations of k players. Each entry in the table is itself a table, since each possible combination is stored as a table of Players.
function FindPlayerCombos( allPlayerList, k )
	local playerComboList = {}

	--This nested function will be used to recursively find all possible combinations of k players.
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

--- Finds the combination of players which are currently most distant from each other, based upon the current starting plots held by each player.
-- @param playerComboList All player combinations to be examined. A table of tables, where each subtable is a list of Players. These lists should be equal in length.
-- @return a single table of Players; this is the combination of players from 'playerComboList' which are most distant from each other.
function FindSeveralMostDistantPlayers( playerComboList )
	--This algorithm is best suited to combinations of three or more players. (For two players, see 'FindTwoMostDistantPlayers' function)
	assert( #playerComboList[1] >= 3, "This function is intended to be used with combinations of 3+ players" )

	--The index number of the most distant combination of players (i.e. players who currently hold starting plots that are furthest from one another) that has been found so far.
	--This 'leading candidate' may be mutated several times during the function as more optimal player combinations are found.
	local leadCandidateIndex

	--The highest minimum distance that has been found in any combination so far.
	--This is used as the primary metric for determining the most optimal player combination.
	local highestMinDistance = 0

	--Whenever a new 'highestMinDistance' is found in a particular combination and recorded above, the sum distance of that combination is also recorded in this variable.
	--This way, if another combination is found with an EQUAL minimum distance to 'highestMinDistance', sum distances can be used as a tiebreaking metric to determine which combination is most optimal.
	local tiebreakerSumDistance

	for i = 1, #playerComboList do
		print("Computing distances for player combination " .. i .. "...")
		local currentPlayerCombo = playerComboList[i]

		--Store the distances between all starting plots in the current player combination.
		local distanceList = ConditionallyGeneratedistanceList( currentPlayerCombo, highestMinDistance )

		--If a nil cache was returned, this indicates that the starting plots in this combination are too close together. The combination can be discarded.
		--Otherwise, examine the returned distance cache to determine whether this player combination is more optimal than the current lead candidate.
		if distanceList ~= nil then
			local minDistance = FindMinDistance( distanceList )
			print("Minimum distance in player combination " .. i .. ": " .. minDistance)

			if minDistance > highestMinDistance then
				local message = "Player combination " .. i .. " is now the lead candidate."
				if leadCandidateIndex ~= nil then
					message = message .. " (Previous lead candidate was player combination " .. leadCandidateIndex .. " with minimum distance: " .. highestMinDistance .. ")"
				end
				print(message)
				highestMinDistance = minDistance
				leadCandidateIndex = i
				tiebreakerSumDistance = ComputeSumDistance( distanceList )
			elseif minDistance == highestMinDistance then
				print("Tie found between player combination " .. i .. " and the lead candidate (player combination " .. leadCandidateIndex .. "). Using sum distance as a tiebreaker...")
				local currentSumDistance = ComputeSumDistance( distanceList )
				if currentSumDistance > tiebreakerSumDistance then
					print("Sum distance (" .. currentSumDistance .. ") of player combination " .. i .. " is higher than the previous lead candidate's sum distance (" .. tiebreakerSumDistance .. "). Player combination " .. i .. " is now the lead candidate.")
					leadCandidateIndex = i
					tiebreakerSumDistance = currentSumDistance
				else
					print("Sum distance (" .. currentSumDistance .. ") of player combination " .. i .. " is not higher than the lead candidate's sum distance (" .. tiebreakerSumDistance .. "). No change in lead candidate.")
				end
			end
		end
	end

	PrintBeneathSeparatorLine("Analysis complete. Player combination " .. leadCandidateIndex .. " contains the most distant starting plots.")
	return playerComboList[leadCandidateIndex]
end

--- Generates a cache containing the distances between all players in the given combination.
-- @param playerCombo A table of Players.
-- @param requiredMinDistance For a distance cache to be returned from this function, all distances within the combination must be greater than or equal to the requiredMinDistance parameter. Otherwise nil will be returned.
-- @return a table of distance values (integers), or nil if any distance is found which is below the requiredMinDistance. This is an optimisation to reject suboptimal (i.e. too close together) player combinations as early as possible.
function ConditionallyGeneratedistanceList( playerCombo, requiredMinDistance )
	local distanceList = {}

	for j = 1, #playerCombo do
		local startingPlot1Index = playerCombo[j]:GetStartingPlot():GetIndex()
		for k = j + 1, #playerCombo do
			local startingPlot2Index = playerCombo[k]:GetStartingPlot():GetIndex()
			local distance = Map.GetPlotDistance(startingPlot1Index, startingPlot2Index)
			print("Distance between plot " .. startingPlot1Index .. " and plot " .. startingPlot2Index .. " is: " .. distance)

			if distance < requiredMinDistance then
				print("Suboptimal distance detected (lower than " .. requiredMinDistance .. "). Discarding combination.")
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

--- Removes human players from processing buffers if they already occupy a most distant starting plot.
-- Nothing is returned; this function simply mutates the given buffers.
-- @param distantPlayerBuffer Initially contains the players who currently occupy the most distant starting plots.
-- @param humanPlayerBuffer Initially contains all human players in the game.
function ExcludeHumanPlayersWhoAlreadyOccupyMostDistantPlots( distantPlayerBuffer, humanPlayerBuffer )
	PrintBeneathSeparatorLine("Checking if any of the most distant plots are already occupied by human players...")

	for i = #humanPlayerBuffer, 1, -1 do		--Iterate backwards so that players can safely be removed from the buffer during iteration.
		local humanStartingPlot = humanPlayerBuffer[i]:GetStartingPlot()
		for j = 1, #distantPlayerBuffer do		--No need to iterate backwards here, since 'break' is invoked upon deletion of an element.
			local mostDistantStartingPlot = distantPlayerBuffer[j]:GetStartingPlot()
			if humanStartingPlot == mostDistantStartingPlot then
				print("Plot " .. mostDistantStartingPlot:GetIndex() .. " is occupied by a human player. This player does not need to be repositioned.")
				--Remove the human player from both processing buffers, since repositioning of this player will not be required.
				table.remove(humanPlayerBuffer, i)
				table.remove(distantPlayerBuffer, j)
				break
			end
		end
	end
end

--- Swaps starting plots between any AI players who currently occupy these plots, and any human players who do not yet occupy a most distant starting plot.
-- Nothing is returned; this function simply mutates the given buffers.
-- @param distantPlayerBuffer This should currently contain only AI players who currently occupy the most distant starting plots.
-- @param humanPlayerBuffer This should currently contain only the human players who do yet not occupy a most distant starting plot.
function SwapStartingPlots( distantPlayerBuffer, humanPlayerBuffer )
	--The number of human players to be repositioned should equal the number of AI players who currently hold 'most distant' starting plots.
	assert( #humanPlayerBuffer == #distantPlayerBuffer )

	while #humanPlayerBuffer > 0 do
		--Take the next player from each buffer and swap their starting positions, leaving the human player with a 'most distant' starting plot.
		local humanPlayer = table.remove(humanPlayerBuffer, 1)
		local aiPlayer    = table.remove(distantPlayerBuffer, 1)

		local humanPlayerStartingPlot = humanPlayer:GetStartingPlot()
		local aiPlayerStartingPlot    = aiPlayer:GetStartingPlot()

		humanPlayer:SetStartingPlot( aiPlayerStartingPlot )
		aiPlayer:SetStartingPlot( humanPlayerStartingPlot )

		print("Reassigned starting plot " .. humanPlayer:GetStartingPlot():GetIndex() .. " from an AI player to a human player.")
	end
end
