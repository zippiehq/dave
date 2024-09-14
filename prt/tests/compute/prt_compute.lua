#!/usr/bin/lua
require "setup_path"

-- amount of time to fastforward if `IDLE_LIMIT` is reached
local FAST_FORWARD_TIME = 300
-- delay time for blockchain node to be ready
local NODE_DELAY = 2
-- delay between each player to run its command process
local PLAYER_DELAY = 5
-- number of fake commitment to make
local FAKE_COMMITMENT_COUNT = 1
-- number of idle players
local IDLE_PLAYER_COUNT = 0

-- Required Modules
local start_hero = require "runners.hero_runner"
local start_sybil = require "runners.sybil_runner"
local start_idle = require "runners.idle_runner"

local helper = require "utils.helper"
local blockchain_utils = require "blockchain.utils"
local time = require "utils.time"
local blockchain_constants = require "blockchain.constants"
local Blockchain = require "blockchain.node"

-- Function to setup players
local function setup_players(use_lua_node, extra_data, contract_address, machine_path)
    local player_coroutines = {}
    local player_index = 1

    if use_lua_node then
        -- use Lua node to defend
        print("Setting up Lua honest player")
        player_coroutines[player_index] = start_hero(player_index, machine_path, contract_address, extra_data)
    else
        -- use Rust node to defend
        print("Setting up Rust honest player")
        -- TODO: create a rust runner
        -- table.insert(commands, string.format(
        --     [[sh -c "echo $$ ; exec env MACHINE_PATH='%s' RUST_LOG='info' \
        --     ../../prt-rs/target/release/cartesi-prt-compute 2>&1 | tee honest.log"]],
        --     machine_path))
    end
    player_index = player_index + 1

    if FAKE_COMMITMENT_COUNT > 0 then
        print(string.format("Setting up dishonest player with %d fake commitments", FAKE_COMMITMENT_COUNT))
        player_coroutines[player_index] = start_sybil(player_index, machine_path, contract_address, FAKE_COMMITMENT_COUNT)
        player_index = player_index + 1
    end

    if IDLE_PLAYER_COUNT > 0 then
        print(string.format("Setting up %d idle players", IDLE_PLAYER_COUNT))
        for _ = 1, IDLE_PLAYER_COUNT do
            player_coroutines[player_index] = start_idle(player_index, machine_path, contract_address)
            player_index = player_index + 1
        end
    end

    return player_coroutines
end

-- Main Execution
local machine_path = os.getenv("MACHINE_PATH")
local use_lua_node = helper.str_to_bool(os.getenv("LUA_NODE"))
local extra_data = helper.str_to_bool(os.getenv("EXTRA_DATA"))
local contract_address = blockchain_constants.root_tournament

print("Hello from Dave lua prototype!")
local player_coroutines = setup_players(use_lua_node, extra_data, contract_address, machine_path)

local blockchain_node = Blockchain:new()
time.sleep(NODE_DELAY)

local deploy_cmd = [[sh -c "cd ../../contracts && ./deploy_anvil.sh"]]
local reader = io.popen(deploy_cmd)
local pid = assert(reader):read()
time.sleep(PLAYER_DELAY)

while true do
    local idle = true
    for i, c in ipairs(player_coroutines) do
        local success, ret = coroutine.resume(c)
        local status = coroutine.status(c)

        if not success then
            print(string.format("coroutine %d fail to resume with error: %s", i, ret))
        elseif status == "dead" then
            player_coroutines[i] = nil
        else
            idle = idle and ret.idle
        end
    end

    if #player_coroutines == 0 then
        print("No active players, ending program...")
        break
    end

    if idle then
        print(string.format("All players idle, fastforward blockchain for %d seconds...", FAST_FORWARD_TIME))
        blockchain_utils.advance_time(FAST_FORWARD_TIME, blockchain_constants.endpoint)
    end
end

print("Good-bye, world!")
