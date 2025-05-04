import { createClient } from 'npm:@supabase/supabase-js@2';
import { JWT } from 'npm:google-auth-library@9';

interface NotifyOfferContactPayload {
  offer_id: string;
  sender_id: string;
}

interface WebhookPayload {
  type: 'INSERT';
  table: string;
  record: NotifyOfferContactPayload;
  schema: 'chats',
  old_record: null | NotifyOfferContactPayload;
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const getAccessToken = ({
  clientEmail,
  privateKey,
}: {
  clientEmail: string;
  privateKey: string;
}): Promise<string> => {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    jwtClient.authorize((err, tokens) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(tokens!.access_token!);
    });
  });
};

Deno.serve(async (req) => {
  const payload = await req.json();
  console.log('Payload recibido:', payload);

  const receiverId = payload.receiver_id;
  const title = payload.title;
  const body = payload.body;

  if (!receiverId || !title || !body) {
    console.error('Payload incompleto:', payload);
    throw new Error('receiver_id, title y body son requeridos');
  }

  // Obtener fmc_token del receptor
  const { data, error } = await supabase
    .schema('chats')
    .from('profiles')
    .select('fmc_token')
    .eq('id', receiverId)
    .single();

  if (error || !data?.fmc_token) {
    console.error('No se pudo obtener el fmc_token:', error);
    throw new Error('No se pudo obtener el fmc_token del receptor');
  }

  const fmc_token = data.fmc_token;

  const serviceAccount = JSON.parse(Deno.env.get('SERVICE_ACCOUNT_JSON')!);

  const accessToken = await getAccessToken({
    clientEmail: serviceAccount.client_email,
    privateKey: serviceAccount.private_key,
  });

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: fmc_token,
          notification: {
            title,
            body,
          },
          data: payload.data ?? {},
        },
      }),
    }
  );

  const contentType = res.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    const resData = await res.json();
    if (res.status < 200 || 299 < res.status) {
      console.error('Error al enviar la notificación', resData);
      throw new Error(`Error al enviar la notificación: ${resData.message || 'Desconocido'}`);
    }
    return new Response(JSON.stringify(resData), {
      headers: { 'Content-Type': 'application/json' },
    });
  } else {
    const textResponse = await res.text();
    console.error('Respuesta no JSON recibida:', textResponse);
    throw new Error(`Respuesta inesperada del servidor FCM: ${res.status}`);
  }
});
