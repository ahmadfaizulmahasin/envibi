import { useEffect, useState } from 'react';
import { supabase } from '../../services/supabase/client';

/**
 * Hook to fetch the current user's role from the `public.user_roles` table.
 * It also subscribes to realtime changes so the UI updates automatically
 * when the role is modified (e.g., an admin promotes a member).
 */
export const useUserRole = () => {
  const [role, setRole] = useState<string | null>(null);
  const user = supabase.auth.user();

  const fetchRole = async () => {
    if (!user) {
      setRole(null);
      return;
    }
    const { data, error } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .single();
    if (error) {
      console.warn('Failed to fetch role:', error.message);
      setRole(null);
    } else {
      setRole(data?.role ?? null);
    }
  };

  useEffect(() => {
    fetchRole();

    if (!user) return undefined;
    const channel = supabase
      .channel('public:user_roles')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'user_roles',
          filter: `user_id=eq.${user.id}`,
        },
        payload => {
          setRole((payload as any).new.role);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user?.id]);

  return role;
};

