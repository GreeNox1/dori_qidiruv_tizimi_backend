# PharmaSearch — Dart Backend API (`pharma_server`)

«PharmaSearch» (Dori qidiruv va dorixonalar boshqaruv tizimi) uchun ishlab chiqilgan Dart Shelf va PostgreSQL asosidagi REST API backend xizmati.

---

## 🛠 Texnologiyalar
* **Til:** Dart 3.13+ (Shelf, Shelf Router)
* **Ma’lumotlar bazasi:** PostgreSQL 15+ (`postgres: ^3.5.x`)
* **Xavfsizlik:** Bcrypt (`bcrypt: ^1.2.x`), JWT (`dart_jsonwebtoken: ^3.4.x`)
* **Konteynerlash:** Docker & Docker Compose

---

## 📂 Loyiha Strukturasi
```text
├── bin/
│   └── server.dart                   # Serverning asosiy kirish nuqtasi (Entrypoint)
├── lib/
│   ├── config/
│   │   ├── env_config.dart           # .env konfiguratsiyasi
│   │   └── database.dart             # PostgreSQL Connection Pool singleton
│   ├── middleware/
│   │   ├── cors_middleware.dart       # CORS (Flutter Web uchun)
│   │   ├── auth_middleware.dart       # JWT token o'qish va tekshirish
│   │   └── role_guard.dart            # RBAC (Admin, Pharmacist rollari)
│   ├── modules/
│   │   ├── auth/                      # Login, Register, Me
│   │   ├── drugs/                     # Qidiruv, Pasport, Narxlar, Analoglar
│   │   ├── favorites/                 # Sevimlilar ro'yxati va toggle
│   │   ├── pharmacist/                # Farmatsevt: filial va ombor inventari
│   │   └── admin/                     # Admin: statistika, dori CRUD, filiallar
│   └── utils/
│       ├── response_helper.dart       # Standart JSON javob formatlari
│       └── password_hasher.dart       # Bcrypt shifrlash
├── database/
│   ├── schema.sql                    # 8 ta PostgreSQL jadvali va indekslar
│   └── seed.sql                      # Boshlang'ich test ma'lumotlari
├── test/
│   └── unit_test.dart                # Unit testlar
├── docker-compose.yml                # PostgreSQL konteyneri
└── .env                              # Muhit o'zgaruvchilari
```

---

## 🚀 Ishga Tushirish Qo‘llanmasi

### 1. Ma’lumotlar bazasini ko‘tarish (Docker orqali):
```bash
docker-compose up -d
```
Bu buyruq PostgreSQL 15 konteynerini ishga tushiradi va avtomatik ravishda `database/schema.sql` hamda `database/seed.sql` ni yuklaydi.

### 2. Backend serverni ishga tushirish:
```bash
dart pub get
dart run bin/server.dart
```

Server odatiy holatda `http://localhost:8080` portida ishga tushadi.

---

## 🔑 Boshlang‘ich Test Foydalanuvchilari (Seed):
* **Admin:** `admin@pharma.uz` / `admin12345` (Roli: `admin`)
* **Farmatsevt:** `pharmacist@pharma.uz` / `pharm12345` (Roli: `pharmacist`, Filial: `1`)
* **Mijoz:** `client@pharma.uz` / `user12345` (Roli: `user`)

---

## 📡 REST API Endpointlari

| Modul | Metod | Endpoint | Ruxsat | Tavsif |
| :--- | :--- | :--- | :--- | :--- |
| **Tizim** | `GET` | `/health` | Ochiq | Server holati |
| **Auth** | `POST` | `/api/v1/auth/login` | Ochiq | Tizimga kirish (JWT olish) |
| **Auth** | `POST` | `/api/v1/auth/register` | Ochiq | Ro‘yxatdan o‘tish |
| **Auth** | `GET` | `/api/v1/auth/me` | User, Pharm, Admin | Joriy foydalanuvchi ma’lumoti |
| **Drugs** | `GET` | `/api/v1/drugs/search` | Ochiq | Dori nomi/INN qidiruv, filtr |
| **Drugs** | `GET` | `/api/v1/drugs/:id` | Ochiq | Dori pasporti va yo‘riqnoma |
| **Drugs** | `GET` | `/api/v1/drugs/:id/prices` | Ochiq | Dorixonalar narxlari jadvali |
| **Drugs** | `GET` | `/api/v1/drugs/:id/analogs` | Ochiq | Bir xil INN bo‘lgan muqobillar |
| **Favorites** | `GET` | `/api/v1/favorites` | User, Pharm, Admin | Sevimlilar ro‘yxati |
| **Favorites** | `POST` | `/api/v1/favorites/toggle` | User, Pharm, Admin | Sevimlilarga qo‘shish/o‘chirish |
| **Pharmacist** | `GET` | `/api/v1/pharmacist/branch` | Pharmacist, Admin | Farmatsevt filiali ma’lumoti |
| **Pharmacist** | `PUT` | `/api/v1/pharmacist/branch` | Pharmacist, Admin | Filial ma’lumotini yangilash |
| **Pharmacist** | `GET` | `/api/v1/pharmacist/inventory` | Pharmacist, Admin | Filial ombor qoldiqlari |
| **Pharmacist** | `POST` | `/api/v1/pharmacist/inventory` | Pharmacist, Admin | Filial omboriga dori kiritish |
| **Pharmacist** | `PUT` | `/api/v1/pharmacist/inventory/:id` | Pharmacist, Admin | Narx va qoldiqni o‘zgartirish |
| **Pharmacist** | `DELETE` | `/api/v1/pharmacist/inventory/:id` | Pharmacist, Admin | Ombor yozuvini o‘chirish |
| **Admin** | `GET` | `/api/v1/admin/dashboard` | Admin | Boshqaruv statistikasi |
| **Admin** | `POST` | `/api/v1/admin/drugs` | Admin | Dori katalogiga yangi dori |
| **Admin** | `PUT` | `/api/v1/admin/drugs/:id` | Admin | Dori ma’lumotini tahrirlash |
| **Admin** | `DELETE` | `/api/v1/admin/drugs/:id` | Admin | Dorini katalogdan o‘chirish |
| **Admin** | `GET` | `/api/v1/admin/branches` | Admin | Filiallar va biriktirilgan xodimlar |
| **Admin** | `POST` | `/api/v1/admin/branches` | Admin | Yangi filial yaratish |
| **Admin** | `PATCH` | `/api/v1/admin/branches/:id/status` | Admin | Filialni faollashtirish/bloklash |
