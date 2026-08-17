--[[
    Hello World + Teleport Script (Roblox Executor)
    -----------------------------------------------
    - รันแล้ววาปไปที่ workspace.Assets.MapTemplate.Map.BorderWall["包围"].Part3
    - กด F6 = ดึงสคริปต์ "เวอร์ชันล่าสุด" จาก SOURCE_URL แล้วคัดลอกลงคลิปบอร์ด
    - กด F7 = วาปซ้ำอีกรอบ (เผื่อตายแล้วเกิดใหม่ ไม่ต้องรันสคริปต์ใหม่)

    v1.2.0 แก้ปัญหา "กด F7 แล้วไม่วาป":
      1. วาปไปยืนบน "ผิวบน" ของ part แทนจุดกึ่งกลาง — BorderWall เป็นกำแพงใหญ่
         วาปเข้ากึ่งกลาง = โผล่ในเนื้อกำแพง แล้วโดนฟิสิกส์ดันออก/ร่วง เหมือนไม่ได้วาป
      2. ค้างตำแหน่งไว้ ~0.4 วิ กันโดนเซิร์ฟเวอร์ดึงกลับ (snapback)
      3. ผูกปุ่มทั้ง UserInputService + ContextActionService เผื่อ input โดน UI กิน
      4. ไม่สนใจ gameProcessed แล้ว (เช็คแค่ว่ากำลังพิมพ์ในช่องแชทอยู่รึเปล่า)
      5. print log ทุกขั้น บอกได้ว่าติดตรงไหน
--]]

local CONFIG = {
    VERSION = "1.2.0",

    -- ลิงก์ raw ของสคริปต์ตัวเอง (แก้โค้ดบน GitHub แล้วกด F6 จะได้ตัวล่าสุดทันที)
    SOURCE_URL = "https://raw.githubusercontent.com/thanadon-dev/rotest/main/HelloWorld.lua",

    -- path ปลายทาง เริ่มนับจาก workspace
    -- "\229\140\133\229\155\180" คือ "包围" เขียนเป็น byte escape กันปัญหา encoding
    TELEPORT_PATH = {
        "Assets",
        "MapTemplate",
        "Map",
        "BorderWall",
        "\229\140\133\229\155\180",
        "Part3",
    },

    PLACE_ON_TOP = true,                    -- true = ยืนบนผิวบนของ part, false = กึ่งกลาง part
    TELEPORT_OFFSET = Vector3.new(0, 5, 0), -- ยกเพิ่มอีกกี่ studs
    HOLD_TIME = 0.4,                        -- ค้างตำแหน่งกี่วินาที กันโดนดึงกลับ (0 = ไม่ค้าง)
    WAIT_TIMEOUT = 10,                      -- รอ instance โผล่กี่วินาที (เผื่อ map ยัง stream ไม่เสร็จ)

    COPY_HOTKEY = Enum.KeyCode.F6,
    TELEPORT_HOTKEY = Enum.KeyCode.F7,
    NOTIFY = true,
    DEBUG = true, -- print log ละเอียด
}

-- โค้ดสำรอง ใช้ตอนดึงจาก URL ไม่ได้
local FALLBACK_SOURCE = [==[
loadstring(game:HttpGet("https://raw.githubusercontent.com/thanadon-dev/rotest/main/HelloWorld.lua"))()
]==]

--------------------------------------------------------------------
-- 1) ตัวช่วย
--------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local function log(fmt, ...)
    if not CONFIG.DEBUG then return end
    local ok, msg = pcall(string.format, fmt, ...)
    print("[TP] " .. (ok and msg or fmt))
end

local function notify(title, text)
    if not CONFIG.NOTIFY then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 4,
        })
    end)
end

-- executor แต่ละตัวตั้งชื่อฟังก์ชันคลิปบอร์ดไม่เหมือนกัน หาอันที่มี
local function getClipboardFn()
    return setclipboard
        or toclipboard
        or set_clipboard
        or (syn and syn.write_clipboard)
        or (Clipboard and Clipboard.set)
        or (getgenv and getgenv().setclipboard)
end

-- HttpGet ก็เช่นกัน
local function httpGet(url)
    local ok, res = pcall(function()
        if syn and syn.request then
            return syn.request({ Url = url, Method = "GET" }).Body
        elseif request then
            return request({ Url = url, Method = "GET" }).Body
        elseif http_request then
            return http_request({ Url = url, Method = "GET" }).Body
        else
            return game:HttpGet(url, true)
        end
    end)
    if ok and type(res) == "string" and #res > 0 then
        return res
    end
    return nil, tostring(res)
end

