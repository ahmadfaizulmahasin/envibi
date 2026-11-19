// scripts/audit.js
// Simple Node script to query key tables via Supabase JS client and print a summary.
// Run with: node scripts/audit.js

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: 'f:/narayanvirtualsmartbank/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;
if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Supabase env vars missing');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function audit() {
  console.log('--- Auditing key tables ---');

  const tables = [
    'profiles',
    'user_roles',
    'account_applications',
    'accounts',
    'savings_boxes',
    'nfc_tags',
    'transactions',
  ];

  for (const tbl of tables) {
    const { data, error, count } = await supabase
      .from(tbl)
      .select('*', { count: 'exact', head: false })
      .limit(5);
    if (error) {
      console.error(`❌ ${tbl}: error -> ${error.message}`);
    } else {
      console.log(`✅ ${tbl}: ${count ?? data.length} rows (showing up to 5)`);
      console.dir(data, { depth: null, colors: true });
    }
  }

  // Test RLS by trying to insert a new account_application as the anon user (member).
  console.log('\n--- Testing INSERT on account_applications (should succeed for member) ---');
  const dummyEmail = 'testmember@example.com';
  // Find a user with that email, otherwise create a new auth user via signup (if allowed).
  let { data: user, error: userErr } = await supabase
    .from('profiles')
    .select('id')
    .eq('email', dummyEmail)
    .single();
  if (userErr && userErr.code === 'PGRST116') {
    // No profile; try sign‑up via auth.
    const { data: authData, error: signErr } = await supabase.auth.signUp({
      email: dummyEmail,
      password: 'Password123!'
    });
    const newUser = authData?.user;
    if (signErr) {
      console.error('Failed to create test user:', signErr.message);
    } else {
      user = { id: newUser.id };
      console.log('Created test user', newUser.id);
    }
  }

  if (user?.id) {
    const { data: insertData, error: insertErr } = await supabase
      .from('account_applications')
      .insert({
        user_id: user.id,
        account_type: 'TABUNGAN',
        initial_deposit: 0,
        status: 'PENDING'
      })
      .select();
    if (insertErr) {
      console.error('❌ INSERT failed (expected if RLS missing):', insertErr.message);
    } else {
      console.log('✅ INSERT succeeded, new application ID:', insertData[0].id);
    }
  }
}

audit().catch(e => console.error('Unexpected error', e));

