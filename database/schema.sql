-- 1. ROLLARI (admin, pharmacist, user)
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE
);

-- 2. FOYDALANUVCHILAR (Admin, Farmatsevt, Mijozlar)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    role_id INT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    is_blocked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. DORIXONALAR TARMOG'I (Brendlar)
CREATE TABLE IF NOT EXISTS pharmacies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    phone VARCHAR(20)
);

-- 4. DORIXONA FILIALLARI (Xaritasiz, matnli manzillar)
CREATE TABLE IF NOT EXISTS branches (
    id SERIAL PRIMARY KEY,
    pharmacy_id INT NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    landmark VARCHAR(150),
    phone VARCHAR(20) NOT NULL,
    working_hours VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. FILIAL XODIMLARI (Farmatsevtni filialga biriktirish)
CREATE TABLE IF NOT EXISTS branch_staff (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    branch_id INT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_branch UNIQUE (user_id, branch_id)
);

-- 6. DORI VOSITALARI VA BATAFSIL YO'RIQNOMASI
CREATE TABLE IF NOT EXISTS drugs (
    id SERIAL PRIMARY KEY,
    trade_name VARCHAR(150) NOT NULL,
    inn_name VARCHAR(150) NOT NULL,
    form VARCHAR(50) NOT NULL,
    dosage VARCHAR(50),
    manufacturer VARCHAR(100),
    prescription_required BOOLEAN DEFAULT FALSE,
    indications TEXT,
    dosage_instructions TEXT,
    contraindications TEXT,
    storage_conditions VARCHAR(150),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. FILIAL OMBOZ QOLDIG'I VA SOTUV NARXI (M:N branches <-> drugs)
CREATE TABLE IF NOT EXISTS branch_inventory (
    id SERIAL PRIMARY KEY,
    branch_id INT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    drug_id INT NOT NULL REFERENCES drugs(id) ON DELETE RESTRICT,
    price NUMERIC(12, 2) NOT NULL CHECK (price > 0),
    quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    is_available BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_branch_drug UNIQUE (branch_id, drug_id)
);

-- 8. MIJOZNING SEVIMLI DORILARI (M:N users <-> drugs)
CREATE TABLE IF NOT EXISTS saved_drugs (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    drug_id INT NOT NULL REFERENCES drugs(id) ON DELETE CASCADE,
    saved_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_drug UNIQUE (user_id, drug_id)
);

-- TEZKOR QIDIRUV VA UNUMDORLIK UCHUN INDEKSLAR
CREATE INDEX IF NOT EXISTS idx_drugs_trade_name ON drugs (LOWER(trade_name));
CREATE INDEX IF NOT EXISTS idx_drugs_inn_name ON drugs (LOWER(inn_name));
CREATE INDEX IF NOT EXISTS idx_branches_district ON branches (district);
CREATE INDEX IF NOT EXISTS idx_inventory_lookup ON branch_inventory (drug_id, is_available, price);
CREATE INDEX IF NOT EXISTS idx_saved_drugs_user ON saved_drugs (user_id);
