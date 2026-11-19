-- =============================================================================
-- FUNGSI RPC ADMIN UNTUK APPROVAL REKENING & DASHBOARD
-- Jalankan ini di Supabase SQL Editor
-- =============================================================================

-- 1. Helper Function: Generate Account Number
CREATE OR REPLACE FUNCTION public.generate_account_number()
RETURNS TEXT AS $$
DECLARE
  prefix TEXT;
  seq_num INT;
  result TEXT;
BEGIN
  prefix := 'NVB-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-';
  
  SELECT COUNT(*) + 1 INTO seq_num
  FROM public.accounts
  WHERE account_number LIKE prefix || '%';
  
  result := prefix || LPAD(seq_num::TEXT, 6, '0');
  
  WHILE EXISTS (SELECT 1 FROM public.accounts WHERE account_number = result) LOOP
    seq_num := seq_num + 1;
    result := prefix || LPAD(seq_num::TEXT, 6, '0');
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. RPC: approve_account_application
CREATE OR REPLACE FUNCTION public.approve_account_application(
  p_application_id UUID,
  p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_app public.account_applications%ROWTYPE;
  v_account_number TEXT;
  v_account_id UUID;
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Akses ditolak: diperlukan role admin');
  END IF;
  
  SELECT * INTO v_app FROM public.account_applications WHERE id = p_application_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pengajuan tidak ditemukan');
  END IF;
  
  IF v_app.status NOT IN ('PENDING', 'UNDER_REVIEW', 'REVISION_REQUIRED') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pengajuan sudah diproses sebelumnya');
  END IF;
  
  v_account_number := public.generate_account_number();
  
  INSERT INTO public.accounts (
    account_number, user_id, account_type, status, book_balance, created_by
  ) VALUES (
    v_account_number, v_app.user_id, v_app.account_type, 'ACTIVE', 0, v_admin_id
  ) RETURNING id INTO v_account_id;
  
  UPDATE public.account_applications SET
    status = 'APPROVED',
    admin_notes = p_admin_notes,
    reviewed_by = v_admin_id,
    reviewed_at = NOW(),
    account_id = v_account_id
  WHERE id = p_application_id;
  
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, new_data)
  VALUES (
    v_admin_id, 'ACCOUNT_APPLICATION_APPROVED', 'account_applications', p_application_id,
    jsonb_build_object('account_id', v_account_id, 'account_number', v_account_number)
  );
  
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_app.user_id,
    'ACCOUNT_APPROVED',
    'Rekening Disetujui',
    'Rekening tabungan Anda telah disetujui. Nomor rekening: ' || v_account_number,
    jsonb_build_object('account_id', v_account_id, 'account_number', v_account_number)
  );
  
  RETURN jsonb_build_object(
    'ok', true,
    'account_id', v_account_id,
    'account_number', v_account_number
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RPC: reject_account_application
CREATE OR REPLACE FUNCTION public.reject_account_application(
  p_application_id UUID,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_app public.account_applications%ROWTYPE;
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Akses ditolak');
  END IF;
  
  SELECT * INTO v_app FROM public.account_applications WHERE id = p_application_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pengajuan tidak ditemukan');
  END IF;
  
  IF v_app.status IN ('APPROVED', 'REJECTED') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pengajuan sudah diputuskan');
  END IF;
  
  UPDATE public.account_applications SET
    status = 'REJECTED',
    admin_notes = p_reason,
    reviewed_by = v_admin_id,
    reviewed_at = NOW()
  WHERE id = p_application_id;
  
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, new_data)
  VALUES (v_admin_id, 'ACCOUNT_APPLICATION_REJECTED', 'account_applications', p_application_id,
    jsonb_build_object('reason', p_reason));
  
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (v_app.user_id, 'ACCOUNT_REJECTED', 'Pengajuan Rekening Ditolak',
    'Maaf, pengajuan rekening Anda ditolak. Alasan: ' || COALESCE(p_reason, '-'),
    jsonb_build_object('application_id', p_application_id));
  
  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: request_application_revision
CREATE OR REPLACE FUNCTION public.request_application_revision(
  p_application_id UUID,
  p_notes TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_app public.account_applications%ROWTYPE;
  v_admin_id UUID := auth.uid();
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Akses ditolak');
  END IF;
  
  SELECT * INTO v_app FROM public.account_applications WHERE id = p_application_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Pengajuan tidak ditemukan');
  END IF;
  
  UPDATE public.account_applications SET
    status = 'REVISION_REQUIRED',
    admin_notes = p_notes,
    reviewed_by = v_admin_id,
    reviewed_at = NOW()
  WHERE id = p_application_id;
  
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, new_data)
  VALUES (v_admin_id, 'ACCOUNT_APPLICATION_REVISION_REQUESTED', 'account_applications', p_application_id,
    jsonb_build_object('notes', p_notes));
  
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (v_app.user_id, 'ACCOUNT_REVISION_REQUIRED', 'Permintaan Revisi Pengajuan',
    'Pengajuan rekening Anda memerlukan revisi: ' || COALESCE(p_notes, '-'),
    jsonb_build_object('application_id', p_application_id));
  
  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: get_admin_dashboard_data
CREATE OR REPLACE FUNCTION public.get_admin_dashboard_data()
RETURNS JSONB AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Akses ditolak');
  END IF;
  
  RETURN jsonb_build_object(
    'ok', true,
    'total_members', (SELECT COUNT(*) FROM public.profiles),
    'total_active_accounts', (SELECT COUNT(*) FROM public.accounts WHERE status = 'ACTIVE'),
    'pending_applications', (SELECT COUNT(*) FROM public.account_applications WHERE status IN ('PENDING','UNDER_REVIEW')),
    'preparing_boxes', (SELECT COUNT(*) FROM public.savings_boxes WHERE status IN ('PREPARING','NFC_PENDING','READY_TO_SHIP')),
    'shipped_boxes', (SELECT COUNT(*) FROM public.savings_boxes WHERE status = 'SHIPPED'),
    'active_boxes', (SELECT COUNT(*) FROM public.savings_boxes WHERE status = 'ACTIVE'),
    'total_book_balance', (SELECT COALESCE(SUM(book_balance), 0) FROM public.accounts WHERE status = 'ACTIVE'),
    'total_deposits_today', (
      SELECT COALESCE(SUM(amount), 0) FROM public.transactions
      WHERE transaction_type = 'DEPOSIT' AND status = 'COMPLETED'
      AND processed_at >= CURRENT_DATE
    ),
    'total_withdrawals_today', (
      SELECT COALESCE(SUM(amount), 0) FROM public.transactions
      WHERE transaction_type = 'WITHDRAWAL' AND status = 'COMPLETED'
      AND processed_at >= CURRENT_DATE
    ),
    'pending_transactions', (
      SELECT COUNT(*) FROM public.transactions WHERE status = 'PENDING_CONFIRMATION'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Berikan izin EXECUTE ke role autentikasi
GRANT EXECUTE ON FUNCTION public.generate_account_number() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_account_application(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reject_account_application(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_application_revision(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_admin_dashboard_data() TO authenticated, service_role;

-- 7. Refresh Schema Cache Supabase PostgREST
NOTIFY pgrst, 'reload schema';
