# rotest

สคริปต์ Roblox executor: print `Hello World` + กด **F6** เพื่อคัดลอกสคริปต์เวอร์ชันล่าสุดลงคลิปบอร์ด

## วิธีใช้

วางบรรทัดนี้ใน executor (ได้ตัวล่าสุดทุกครั้งที่รัน):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/thanadon-dev/rotest/main/HelloWorld.lua"))()
```

## ปุ่ม

| ปุ่ม | ทำอะไร |
|-----|--------|
| `F6` | ดึงโค้ดล่าสุดจาก GitHub raw แล้วคัดลอกลงคลิปบอร์ด |

## อัพเดทสคริปต์

แก้ `HelloWorld.lua` แล้ว push ขึ้น `main` — คนที่กด F6 จะได้ตัวใหม่ทันที
(มี `?nocache=` ต่อท้ายกัน CDN cache ให้แล้ว)

ถ้าเพิ่ม feature ใหม่ อย่าลืมขยับ `CONFIG.VERSION` ด้วย — สคริปต์เทียบเวอร์ชันที่ดึงมากับที่รันอยู่
แล้วแจ้งว่า "คัดลอกเวอร์ชันใหม่ x.x.x แล้ว"

## ไฟล์

- `HelloWorld.lua` — สคริปต์หลัก
- `loader.lua` — บรรทัดเดียวสำหรับ paste ใน executor
