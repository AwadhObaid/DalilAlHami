const APP_HOST = 'dalilalhami-share.pages.dev'
const PACKAGE_NAME = 'com.awadhobaid.dalilalhami'
const BUSINESS_MEDIA_BUCKET = 'business-media'
const RELEASE_URL =
  'https://github.com/AwadhObaid/DalilAlHami-Releases/releases/latest/download/DalilAlHami.apk'

function text(value) {
  return typeof value === 'string' ? value.trim() : ''
}

function escapeHtml(value) {
  return text(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function safeImageUrl(value) {
  try {
    const uri = new URL(text(value))
    return uri.protocol === 'https:' ? uri.toString() : ''
  } catch {
    return ''
  }
}

function safeBusinessId(value) {
  const candidate = text(value)
  return /^[A-Za-z0-9_-]{1,160}$/.test(candidate) ? candidate : ''
}

function storagePublicUrl(supabaseUrl, storagePath) {
  const path = text(storagePath).replace(/^\/+/, '')
  if (!path) return ''

  const segments = path.split('/')
  if (segments.some((segment) => !segment || segment === '.' || segment === '..')) {
    return ''
  }

  try {
    const base = new URL(text(supabaseUrl))
    if (base.protocol !== 'https:') return ''

    const encodedPath = segments.map(encodeURIComponent).join('/')
    const publicPath =
      `/storage/v1/object/public/${BUSINESS_MEDIA_BUCKET}/${encodedPath}`
    return new URL(publicPath, base).toString()
  } catch {
    return ''
  }
}

function orderedGalleryImages(value) {
  if (!Array.isArray(value)) return []

  return [...value]
    .filter((image) => image && typeof image === 'object')
    .sort((first, second) => {
      const firstPrimary = first.is_primary === true ? 1 : 0
      const secondPrimary = second.is_primary === true ? 1 : 0
      if (firstPrimary !== secondPrimary) return secondPrimary - firstPrimary

      const firstOrder = Number.isFinite(Number(first.sort_order))
        ? Number(first.sort_order)
        : 0
      const secondOrder = Number.isFinite(Number(second.sort_order))
        ? Number(second.sort_order)
        : 0
      if (firstOrder !== secondOrder) return firstOrder - secondOrder

      return text(first.created_at).localeCompare(text(second.created_at))
    })
}

function galleryImageUrl(business, supabaseUrl) {
  const images = orderedGalleryImages(business?.business_images)
  for (const image of images) {
    const publicUrl = safeImageUrl(image.public_url)
    if (publicUrl) return publicUrl

    const derivedUrl = storagePublicUrl(supabaseUrl, image.storage_path)
    if (derivedUrl) return derivedUrl
  }
  return ''
}

function selectPreviewImage(business, supabaseUrl) {
  const coverUrl = safeImageUrl(business?.cover_url)
  if (coverUrl) return { url: coverUrl, source: 'cover' }

  const galleryUrl = galleryImageUrl(business, supabaseUrl)
  if (galleryUrl) return { url: galleryUrl, source: 'gallery' }

  const logoUrl = safeImageUrl(business?.logo_url)
  if (logoUrl) return { url: logoUrl, source: 'logo' }

  return {
    url: `https://${APP_HOST}/share-card.svg`,
    source: 'fallback',
  }
}

async function loadBusiness(env, businessId) {
  const supabaseUrl = text(env.SUPABASE_URL)
  const publishableKey = text(env.SUPABASE_PUBLISHABLE_KEY)
  if (!supabaseUrl || !publishableKey) return null

  const endpoint = new URL('/rest/v1/businesses', supabaseUrl)
  endpoint.searchParams.set('id', `eq.${businessId}`)
  endpoint.searchParams.set('status', 'eq.approved')
  endpoint.searchParams.set('is_active', 'eq.true')
  endpoint.searchParams.set('deleted_at', 'is.null')
  endpoint.searchParams.set(
    'select',
    'id,name,description,address,cover_url,logo_url,'
      + 'business_images(id,storage_path,public_url,alt_text,'
      + 'sort_order,is_primary,created_at)',
  )
  endpoint.searchParams.set('limit', '1')

  const result = await fetch(endpoint, {
    headers: {
      apikey: publishableKey,
      Accept: 'application/json',
    },
  })
  if (!result.ok) return null

  const rows = await result.json().catch(() => [])
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null
}

function renderPage(businessId, business, supabaseUrl) {
  const currentUrl = `https://${APP_HOST}/b/${encodeURIComponent(businessId)}`
  const encodedFallback = encodeURIComponent(RELEASE_URL)
  const intentUrl =
    `intent://${APP_HOST}/b/${encodeURIComponent(businessId)}`
    + `#Intent;scheme=https;package=${PACKAGE_NAME};`
    + `S.browser_fallback_url=${encodedFallback};end`

  const name = escapeHtml(business?.name || 'نشاط على دليل الحامي')
  const address = escapeHtml(business?.address || 'مدينة الحامي')
  const rawDescription = text(business?.description)
  const description = escapeHtml(
    rawDescription || 'شاهد أرقام التواصل والموقع والصور وبقية التفاصيل داخل تطبيق دليل الحامي.',
  )
  const metaDescription = escapeHtml(
    (rawDescription || `اطّلع على تفاصيل ${text(business?.name) || 'النشاط'} في تطبيق دليل الحامي`)
      .slice(0, 180),
  )
  const previewImage = selectPreviewImage(business, supabaseUrl)
  const image = previewImage.url
  const imageAlt = escapeHtml(`صورة ${text(business?.name) || 'النشاط'} على دليل الحامي`)
  const imageMarkup = previewImage.source === 'fallback'
    ? ''
    : `<img class="business-image" src="${escapeHtml(image)}" alt="${imageAlt}">`

  return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#097175">
  <meta name="description" content="${metaDescription}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="دليل الحامي">
  <meta property="og:title" content="${name} – دليل الحامي">
  <meta property="og:description" content="${metaDescription}">
  <meta property="og:url" content="${currentUrl}">
  <meta property="og:image" content="${escapeHtml(image)}">
  <meta property="og:image:secure_url" content="${escapeHtml(image)}">
  <meta property="og:image:alt" content="${imageAlt}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="${escapeHtml(image)}">
  <meta name="twitter:image:alt" content="${imageAlt}">
  <meta name="dalilalhami:preview_image_source" content="${previewImage.source}">
  <link rel="canonical" href="${currentUrl}">
  <title>${name} – دليل الحامي</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <main class="page-shell">
    <section class="business-card">
      <div class="brand-row">
        <img class="brand-logo" src="/logo.png" alt="شعار دليل الحامي">
        <div>
          <p class="eyebrow">نشاط مشارك من دليل الحامي</p>
          <h1>${name}</h1>
        </div>
      </div>
      ${imageMarkup}
      <p class="meta">${address}</p>
      <p class="description">${description}</p>
      <div class="actions">
        <a class="button primary" href="${intentUrl}">فتح النشاط في التطبيق</a>
        <a class="button secondary" href="${RELEASE_URL}">تنزيل التطبيق</a>
      </div>
      <p class="hint">لا يحتاج تصفح النشاط إلى تسجيل حساب.</p>
    </section>
  </main>
</body>
</html>`
}

export async function onRequestGet(context) {
  const businessId = safeBusinessId(context.params.id)
  if (!businessId) {
    return new Response('Invalid business link.', { status: 400 })
  }

  let business = null
  try {
    business = await loadBusiness(context.env, businessId)
  } catch (error) {
    console.error('Unable to load shared business preview', error)
  }

  return new Response(
    renderPage(businessId, business, text(context.env.SUPABASE_URL)),
    {
      status: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'public, max-age=120, stale-while-revalidate=300',
        'Content-Security-Policy':
          "default-src 'self'; img-src 'self' https: data:; style-src 'self'; "
          + "base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
      },
    },
  )
}
