import React, { useState } from 'react';
import { supabase } from '../../services/supabase/client';
import { useAuth } from '../../app/providers/AuthProvider';

/**
 * ResetBox component allows a member to reset their physical box.
 * The member must re‑enter their password to confirm the action.
 * On successful verification a Supabase RPC `reset_box` is called.
 */
const ResetBox = () => {
  const { user } = useAuth();
  const [showModal, setShowModal] = useState(false);
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState(null);

  const handleReset = async () => {
    setLoading(true);
    setMessage(null);
    try {
      if (!user) {
        setMessage('Anda belum login.');
        setLoading(false);
        return;
      }
      // Verify password by attempting sign‑in with same credentials
      const { error: signInErr } = await supabase.auth.signInWithPassword({
        email: user.email,
        password,
      });
      if (signInErr) {
        setMessage('Password tidak valid.');
        setLoading(false);
        return;
      }
      // Call RPC to reset the box status
      const { error: rpcErr } = await supabase.rpc('reset_box', {
        member_id: user.id,
      });
      if (rpcErr) {
        setMessage(`Gagal mereset kotak: ${rpcErr.message}`);
      } else {
        setMessage('Kotak tabungan berhasil direset. Status kembali ke PREPARING.');
      }
    } catch (e) {
      setMessage(`Error: ${e.message}`);
    }
    setLoading(false);
    setPassword('');
    setShowModal(false);
  };

  return (
    <>
      <button className="btn btn-warning" onClick={() => setShowModal(true)}>
        Reset Kotak Tabungan
      </button>
      {showModal && (
        <div className="member-portal-overlay">
          <div className="card" style={{ maxWidth: '400px', width: '100%', padding: '24px' }}>
            <h3 style={{ margin: '0 0 10px', fontSize: '16px' }}>Reset Kotak Tabungan</h3>
            <p style={{ color: 'var(--fg-muted)', fontSize: '13px' }}>
              Masukkan password akun Anda untuk mengonfirmasi reset kotak tabungan.
            </p>
            <input
              type="password"
              placeholder="Password akun Anda"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="form-field"
              style={{ width: '100%', marginTop: '10px' }}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '16px' }}>
              <button className="btn btn-secondary" onClick={() => setShowModal(false)} disabled={loading}>
                Batal
              </button>
              <button className="btn btn-primary" onClick={handleReset} disabled={loading || !password}>
                {loading ? 'Memproses…' : 'Konfirmasi Reset'}
              </button>
            </div>
            {message && <p style={{ marginTop: '10px', fontSize: '12px', color: 'var(--accent2)' }}>{message}</p>}
          </div>
        </div>
      )}
    </>
  );
};

export default ResetBox;
