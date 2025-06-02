import { serve } from "https://deno.land/std@0.131.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabaseClient = createClient(
  Deno.env.get("SUPABASE_URL") || "",
  Deno.env.get("SUPABASE_ANON_KEY") || "",
  {
    auth: { persistSession: false }
  }
);

const APP_WEB_URL = "https://app.perdiem.cl";
const APP_SCHEME = "perdiem";
const ANDROID_PACKAGE = "com.tuempresa.tuapp";
const IOS_APP_ID = "tuappid";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const pathParts = url.pathname.split("/");
    const userAgent = req.headers.get("user-agent") || "";

    if (pathParts.length >= 3 && pathParts[1] === "compartir") {
      const offerId = pathParts[2];

      const { data, error } = await supabaseClient
        .schema("jobs")
        .from("offers_l")
        .select("*")
        .eq("id", offerId)
        .single();

      if (error || !data) {
        return new Response(JSON.stringify({ error: "Oferta no encontrada" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const oferta = data;
      const offerName = oferta.offer_name || "Oferta sin nombre";
      const description = oferta.description || "";
      const amount = oferta.amount || 0;
      const imageUrl = oferta.image_url || "https://via.placeholder.com/1200x630?text=Oferta";

      const firstName = oferta.created_by_first_name || "";
      const lastName = oferta.created_by_last_name || "";
      const fullName = `${firstName} ${lastName}`.trim() || "Usuario";
      const userImageUrl = oferta.user_image_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(firstName || "Usuario")}&size=100`;

      const presupuestoFormateado = new Intl.NumberFormat('es-ES').format(Number(amount));
      const isSocialBot = /facebookexternalhit|whatsapp|WhatsApp|facebook|twitter|linkedinbot|pinterest|Instagram|fban|fbsv|fb_iab|fbav/i.test(userAgent);

      const htmlResponse = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>${offerName} - TuApp</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="apple-itunes-app" content="app-id=${IOS_APP_ID}, app-argument=${APP_SCHEME}://offers/${offerId}">
  <link rel="alternate" href="android-app://${ANDROID_PACKAGE}/${APP_SCHEME}/offers/${offerId}">
  <meta property="og:title" content="${offerName}">
  <meta property="og:description" content="${description.substring(0, 200)}${description.length > 200 ? '...' : ''}">
  <meta property="og:image" content="${imageUrl}">
  <meta property="og:url" content="${url.origin}/functions/v1/compartir/${offerId}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="TuApp - Ofertas">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:locale" content="es_ES">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${offerName}">
  <meta name="twitter:description" content="${description.substring(0, 200)}${description.length > 200 ? '...' : ''}">
  <meta name="twitter:image" content="${imageUrl}">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      line-height: 1.6;
    }
    .card {
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      margin-bottom: 20px;
    }
    .card-image {
      width: 100%;
      height: 300px;
      object-fit: cover;
    }
    .card-content {
      padding: 20px;
    }
    .price {
      font-size: 22px;
      font-weight: bold;
      color: #2E7D32;
    }
    .user-info {
      display: flex;
      align-items: center;
      margin-top: 15px;
    }
    .avatar {
      width: 50px;
      height: 50px;
      border-radius: 25px;
      margin-right: 15px;
      object-fit: cover;
    }
    .user-details {
      flex-grow: 1;
    }
    .download-section {
      background-color: #f5f5f5;
      border-radius: 12px;
      padding: 20px;
      text-align: center;
      margin-top: 30px;
    }
    .btn {
      background-color: #1976D2;
      color: white;
      border: none;
      padding: 12px 24px;
      border-radius: 6px;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      text-decoration: none;
      display: inline-block;
      margin: 10px;
    }
    .store-buttons {
      margin: 30px 0;
      text-align: center;
    }
  </style>
</head>
<body>
  <div id="content">
    <h1>¡Descubre ${offerName}!</h1>
    <div class="card">
      <img class="card-image" src="${imageUrl}" alt="${offerName}">
      <div class="card-content">
        <h2>${offerName}</h2>
        <p>${description}</p>
        <p class="price">$${presupuestoFormateado}</p>
        <div class="user-info">
          <img class="avatar" src="${userImageUrl}" alt="${fullName}">
          <div class="user-details">
            <h3>${fullName}</h3>
          </div>
        </div>
      </div>
    </div>
    <p>Para ver más detalles y contactar, abre esta oferta en nuestra app</p>
    <div id="app-buttons" class="store-buttons">
      <a id="open-app" class="btn">Abrir en la app</a>
      <div id="store-buttons" style="display: none;">
        <a id="google-play" class="btn" href="https://play.google.com/store/apps/details?id=${ANDROID_PACKAGE}">Google Play</a>
        <a id="app-store" class="btn" href="https://apps.apple.com/us/app/id${IOS_APP_ID}">App Store</a>
      </div>
    </div>
  </div>
  <script>
    const APP_SCHEME = "${APP_SCHEME}";
    const ANDROID_PACKAGE = "${ANDROID_PACKAGE}";
    const IOS_APP_ID = "${IOS_APP_ID}";
    const APP_WEB_URL = "${APP_WEB_URL}";
    const offerId = "${offerId}";

    function openAppAndroid(offerId) {
      const intentUri = \`intent://offers/\${offerId}#Intent;scheme=\${APP_SCHEME};package=\${ANDROID_PACKAGE};S.browser_fallback_url=\${encodeURIComponent(APP_WEB_URL + '/offers/' + offerId)};end\`;
      window.location.href = intentUri;
      setTimeout(() => {
        window.location.href = \`https://play.google.com/store/apps/details?id=\${ANDROID_PACKAGE}\`;
      }, 1500);
    }

    function openApp() {
      const userAgent = navigator.userAgent || '';
      const isAndroid = /Android/i.test(userAgent);
      const isIOS = /iPhone|iPad|iPod/i.test(userAgent);
      const isSocialBot = /facebookexternalhit|whatsapp|facebook|twitter|linkedinbot|pinterest|Instagram|fban|fbsv|fb_iab|fbav/i.test(userAgent);
      if (isSocialBot) return;
      if (isAndroid) {
        openAppAndroid(offerId);
      } else if (isIOS) {
        window.location.href = \`\${APP_SCHEME}://offers/\${offerId}\`;
        setTimeout(() => {
          window.location.href = \`https://apps.apple.com/us/app/id\${IOS_APP_ID}\`;
        }, 1000);
      } else {
        window.location.href = \`\${APP_WEB_URL}/offers/\${offerId}\`;
      }
    }

    document.getElementById("open-app").addEventListener("click", openApp);
  </script>
</body>
</html>`;

      return new Response(htmlResponse, {
        headers: {
          ...corsHeaders,
          "Content-Type": "text/html; charset=utf-8"
        }
      });
    }

    return new Response("Ruta no encontrada", {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "text/plain" }
    });

  } catch (err) {
    console.error("Error interno:", err);
    return new Response("Error interno del servidor", {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "text/plain" }
    });
  }
});
