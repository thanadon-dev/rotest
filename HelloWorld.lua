--[[
    Hello World Script (Roblox Executor)
    -----------------------------------
    - รันแล้ว print("Hello World") ออกมาที่ console (F9 / executor console)
    - กด F6 = ดึงสคริปต์ "เวอร์ชันล่าสุด" จาก SOURCE_URL แล้วคัดลอกลงคลิปบอร์ด
      ถ้าดึงไม่ได้ (ไม่มีเน็ต / ไม่ได้ตั้ง URL) จะคัดลอกโค้ดที่ฝังไว้ในตัวแทน
--]]

local CONFIG = {
    VERSION = "1.0.0",

    -- ลิงก์ raw ของสคริปต์ตัวเอง (แก้โค้ดบน GitHub แล้วกด F6 จะได้ตัวล่าสุดทันที)
    SOURCE_URL = "https://raw.githubusercontent.com/thanadon-dev/rotest/main/HelloWorld.lua",

    HOTKEY = Enum.KeyCode.F6,
    NOTIFY = true, -- แจ้งเตือนมุมขวาบนเวลาคัดลอกสำเร็จ
}

-- โค้ดสำรอง ใช้ตอนดึงจาก URL ไม่ได้
local FALLBACK_SOURCE = [==[
print("Hello World")
]==]

--------------------------------------------------------------------
-- 1) งานหลัก: print Hello World
--------------------------------------------------------------------
print("Hello World")

--------------------------------------------------------------------
-- 2) ตัวช่วย
--------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

-- executor แต่ละตัวตั้งชื่อฟังก์ชันคลิปบอร์ดไม่เหมือนกัน หาอันที่มี
local function getClipboardFn()
    local fn = setclipboard
        or toclipboard
        or set_clipboard
        or (syn and syn.write_clipboard)
        or (Clipboard and Clipboard.set)
        or (getgenv and getgenv().setclipboard)
    return fn
end

-- HttpGet ก็เช่นกัน
local function httpGet(url)
    local ok, res = pcall(function()
        if syn and syn.request then
            local r = syn.request({ Url = url, Method = "GET" })
            return r.Body
        elseif request then
            local r = request({ Url = url, Method = "GET" })
            return r.Body
        elseif http_request then
            local r = http_request({ Url = url, Method = "GET" })
            return r.Body
        else
            return game:HttpGet(url, true)
        end
    end)
    if ok and type(res) == "string" and #res > 0 then
        return res
    end
    return nil, tostring(res)
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

--------------------------------------------------------------------
-- 3) ดึงสคริปต์ล่าสุด + คัดลอก
--------------------------------------------------------------------
local function copyLatest()
    local clipboard = getClipboardFn()
    if not clipboard then
        warn("[HelloWorld] executor นี้ไม่รองรับ setclipboard")
        notify("Hello World", "executor ไม่รองรับ setclipboard")
        return
    end

    local source, err
    if CONFIG.SOURCE_URL ~= "" then
        -- กัน cache ของ GitHub/CDN เพื่อให้ได้เวอร์ชันล่าสุดจริง ๆ
        local sep = CONFIG.SOURCE_URL:find("?") and "&" or "?"
        local url = CONFIG.SOURCE_URL .. sep .. "nocache=" .. tostring(tick())
        source, err = httpGet(url)
    end

    if source then
        clipboard(source)
        local ver = source:match('VERSION%s*=%s*"([^"]+)"')
        if ver and ver ~= CONFIG.VERSION then
            print(("[HelloWorld] คัดลอกเวอร์ชันล่าสุดแล้ว: %s (ที่รันอยู่ %s)"):format(ver, CONFIG.VERSION))
            notify("Hello World", "คัดลอกเวอร์ชันใหม่ " .. ver .. " แล้ว")
        else
            print("[HelloWorld] คัดลอกสคริปต์ล่าสุดลงคลิปบอร์ดแล้ว (" .. #source .. " ตัวอักษร)")
            notify("Hello World", "คัดลอกสคริปต์ล่าสุดแล้ว")
        end
    else
        clipboard(FALLBACK_SOURCE)
        if CONFIG.SOURCE_URL == "" then
            warn("[HelloWorld] ยังไม่ได้ตั้ง SOURCE_URL — คัดลอกโค้ดสำรองแทน")
            notify("Hello World", "ยังไม่ได้ตั้ง SOURCE_URL (คัดลอกโค้ดสำรอง)")
        else
            warn("[HelloWorld] ดึงจาก URL ไม่สำเร็จ: " .. tostring(err) .. " — คัดลอกโค้ดสำรองแทน")
            notify("Hello World", "ดึงอัพเดทไม่สำเร็จ (คัดลอกโค้ดสำรอง)")
        end
    end
end

--------------------------------------------------------------------
-- 4) ผูกปุ่ม F6
--------------------------------------------------------------------
-- ถ้ารันสคริปต์ซ้ำ ให้ตัดการเชื่อมต่อของรอบเก่าก่อน จะได้ไม่ทำงานซ้อนกัน
local genv = (getgenv and getgenv()) or _G
if genv.__HelloWorldConnection then
    pcall(function() genv.__HelloWorldConnection:Disconnect() end)
end

genv.__HelloWorldConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.HOTKEY then
        copyLatest()
    end
end)

print(("[HelloWorld] v%s พร้อมใช้งาน — กด %s เพื่อคัดลอกสคริปต์ล่าสุด")
    :format(CONFIG.VERSION, CONFIG.HOTKEY.Name))
