--[[
	Tests for VoteRandom v2's vote menu hook.

	Extracts HookVoteMenu, UnhookVoteMenu and Cleanup from the shipped server.lua (so it tests the real
	code, not a copy), runs them against a stub of the parts of Shine they touch, and checks that the
	"voterandom" substitution only exists while Shine builds the vote menu data.

	Run from anywhere with a standalone Lua interpreter:

		lua test/votemenu_hook.lua
]]

local ScriptDir = debug.getinfo( 1, "S" ).source:match( "^@(.*[/\\])" ) or "./"
local File = assert( io.open( ScriptDir.."../source/lua/shine/extensions/voterandomv2/server.lua", "rb" ) )
local Source = File:read( "a" ):gsub( "\r\n", "\n" )
File:close()

local Start = Source:find( "\nfunction Plugin:HookVoteMenu%(%)" )
local CleanupStart = Source:find( "\nfunction Plugin:Cleanup%(%)" )
assert( Start and CleanupStart, "could not find the vote menu hook functions in server.lua" )
local CleanupEnd = select( 2, Source:find( "\nend\n", CleanupStart ) )
local Chunk = Source:sub( Start, CleanupEnd )

-- Stub Shine -----------------------------------------------------------------
local StockVoteRandom = { Enabled = false }
local MapVote = { Enabled = true, Config = { EnableRTV = true } }
local LastSent
local BaseCleanupCalls = 0

Shine = {
	Plugins = { voterandom = StockVoteRandom, mapvote = MapVote }
}

function Shine:IsExtensionEnabled( Name )
	local Plugin = self.Plugins[ Name ]
	if Plugin then return Plugin.Enabled, Plugin end
	return false
end

-- Mirrors BuildPluginData in Shine's core/server/votemenu.lua.
function Shine:SendPluginData( Player )
	if self.ThrowNext then
		self.ThrowNext = false
		error( "boom" )
	end
	LastSent = {
		Shuffle = self:IsExtensionEnabled( "voterandom" ),
		[ "Map Vote" ] = self:IsExtensionEnabled( "mapvote" ) and self.Plugins.mapvote.Config.EnableRTV or false
	}
end

local OriginalIsExtensionEnabled = Shine.IsExtensionEnabled
local OriginalSendPluginData = Shine.SendPluginData

local Plugin = { BaseClass = { Cleanup = function() BaseCleanupCalls = BaseCleanupCalls + 1 end } }
local Env = setmetatable( { Plugin = Plugin, Shine = Shine }, { __index = _G } )
assert( load( Chunk, "=server.lua (vote menu hook)", "t", Env ) )()

-- Helpers ----------------------------------------------------------------------
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

-- Tests ------------------------------------------------------------------------
print( "\nHooking:" )
Plugin:HookVoteMenu()
Check( "broadcasts updated vote menu data on hook", LastSent ~= nil )
Check( "Shuffle button shown while v2 is running", LastSent.Shuffle == true )
Check( "other buttons unaffected (Map Vote)", LastSent[ "Map Vote" ] == true )
Check( "substitution does not leak: voterandom still reported disabled",
	Shine:IsExtensionEnabled( "voterandom" ) == false )
Check( "IsExtensionEnabled restored to the original function", Shine.IsExtensionEnabled == OriginalIsExtensionEnabled )

print( "\nPer-client sends (e.g. on connect):" )
LastSent = nil
Shine:SendPluginData( "someclient" )
Check( "Shuffle shown for a single client", LastSent and LastSent.Shuffle == true )

print( "\nHooking twice:" )
local Wrapped = Shine.SendPluginData
Plugin:HookVoteMenu()
Check( "second hook is a no-op", Shine.SendPluginData == Wrapped )

print( "\nErrors inside Shine's own send:" )
Shine.ThrowNext = true
local Ok, Err = pcall( Shine.SendPluginData, Shine, nil )
Check( "error still propagates", not Ok and tostring( Err ):find( "boom" ) ~= nil )
Check( "IsExtensionEnabled restored even after an error", Shine.IsExtensionEnabled == OriginalIsExtensionEnabled )

print( "\nCleanup:" )
LastSent = nil
Plugin:Cleanup()
Check( "SendPluginData restored", Shine.SendPluginData == OriginalSendPluginData )
Check( "broadcasts vote menu data again on cleanup", LastSent ~= nil )
Check( "Shuffle button hidden again after cleanup", LastSent.Shuffle == false )
Check( "default cleanup still runs", BaseCleanupCalls == 1 )

Plugin:Cleanup()
Check( "cleanup twice does not break anything", Shine.SendPluginData == OriginalSendPluginData and BaseCleanupCalls == 2 )

print( string.format( "\n%d passed, %d failed\n", Passed, Failed ) )
os.exit( Failed == 0 and 0 or 1 )
