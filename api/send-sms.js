// ============================================================
// POST /api/send-sms
// Called by a Supabase Database Webhook whenever a row in
// `orders` is updated (Database > Webhooks > on UPDATE of orders).
// Supabase sends the new row as `record` in the webhook payload.
//
// Env vars needed (set in Vercel Project Settings > Environment Variables):
//   TWILIO_ACCOUNT_SID
//   TWILIO_AUTH_TOKEN
//   TWILIO_FROM_NUMBER      (your Twilio number, e.g. +61xxxxxxxxx)
//   SUPABASE_WEBHOOK_SECRET (shared secret — set the same value as a
//                            custom header in the Supabase webhook config,
//                            e.g. header "x-webhook-secret")
// ============================================================

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');

  // Verify the request actually came from Supabase's webhook, not a random caller
  if (req.headers['x-webhook-secret'] !== process.env.SUPABASE_WEBHOOK_SECRET) {
    return res.status(401).send('Unauthorized');
  }

  const { record, old_record } = req.body;
  if (!record) return res.status(400).send('Missing record');

  // Only text when there's an actual status change, opt-in, and a phone number
  if (!record.sms_opt_in || !record.customer_phone) return res.status(200).send('Skipped: no opt-in/phone');
  if (old_record && old_record.status === record.status) return res.status(200).send('Skipped: no status change');

  const messages = {
    in_preparation: `Oi ${record.customer_name}! Seu pedido na Brazilian Mood (mesa ${record.table_number}) está sendo preparado. 🍳`,
    done: `${record.customer_name}, seu pedido está pronto! Pode retirar na mesa ${record.table_number}. 🎉`
  };
  const body = messages[record.status];
  if (!body) return res.status(200).send('Skipped: no message for this status');

  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM_NUMBER;

  const twilioRes = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: 'POST',
    headers: {
      'Authorization': 'Basic ' + Buffer.from(`${sid}:${token}`).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({ To: record.customer_phone, From: from, Body: body })
  });

  if (!twilioRes.ok) {
    const errText = await twilioRes.text();
    console.error('Twilio error:', errText);
    return res.status(502).send('SMS provider error');
  }

  return res.status(200).send('SMS sent');
}
