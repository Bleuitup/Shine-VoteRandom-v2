--[[
	Tests for VoteRandom v2's shuffle skill log.

	Loads the real code from team_balance.lua (GetAverageSkillFunc, the Hive skill helper block and
	ApplyConfigToRankingFunction) against a stub of the parts of Shine it touches, runs LogShuffleSkills on
	mock teams, and checks the logged values, averages, the bot case and the mismatch warning.

	Run from anywhere with a standalone Lua interpreter:

		lua test/shuffle_skill_log.lua

	Pass "-v" to also print the log lines.
]]

local Verbose = arg and arg[ 1 ] == "-v"

local ScriptDir = debug.getinfo( 1, "S" ).source:match( "^@(.*[/\\])" ) or "./"
local File = assert( io.open( ScriptDir.."../source/lua/shine/extensions/voterandomv2/team_balance.lua", "rb" ) )
local Source = File:read( "a" ):gsub( "\r\n", "\n" )
File:close()

local function Extract( StartPattern, EndPattern, IncludeEnd )
	local S = assert( Source:find( StartPattern ), "not found: "..StartPattern )
	local EStart, EEnd = Source:find( EndPattern, S )
	assert( EStart, "not found: "..EndPattern )
	return Source:sub( S, IncludeEnd and EEnd or EStart - 1 )
end

local AverageCode = Extract( "\nlocal function SortDescending", "\n\ndo\n\tlocal DebugMode" )
local HelperBlock = Extract( "\ndo\n\tlocal DebugMode", "\nBalanceModule%.HappinessHistoryFile" )
local ApplyConfig = Extract( "\nfunction BalanceModule:ApplyConfigToRankingFunction", "\nfunction BalanceModule:LoadHappinessHistory" )

-- Stubs -----------------------------------------------------------------------
local Plugin = {
	CommanderSkillBlendType = { COMMANDER_ONLY = "COMMANDER_ONLY", AVERAGE = "AVERAGE",
		AVERAGE_IF_FIELD_SKILL_HIGHER = "AVERAGE_IF_FIELD_SKILL_HIGHER" },
	CommanderSkillBlendDescriptions = {
		COMMANDER_ONLY = "commander skill only",
		AVERAGE = "average of commander and field skill",
		AVERAGE_IF_FIELD_SKILL_HIGHER = "average of commander and field skill, only when field skill is higher"
	}
}

function math.StandardDeviation( Values )
	local Count = #Values
	if Count == 0 then return 0, 0 end
	local Sum = 0
	for i = 1, Count do Sum = Sum + Values[ i ] end
	local Average = Sum / Count
	local Squares = 0
	for i = 1, Count do Squares = Squares + ( Values[ i ] - Average ) ^ 2 end
	return math.sqrt( Squares / Count ), Average
end

local ShineStub = {
	GetClientInfo = function( Client ) return string.format( "%s[%d]", Client.Name, Client.ID ) end,
	GetTeamName = function( self, TeamNumber ) return TeamNumber == 1 and "Marines" or "Aliens" end
}

local BalanceModule = {}
local Env = setmetatable( {
	Plugin = Plugin,
	BalanceModule = BalanceModule,
	Shine = ShineStub,
	GetClientForPlayer = function( Ply ) return Ply.Client end,
	Abs = math.abs,
	TableSort = table.sort,
	Random = math.random
}, { __index = _G } )

assert( load( AverageCode..HelperBlock..ApplyConfig, "=team_balance.lua (extracted)", "t", Env ) )()

-- Mock players ----------------------------------------------------------------
local NextID = 1000
local function MakePlayer( Name, Team, Skill, Offset, Options )
	Options = Options or {}
	NextID = NextID + 1
	return {
		Client = { Name = Name, ID = NextID, GetIsVirtual = function() return Options.Bot == true end },
		GetName = function() return Name end,
		GetPlayerSkill = function() return Skill end,
		GetPlayerSkillOffset = function() return Offset end,
		GetCommanderSkill = function() return Options.CommSkill end,
		GetCommanderSkillOffset = function() return Options.CommOffset or 0 end,
		GetTeamNumber = function() return Team end,
		isa = function( self, ClassName ) return Options.Commander == true and ClassName == "Commander" end
	}
end

