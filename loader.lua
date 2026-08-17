-- วางบรรทัดนี้ใน executor ก็พอ จะดึงตัวล่าสุดจาก GitHub มารันทุกครั้ง
loadstring(game:HttpGet("https://raw.githubusercontent.com/thanadon-dev/rotest/main/HelloWorld.lua?nocache=" .. tostring(tick())))()
