import React from 'react';
import RequireAdmin from '../../components/RequireAdmin';

/**
 * Simple placeholder admin dashboard. In a real app you would add
 * navigation to admin‑only screens (manage users, view applications, etc.).
 */
const AdminDashboard = () => {
  return (
    <RequireAdmin>
      <div className="p-4">
        <h1 className="text-2xl font-bold mb-4">Admin Dashboard</h1>
        <p>Halaman ini hanya dapat diakses oleh pengguna dengan peran ADMIN.</p>
        {/* Add admin UI components here, e.g., tables of account applications */}
      </div>
    </RequireAdmin>
  );
};

export default AdminDashboard;
