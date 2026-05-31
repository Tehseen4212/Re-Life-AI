-- ==========================================
-- RELIFE AI: FINAL MASTER DATABASE SCHEMA (V10 - NOTIFICATION SYSTEM)
-- Includes Multi-Product Storage Bin Sync + Dynamic IoT Triggers
-- Added 3-Day Auto-Cleanup Support + Real-time Alerts
-- ==========================================

-- 1. Enable UUID extension for auto-generating IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Table: users (Store Owners & NGOs)
create table if not exists public.users (
  id uuid references auth.users(id) on delete cascade primary key,
  email text unique not null,
  role text check(role in ('store_owner', 'ngo')) not null,
  store_name text,
  contact_number text,
  location_address text,
  google_map_url text,
  about_store text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.users enable row level security;
create policy "Users can view all public profiles" on public.users for select using (true);
create policy "Users can insert their own profile" on public.users for insert with check (auth.uid() = id);
create policy "Users can update their own profile" on public.users for update using (auth.uid() = id);

-- 3. NEW FEATURE: storage_bins (Super IDs for IoT Hardware)
CREATE TABLE IF NOT EXISTS public.storage_bins (
    id uuid default uuid_generate_v4() primary key,
    store_owner_id uuid references public.users(id) on delete cascade not null,
    storage_no text not null,
    UNIQUE(store_owner_id, storage_no)
);
ALTER TABLE public.storage_bins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Store owners manage their bins" ON public.storage_bins FOR ALL USING (auth.uid() = store_owner_id);

-- 4. Table: products (Inventory Tracking with IoT Data and Storage Bin Location)
create table if not exists public.products (
  id uuid default uuid_generate_v4() primary key,
  store_owner_id uuid references public.users(id) on delete cascade not null,
  name text not null,
  category text not null,
  quantity integer not null default 0,
  price numeric default 0,
  barcode text,
  status text check(status in ('active', 'offered', 'donated', 'sold', 'expired')) default 'active' not null,
  entry_date timestamp with time zone default timezone('utc'::text, now()) not null,
  
  -- Dynamic Mode
  shelf_life_days integer,
  mfg_date timestamp with time zone,
  expiry_date timestamp with time zone,
  
  -- Hardware Connection Link (Auto-Synced via Storage_No)
  storage_no text,
  
  freshness_score numeric,
  risk_score numeric,
  temperature numeric default 0,
  humidity numeric default 0,
  env_risk numeric default 0,
  status_updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.products enable row level security;
create policy "Store owners can view their products" on public.products for select using (auth.uid() = store_owner_id);
create policy "NGOs can view products marked for donation" on public.products for select using (
  status in ('donated', 'offered') and exists (
    select 1 from public.users where id = auth.uid() and role = 'ngo'
  )
);
create policy "Store owners can insert products" on public.products for insert with check (auth.uid() = store_owner_id);
create policy "Store owners can update their products" on public.products for update using (auth.uid() = store_owner_id);
create policy "Store owners can delete their products" on public.products for delete using (auth.uid() = store_owner_id);

-- 4.5. Auto-Create Bins Trigger (To automatically give hardware "Super IDs" effortlessly)
CREATE OR REPLACE FUNCTION auto_manage_storage_bins() RETURNS trigger SECURITY DEFINER AS $$
BEGIN
  IF NEW.storage_no IS NOT NULL AND NEW.storage_no != '' THEN
    INSERT INTO public.storage_bins (store_owner_id, storage_no)
    VALUES (NEW.store_owner_id, NEW.storage_no)
    ON CONFLICT (store_owner_id, storage_no) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_product_storage_upsert ON public.products;
CREATE TRIGGER after_product_storage_upsert
  AFTER INSERT OR UPDATE OF storage_no ON public.products
  FOR EACH ROW EXECUTE FUNCTION auto_manage_storage_bins();


-- 5. NEW: storage_telemetry_logs (Super ID Live Sync endpoint for ESP32/Hardware)
CREATE TABLE IF NOT EXISTS public.storage_telemetry_logs (
    id uuid default uuid_generate_v4() primary key,
    storage_bin_id uuid references public.storage_bins(id) on delete cascade not null,
    temperature numeric not null,
    humidity numeric not null,
    recorded_at timestamp with time zone default timezone('utc'::text, now()) not null
);
ALTER TABLE public.storage_telemetry_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Hardware writes storage telemetry logs freely" ON public.storage_telemetry_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Owners view logs" ON public.storage_telemetry_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.storage_bins WHERE storage_bins.id = storage_telemetry_logs.storage_bin_id AND storage_bins.store_owner_id = auth.uid())
);