--------------------------------------------------------------------
-- 2) วาปไปที่ path ที่กำหนด
--------------------------------------------------------------------
-- เดิน path ทีละชั้น ถ้าชั้นไหนหาย จะบอกได้ว่าพังตรงไหน
local function resolvePath(root, segments, timeout)
    local node = root
    local walked = "workspace"
    for _, name in ipairs(segments) do
        local child = node:FindFirstChild(name)
        if not child then
            local ok, res = pcall(function()
                return node:WaitForChild(name, timeout)
            end)
            child = ok and res or nil
        end
        if not child then
            local names = {}
            for _, c in ipairs(node:GetChildren()) do
                table.insert(names, c.Name)
                if #names >= 10 then break end
            end
            return nil, ("หาไม่เจอ: %s -> %q | ลูกที่มีจริง: %s")
                :format(walked, name, table.concat(names, ", "))
        end
        node = child
        walked = walked .. "." .. name
    end
    return node
end

-- จุดที่จะวาปไป: ยืนบนผิวบนของ part (ไม่ใช่กลางเนื้อ part)
local function getDestination(target)
    if target:IsA("BasePart") then
        local cf = target.CFrame
        if CONFIG.PLACE_ON_TOP then
            -- ใช้ผิวบนตามแกน Y ของโลก ไม่ใช่แกนของ part เผื่อ part เอียง
            local topY = target.Position.Y + (target.Size.Y * 0.5)
            cf = CFrame.new(target.Position.X, topY, target.Position.Z)
        end
        return cf + CONFIG.TELEPORT_OFFSET, target.Size
    elseif target:IsA("Model") then
        local cf, size = target:GetBoundingBox()
        if CONFIG.PLACE_ON_TOP then
            cf = CFrame.new(cf.Position.X, cf.Position.Y + size.Y * 0.5, cf.Position.Z)
        end
        return cf + CONFIG.TELEPORT_OFFSET, size
    elseif target:IsA("Attachment") then
        return target.WorldCFrame + CONFIG.TELEPORT_OFFSET, Vector3.zero
    end
    return nil
end

local function teleport()
    log("เริ่มวาป...")

    local character = LocalPlayer.Character
    if not character or not character.Parent then
        log("ยังไม่มีตัวละคร รอ CharacterAdded...")
        character = LocalPlayer.CharacterAdded:Wait()
    end

    local root = character:FindFirstChild("HumanoidRootPart")
        or character:WaitForChild("HumanoidRootPart", CONFIG.WAIT_TIMEOUT)
    if not root then
        warn("[TP] ไม่เจอ HumanoidRootPart (ตัวละครยังโหลดไม่เสร็จ?)")
        notify("Teleport ล้มเหลว", "ไม่เจอ HumanoidRootPart")
        return false
    end

    local target, err = resolvePath(workspace, CONFIG.TELEPORT_PATH, CONFIG.WAIT_TIMEOUT)
    if not target then
        warn("[TP] " .. err)
        notify("Teleport ล้มเหลว", "หา path ไม่เจอ (ดู console)")
        return false
    end

    local dest, size = getDestination(target)
    if not dest then
        local msg = ("%s เป็น %s ไม่มีตำแหน่งให้วาป"):format(target.Name, target.ClassName)
        warn("[TP] " .. msg)
        notify("Teleport ล้มเหลว", msg)
        return false
    end

    local before = root.Position
    log("เจอ %s (%s) size=%s", target:GetFullName(), target.ClassName, tostring(size))
    log("จาก (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f)",
        before.X, before.Y, before.Z, dest.Position.X, dest.Position.Y, dest.Position.Z)

    -- ปลด anchor ชั่วคราวไม่ต้อง แต่ต้องเคลียร์ความเร็ว กันโดนเหวี่ยง (fling)
    local function snap()
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        character:PivotTo(dest)
    end

    snap()

    -- ค้างตำแหน่งไว้แป๊บนึง กันเซิร์ฟเวอร์/ฟิสิกส์ดึงกลับที่เดิม
    if CONFIG.HOLD_TIME > 0 then
        task.spawn(function()
            local elapsed = 0
            while elapsed < CONFIG.HOLD_TIME do
                elapsed = elapsed + RunService.Heartbeat:Wait()
                if not (character.Parent and root.Parent) then break end
                snap()
            end

            local after = root.Position
            local drift = (after - dest.Position).Magnitude
            if drift > 10 then
                warn(("[TP] วาปแล้วโดนดึงกลับ (ห่างจากเป้า %.1f studs) — เกมนี้น่าจะมีกันโกงฝั่งเซิร์ฟเวอร์"):format(drift))
                notify("Teleport", "โดนดึงกลับ — เกมมี anti-cheat")
            else
                log("อยู่ที่เป้าหมายแล้ว (คลาด %.1f studs)", drift)
            end
        end)
    end

    print(("[TP] วาปไป %s แล้ว"):format(target:GetFullName()))
    notify("Teleport", "วาปไป " .. target.Name .. " แล้ว")
    return true
