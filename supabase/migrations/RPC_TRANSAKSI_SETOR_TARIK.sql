-- =============================================================================
-- FUNGSI RPC TRANSAKSI PERBANKAN (SETOR & TARIK MANDIRI)
-- Jalankan ini di Supabase SQL Editor
-- =============================================================================

-- 1. Helper: Generate Nomor Transaksi Unik (TRX-YYYYMMDD-NNNNNN)
CREATE OR REPLACE FUNCTION public.generate_transaction_number()
RETURNS TEXT AS $$
DECLARE
  prefix TEXT;
  seq_num INT;
  result TEXT;
BEGIN
  prefix := 'TRX-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-';
  
  SELECT COUNT(*) + 1 INTO seq_num
  FROM public.transactions
  WHERE transaction_number LIKE prefix || '%';
  
  result := prefix || LPAD(seq_num::TEXT, 6, '0');
  
  WHILE EXISTS (SELECT 1 FROM public.transactions WHERE transaction_number = result) LOOP
    seq_num := seq_num + 1;
    result := prefix || LPAD(seq_num::TEXT, 6, '0');
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. RPC: process_deposit (Lapor Setoran Mandiri)
CREATE OR REPLACE FUNCTION public.process_deposit(
  p_account_id UUID,
  p_box_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT NULL,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_account public.accounts%ROWTYPE;
  v_box public.savings_boxes%ROWTYPE;
  v_transaction_id UUID;
  v_transaction_number TEXT;
  v_user_id UUID := auth.uid();
BEGIN
  -- Cek idempotency agar tidak terjadi transaksi ganda
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id FROM public.transactions
    WHERE idempotency_key = p_idempotency_key AND status IN ('COMPLETED', 'PENDING_CONFIRMATION');
    IF FOUND THEN
      RETURN jsonb_build_object('ok', true, 'duplicate', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;
  
  -- Validasi akun rekening
  SELECT * INTO v_account FROM public.accounts WHERE id = p_account_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rekening tabungan tidak ditemukan');
  END IF;
  
  IF v_account.user_id != v_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Anda tidak memiliki hak akses ke rekening ini');
  END IF;
  
  IF v_account.status != 'ACTIVE' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rekening tabungan belum berstatus aktif');
  END IF;
  
  -- Validasi nominal setoran
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Nominal setoran harus lebih besar dari Rp 0');
  END IF;
  
  IF p_amount < 10000 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Minimal setoran tabungan adalah Rp 10.000');
  END IF;
  
  -- Validasi kotak jika disertakan
  IF p_box_id IS NOT NULL THEN
    SELECT * INTO v_box FROM public.savings_boxes WHERE id = p_box_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan fisik tidak ditemukan');
    END IF;
    IF v_box.account_id != p_account_id THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan tidak tertaut dengan rekening ini');
    END IF;
    IF v_box.status != 'ACTIVE' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan fisik belum diaktifkan');
    END IF;
  END IF;
  
  v_transaction_number := public.generate_transaction_number();
  
  -- Buat baris transaksi
  INSERT INTO public.transactions (
    transaction_number, account_id, user_id, box_id,
    transaction_type, amount, status, description, idempotency_key,
    source, physical_confirmed, submitted_at
  ) VALUES (
    v_transaction_number, p_account_id, v_user_id, p_box_id,
    'DEPOSIT', p_amount, 'PENDING_CONFIRMATION', p_description, p_idempotency_key,
    CASE WHEN p_box_id IS NOT NULL THEN 'NFC' ELSE 'MEMBER_APP' END,
    FALSE, NOW()
  ) RETURNING id INTO v_transaction_id;
  
  -- Catat audit log
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, new_data)
  VALUES (v_user_id, 'DEPOSIT_SUBMITTED', 'transactions', v_transaction_id,
    jsonb_build_object('amount', p_amount, 'account_id', p_account_id));
  
  RETURN jsonb_build_object(
    'ok', true,
    'transaction_id', v_transaction_id,
    'transaction_number', v_transaction_number,
    'status', 'PENDING_CONFIRMATION'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RPC: confirm_physical_deposit (Konfirmasi Uang Fisik Dimasukkan ke Kotak)
CREATE OR REPLACE FUNCTION public.confirm_physical_deposit(
  p_transaction_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_tx public.transactions%ROWTYPE;
  v_account public.accounts%ROWTYPE;
  v_new_balance NUMERIC;
  v_user_id UUID := auth.uid();
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transaksi tidak ditemukan');
  END IF;
  
  IF v_tx.user_id != v_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Akses ditolak: transaksi ini bukan milik Anda');
  END IF;
  
  IF v_tx.status != 'PENDING_CONFIRMATION' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Transaksi ini sudah selesai atau dibatalkan sebelumnya');
  END IF;
  
  IF v_tx.transaction_type != 'DEPOSIT' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hanya setoran yang dapat dikonfirmasi dengan cara ini');
  END IF;
  
  -- Ambil dan kunci baris rekening untuk mutasi saldo atomik
  SELECT * INTO v_account FROM public.accounts WHERE id = v_tx.account_id FOR UPDATE;
  
  v_new_balance := v_account.book_balance + v_tx.amount;
  
  -- Update saldo pembukuan rekening
  UPDATE public.accounts SET
    book_balance = v_new_balance,
    updated_at = NOW()
  WHERE id = v_tx.account_id;
  
  -- Update status transaksi menjadi COMPLETED
  UPDATE public.transactions SET
    status = 'COMPLETED',
    physical_confirmed = TRUE,
    physical_confirmed_at = NOW(),
    confirmed_at = NOW(),
    processed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_transaction_id;
  
  -- Catat entri pembukuan berpasangan (Double-Entry Ledger)
  INSERT INTO public.ledger_entries (
    transaction_id, account_id, entry_type, amount, balance_after, description
  ) VALUES (
    p_transaction_id, v_tx.account_id, 'CREDIT', v_tx.amount, v_new_balance, 'Setoran tabungan mandiri dikonfirmasi'
  );
  
  -- Catat audit log
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, old_data, new_data)
  VALUES (
    v_user_id, 'DEPOSIT_CONFIRMED', 'transactions', p_transaction_id,
    jsonb_build_object('balance_before', v_account.book_balance),
    jsonb_build_object('balance_after', v_new_balance, 'amount', v_tx.amount)
  );
  
  -- Notifikasi ke member
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_tx.user_id, 'DEPOSIT_COMPLETED', 'Setoran Berhasil',
    'Setoran Rp ' || TO_CHAR(v_tx.amount, 'FM999,999,999,999') || ' berhasil masuk ke tabungan Anda.',
    jsonb_build_object('transaction_id', p_transaction_id, 'amount', v_tx.amount, 'new_balance', v_new_balance)
  );
  
  RETURN jsonb_build_object(
    'ok', true,
    'new_balance', v_new_balance,
    'transaction_id', p_transaction_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: process_withdrawal (Penarikan Mandiri)
CREATE OR REPLACE FUNCTION public.process_withdrawal(
  p_account_id UUID,
  p_box_id UUID,
  p_amount NUMERIC,
  p_description TEXT DEFAULT NULL,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_account public.accounts%ROWTYPE;
  v_box public.savings_boxes%ROWTYPE;
  v_transaction_id UUID;
  v_transaction_number TEXT;
  v_new_balance NUMERIC;
  v_user_id UUID := auth.uid();
BEGIN
  -- Cek idempotency
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id FROM public.transactions
    WHERE idempotency_key = p_idempotency_key AND status = 'COMPLETED';
    IF FOUND THEN
      RETURN jsonb_build_object('ok', true, 'duplicate', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;
  
  -- Ambil rekening dengan lock
  SELECT * INTO v_account FROM public.accounts WHERE id = p_account_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rekening tabungan tidak ditemukan');
  END IF;
  
  IF v_account.user_id != v_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Anda tidak memiliki hak akses ke rekening ini');
  END IF;
  
  IF v_account.status != 'ACTIVE' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rekening tabungan belum aktif');
  END IF;
  
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Nominal penarikan harus lebih dari Rp 0');
  END IF;
  
  IF v_account.book_balance < p_amount THEN
    RETURN jsonb_build_object('ok', false, 'error',
      'Saldo tidak mencukupi. Saldo saat ini: Rp ' || TO_CHAR(v_account.book_balance, 'FM999,999,999,999'));
  END IF;
  
  IF p_box_id IS NOT NULL THEN
    SELECT * INTO v_box FROM public.savings_boxes WHERE id = p_box_id;
    IF v_box.account_id != p_account_id OR v_box.status != 'ACTIVE' THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan fisik tidak valid atau belum aktif');
    END IF;
  END IF;
  
  v_new_balance := v_account.book_balance - p_amount;
  v_transaction_number := public.generate_transaction_number();
  
  -- Buat transaksi
  INSERT INTO public.transactions (
    transaction_number, account_id, user_id, box_id,
    transaction_type, amount, status, description, idempotency_key,
    source, physical_confirmed, submitted_at, confirmed_at, processed_at
  ) VALUES (
    v_transaction_number, p_account_id, v_user_id, p_box_id,
    'WITHDRAWAL', p_amount, 'COMPLETED', p_description, p_idempotency_key,
    CASE WHEN p_box_id IS NOT NULL THEN 'NFC' ELSE 'MEMBER_APP' END,
    TRUE, NOW(), NOW(), NOW()
  ) RETURNING id INTO v_transaction_id;
  
  -- Potong saldo rekening
  UPDATE public.accounts SET
    book_balance = v_new_balance,
    updated_at = NOW()
  WHERE id = p_account_id;
  
  -- Double-entry ledger
  INSERT INTO public.ledger_entries (
    transaction_id, account_id, entry_type, amount, balance_after, description
  ) VALUES (
    v_transaction_id, p_account_id, 'DEBIT', p_amount, v_new_balance, 'Penarikan dana tabungan mandiri'
  );
  
  -- Audit log
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, old_data, new_data)
  VALUES (
    v_user_id, 'WITHDRAWAL_COMPLETED', 'transactions', v_transaction_id,
    jsonb_build_object('balance_before', v_account.book_balance),
    jsonb_build_object('balance_after', v_new_balance, 'amount', p_amount)
  );
  
  -- Notifikasi
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_user_id, 'WITHDRAWAL_COMPLETED', 'Penarikan Berhasil',
    'Penarikan Rp ' || TO_CHAR(p_amount, 'FM999,999,999,999') || ' berhasil dicatat.',
    jsonb_build_object('transaction_id', v_transaction_id, 'amount', p_amount, 'new_balance', v_new_balance)
  );
  
  RETURN jsonb_build_object(
    'ok', true,
    'transaction_id', v_transaction_id,
    'transaction_number', v_transaction_number,
    'new_balance', v_new_balance,
    'status', 'COMPLETED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Berikan izin EXECUTE kepada role authenticated
GRANT EXECUTE ON FUNCTION public.generate_transaction_number() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_deposit(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_physical_deposit(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_withdrawal(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role;

-- 6. Muat ulang cache schema PostgREST Supabase
NOTIFY pgrst, 'reload schema';
