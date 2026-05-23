# send-push

Sends APNs pushes to a user's registered iOS devices.

## Invocation

Internal only — called by Postgres triggers via `pg_net.http_post`. Not user-facing.

Request body:
```json
{
  "recipient_user_id": "<uuid>",
  "type": "message" | "match" | "like",
  "payload": {
    "title": "string",
    "body": "string",
    "deepLink": "chat:<id>" | "match:<id>" | "likes",
    "threadId": "optional collapse identifier",
    "badgeCount": 1
  }
}
```

Response:
```json
{ "sent": 1 }
```

## Required secrets

| Secret             | Source                                            |
|--------------------|---------------------------------------------------|
| `APNS_KEY_ID`      | Apple Developer → Keys → Key ID (10 chars)        |
| `APNS_TEAM_ID`     | Apple Developer → top-right of portal (10 chars)  |
| `APNS_BUNDLE_ID`   | `HarvestGlass.Harvest`                            |
| `APNS_AUTH_KEY`    | Contents of the .p8 file (with BEGIN/END lines)   |
| `APNS_ENVIRONMENT` | `production` (TestFlight + App Store) or `development` (Xcode dev builds) |

Set via `supabase secrets set` or in Dashboard → Project Settings → Edge Functions → Secrets.

## Local testing

```sh
supabase functions serve send-push
curl -X POST http://localhost:54321/functions/v1/send-push \
  -H "content-type: application/json" \
  -d '{
    "recipient_user_id": "<your-uuid>",
    "type": "message",
    "payload": {
      "title": "Test sender",
      "body": "Hi from the Edge Function",
      "deepLink": "chat:abc",
      "threadId": "abc"
    }
  }'
```
