# SRP Warranty — คู่มือติดตั้งภาษาไทย

## ใน ZIP นี้มีอะไรบ้าง
- `index.html` — หน้าเว็บลูกค้า: ลงทะเบียนรับประกันและตรวจสอบสถานะ
- `admin.html` — หน้าแอดมิน: เข้าสู่ระบบ ดูรายการลงทะเบียน เพิ่มสินค้า และเพิ่ม Serial
- `config.js` — URL และ Publishable key ของ Supabase
- `manifest.json`, `sw.js` — รองรับติดตั้งเป็น PWA ขั้นพื้นฐาน
- `setup.sql` — สคริปต์ตั้งค่าความปลอดภัยและ RPC ที่ใช้โดยหน้าเว็บ

## สำคัญก่อนเปิดใช้งาน
เว็บนี้เรียกใช้ RPC `srp_register_warranty` และ `srp_check_warranty` จากฐานข้อมูล Supabase โดยตรง ห้ามนำ `sb_secret_` หรือ `service_role` key มาใส่ในไฟล์หน้าเว็บเด็ดขาด

### 1. ตั้งค่าฐานข้อมูล
หากคุณรัน `setup.sql` ใน Supabase แล้วและขึ้น `Success. No rows returned` ให้ข้ามขั้นตอนนี้ได้
หากยังไม่ได้รัน ให้เปิด SQL Editor แล้วรันไฟล์ `setup.sql` ก่อน โดยตรวจสอบว่าโครงสร้างตารางเดิมมีคอลัมน์:
- products: `id`, `name`, `model`, `warranty_months`
- serial_numbers: `id`, `serial_number`, `product_id`
- warranty_registrations: `id`, `serial_id`, `customer_name`, `phone`, `email`, `purchase_date`, `created_at`

สคริปต์นี้สร้าง `admin_users`, ตั้ง RLS/policies, unique indexes และ RPC สำหรับลูกค้า ไม่ได้เปิดสิทธิ์อ่านข้อมูลลูกค้าให้สาธารณะ

### 2. เปิดสิทธิ์แอดมิน
1. ไปที่ Supabase → Authentication → Users แล้วสร้างผู้ใช้แอดมิน (หรือใช้บัญชีที่สร้างไว้แล้ว)
2. คัดลอก UUID ของผู้ใช้นั้น
3. เปิด SQL Editor และรันคำสั่งต่อไปนี้ โดยแทน `ใส่-UUID-ตรงนี้` ด้วย UUID จริง:

```sql
insert into public.admin_users (user_id)
values ('ใส่-UUID-ตรงนี้')
on conflict (user_id) do nothing;
```

ถ้าคุณเพิ่ม UUID ใน `admin_users` ไปแล้ว ไม่ต้องทำซ้ำ

### 3. อัปโหลดขึ้น GitHub Pages
1. แตก ZIP นี้
2. อัปโหลดไฟล์ทั้งหมดในโฟลเดอร์นี้เข้า repository `srp_warranty` (หรือ repository ที่คุณสร้างไว้) ที่ระดับ root — ให้เห็น `index.html` ทันทีเมื่อเปิดหน้า Code
3. ไปที่ Settings → Pages
4. ใน Build and deployment เลือก `Deploy from a branch`
5. เลือก branch `main` และ folder `/ (root)` แล้วกด Save
6. รอให้ GitHub แสดงลิงก์ Pages

หน้าเว็บลูกค้าอยู่ที่ `/` หรือ `/index.html`; หน้าแอดมินอยู่ที่ `/admin.html`

## วิธีทดสอบ
- ใน `serial_numbers` ต้องมี Serial ที่ผูกกับสินค้าอยู่แล้ว
- ลองลงทะเบียน Serial ทดสอบหนึ่งรายการในหน้าเว็บลูกค้า
- ตรวจสอบสถานะด้วย Serial เดียวกัน
- เปิด `/admin.html` แล้วเข้าสู่ระบบด้วยบัญชีที่อยู่ใน `admin_users`

## ข้อควรทราบ
- Publishable key ถูกออกแบบมาให้ใช้ในเบราว์เซอร์ได้ แต่ความปลอดภัยต้องอาศัย RLS และ RPC ที่กำหนดสิทธิ์อย่างเหมาะสม
- หากหน้าแอดมินขึ้นสิทธิ์ไม่พอ ให้ตรวจว่า UUID ใน `admin_users` ตรงกับ `auth.users.id` ของบัญชีที่ล็อกอิน และรัน `setup.sql` ครบแล้ว
- เว็บไซต์ GitHub Pages ต้องเปิดผ่าน HTTPS; การเปิดไฟล์ HTML โดยตรงจากเครื่องอาจไม่ทำงานตามปกติ