end

--------------------------------------------------------------------
-- 3) ดึงสคริปต์ล่าสุด + คัดลอก
--------------------------------------------------------------------
local function copyLatest()
    local clipboard = getClipboardFn()
    if not clipboard then
        warn("[Update] executor นี้ไม่รองรับ setclipboard")
        notify("Update", "executor ไม่รองรับ setclipboard")
        return
    end

    local source, err
    if CONFIG.SOURCE_URL ~= "" then
        -- กัน cache ของ GitHub/CDN เพื่อให้ได้เวอร์ชันล่าสุดจริง ๆ
        local sep = CONFIG.SOURCE_URL:find("?") and "&" or "?"
        source, err = httpGet(CONFIG.SOURCE_URL .. sep .. "nocache=" .. tostring(tick()))
    end

    if source then
        clipboard(source)
        local ver = source:match('VERSION%s*=%s*"([^"]+)"')
        if ver and ver ~= CONFIG.VERSION then
            print(("[Update] คัดลอกเวอร์ชันล่าสุดแล้ว: %s (ที่รันอยู่ %s)"):format(ver, CONFIG.VERSION))
            notify("Update", "คัดลอกเวอร์ชันใหม่ " .. ver .. " แล้ว")
        else
            print("[Update] คัดลอกสคริปต์ล่าสุดลงคลิปบอร์ดแล้ว (" .. #source .. " ตัวอักษร)")
            notify("Update", "คัดลอกสคริปต์ล่าสุดแล้ว")
        end
    else
        clipboard(FALLBACK_SOURCE)
        warn("[Update] ดึงจาก URL ไม่สำเร็จ: " .. tostring(err) .. " — คัดลอก loader สำรองแทน")
        notify("Update", "ดึงอัพเดทไม่สำเร็จ (คัดลอก loader สำรอง)")
    end
end

--------------------------------------------------------------------
-- 4) ผูกปุ่ม (ผูก 2 ทาง เผื่อทางใดทางหนึ่งโดน UI กิน)
--------------------------------------------------------------------
local genv = (getgenv and getgenv()) or _G

-- ถ้ารันสคริปต์ซ้ำ ให้เก็บกวาดของรอบเก่าก่อน จะได้ไม่ทำงานซ้อนกัน
if genv.__HelloWorldConnection then
    pcall(function() genv.__HelloWorldConnection:Disconnect() end)
end
pcall(function()
    ContextActionService:UnbindAction("HelloWorldTeleport")
    ContextActionService:UnbindAction("HelloWorldCopy")
end)

local function onHotkey(keyCode)
    -- เช็คแค่ว่ากำลังพิมพ์อยู่รึเปล่า ไม่ใช้ gameProcessed
    -- (gameProcessed = true ตอนมี UI เปิดอยู่ ทำให้ปุ่มไม่ทำงานเฉย ๆ)
    if UserInputService:GetFocusedTextBox() then return end

    if keyCode == CONFIG.TELEPORT_HOTKEY then
        log("กด %s แล้ว", keyCode.Name)
        teleport()
    elseif keyCode == CONFIG.COPY_HOTKEY then
        log("กด %s แล้ว", keyCode.Name)
        copyLatest()
    end
end

genv.__HelloWorldConnection = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        onHotkey(input.KeyCode)
    end
end)

-- ทางสำรอง: CAS มี priority สูงกว่า จับปุ่มได้แม้ตอน UI ของเกมกิน input อยู่
-- (ถ้าทั้งสองทางยิงพร้อมกัน ก็แค่วาปซ้ำที่เดิม ไม่มีผลเสีย)
pcall(function()
    ContextActionService:BindActionAtPriority("HelloWorldTeleport", function(_, state)
        if state == Enum.UserInputState.Begin then
            teleport()
        end
        return Enum.ContextActionResult.Pass
    end, false, 3000, CONFIG.TELEPORT_HOTKEY)
end)

--------------------------------------------------------------------
-- 5) งานหลัก: รันปุ๊บวาปเลย
--------------------------------------------------------------------
print("Hello World")
print(("[TP] v%s พร้อมใช้งาน — %s = คัดลอกสคริปต์ล่าสุด, %s = วาป")
    :format(CONFIG.VERSION, CONFIG.COPY_HOTKEY.Name, CONFIG.TELEPORT_HOTKEY.Name))

task.spawn(teleport)
