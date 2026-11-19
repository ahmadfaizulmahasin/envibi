import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../app/providers/AuthProvider';

/**
 * RequireAdmin component – renders children only if logged-in user is ADMIN or SUPER_ADMIN.
 */
const RequireAdmin = ({ children }) => {
  const { isAdmin, loading } = useAuth();

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '50vh' }}>
        <div className="loading-spinner" />
      </div>
    );
  }

  if (!isAdmin) {
    return <Navigate to="/dashboard" replace />;
  }

  return <>{children}</>;
};

export default RequireAdmin;
