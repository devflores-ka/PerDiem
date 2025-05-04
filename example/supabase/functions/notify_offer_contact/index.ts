import {createClient} from 'npm:@supabase/supabase-js@2'
import {JWT} from 'npm:google-auth-library@9'

interface NotifyOfferContactPayload {
  offerId: string;        // ID de la oferta
  offerName: string;      // Nombre de la oferta
  offerOwnerId: string;   // ID del usuario dueño de la oferta (quién recibirá la notificación)
  senderId: string;       // ID del usuario que está haciendo la consulta
}

interface WebhookPayload {
    type: 'INSERT'
    table: string
    record: NotifyOfferContactPayload
    schema: 'chats',
    old_record: null | NotifyOfferContactPayload
}

const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

console.log("Hello from Functions!")

Deno.serve(async (req) => {
  const payload: WebhookPayload = await req.json();
  console.log('Payload recibido:', payload);

  // Verificamos si existe el offer_id en el payload
  if (!payload.record || !payload.record.offer_id) {
    console.error('offer_id no presente en el payload:', payload.record);
    throw new Error('offer_id no presente en el payload');
  }

  // Obtenemos el propietario de la oferta usando el offer_id
  const { data: offerData, error: offerError } = await supabase
    .schema('jobs')
    .from('offers')
    .select('user_id, name')
    .eq('id', payload.record.offer_id)
    .single();

  if (offerError || !offerData) {
    console.error('Error al obtener la oferta:', offerError);
    throw new Error('No se pudo obtener el propietario de la oferta');
  }

  const offerOwnerId = offerData.user_id;
  console.log('Owner ID de la oferta:', offerOwnerId);

  if (!offerOwnerId) {
    console.error('No se encontró el offerOwnerId en la oferta');
    throw new Error('No se encontró el offerOwnerId en la oferta');
  }

  // Ahora podemos proceder a obtener el fmc_token para el propietario de la oferta
  const { data, error } = await supabase
    .schema('chats')
    .from('profiles')
    .select('fmc_token')
    .eq('id', offerOwnerId)
    .single();

  if (error) {
    console.error('Error al obtener el fmc_token:', error);
    throw new Error('No se encontró el fmc_token para el propietario de la oferta');
  }

  const fmc_token = data!.fmc_token;
  console.log('fmc_token para la oferta:', fmc_token);

  if (!fmc_token) {
    console.error('No se encontró el fmc_token');
    throw new Error('No se encontró el fmc_token para el propietario de la oferta');
  }

  const serviceAccount = JSON.parse(Deno.env.get('SERVICE_ACCOUNT_JSON')!);

  const accessToken = await getAccessToken({
      clientEmail: serviceAccount.client_email,
      privateKey: serviceAccount.private_key,
  })

  // Luego en el body de la notificación usas offerData.name
  const notificationBody = `${offerData.name}`;

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
                    title: `Te han hablado`,
                    body: notificationBody,
                }
            }
        })
      }
  )

  // Añade manejo de errores más detallado
  const contentType = res.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    const resData = await res.json();
    if (res.status < 200 || 299 < res.status) {
      console.error('Error al enviar la notificación', resData);
      throw new Error(`Error al enviar la notificación: ${resData.message || 'Desconocido'}`);
    }
    return new Response(
      JSON.stringify(resData),
      { headers: { "Content-Type": "application/json" } },
    );
  } else {
    // Si la respuesta no es JSON, muestra el texto
    const textResponse = await res.text();
    console.error('Respuesta no JSON recibida:', textResponse);
    throw new Error(`Respuesta inesperada del servidor FCM: ${res.status}`);
  }

  return new Response(
    JSON.stringify(resData),
    { headers: { "Content-Type": "application/json" } },
  )
})

const getAccessToken = ({
    clientEmail,
    privateKey,
  }: {
    clientEmail: string
    privateKey: string
  }): Promise <string> => {
    return new Promise((resolve, reject) => {
        const jwtClient = new JWT({
            email: clientEmail,
            key: privateKey,
            scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
        })
        jwtClient.authorize((err, tokens) => {
            if(err) {
                reject(err)
                return;
            }
            resolve(tokens!.access_token!)
        })
    })
}