-- 6. LEGACY: sensor_logs (Still active solely for receiving ML Image Analytics Data targeting individual products)
CREATE TABLE IF NOT EXISTS public.sensor_logs (
    id uuid default uuid_generate_v4() primary key,
    product_id uuid references public.products(id) on delete cascade not null,
    temperature numeric not null default 0,
    humidity numeric not null default 0,
    env_risk numeric not null default 0,
    freshness_score numeric,
    photo_urls text[],
    recorded_at timestamp with time zone default timezone('utc'::text, now()) not null
);
ALTER TABLE public.sensor_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Store owners can view their sensor logs" ON public.sensor_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.products WHERE products.id = sensor_logs.product_id AND products.store_owner_id = auth.uid())
);
CREATE POLICY "System/Hardware can insert sensor logs" ON public.sensor_logs FOR INSERT WITH CHECK (true);

-- 7. RISK CORE FUNCTION
CREATE OR REPLACE FUNCTION calculate_env_risk(t numeric, h numeric, cat text) RETURNS numeric AS $$
DECLARE
  risk numeric := 0.0;
BEGIN
  IF t IS NULL OR h IS NULL THEN RETURN 0.0; END IF;
  
  IF cat = 'Dairy' THEN
    IF t > 6 THEN risk := risk + 40; END IF;
    IF t > 10 THEN risk := risk + 40; END IF;
    IF t < 0 THEN risk := risk + 20; END IF;
  ELSIF cat = 'Meat' THEN
    IF t > 4 THEN risk := risk + 50; END IF;
    IF t > 8 THEN risk := risk + 50; END IF;
    IF t < -2 THEN risk := risk + 20; END IF;
  ELSIF cat = 'Produce' OR cat = 'Vegetables' THEN
    IF t > 15 THEN risk := risk + 30; END IF;
    IF h < 50 THEN risk := risk + 30; END IF;
    IF h > 90 AND t > 20 THEN risk := risk + 50; END IF;
  ELSIF cat = 'Medicine' THEN
    IF t > 25 THEN risk := risk + 50; END IF;
    IF t > 30 THEN risk := risk + 50; END IF;
    IF h > 65 THEN risk := risk + 30; END IF;
  ELSIF cat = 'Bakery' THEN
    IF h > 60 THEN risk := risk + 40; END IF;
    IF t > 30 THEN risk := risk + 20; END IF;
  ELSE
    IF t < 2 OR t > 15 THEN risk := risk + 40; END IF;
    IF h < 40 OR h > 90 THEN risk := risk + 30; END IF;
  END IF;

  IF risk > 100 THEN RETURN 100.0; END IF;
  RETURN risk;
END;
$$ LANGUAGE plpgsql;

-- 8. THE NEW MULTI-PRODUCT SYNC TRIGGER (Updates ALL products at once from one Hardware ID)
CREATE OR REPLACE FUNCTION process_storage_telemetry() RETURNS trigger SECURITY DEFINER AS $$
DECLARE
    bin_owner uuid;
    bin_no text;
BEGIN
    SELECT store_owner_id, storage_no INTO bin_owner, bin_no
    FROM public.storage_bins WHERE id = NEW.storage_bin_id;

    IF bin_no IS NULL THEN RETURN NEW; END IF;

    -- 1. Pehle Direct Pura Database ka Products Update kardo (Important for Live UI Mapping!)
    UPDATE public.products
    SET 
        temperature = NEW.temperature,
        humidity = NEW.humidity
    WHERE store_owner_id = bin_owner AND storage_no = bin_no;

    -- 2. Uiske Baad Purane UI ko Support Dene ke liye Sensor Graphs ka Snapshot Store kar do
    INSERT INTO public.sensor_logs (product_id, temperature, humidity, env_risk)
    SELECT id, NEW.temperature, NEW.humidity, 0
    FROM public.products
    WHERE store_owner_id = bin_owner AND storage_no = bin_no;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_storage_telemetry_insert ON public.storage_telemetry_logs;
CREATE TRIGGER on_storage_telemetry_insert
  BEFORE INSERT ON public.storage_telemetry_logs
  FOR EACH ROW EXECUTE FUNCTION process_storage_telemetry();

