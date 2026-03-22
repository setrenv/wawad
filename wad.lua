--!strict
--[[
UNC CHAOS LAB v6 - Monolithic aggressive test script
Built against the uploaded sUNC-style docs the user provided.

Coverage:
- Closures: checkcaller, clonefunction, getfunctionhash, hookfunction, hookmetamethod,
            iscclosure, isexecutorclosure, islclosure, newcclosure
- Debug: debug.getconstant, debug.getconstants, debug.getproto, debug.getprotos,
         debug.getupvalue, debug.getupvalues, debug.getstack,
         debug.setstack, debug.setconstant, debug.setupvalue
- Drawing: getrenderproperty, cleardrawcache, isrenderobj, setrenderproperty
- Encoding: crypt.base64decode, crypt.base64encode, lz4compress, lz4decompress
- Environment: getgc, getgenv, getreg, getrenv
- FilterGC support data: FunctionFilterOptions, TableFilterOptions (tested through filtergc if present)
- Filesystem: appendfile, delfile, delfolder, getcustomasset, isfolder, isfile,
              loadfile, listfiles, makefolder, writefile
- Instances: cloneref, compareinstances, fireproximityprompt, fireclickdetector,
             getcallbackvalue, firetouchinterest, getinstances, gethui, getnilinstances
- Metatable: getnamecallmethod, getrawmetatable, isreadonly, setrawmetatable, setreadonly
- Network/Identity: request, identifyexecutor
- Hidden/Privilege: gethiddenproperty, getthreadidentity, isscriptable,
                    sethiddenproperty, setscriptable, setthreadidentity
- Scripts: getscriptbytecode, getrunningscripts, getloadedmodules, getcallingscript,
           getscripthash, getscriptclosure, getsenv, getscripts, loadstring
- Signals: Connection object, firesignal, getconnections, replicatesignal

Notes:
- This is intentionally heavy and aggressive.
- Some tests are environment-sensitive and will report soft failures/warnings if the
  target game/runtime lacks the required object/state.
- WebSocket docs were not provided, so WebSocket is intentionally not included.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local pass, fail, warnCount = 0, 0, 0
local results = {}
local startClock = os.clock()

local function log(kind: string, name: string, msg: string?)
    table.insert(results, {
        kind = kind,
        name = name,
        msg = msg or ""
    })

    if kind == "PASS" then
        pass += 1
        print(("✅ %s%s"):format(name, msg and msg ~= "" and (" • " .. msg) or ""))
    elseif kind == "WARN" then
        warnCount += 1
        warn(("⚠️ %s%s"):format(name, msg and msg ~= "" and (" • " .. msg) or ""))
    else
        fail += 1
        warn(("⛔ %s%s"):format(name, msg and msg ~= "" and (" • " .. msg) or ""))
    end
end

local function test(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if ok then
        log("PASS", name)
    else
        log("FAIL", name, tostring(err))
    end
end

local function soft(name: string, fn: () -> ())
    local ok, err = pcall(fn)
    if ok then
        log("PASS", name)
    else
        log("WARN", name, tostring(err))
    end
end

local function expect(cond: boolean, msg: string?)
    assert(cond, msg or "assertion failed")
end

local function expectEq(a: any, b: any, msg: string?)
    assert(a == b, msg or ("expected equality, got %s vs %s"):format(tostring(a), tostring(b)))
end

local function expectNe(a: any, b: any, msg: string?)
    assert(a ~= b, msg or ("expected inequality, got %s vs %s"):format(tostring(a), tostring(b)))
end

local function existsGlobal(path: string): boolean
    local env = getfenv(0)
    local current: any = env
    local rest = path
    while current ~= nil and rest ~= "" do
        local name, nextRest = string.match(rest, "^([^.]+)%.?(.*)$")
        current = current[name]
        rest = nextRest
    end
    return current ~= nil
end

local function getGlobal(path: string): any
    local env = getfenv(0)
    local current: any = env
    local rest = path
    while current ~= nil and rest ~= "" do
        local name, nextRest = string.match(rest, "^([^.]+)%.?(.*)$")
        current = current[name]
        rest = nextRest
    end
    return current
end

local function withTempPart(name: string?): BasePart
    local p = Instance.new("Part")
    p.Name = name or "UNC_TEMP_PART"
    p.Anchored = true
    p.CanCollide = true
    p.Size = Vector3.new(4, 4, 4)
    p.Position = Vector3.new(0, 10000, 0)
    p.Parent = workspace
    return p
end

local function withTempFolder(name: string?): Folder
    local f = Instance.new("Folder")
    f.Name = name or "UNC_TEMP_FOLDER"
    f.Parent = workspace
    return f
end

local function cleanupInstance(inst: Instance?)
    if inst then
        pcall(function()
            inst:Destroy()
        end)
    end
end

local function hasFunction(path: string)
    return type(getGlobal(path)) == "function"
end

local function aliasEq(mainName: string, aliases: {string})
    local main = getGlobal(mainName)
    if main == nil then
        error("main missing: " .. mainName)
    end
    for _, alias in ipairs(aliases) do
        expect(getGlobal(alias) ~= nil, "missing alias " .. alias)
    end
end

print("")
print("UNC CHAOS LAB v6")
print("Heavy monolithic executor torture tests")
print("")

-- existence sweep
do
    local required = {
        "checkcaller", "clonefunction", "getfunctionhash", "hookfunction", "hookmetamethod",
        "iscclosure", "isexecutorclosure", "islclosure", "newcclosure",
        "debug.getconstant", "debug.getconstants", "debug.getproto", "debug.getprotos",
        "debug.getupvalue", "debug.getupvalues", "debug.getstack",
        "debug.setstack", "debug.setconstant", "debug.setupvalue",
        "getrenderproperty", "cleardrawcache", "isrenderobj", "setrenderproperty",
        "crypt.base64decode", "crypt.base64encode", "lz4compress", "lz4decompress",
        "getgc", "getgenv", "getreg", "getrenv",
        "appendfile", "delfile", "delfolder", "getcustomasset", "isfolder", "isfile",
        "loadfile", "listfiles", "makefolder", "writefile",
        "cloneref", "compareinstances", "fireproximityprompt", "fireclickdetector",
        "getcallbackvalue", "firetouchinterest", "getinstances", "gethui", "getnilinstances",
        "getnamecallmethod", "getrawmetatable", "isreadonly", "setrawmetatable", "setreadonly",
        "request", "identifyexecutor",
        "gethiddenproperty", "getthreadidentity", "isscriptable", "sethiddenproperty",
        "setscriptable", "setthreadidentity",
        "getscriptbytecode", "getrunningscripts", "getloadedmodules", "getcallingscript",
        "getscripthash", "getscriptclosure", "getsenv", "getscripts", "loadstring",
        "firesignal", "getconnections", "replicatesignal",
    }

    for _, name in ipairs(required) do
        test("exists/" .. name, function()
            expect(existsGlobal(name), "missing global")
        end)
    end
end

-- aliases from provided docs/common aliases
soft("aliases/base64decode", function()
    aliasEq("crypt.base64decode", {"crypt.base64.decode", "crypt.base64_decode", "base64.decode", "base64_decode"})
end)
soft("aliases/base64encode", function()
    aliasEq("crypt.base64encode", {"crypt.base64.encode", "crypt.base64_encode", "base64.encode", "base64_encode"})
end)

-- Closures
test("checkcaller/main-scope", function()
    expectEq(checkcaller(), true, "main executor scope should report true")
end)

test("clonefunction/basic", function()
    local function f(x)
        return x + 1
    end
    local c = clonefunction(f)
    expect(type(c) == "function", "clone must be function")
    expectNe(c, f, "clone should not be reference-equal")
    expectEq(c(4), 5, "clone behavior mismatch")
end)

test("clonefunction/not-affected-by-hook", function()
    local function f()
        return "orig"
    end
    local c = clonefunction(f)
    local old = hookfunction(f, function()
        return "hooked"
    end)
    expectEq(f(), "hooked", "hook failed")
    expectEq(old(), "orig", "returned original function wrong")
    expectEq(c(), "orig", "clone should remain unhooked")
end)

test("getfunctionhash/basic", function()
    local function a()
        return "abc"
    end
    local function b()
        return "xyz"
    end
    local ha = getfunctionhash(a)
    local hb = getfunctionhash(b)
    expect(type(ha) == "string", "hash must be string")
    expect(#ha == 96, "SHA-384 hex should be 96 chars")
    expect(ha ~= hb, "different functions should hash differently")
end)

test("getfunctionhash/errors-on-cclosure", function()
    local ok = pcall(function()
        return getfunctionhash(print)
    end)
    expectEq(ok, false, "C closure should error")
end)

test("hookfunction/basic", function()
    local function f()
        return 1
    end
    local old = hookfunction(f, function()
        return 2
    end)
    expectEq(f(), 2, "hooked function bad result")
    expectEq(old(), 1, "old/original bad result")
end)

test("hookmetamethod/__index", function()
    local p = withTempPart("HookMetaPart")
    local old
    old = hookmetamethod(game, "__index", function(self, key)
        if self == p and key == "Name" then
            return "SPOOFED_NAME"
        end
        return old(self, key)
    end)
    expectEq(p.Name, "SPOOFED_NAME", "__index hook failed")
    cleanupInstance(p)
end)

test("iscclosure/islclosure/newcclosure", function()
    local function l()
        return true
    end
    local c = newcclosure(function()
        return true
    end)
    expectEq(islclosure(l), true, "Lua function should be lclosure")
    expectEq(iscclosure(l), false, "Lua function should not be cclosure")
    expectEq(iscclosure(c), true, "newcclosure result should be cclosure")
    expectEq(islclosure(c), false, "newcclosure result should not be lclosure")
end)

test("isexecutorclosure/basic", function()
    local function localLua()
        return 1
    end
    local c = newcclosure(function()
        return 2
    end)
    expectEq(isexecutorclosure(localLua), true, "executor lua closure should count")
    expectEq(isexecutorclosure(c), true, "executor cclosure should count")
end)

test("newcclosure/yieldable", function()
    local c = newcclosure(function()
        task.wait()
        return 123
    end)
    expectEq(c(), 123, "newcclosure should be yieldable")
end)

-- Debug
test("debug.getconstant/basic", function()
    local function f()
        print("HELLO_CONST")
    end
    expectEq(debug.getconstant(f, 1), "print")
    expectEq(debug.getconstant(f, 2), nil)
    expectEq(debug.getconstant(f, 3), "HELLO_CONST")
end)

test("debug.getconstant/cclosure-error", function()
    local ok = pcall(function()
        return debug.getconstant(print, 1)
    end)
    expectEq(ok, false)
end)

test("debug.getconstants/basic", function()
    local function f()
        local num = 5000 .. 50000
        print("Hello, world!", num, warn)
    end
    local constants = debug.getconstants(f)
    expect(type(constants) == "table", "constants must be table")
    expectEq(constants[1], 50000)
    expectEq(constants[2], "print")
    expectEq(constants[3], nil)
    expectEq(constants[4], "Hello, world!")
    expectEq(constants[5], "warn")
end)

test("debug.getproto/basic", function()
    local function outer()
        local function inner()
            return true
        end
        return inner
    end
    local active = debug.getproto(outer, 1, true)
    expect(type(active) == "table" and type(active[1]) == "function", "active proto lookup broken")
    expectEq(active[1](), true)
    local inactive = debug.getproto(outer, 1)
    expect(type(inactive) == "function", "inactive proto should still be a function handle")
end)

test("debug.getprotos/basic", function()
    local function outer()
        local function a()
            return 1
        end
        local function b()
            return 2
        end
        return a, b
    end
    local protos = debug.getprotos(outer)
    expect(type(protos) == "table", "getprotos must return table")
    expect(#protos >= 2, "expected at least two protos")
end)

test("debug.getupvalue/basic", function()
    local uv = "UPVALUE_OK"
    local function f()
        return uv
    end
    expectEq(debug.getupvalue(f, 1), uv)
end)

test("debug.getupvalues/basic", function()
    local uv = 9876
    local function f()
        return uv
    end
    local uvs = debug.getupvalues(f)
    expect(type(uvs) == "table", "getupvalues must return table")
    expectEq(uvs[1], uv)
end)

test("debug.getstack/basic", function()
    local function f()
        local x = "AB"
        expectEq(debug.getstack(1, 1), x)
        local all = debug.getstack(1)
        expect(type(all) == "table")
        expectEq(all[1], x)
    end
    f()
end)

test("debug.setstack/basic", function()
    local function f()
        local x = "before"
        debug.setstack(1, 1, "after")
        return x
    end
    expectEq(f(), "after", "setstack must mutate local value")
end)

test("debug.setconstant/basic", function()
    local function f()
        return "fail"
    end
    debug.setconstant(f, 1, "success")
    expectEq(f(), "success")
end)

test("debug.setupvalue/basic", function()
    local uv = "bad"
    local function f()
        return uv
    end
    debug.setupvalue(f, 1, "good")
    expectEq(f(), "good")
end)

-- Drawing
soft("drawing/isrenderobj", function()
    local sq = Drawing.new("Square")
    expectEq(isrenderobj(sq), true)
    expectEq(isrenderobj("x"), false)
    sq:Destroy()
end)

soft("drawing/getrenderproperty-setrenderproperty", function()
    local sq = Drawing.new("Square")
    setrenderproperty(sq, "Visible", true)
    expectEq(getrenderproperty(sq, "Visible"), true)
    sq.Visible = false
    expectEq(getrenderproperty(sq, "Visible"), false)
    sq:Destroy()
end)

soft("drawing/cleardrawcache", function()
    local a = Drawing.new("Square")
    local b = Drawing.new("Text")
    a.Visible = true
    b.Visible = true
    cleardrawcache()
    task.wait()
    local okA = pcall(function() return a.Visible end)
    local okB = pcall(function() return b.Visible end)
    expectEq(okA, false, "draw object A should be invalidated after cleardrawcache")
    expectEq(okB, false, "draw object B should be invalidated after cleardrawcache")
end)

-- Encoding / Compression
test("crypt.base64encode/base64decode/roundtrip", function()
    local s = "hello\0world_" .. tostring(math.random(1000, 9999))
    local enc = crypt.base64encode(s)
    local dec = crypt.base64decode(enc)
    expect(type(enc) == "string")
    expectEq(dec, s)
    expectEq(crypt.base64encode("test"), "dGVzdA==")
    expectEq(crypt.base64decode("dGVzdA=="), "test")
end)

test("lz4compress/lz4decompress/roundtrip", function()
    local s = string.rep("Hello Hello Hello ", 25)
    local c = lz4compress(s)
    local d = lz4decompress(c)
    expect(type(c) == "string")
    expectEq(d, s)
end)

-- Environment / memory
test("getgc/basic-filtering", function()
    local t = {}
    local function f() return 1 end
    task.wait()
    local foundFunc = false
    local foundTableInFalse = false
    for _, v in pairs(getgc()) do
        if v == f then
            foundFunc = true
        end
        if v == t then
            foundTableInFalse = true
        end
    end
    expect(foundFunc, "new function should appear in getgc()")
    expectEq(foundTableInFalse, false, "tables should not appear in getgc() without true")

    local foundTableInTrue = false
    for _, v in pairs(getgc(true)) do
        if v == t then
            foundTableInTrue = true
            break
        end
    end
    expect(foundTableInTrue, "table should appear in getgc(true)")
end)

test("getgenv/pollution", function()
    local g = getgenv()
    g.__UNC_GEN_TEST = 123
    local threadEnv = getfenv(0)
    threadEnv.__UNC_LOCAL_POLLUTE = 999
    expectEq(getgenv().__UNC_GEN_TEST, 123)
    expectEq(getgenv().__UNC_LOCAL_POLLUTE, nil, "getgenv should not be polluted by thread getfenv modifications")
end)

test("getreg/basic", function()
    local th = task.spawn(function() task.wait(0.1) end)
    task.wait()
    local reg = getreg()
    expect(type(reg) == "table", "registry must be table")
    local found = false
    for _, v in pairs(reg) do
        if v == th then
            found = true
            break
        end
    end
    expect(found, "spawned thread should appear in registry")
end)

test("getrenv/basic", function()
    local env = getrenv()
    expect(type(env) == "table")
    env.__UNC_RENV_TEST = 77
    expectEq(__UNC_RENV_TEST, 77)
end)

-- filtergc tests if present
if hasFunction("filtergc") then
    test("filtergc/function-name-hash-upvalues", function()
        local marker = 424242
        local function specialFilterTarget()
            local uv = marker
            print("UNC_FILTER_CONST", uv)
            return uv
        end
        local hash = getfunctionhash(specialFilterTarget)
        local one = filtergc("function", {
            Name = "specialFilterTarget",
            IgnoreExecutor = false,
            Hash = hash,
            Constants = {"print", "UNC_FILTER_CONST"},
        }, true)
        expect(type(one) == "function", "filtergc one(function) must return function")
        expectEq(getfunctionhash(one), hash)
        expectEq(debug.getupvalue(one, 1), marker)
    end)

    test("filtergc/table-keys-values-kvp-metatable", function()
        local mt = {__index = {}}
        local t = setmetatable({A = 1, B = 2}, mt)
        local one = filtergc("table", {
            Keys = {"A", "B"},
            Values = {1, 2},
            KeyValuePairs = {A = 1, B = 2},
            Metatable = mt,
        }, true)
        expect(type(one) == "table", "filtergc one(table) must return table")
        expectEq(one.A, 1)
        expectEq(getmetatable(one), mt)
    end)
else
    log("WARN", "filtergc/*", "filtergc docs were provided via option pages, but no filtergc function doc/file was uploaded")
end

-- Filesystem
do
    local base = ".unc_chaos_v6"
    soft("filesystem/cleanup-old", function()
        if isfolder(base) then
            delfolder(base)
        end
    end)

    test("filesystem/makefolder-isfolder", function()
        makefolder(base)
        expectEq(isfolder(base), true)
    end)

    test("filesystem/write-read-overwrite", function()
        writefile(base .. "/a.txt", "A")
        expectEq(isfile(base .. "/a.txt"), true)
        expectEq(readfile(base .. "/a.txt"), "A")
        writefile(base .. "/a.txt", "Z")
        expectEq(readfile(base .. "/a.txt"), "Z")
    end)

    test("filesystem/appendfile", function()
        writefile(base .. "/append.txt", "su")
        appendfile(base .. "/append.txt", "cce")
        appendfile(base .. "/append.txt", "ss")
        expectEq(readfile(base .. "/append.txt"), "success")
    end)

    test("filesystem/listfiles", function()
        local listed = listfiles(base)
        expect(type(listed) == "table", "listfiles must return table")
        local found = false
        for _, v in ipairs(listed) do
            if tostring(v):find("append%.txt") then
                found = true
                break
            end
        end
        expect(found, "listfiles must include appended file")
    end)

    test("filesystem/loadfile", function()
        writefile(base .. "/chunk.lua", "return function() return 321 end")
        local chunk = loadfile(base .. "/chunk.lua")
        expect(type(chunk) == "function", "loadfile must return compiled chunk")
        local produced = chunk()
        expect(type(produced) == "function", "chunk should return inner function")
        expectEq(produced(), 321)
    end)

    test("filesystem/getcustomasset", function()
        writefile(base .. "/asset.txt", "HELLO")
        local asset = getcustomasset(base .. "/asset.txt")
        expect(type(asset) == "string")
        expect(asset:find("rbxasset") ~= nil, "expected rbxasset-like content id")
    end)

    test("filesystem/delfile", function()
        writefile(base .. "/dead.txt", "bye")
        expectEq(isfile(base .. "/dead.txt"), true)
        delfile(base .. "/dead.txt")
        expectEq(isfile(base .. "/dead.txt"), false)
    end)

    test("filesystem/delfolder", function()
        makefolder(base .. "/sub")
        expectEq(isfolder(base .. "/sub"), true)
        delfolder(base .. "/sub")
        expectEq(isfolder(base .. "/sub"), false)
    end)
end

-- Instances / engine interaction
test("cloneref/basic", function()
    local p = Players.LocalPlayer or game
    local c = cloneref(p)
    expectNe(p, c, "cloneref should not be == to original")
    expectEq(c.Name, p.Name)
end)

test("compareinstances/basic", function()
    local c = cloneref(game)
    expectEq(compareinstances(game, c), true)
    expectEq(compareinstances(game, game), true)
end)

test("getcallbackvalue/basic", function()
    local b = Instance.new("BindableFunction")
    b.OnInvoke = function(x)
        return x + 1
    end
    local cb = getcallbackvalue(b, "OnInvoke")
    expect(type(cb) == "function")
    expectEq(cb(9), 10)
    cleanupInstance(b)
end)

test("getinstances/includes-parent-nil", function()
    local p = Instance.new("Part")
    p.Parent = nil
    local found = false
    for _, v in pairs(getinstances()) do
        if v == p then
            found = true
            break
        end
    end
    expect(found, "parent=nil instance should appear in getinstances")
    cleanupInstance(p)
end)

test("getnilinstances/basic", function()
    local p = Instance.new("Part")
    p.Parent = nil
    local found = false
    for _, v in pairs(getnilinstances()) do
        if v == p then
            found = true
            break
        end
    end
    expect(found, "parent=nil instance should appear in getnilinstances")
    cleanupInstance(p)
end)

test("gethui/basic", function()
    local hui = gethui()
    expect(typeof(hui) == "Instance", "gethui must return instance")
    local g = Instance.new("ScreenGui")
    g.Name = "UNC_HUI_TEST"
    g.Parent = hui
    expect(hui:FindFirstChild("UNC_HUI_TEST") ~= nil, "UI should persist under gethui() container")
    cleanupInstance(g)
end)

soft("fireclickdetector/basic", function()
    local p = withTempPart("ClickDetectorHost")
    local d = Instance.new("ClickDetector")
    d.MaxActivationDistance = 10000
    d.Parent = p
    local hit = false
    d.MouseHoverEnter:Connect(function()
        hit = true
    end)
    fireclickdetector(d, 50, "MouseHoverEnter")
    task.wait(0.1)
    expect(hit, "fireclickdetector should fire selected event")
    cleanupInstance(p)
end)

soft("fireproximityprompt/basic", function()
    local cam = workspace.CurrentCamera
    expect(cam ~= nil, "CurrentCamera missing")
    local p = withTempPart("PromptHost")
    p.Position = cam.CFrame.Position + cam.CFrame.LookVector * 12
    local prompt = Instance.new("ProximityPrompt")
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 10000
    prompt.HoldDuration = 999
    prompt.Parent = p
    local triggered = false
    prompt.Triggered:Connect(function()
        triggered = true
    end)
    fireproximityprompt(prompt)
    task.wait(0.15)
    expect(triggered, "fireproximityprompt should bypass hold duration")
    cleanupInstance(p)
end)

soft("firetouchinterest/basic", function()
    local lp = Players.LocalPlayer
    expect(lp ~= nil, "LocalPlayer missing")
    local char = lp.Character or lp.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    expect(root ~= nil, "No root part")
    local p = withTempPart("TouchTarget")
    local touched = false
    local ended = false
    p.Touched:Connect(function(hit)
        if hit == root then
            touched = true
        end
    end)
    p.TouchEnded:Connect(function(hit)
        if hit == root then
            ended = true
        end
    end)
    firetouchinterest(root, p, 0)
    task.wait(0.05)
    firetouchinterest(root, p, 1)
    task.wait(0.05)
    expect(touched, "Touched event not observed")
    expect(ended, "TouchEnded event not observed")
    cleanupInstance(p)
end)

-- Metatable / namecall
test("getrawmetatable/basic", function()
    local mt = getrawmetatable(game)
    expect(type(mt) == "table" or mt == nil, "must return table or nil")
end)

test("isreadonly-setreadonly/basic", function()
    local t = {}
    expectEq(isreadonly(t), false)
    setreadonly(t, true)
    expectEq(isreadonly(t), true)
    setreadonly(t, false)
    expectEq(isreadonly(t), false)
    t.x = 10
    expectEq(t.x, 10)
end)

test("setrawmetatable/basic", function()
    local t = {}
    setrawmetatable(t, {
        __index = function()
            return 5
        end
    })
    expectEq(t.anything, 5)
end)

test("getnamecallmethod/outside-hook-nil", function()
    expectEq(getnamecallmethod(), nil)
end)

soft("getnamecallmethod/inside-namecall-hook", function()
    local called = false
    local seenMethod
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if m ~= nil then
            called = true
            seenMethod = m
        end
        return old(self, ...)
    end)
    game:GetService("Players")
    task.wait()
    expect(called, "getnamecallmethod never returned inside __namecall hook")
    expect(type(seenMethod) == "string", "method name must be string")
end)

-- Network / identity
test("identifyexecutor/basic", function()
    local name, version = identifyexecutor()
    expect(type(name) == "string" and #name > 0, "executor name missing")
    expect(type(version) == "string", "executor version must be string")
end)

soft("request/get", function()
    local r = request({
        Url = "https://httpbin.org/get",
        Method = "GET",
    })
    expect(type(r) == "table")
    expect(type(r.Success) == "boolean")
    expect(type(r.Body) == "string")
    expect(type(r.StatusCode) == "number")
    expect(type(r.StatusMessage) == "string")
    expect(type(r.Headers) == "table")
end)

soft("request/post-body-roundtrip", function()
    local body = "unc_payload_" .. tostring(math.random(1000, 9999))
    local r = request({
        Url = "https://httpbin.org/post",
        Method = "POST",
        Body = body,
        Headers = {
            ["Content-Type"] = "text/plain",
        }
    })
    expect(type(r.Body) == "string", "response body missing")
    local decoded = HttpService:JSONDecode(r.Body)
    expectEq(decoded.data, body)
end)

soft("request/header-injection", function()
    local r = request({
        Url = "https://httpbin.org/get",
        Method = "GET",
    })
    local decoded = HttpService:JSONDecode(r.Body)
    local headers = decoded.headers
    expect(type(headers) == "table", "httpbin headers missing")
    local hasUA, hasFingerprintish = false, false
    for k, _ in pairs(headers) do
        local lower = string.lower(k)
        if lower == "user-agent" then
            hasUA = true
        end
        if string.find(lower, "fingerprint", 1, true) or string.find(lower, "identifier", 1, true) then
            hasFingerprintish = true
        end
    end
    expect(hasUA, "User-Agent must exist")
    expect(hasFingerprintish, "expected fingerprint/identifier header")
end)

-- Hidden / privilege / scriptable
soft("getthreadidentity-setthreadidentity/basic", function()
    local before = getthreadidentity()
    setthreadidentity(3)
    expectEq(getthreadidentity(), 3)
    setthreadidentity(before)
    expectEq(getthreadidentity(), before)
end)

soft("isscriptable-setscriptable/basic", function()
    local p = Instance.new("Part")
    local prop = "BottomParamA"
    local prev = isscriptable(p, prop)
    local toggled = setscriptable(p, prop, true)
    expect(toggled ~= nil, "setscriptable should not return nil for supported property")
    expectEq(isscriptable(p, prop), true)
    setscriptable(p, prop, false)
    expectEq(isscriptable(p, prop), false)
    if prev ~= nil then
        setscriptable(p, prop, prev)
    end
    cleanupInstance(p)
end)

soft("gethiddenproperty/basic-visible-prop", function()
    local p = Instance.new("Part")
    local v, hidden = gethiddenproperty(p, "Name")
    expectEq(v, "Part")
    expectEq(hidden, false)
    cleanupInstance(p)
end)

soft("sethiddenproperty/basic", function()
    local p = Instance.new("Part")
    local before = select(1, gethiddenproperty(p, "Name"))
    local hidden = sethiddenproperty(p, "Name", "UNC_HIDDEN_SET")
    local after = select(1, gethiddenproperty(p, "Name"))
    expectEq(after, "UNC_HIDDEN_SET")
    expect(type(hidden) == "boolean", "sethiddenproperty should return boolean")
    p.Name = before
    cleanupInstance(p)
end)

soft("privilege/identity-affects-access", function()
    local before = getthreadidentity()
    setthreadidentity(2)
    local okLow = pcall(function()
        return game.CoreGui
    end)
    setthreadidentity(8)
    local okHigh = pcall(function()
        return game.CoreGui
    end)
    setthreadidentity(before)
    expect(okLow ~= okHigh or okHigh == true, "identity change should affect capability surface or at least succeed high")
end)

-- Scripts / bytecode / env
test("loadstring/valid", function()
    local f = loadstring("return 5")
    expect(type(f) == "function")
    expectEq(f(), 5)
end)

test("loadstring/invalid-does-not-throw", function()
    local f, err = loadstring("return ")
    expectEq(f, nil)
    expect(type(err) == "string" and #err > 0, "invalid loadstring should return nil,error")
end)

test("getcallingscript/executor-thread", function()
    expectEq(getcallingscript(), nil, "executor thread should usually have no calling script")
end)

soft("getscripts/basic", function()
    local list = getscripts()
    expect(type(list) == "table")
    local foundAny = false
    for _, v in ipairs(list) do
        if v:IsA("LocalScript") or v:IsA("ModuleScript") or v:IsA("Script") then
            foundAny = true
            break
        end
    end
    expect(foundAny or #list == 0, "getscripts returned malformed entries")
end)

soft("getloadedmodules/only-loaded", function()
    local m = Instance.new("ModuleScript")
    m.Source = "return { x = 1 }"
    m.Parent = workspace
    local beforeFound = false
    for _, v in ipairs(getloadedmodules()) do
        if v == m then
            beforeFound = true
            break
        end
    end
    pcall(require, m)
    local afterFound = false
    for _, v in ipairs(getloadedmodules()) do
        if v == m then
            afterFound = true
            break
        end
    end
    expectEq(beforeFound, false, "unrequired module should not already be considered loaded")
    expect(afterFound, "required module should appear in getloadedmodules")
    cleanupInstance(m)
end)

soft("getrunningscripts/basic", function()
    local running = getrunningscripts()
    expect(type(running) == "table")
end)

soft("getscriptbytecode-nil-on-empty", function()
    local s = Instance.new("LocalScript")
    expectEq(getscriptbytecode(s), nil)
    cleanupInstance(s)
end)

soft("getscripthash/basic-or-nil", function()
    local s = Instance.new("LocalScript")
    local hash = getscripthash(s)
    expect(hash == nil or (type(hash) == "string" and #hash == 96), "hash must be nil or 96-char hex")
    cleanupInstance(s)
end)

soft("getscriptclosure/basic-or-nil", function()
    local s = Instance.new("LocalScript")
    local cl = getscriptclosure(s)
    expect(cl == nil or type(cl) == "function", "must be function or nil")
    cleanupInstance(s)
end)

soft("getsenv/errors-on-not-running", function()
    local s = Instance.new("LocalScript")
    local ok = pcall(function()
        return getsenv(s)
    end)
    expectEq(ok, false, "getsenv should error on non-running script")
    cleanupInstance(s)
end)

-- Signals / connections
test("getconnections-basic-connection-object", function()
    local b = Instance.new("BindableEvent")
    local hit = 0
    b.Event:Connect(function(a, c)
        if a == 1 and c == 2 then
            hit += 1
        end
    end)
    local conns = getconnections(b.Event)
    expect(type(conns) == "table" and #conns > 0, "must return connection list")
    local c = conns[1]
    expect(type(c.Enabled) == "boolean", "Connection.Enabled missing")
    expect(type(c.ForeignState) == "boolean", "Connection.ForeignState missing")
    expect(type(c.LuaConnection) == "boolean", "Connection.LuaConnection missing")
    expect(type(c.Function) == "function" or c.Function == nil, "Connection.Function malformed")
    expect(c.Thread == nil or type(c.Thread) == "thread", "Connection.Thread malformed")
    c:Fire(1, 2)
    task.wait()
    expectEq(hit, 1, "Connection:Fire should invoke callback")
    cleanupInstance(b)
end)

test("Connection-enable-disable-disconnect", function()
    local b = Instance.new("BindableEvent")
    local count = 0
    b.Event:Connect(function()
        count += 1
    end)
    local c = getconnections(b.Event)[1]
    c:Disable()
    c:Fire()
    task.wait()
    expectEq(count, 0, "disabled connection should not fire")
    c:Enable()
    c:Fire()
    task.wait()
    expectEq(count, 1, "enabled connection should fire")
    c:Disconnect()
    c:Fire()
    task.wait()
    expectEq(count, 1, "disconnected connection should stay dead")
    cleanupInstance(b)
end)

test("firesignal/basic", function()
    local b = Instance.new("BindableEvent")
    local hit = false
    b.Event:Connect(function(a, c)
        if a == 1 and c == 2 then
            hit = true
        end
    end)
    firesignal(b.Event, 1, 2)
    task.wait()
    expect(hit, "firesignal should invoke signal listeners")
    cleanupInstance(b)
end)

soft("replicatesignal/invalid-args-should-error", function()
    local b = Instance.new("BindableEvent")
    local ok = pcall(function()
        replicatesignal(b.Event, {impossible = true})
    end)
    expectEq(ok, false, "replicatesignal should error on invalid signal/arg structure")
    cleanupInstance(b)
end)

-- Aggressive mini-stress passes
soft("stress/thread-flood", function()
    local n = 0
    for _ = 1, 200 do
        task.spawn(function()
            n += 1
        end)
    end
    task.wait(0.2)
    expectEq(n, 200)
end)

soft("stress/getgc-spam", function()
    for _ = 1, 50 do
        local g = getgc(true)
        expect(type(g) == "table")
    end
end)

soft("stress/request-head", function()
    local r = request({
        Url = "https://httpbin.org/get",
        Method = "HEAD",
    })
    expect(type(r.StatusCode) == "number")
end)

soft("stress/filesystem-spam", function()
    local dir = ".unc_chaos_v6_spam"
    if not isfolder(dir) then
        makefolder(dir)
    end
    for i = 1, 20 do
        writefile(("%s/%d.txt"):format(dir, i), tostring(i))
    end
    local listed = listfiles(dir)
    expect(#listed >= 20, "expected many files after spam write")
end)

-- Final report
do
    local total = pass + fail
    local strictRate = total > 0 and ((pass / total) * 100) or 0
    local softTotal = pass + fail + warnCount
    local blendedRate = softTotal > 0 and ((pass / softTotal) * 100) or 0
    local elapsed = os.clock() - startClock

    print("")
    print(("========== UNC CHAOS LAB v6 SUMMARY =========="))
    print(("PASS: %d"):format(pass))
    print(("FAIL: %d"):format(fail))
    print(("WARN: %d"):format(warnCount))
    print(("STRICT RATE: %.2f%%"):format(strictRate))
    print(("BLENDED RATE: %.2f%%"):format(blendedRate))
    print(("TIME: %.2fs"):format(elapsed))
    print(("============================================="))
    print("")

    local verdict
    if strictRate >= 95 then
        verdict = "🟢 top-tier / extremely complete"
    elseif strictRate >= 80 then
        verdict = "🟡 strong but flawed"
    elseif strictRate >= 60 then
        verdict = "🟠 partial / unstable"
    else
        verdict = "🔴 heavily broken / fake / incomplete"
    end

    print("VERDICT:", verdict)

    if fail > 0 or warnCount > 0 then
        print("")
        print("Detailed non-pass results:")
        for _, item in ipairs(results) do
            if item.kind ~= "PASS" then
                print(("[%s] %s%s"):format(item.kind, item.name, item.msg ~= "" and (" • " .. item.msg) or ""))
            end
        end
    end
end
