import React, { useState } from 'react';
import { supabase } from '../../../services/supabase/client';
import Modal from '../../components/Modal'; // generic modal component

/**
 * ResetBox component allows a member to reset their physical box.
 * The member must re‑enter their password to confirm the action.
 * On successful verification a Supabase RPC `reset_box` is called.
 */
const ResetBox = () => {
  const [showModal, setShowModal] = useState(false);
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState(null);

  const handleReset = async () => {
    setLoading(true);
    setMessage(null);
    try {
      const user = supabase.auth.user();
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
      const { data, error: rpcErr } = await supabase.rpc('reset_box', {
        member_id: user.id,
      });
      if (rpcErr) {
        setMessage(`Gagal mereset kotak: ${rpcErr.message}`);
      } else {
        setMessage('Kotak tabungan berhasil direset. Status kembali ke PREPARING.');
        // optionally trigger realtime update or refresh UI
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
        <Modal onClose={() => setShowModal(false)} title="Reset Kotak Tabungan">
          <p>Masukkan password akun Anda untuk mengkonfirmasi reset kotak.</p>
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="input"
          />
          <div className="mt-4 flex space-x-2">
            <button className="btn btn-primary" onClick={handleReset} disabled={loading}>
              {loading ? 'Memproses…' : 'Konfirmasi Reset'}
            </button>
            <button className="btn btn-secondary" onClick={() => setShowModal(false)} disabled={loading}>
              Batal
            </button>
          </div>
          {message && <p className="mt-2 text-sm text-gray-700">{message}</p>}
        </Modal>
      )}
    </>
  );
};

export default ResetBox;
