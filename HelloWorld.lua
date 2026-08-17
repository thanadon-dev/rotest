--[[
    Hello World + Teleport Script (Roblox Executor)
    -----------------------------------------------
    - รันแล้ววาปไปที่ workspace.Assets.MapTemplate.Map.BorderWall["包围"].Part3
    - กด F6 = ดึงสคริปต์ "เวอร์ชันล่าสุด" จาก SOURCE_URL แล้วคัดลอกลงคลิปบอร์ด
    - กด F7 = วาปซ้ำอีกรอบ (เผื่อตายแล้วเกิดใหม่ ไม่ต้องรันสคริปต์ใหม่)
--]]

local CONFIG = {
    VERSION = "1.1.0",

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
    TELEPORT_OFFSET = Vector3.new(0, 5, 0), -- ยกขึ้นเหนือ part กันจมพื้น
    WAIT_TIMEOUT = 10, -- วินาที รอ instance โผล่ (เผื่อ map ยัง stream ไม่เสร็จ)

    COPY_HOTKEY = Enum.KeyCode.F6,
    TELEPORT_HOTKEY = Enum.KeyCode.F7,
    NOTIFY = true, -- แจ้งเตือนมุมขวาบน
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
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

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
            return nil, ("หาไม่เจอ: %s -> %q"):format(walked, name)
        end
        node = child
        walked = walked .. "." .. name
    end
    return node
end

local function getTargetCFrame(target)
    if target:IsA("BasePart") then
        return target.CFrame
    elseif target:IsA("Model") then
        return target:GetPivot()
    elseif target:IsA("Attachment") then
        return target.WorldCFrame
    end
    return nil
end

local function teleport()
    local character = LocalPlayer.Character
    if not character then
        character = LocalPlayer.CharacterAdded:Wait()
    end

    local root = character:FindFirstChild("HumanoidRootPart")
        or character:WaitForChild("HumanoidRootPart", CONFIG.WAIT_TIMEOUT)
    if not root then
        warn("[Teleport] ไม่เจอ HumanoidRootPart (ตัวละครยังโหลดไม่เสร็จ?)")
        notify("Teleport", "ไม่เจอ HumanoidRootPart")
        return false
    end

    local target, err = resolvePath(workspace, CONFIG.TELEPORT_PATH, CONFIG.WAIT_TIMEOUT)
    if not target then
        warn("[Teleport] " .. err)
        notify("Teleport ล้มเหลว", err)
        return false
    end

    local cf = getTargetCFrame(target)
    if not cf then
        local msg = ("%s เป็น %s ไม่มีตำแหน่งให้วาป"):format(target.Name, target.ClassName)
        warn("[Teleport] " .. msg)
        notify("Teleport ล้มเหลว", msg)
        return false
    end

    -- เคลียร์ความเร็วก่อน กันโดนเหวี่ยง (fling) ตอนวาป
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    character:PivotTo(cf + CONFIG.TELEPORT_OFFSET)

    local pos = cf.Position
    print(("[Teleport] วาปไปที่ %s แล้ว (%.1f, %.1f, %.1f)")
        :format(target:GetFullName(), pos.X, pos.Y, pos.Z))
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
-- 4) ผูกปุ่ม
--------------------------------------------------------------------
-- ถ้ารันสคริปต์ซ้ำ ให้ตัดการเชื่อมต่อของรอบเก่าก่อน จะได้ไม่ทำงานซ้อนกัน
local genv = (getgenv and getgenv()) or _G
if genv.__HelloWorldConnection then
    pcall(function() genv.__HelloWorldConnection:Disconnect() end)
end

genv.__HelloWorldConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.COPY_HOTKEY then
        copyLatest()
    elseif input.KeyCode == CONFIG.TELEPORT_HOTKEY then
        teleport()
    end
end)

--------------------------------------------------------------------
-- 5) งานหลัก: รันปุ๊บวาปเลย
--------------------------------------------------------------------
print("Hello World")
print(("[HelloWorld] v%s พร้อมใช้งาน — %s = คัดลอกสคริปต์ล่าสุด, %s = วาปซ้ำ")
    :format(CONFIG.VERSION, CONFIG.COPY_HOTKEY.Name, CONFIG.TELEPORT_HOTKEY.Name))

task.spawn(teleport)
