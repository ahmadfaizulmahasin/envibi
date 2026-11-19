import React from 'react';
import { Navigate } from 'react-router-dom';
import { useUserRole } from '../hooks/useUserRole';

/**
 * RequireAdmin component – renders children only if the logged‑in user has role "ADMIN".
 * If no user or role is not ADMIN, redirects to home (or a 403 page).
 */
const RequireAdmin = ({ children }) => {
  const role = useUserRole();

  // While role is loading we can show nothing or a spinner.
  if (role === null) {
    return null; // or a loading indicator
  }

  // If the user is not admin, redirect.
  if (role !== 'ADMIN') {
    return <Navigate to="/" replace />;
  }

  // Admin – render the protected content.
  return <>{children}</>;
};

export default RequireAdmin;

