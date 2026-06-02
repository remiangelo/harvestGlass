// Copy this file to `config.js` and fill in your values.
// `config.js` is gitignored — it holds the SERVICE ROLE key, which has full
// database access. NEVER commit it and NEVER deploy this panel to a public URL.
window.HARVEST_ADMIN_CONFIG = {
  // Supabase Dashboard → Project Settings → API → Project URL
  SUPABASE_URL: "https://YOUR-PROJECT.supabase.co",

  // Supabase Dashboard → Project Settings → API → service_role secret.
  // This bypasses Row Level Security, so it must stay on your machine only.
  SERVICE_ROLE_KEY: "REPLACE_ME",
};
