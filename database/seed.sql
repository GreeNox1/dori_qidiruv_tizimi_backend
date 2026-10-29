-- 1. Rollar
INSERT INTO roles (id, name) VALUES 
(1, 'admin'),
(2, 'pharmacist'),
(3, 'user')
ON CONFLICT (id) DO NOTHING;

-- 2. Foydalanuvchilar (Bcrypt hesh: admin12345, pharm12345, user12345)
INSERT INTO users (id, full_name, email, password_hash, phone, role_id) VALUES
(1, 'Tizim Administratori', 'admin@pharma.uz', '$2a$10$mrmKvFcq8QUWEmS5TDNmy.fSZB18abuJxyt9VENVqGsy..D18NKAy', '+998 90 111-22-33', 1),
(2, 'Sardor Aliyev (Farmatsevt)', 'pharmacist@pharma.uz', '$2a$10$CGCr8k9fjnxqaTJIEcqb8OmvhHTqG/TmT2kHOagowYfJ3sEoPRAs6', '+998 90 444-55-66', 2),
(3, 'Anvar Karimov (Mijoz)', 'client@pharma.uz', '$2a$10$YhJ7PAewbIKYpcCH98sEW.WWf9LCwVcbe3z35sGU6f.WDJrl5hUVS', '+998 90 777-88-99', 3)
ON CONFLICT (id) DO NOTHING;

-- 3. Dorixonalar va filiallar
INSERT INTO pharmacies (id, name, phone) VALUES
(1, 'Grand Pharm', '+998 71 200-00-01'),
(2, 'OxyMed', '+998 71 200-00-02'),
(3, 'Best Pharmacy', '+998 71 200-00-03')
ON CONFLICT (id) DO NOTHING;

INSERT INTO branches (id, pharmacy_id, name, district, address, landmark, phone, working_hours) VALUES
(1, 1, 'Chilonzor filiali', 'Chilonzor', 'Chilonzor 9-mavze, 12-uy', 'Rayhon milliy taomlari ro‘parasi', '+998 71 200-00-01', '08:00 - 23:00'),
(2, 2, 'Yunusobod filiali', 'Yunusobod', 'Amir Temur shox ko‘chasi, 45-uy', 'Megaplanet savdo majmuasi yonida', '+998 71 200-00-02', '24/7 (Kun-u tun)'),
(3, 3, 'Mirzo Ulug‘bek filiali', 'Mirzo Ulug‘bek', 'Buyuk Ipak Yo‘li ko‘chasi, 102-uy', 'Buyuk Ipak Yo‘li metro bekati', '+998 71 200-00-03', '08:00 - 22:00')
ON CONFLICT (id) DO NOTHING;

-- Farmatsevtni 1-filialga biriktirish
INSERT INTO branch_staff (user_id, branch_id) VALUES (2, 1) ON CONFLICT DO NOTHING;

-- 4. Dorilar
INSERT INTO drugs (id, trade_name, inn_name, form, dosage, manufacturer, prescription_required, indications, dosage_instructions, contraindications, storage_conditions) VALUES
(1, 'PARATSETAMOL', 'Paracetamol', 'Tabletka', '500 mg', 'Farmak, Ukraina', FALSE, 'Isitma va og‘riq sindromi', '1-2 tabletka kuniga 4 mahal', 'Jigar yetishmovchiligi', '25°C gacha'),
(2, 'IBUPROFEN', 'Ibuprofen', 'Tabletka', '400 mg', 'Borisov, Belarus', FALSE, 'Og‘riq qoldiruvchi, shamollashga qarshi', '1 tabletkadan 3 mahal', 'Oshqozon yarasi', '25°C gacha'),
(3, 'KARDIOMAGNIL', 'Acetylsalicylic acid', 'Tabletka', '75 mg', 'Takeda, Yaponiya', FALSE, 'Yurak-qon tomir kasalliklari profilaktikasi', 'Kuniga 1 tabletka', 'Astma, oshqozon qon ketishi', 'Yorug‘likdan himoyalangan'),
(4, 'SITRAMON P', 'Paracetamol + Acetylsalicylic acid + Caffeine', 'Tabletka', 'Standart', 'Nobel Pharmsanoat', FALSE, 'Bosh og‘rig‘i va migren', '1 tabletkadan 2-3 mahal', 'Oshqozon yarasi', 'Quruq joyda')
ON CONFLICT (id) DO NOTHING;

-- 5. Inventar (narx va qoldiq)
INSERT INTO branch_inventory (branch_id, drug_id, price, quantity, is_available) VALUES
(1, 1, 4200.00, 24, TRUE),
(2, 1, 4500.00, 15, TRUE),
(3, 1, 5000.00, 32, TRUE),
(1, 2, 7500.00, 18, TRUE),
(2, 2, 8200.00, 12, TRUE),
(1, 3, 18500.00, 30, TRUE),
(2, 3, 19500.00, 22, TRUE),
(3, 3, 21000.00, 14, TRUE)
ON CONFLICT DO NOTHING;

SELECT setval('roles_id_seq', (SELECT COALESCE(MAX(id), 1) FROM roles));
SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 1) FROM users));
SELECT setval('pharmacies_id_seq', (SELECT COALESCE(MAX(id), 1) FROM pharmacies));
SELECT setval('branches_id_seq', (SELECT COALESCE(MAX(id), 1) FROM branches));
SELECT setval('drugs_id_seq', (SELECT COALESCE(MAX(id), 1) FROM drugs));
SELECT setval('branch_inventory_id_seq', (SELECT COALESCE(MAX(id), 1) FROM branch_inventory));
