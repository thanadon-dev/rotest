# rotest

สคริปต์ Roblox executor: รันแล้ววาปไปที่ `BorderWall["包围"].Part3` + กด **F6** เพื่อคัดลอกสคริปต์เวอร์ชันล่าสุดลงคลิปบอร์ด

## วิธีใช้

วางบรรทัดนี้ใน executor (ได้ตัวล่าสุดทุกครั้งที่รัน):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/thanadon-dev/rotest/main/HelloWorld.lua"))()
```

## ปุ่ม

| ปุ่ม | ทำอะไร |
|-----|--------|
| `F6` | ดึงโค้ดล่าสุดจาก GitHub raw แล้วคัดลอกลงคลิปบอร์ด |
| `F7` | วาปซ้ำอีกรอบ (ตายแล้วเกิดใหม่ไม่ต้องรันสคริปต์ใหม่) |

## จุดวาป

```
workspace.Assets.MapTemplate.Map.BorderWall["包围"].Part3
```

แก้ปลายทางได้ที่ `CONFIG.TELEPORT_PATH` ใน `HelloWorld.lua` — เป็น list ของชื่อ child ไล่จาก `workspace`
ชื่อจีน `包围` เขียนเป็น byte escape `"\229\140\133\229\155\180"` กันปัญหา encoding ตอน copy/paste

ถ้าหา path ไม่เจอ สคริปต์จะบอกว่าพังตรงชั้นไหน เช่น `หาไม่เจอ: workspace.Assets.MapTemplate -> "Map"`

## อัพเดทสคริปต์

แก้ `HelloWorld.lua` แล้ว push ขึ้น `main` — คนที่กด F6 จะได้ตัวใหม่ทันที
(มี `?nocache=` ต่อท้ายกัน CDN cache ให้แล้ว)

ถ้าเพิ่ม feature ใหม่ อย่าลืมขยับ `CONFIG.VERSION` ด้วย — สคริปต์เทียบเวอร์ชันที่ดึงมากับที่รันอยู่
แล้วแจ้งว่า "คัดลอกเวอร์ชันใหม่ x.x.x แล้ว"

## ไฟล์

- `HelloWorld.lua` — สคริปต์หลัก
- `loader.lua` — บรรทัดเดียวสำหรับ paste ใน executor
