// Klang Hock Li V6 - customer sign-up (draft, do not deploy without abuse controls).
// Supabase Edge Function. Uses server-side service role secret only.
import { createClient } from 'npm:@supabase/supabase-js@2';

const projectUrl = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(projectUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
const allowedOrigin = 'https://jordanlim1984.github.io';
const headers = { 'Access-Control-Allow-Origin': allowedOrigin, 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers });
const normalPhone = (v: string) => {
  const digits = v.replace(/[^\d]/g, '');
  if (/^01\d{8,9}$/.test(digits)) return '60' + digits.slice(1);
  if (/^601\d{8,9}$/.test(digits)) return digits;
  return null;
};
export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (req.method !== 'POST') return reply(405, { error: 'Method not allowed' });
  if (req.headers.get('origin') !== allowedOrigin) return reply(403, { error: 'Origin not allowed' });
  try {
    const body = await req.json();
    const phone = normalPhone(String(body.phone || ''));
    const name = String(body.name || '').trim();
    const password = String(body.password || '');
    if (!phone || name.length < 2 || name.length > 100 || password.length < 12 || password.length > 128)
      return reply(400, { error: 'Enter a valid Malaysian mobile number, name, and password of at least 12 characters' });
    // A synthetic internal email allows password sign-in without sending email or SMS.
    // Not proof of phone ownership. Production deployment must add CAPTCHA and throttling.
    const email = `customer-${phone}@login.invalid`;
    const created = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { display_name: name, customer_phone: phone } });
    if (created.error || !created.data.user) {
      if (/already|registered|exists/i.test(created.error?.message || '')) return reply(409, { error: 'This mobile number is already registered' });
      return reply(400, { error: 'Registration could not be completed' });
    }
    const id = created.data.user.id;
    const record = await admin.from('customer_accounts').insert({ id, phone, display_name: name });
    if (record.error) {
      await admin.auth.admin.deleteUser(id);
      return reply(500, { error: 'Registration could not be completed' });
    }
    await admin.from('admin_notifications').insert({ customer_account_id: id, title: `New customer registered: ${name}` });
    return reply(201, { ok: true, message: 'Registration successful', loginEmail: email });
  } catch {
    return reply(400, { error: 'Invalid request' });
  }
}
