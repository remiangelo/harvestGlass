## openai-chat Edge Function

This function securely proxies OpenAI chat-completions requests for Harvest.

It lets the iOS app call your Supabase Edge Function instead of shipping a real
OpenAI API key inside the app bundle.

### Required secret

Set this in Supabase:

- `OPENAI_API_KEY`

### Deploy

From the repo root:

```bash
supabase functions deploy openai-chat
```

### Test

Once deployed and the secret is set, Gardener and mindful-messaging AI calls
should work without putting the OpenAI key in `Config.swift`.
