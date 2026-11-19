import { useAuth } from '../app/providers/AuthProvider';

/**
 * Hook to get current user role from AuthProvider.
 */
export const useUserRole = () => {
  const { role } = useAuth();
  return role;
};
