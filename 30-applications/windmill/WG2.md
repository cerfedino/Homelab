# WG2 (converted from the n8n "WG2 copy" workflow)

Weekly cleaning rota with a Telegram inline-keyboard checklist, monthly expense
settlement, and a webhook handling button callbacks plus `/repeat` and `/reset`
(Albert-only). Lives in `workspace/f/wg2/`, synced with `devbox run wmill sync
push|pull`; n8n's three data tables became the `f/wg2/state` and
`f/wg2/movements` resources.

## Pieces

- `lib`: constants (chat, tasks, tenants), state access, keyboard/rota rendering,
  Telegram calls; `CHAT_ID` swaps between the flat group and Albert's DM for
  spam-free testing
- `weekly_rota` / `monthly_money`: the two scheduled entry points; schedules are
  `.schedule.yaml` files next to them, disabled until flipped
- `telegram_webhook`: toggles a task on button press, edits that message's
  keyboard in place, announces completions as a reply (unchecking is silent);
  `callback_data` carries `week:task` so previous weeks' buttons are inert
- `setup_webhook`: one-shot cutover: seeds the resources, registers the bot's
  command menu, mints a webhook-scoped token and points the bot at
  `telegram_webhook` with the pending backlog dropped; returns `getWebhookInfo`
- Variable `f/wg2/telegram_bot_token` (secret) holds the bot token; secrets are
  excluded from sync so it exists only in Windmill

## Behavior notes

- Rota rotation is `TENANTS[(week + idx) % 4]`; `/reset` advances the week like
  the weekly schedule does; `movements` is edited as JSON on the Resources page
- Inherited quirk, left as-is: when a creditor also appears in `SharedBy`, share
  attribution after the creditor's position shifts by one entry; current data
  never hits it since `Creditor` is null
