// scripts/test_supabase.js
// Simple script to test connectivity to the Supabase instance.
// Run with: node scripts/test_supabase.js

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config({ path: 'f:/narayanvirtualsmartbank/.env' });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('❌ Supabase URL or ANON key not set in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function test() {
  try {
    console.log('🔌 Testing connection to Supabase...');
    const { data, error, count } = await supabase
      .from('profiles')
      .select('id', { count: 'exact', head: false })
      .limit(1);
    if (error) {
      console.error('❌ Error fetching profiles:', error.message);
    } else {
      console.log('✅ Connected! Sample profile IDs:', data.map(p => p.id));
      console.log('Total profiles count (if returned):', count);
    }

    // Test RLS INSERT on account_applications (member create)
    console.log('\n🔐 Testing INSERT on account_applications (member) ...');
    // Create a temporary user via SignUp (if not existing)
    const testEmail = 'supabase_test_user_' + Date.now() + '@example.com';
    const { data: authData, error: signUpErr } = await supabase.auth.signUp({
      email: testEmail,
      password: 'Password123!'
    });
    if (signUpErr) {
      console.error('❌ SignUp failed:', signUpErr.message);
      return;
    }
    const user = authData?.user;
    if (!user) {
      console.error('❌ User is null after signUp (email confirmation may be enabled)');
      return;
    }
    console.log('✅ Test user created, id:', user.id);

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
      console.error('❌ Insert into account_applications failed:', insertErr.message);
    } else {
      console.log('✅ Insert succeeded, new application id:', insertData[0].id);
    }
  } catch (e) {
    console.error('Unexpected error:', e);
  }
}

test();

