## delete-account Edge Function

This function performs full account deletion for Harvest:

- deletes application data tied to the current user
- deletes the public `users` row
- deletes the Supabase Auth user

### Deploy

From the repo root:

```bash
supabase functions deploy delete-account
```

### Required secrets

The function expects the standard Supabase function environment:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

### Test

1. Create a fresh account in the app.
2. Delete the account from Settings.
3. Verify the app signs out.
4. Attempt to sign in again with the same credentials.
5. Expected: sign-in fails because the auth user no longer exists.