local function MakeSelf( Settings )
	local Lines = {}
	local Self = setmetatable( {
		Logger = {
			IsInfoEnabled = function() return Settings.InfoEnabled ~= false end,
			Info = function( _, Message, ... ) Lines[ #Lines + 1 ] = string.format( Message, ... ) end
		},
		IsPerTeamSkillEnabled = function() return Settings.TeamSkill end,
		IsCommanderSkillEnabled = function() return Settings.CommanderSkill end,
		GetBalanceModeConfig = function() return Settings.Config end,
		SkillGetters = BalanceModule.SkillGetters,
		CommanderSkillBlendDescriptions = Plugin.CommanderSkillBlendDescriptions
	}, { __index = BalanceModule } )
	return Self, Lines
end

-- Helpers -----------------------------------------------------------------------
local Passed, Failed = 0, 0
local function Check( Name, Condition )
	if Condition then
		Passed = Passed + 1
		print( "  PASS  "..Name )
	else
		Failed = Failed + 1
		print( "  FAIL  "..Name )
	end
end
local function HasLine( Lines, Plain )
	for i = 1, #Lines do
		if Lines[ i ]:find( Plain, 1, true ) then return Lines[ i ] end
	end
	return nil
end
local function Show( Lines )
	if not Verbose then return end
	for i = 1, #Lines do print( "        [Info] "..Lines[ i ] ) end
end

-- Teams: team skill offsets on, commander skills on, marines AVERAGE_IF_FIELD_SKILL_HIGHER, aliens AVERAGE.
-- Resolved values (marines add the offset, aliens subtract it):
--   Marine comm: commander 2000+0 = 2000, field 1200+100 = 1300 -> comm higher -> 2000
--   Marine A:    1500+100 = 1600
--   Marine bot:  not counted
--   Alien comm:  commander 1800-200 = 1600, field 2400-(-100) = 2500 -> AVERAGE -> 2050
--   Alien B:     1000-50 = 950
local function BuildTeams()
	return {
		{
			MakePlayer( "MarineComm", 1, 1200, 100, { Commander = true, CommSkill = 2000, CommOffset = 0 } ),
			MakePlayer( "MarineA", 1, 1500, 100 ),
			MakePlayer( "Bot", 1, 0, 0, { Bot = true } )
		},
		{
			MakePlayer( "AlienComm", 2, 2400, -100, { Commander = true, CommSkill = 1800, CommOffset = 200 } ),
			MakePlayer( "AlienB", 2, 1000, 50 )
		}
	}
end

local Settings = {
	TeamSkill = true,
	CommanderSkill = true,
	Config = { MarineCommanderSkillBlend = "AVERAGE_IF_FIELD_SKILL_HIGHER", AlienCommanderSkillBlend = "AVERAGE" }
}

print( "\nNormal shuffle log:" )
local Self, Lines = MakeSelf( Settings )
Self:LogShuffleSkills( BuildTeams() )
Show( Lines )
Check( "header states skill settings", HasLine( Lines, "Team skills are enabled. Commander skills are enabled." ) )
Check( "marine commander kept at commander skill (field lower)",
	HasLine( Lines, "MarineComm[1001]: 2000 (commander: commander skill 2000, field skill 1300, blend: average of commander and field skill, only when field skill is higher)" ) )
Check( "marine field player gets team offset added", HasLine( Lines, "MarineA[1002]: 1600" ) )
Check( "bot shown as not counted", HasLine( Lines, "Bot[1003]: no skill value (bot), not counted." ) )
Check( "alien commander averaged with offsets applied",
	HasLine( Lines, "AlienComm[1004]: 2050 (commander: commander skill 1600, field skill 2500, blend: average of commander and field skill)" ) )
Check( "alien field player gets team offset subtracted", HasLine( Lines, "AlienB[1005]: 950" ) )
Check( "marine average excludes the bot: (2000 + 1600) / 2 = 1800",
	HasLine( Lines, "Marines: 3 players, 2 counted. Average skill 1800, standard deviation 200." ) )
Check( "alien average: (2050 + 950) / 2 = 1500",
	HasLine( Lines, "Aliens: 2 players, 2 counted. Average skill 1500, standard deviation 550." ) )
Check( "difference between averages", HasLine( Lines, "Difference between team averages: 300." ) )
Check( "no mismatch warning when breakdown agrees", not HasLine( Lines, "WARNING" ) )

print( "\nCommander skills disabled:" )
local Self2, Lines2 = MakeSelf( { TeamSkill = true, CommanderSkill = false, Config = Settings.Config } )
Self2:LogShuffleSkills( BuildTeams() )
Show( Lines2 )
Check( "commander logged with field skill and no breakdown", HasLine( Lines2, "MarineComm[1006]: 1300" )
	and not HasLine( Lines2, "MarineComm[1006]: 1300 (" ) )

print( "\nMismatch between breakdown and value used:" )
local Self3, Lines3 = MakeSelf( Settings )
local RealGetter = BalanceModule.SkillGetters.GetHiveSkill
Self3.SkillGetters = { GetHiveSkill = function( ... )
	local Value = RealGetter( ... )
	return Value and Value + 10
end }
Self3:LogShuffleSkills( BuildTeams() )
Show( Lines3 )
Check( "warning shown with the breakdown's own value",
	HasLine( Lines3, "WARNING: this breakdown gives 2000, not the value used" ) )

print( "\nLogger below INFO:" )
local Self4, Lines4 = MakeSelf( { TeamSkill = true, CommanderSkill = true, Config = Settings.Config, InfoEnabled = false } )
Self4:LogShuffleSkills( BuildTeams() )
Check( "nothing logged when INFO is disabled", #Lines4 == 0 )

print( string.format( "\n%d passed, %d failed\n", Passed, Failed ) )
os.exit( Failed == 0 and 0 or 1 )