-- 9. STANDALONE PRODUCT UPDATE SYNC (Fires automatically when the above trigger updates products)
CREATE OR REPLACE FUNCTION on_product_update() RETURNS trigger SECURITY DEFINER AS $$
BEGIN
  -- Track status change timestamp for 3-day cleanup logic
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_updated_at := timezone('utc'::text, now());
  END IF;

  IF NEW.temperature IS DISTINCT FROM OLD.temperature OR NEW.humidity IS DISTINCT FROM OLD.humidity THEN
    NEW.env_risk := calculate_env_risk(NEW.temperature, NEW.humidity, NEW.category);
  END IF;

  IF NEW.freshness_score IS NOT NULL THEN
    NEW.risk_score := 1.0 - NEW.freshness_score;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_product_update_trigger ON public.products;
CREATE TRIGGER on_product_update_trigger
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION on_product_update();

-- 10. Table: donations 
create table if not exists public.donations (
  id uuid default uuid_generate_v4() primary key,
  product_id uuid references public.products(id) on delete cascade not null,
  store_owner_id uuid references public.users(id) on delete cascade not null,
  ngo_id uuid references public.users(id) on delete cascade,
  request_type text check(request_type in ('donation', 'offer')) default 'donation',
  status text check(status in ('pending', 'claimed', 'completed', 'rejected')) default 'pending' not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.donations enable row level security;
create policy "Participants can view their donations" on public.donations for select using (
  auth.uid() = store_owner_id or auth.uid() = ngo_id or 
  (status = 'pending' and exists (
    select 1 from public.users where id = auth.uid() and role = 'ngo'
  ))
);
create policy "Store owners can insert donations" on public.donations for insert with check (auth.uid() = store_owner_id);
create policy "NGOs can update donations (accept/reject)" on public.donations for update using (
  exists (select 1 from public.users where id = auth.uid() and role = 'ngo')
);
create policy "Store Owners can manage tracking statuses" on public.donations for update using (auth.uid() = store_owner_id);

CREATE POLICY "NGOs can view history products" ON public.products FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.donations 
    WHERE donations.product_id = products.id AND donations.ngo_id = auth.uid()
  )
);

-- 11. NEW: notifications
create table if not exists public.notifications (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.users(id) on delete cascade not null,
  title text not null,
  message text not null,
  type text check(type in ('CLAIM', 'EXPIRY', 'SYSTEM')) not null,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);
alter table public.notifications enable row level security;
create policy "Users can manage their own notifications" on public.notifications for all using (auth.uid() = user_id);

-- 12. Trigger: Notify Store Owner on NGO Claim
CREATE OR REPLACE FUNCTION notify_on_donation_claim() RETURNS trigger SECURITY DEFINER AS $$
DECLARE
    p_name text;
    ngo_name text;
BEGIN
    IF NEW.status = 'claimed' AND OLD.status = 'pending' THEN
        SELECT name INTO p_name FROM public.products WHERE id = NEW.product_id;
        SELECT store_name INTO ngo_name FROM public.users WHERE id = NEW.ngo_id;
        
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            NEW.store_owner_id, 
            'Donation Claimed!', 
            ngo_name || ' has claimed your donation of ' || p_name || '. Please arrange the handover.',
            'CLAIM'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_notify_on_donation_claim ON public.donations;
CREATE TRIGGER tr_notify_on_donation_claim
    AFTER UPDATE ON public.donations
    FOR EACH ROW EXECUTE FUNCTION notify_on_donation_claim();


-- 13. ENABLE LIVE STREAMS & FULL REPLICA RECORD SYNC
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
ALTER PUBLICATION supabase_realtime ADD TABLE public.sensor_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.donations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.donations REPLICA IDENTITY FULL;

-- 14. STORAGE BUCKETS (V5 Edge AI Scans)
insert into storage.buckets (id, name, public) 
values ('product_scans', 'product_scans', true)
on conflict (id) do nothing;

drop policy if exists "Public Access to Scans" on storage.objects;
create policy "Public Access to Scans"
on storage.objects for select
using (bucket_id = 'product_scans');

drop policy if exists "Authenticated Users can Upload Scans" on storage.objects;
create policy "Authenticated Users can Upload Scans"
on storage.objects for insert
with check (bucket_id = 'product_scans' and auth.role() = 'authenticated');

-- 15. EXPLICIT POLICIES & REALTIME FIXES
-- Ensure store owners can actually delete donations to prevent ghost records
DROP POLICY IF EXISTS "Store owners can delete their donations" ON public.donations;
CREATE POLICY "Store owners can delete their donations" ON public.donations FOR DELETE USING (auth.uid() = store_owner_id);

-- Ensure users can delete notifications via swipe without RLS silent failures
DROP POLICY IF EXISTS "Users can delete their notifications" ON public.notifications;
CREATE POLICY "Users can delete their notifications" ON public.notifications FOR DELETE USING (auth.uid() = user_id);

