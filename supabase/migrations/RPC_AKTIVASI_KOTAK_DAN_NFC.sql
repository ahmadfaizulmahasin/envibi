-- =============================================================================
-- RPC: AKTIVASI KOTAK TABUNGAN & VERIFIKASI NFC OLEH MEMBER
-- Jalankan ini di Supabase SQL Editor
-- =============================================================================

-- 1. RPC: activate_savings_box
CREATE OR REPLACE FUNCTION public.activate_savings_box(
  p_box_id UUID,
  p_nfc_token TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_box public.savings_boxes%ROWTYPE;
  v_tag public.nfc_tags%ROWTYPE;
  v_user_id UUID := auth.uid();
BEGIN
  -- Verifikasi token
  SELECT * INTO v_tag FROM public.nfc_tags WHERE public_token = p_nfc_token;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Token NFC tidak valid atau belum terdaftar');
  END IF;
  
  -- Ambil data kotak
  SELECT * INTO v_box FROM public.savings_boxes WHERE id = p_box_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan tidak ditemukan');
  END IF;
  
  -- Pastikan kotak milik user yang sedang login
  IF v_box.user_id != v_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan ini bukan terdaftar atas nama akun Anda');
  END IF;
  
  -- Pastikan tag NFC terhubung ke kotak ini
  IF v_tag.box_id != p_box_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tag NFC yang discan tidak cocok dengan kotak tabungan ini');
  END IF;
  
  -- Jika kotak sudah berstatus aktif
  IF v_box.status = 'ACTIVE' THEN
    RETURN jsonb_build_object('ok', true, 'box_id', p_box_id, 'status', 'ACTIVE', 'message', 'Kotak tabungan Anda sudah aktif sebelumnya');
  END IF;

  -- Izinkan aktivasi untuk status yang wajar sebelum aktif
  IF v_box.status NOT IN ('READY_TO_SHIP', 'SHIPPED', 'RECEIVED', 'NFC_PENDING', 'PREPARING') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Status kotak saat ini (' || v_box.status || ') tidak memungkinkan aktivasi');
  END IF;
  
  -- Aktifkan kotak tabungan
  UPDATE public.savings_boxes SET
    status = 'ACTIVE',
    received_at = COALESCE(received_at, NOW()),
    activated_at = NOW()
  WHERE id = p_box_id;
  
  -- Audit log
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, new_data)
  VALUES (
    v_user_id, 'BOX_ACTIVATED', 'savings_boxes', p_box_id,
    jsonb_build_object('nfc_token', LEFT(p_nfc_token, 8) || '...')
  );
  
  -- Notifikasi ke admin bahwa member telah mengaktifkan kotak
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT u.id, 'BOX_ACTIVATED_BY_MEMBER', 'Kotak Tabungan Diaktifkan',
    'Member telah berhasil mengaktifkan kotak fisik ' || v_box.box_code,
    jsonb_build_object('box_id', p_box_id, 'box_code', v_box.box_code, 'member_id', v_user_id)
  FROM public.user_roles ur
  JOIN auth.users u ON u.id = ur.user_id
  WHERE ur.role IN ('ADMIN', 'SUPER_ADMIN');
  
  RETURN jsonb_build_object('ok', true, 'box_id', p_box_id, 'status', 'ACTIVE');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. RPC: verify_nfc_token (Untuk verifikasi saat scan NFC)
CREATE OR REPLACE FUNCTION public.verify_nfc_token(
  p_public_token TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_tag public.nfc_tags%ROWTYPE;
  v_box public.savings_boxes%ROWTYPE;
  v_account public.accounts%ROWTYPE;
  v_user_id UUID := auth.uid();
BEGIN
  -- Cari tag berdasarkan token
  SELECT * INTO v_tag FROM public.nfc_tags WHERE public_token = p_public_token AND status = 'VERIFIED';
  IF NOT FOUND THEN
    SELECT * INTO v_tag FROM public.nfc_tags WHERE public_token = p_public_token;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Token NFC tidak terdaftar dalam sistem');
    END IF;
    RETURN jsonb_build_object('ok', false, 'error', 'Tag NFC belum diverifikasi oleh admin');
  END IF;
  
  -- Ambil data kotak
  SELECT * INTO v_box FROM public.savings_boxes WHERE id = v_tag.box_id;
  IF NOT FOUND OR v_box.status != 'ACTIVE' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kotak tabungan belum berstatus aktif');
  END IF;
  
  -- Validasi kepemilikan (kecuali admin)
  IF v_box.user_id != v_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Token NFC ini bukan milik akun Anda');
  END IF;
  
  -- Ambil data rekening
  SELECT * INTO v_account FROM public.accounts WHERE id = v_box.account_id;
  IF NOT FOUND OR v_account.status != 'ACTIVE' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Rekening terkait kotak ini tidak aktif');
  END IF;
  
  RETURN jsonb_build_object(
    'ok', true,
    'box_id', v_box.id,
    'box_code', v_box.box_code,
    'account_id', v_account.id,
    'account_number', v_account.account_number,
    'book_balance', v_account.book_balance
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Berikan izin EXECUTE kepada user yang login (authenticated)
GRANT EXECUTE ON FUNCTION public.activate_savings_box(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_nfc_token(TEXT) TO authenticated, service_role;

-- 4. Muat ulang cache PostgREST Supabase
NOTIFY pgrst, 'reload schema';
