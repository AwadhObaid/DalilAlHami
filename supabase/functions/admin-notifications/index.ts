import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const jsonHeaders = {
  ...corsHeaders,
  'Content-Type': 'application/json; charset=utf-8',
}

type JsonRecord = Record<string, unknown>

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
  token_uri?: string
}

type FcmResult = {
  ok: boolean
  permanentInvalid: boolean
  messageId?: string
  error?: string
}

type AccessTokenCache = {
  token: string
  expiresAt: number
}

let accessTokenCache: AccessTokenCache | null = null

function response(status: number, body: JsonRecord): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : ''
}

function integer(value: unknown, fallback: number): number {
  const parsed = Number.parseInt(String(value ?? ''), 10)
  return Number.isFinite(parsed) ? parsed : fallback
}

function safeSearch(value: unknown): string {
  return text(value)
    .replace(/[^\p{L}\p{N}@\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .slice(0, 80)
}

function uuidArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return []
  }
  const pattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
  return [...new Set(value.map((item) => text(item)).filter((item) => pattern.test(item)))]
    .slice(0, 100)
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message
  }
  if (error && typeof error === 'object' && 'message' in error) {
    const value = text((error as JsonRecord).message)
    if (value) {
      return value
    }
  }
  return String(error)
}

function serviceAccountFromSecret(): ServiceAccount {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? ''
  if (!raw.trim()) {
    throw new Error('Firebase service-account secret is unavailable.')
  }

  let parsed: JsonRecord
  try {
    parsed = JSON.parse(raw) as JsonRecord
  } catch {
    throw new Error('Firebase service-account secret is not valid JSON.')
  }

  const projectId = text(parsed.project_id)
  const clientEmail = text(parsed.client_email)
  const privateKey = text(parsed.private_key)
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('Firebase service-account JSON is incomplete.')
  }

  return {
    project_id: projectId,
    client_email: clientEmail,
    private_key: privateKey,
    token_uri: text(parsed.token_uri) || 'https://oauth2.googleapis.com/token',
  }
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

function base64UrlText(value: string): string {
  return base64UrlBytes(new TextEncoder().encode(value))
}

function pemBytes(value: string): Uint8Array {
  const normalized = value.replace(/\\n/g, '\n')
  const base64 = normalized
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const binary = atob(base64)
  return Uint8Array.from(binary, (character) => character.charCodeAt(0))
}

async function signedJwt(credentials: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = base64UrlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64UrlText(JSON.stringify({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: credentials.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const signingInput = `${header}.${payload}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemBytes(credentials.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  )

  return `${signingInput}.${base64UrlBytes(new Uint8Array(signature))}`
}

async function accessToken(credentials: ServiceAccount): Promise<string> {
  if (
    accessTokenCache &&
    accessTokenCache.expiresAt > Date.now() + 60_000
  ) {
    return accessTokenCache.token
  }

  const assertion = await signedJwt(credentials)
  const tokenResponse = await fetch(
    credentials.token_uri ?? 'https://oauth2.googleapis.com/token',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    },
  )

  const payload = await tokenResponse.json().catch(() => ({})) as JsonRecord
  const token = text(payload.access_token)
  if (!tokenResponse.ok || !token) {
    throw new Error(
      `Unable to obtain Firebase access token: ${text(payload.error_description) || tokenResponse.status}`,
    )
  }

  const expiresIn = Math.max(300, integer(payload.expires_in, 3600))
  accessTokenCache = {
    token,
    expiresAt: Date.now() + (expiresIn * 1000),
  }
  return token
}

function fcmErrorCode(payload: JsonRecord): string {
  const error = payload.error
  if (!error || typeof error !== 'object') {
    return ''
  }
  const details = (error as JsonRecord).details
  if (!Array.isArray(details)) {
    return ''
  }
  for (const detail of details) {
    if (detail && typeof detail === 'object') {
      const code = text((detail as JsonRecord).errorCode)
      if (code) {
        return code
      }
    }
  }
  return ''
}

async function sendFcmMessage(
  credentials: ServiceAccount,
  message: JsonRecord,
): Promise<FcmResult> {
  const token = await accessToken(credentials)
  const endpoint = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(credentials.project_id)}/messages:send`
  const result = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: JSON.stringify({ message }),
  })

  const payload = await result.json().catch(() => ({})) as JsonRecord
  if (result.ok) {
    return {
      ok: true,
      permanentInvalid: false,
      messageId: text(payload.name),
    }
  }

  if (result.status === 401) {
    accessTokenCache = null
  }

  const code = fcmErrorCode(payload)
  const firebaseError = payload.error && typeof payload.error === 'object'
    ? text((payload.error as JsonRecord).message)
    : ''
  return {
    ok: false,
    permanentInvalid: code === 'UNREGISTERED',
    error: firebaseError || code || `FCM HTTP ${result.status}`,
  }
}

function notificationData(
  notificationId: string,
  navigationType: string,
  businessId: string,
): Record<string, string> {
  return {
    notification_id: notificationId,
    type: navigationType,
    ...(businessId ? { business_id: businessId } : {}),
  }
}

function fcmPayload(
  title: string,
  body: string,
  data: Record<string, string>,
): JsonRecord {
  return {
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: {
        channel_id: 'dalil_alhami_push',
        sound: 'default',
      },
    },
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (request.method !== 'POST') {
    return response(405, { message: 'Only POST requests are supported.' })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!supabaseUrl || !serviceRoleKey) {
    return response(500, { message: 'Supabase function secrets are unavailable.' })
  }

  const authorization = request.headers.get('Authorization') ?? ''
  const token = authorization.replace(/^Bearer\s+/i, '').trim()
  if (!token) {
    return response(401, { message: 'يجب تسجيل الدخول أولًا.' })
  }

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })

  const { data: callerData, error: callerError } = await service.auth.getUser(token)
  const caller = callerData.user
  if (callerError || !caller) {
    return response(401, { message: 'جلسة تسجيل الدخول غير صالحة.' })
  }

  const { data: actorProfile, error: actorError } = await service
    .from('profiles')
    .select('id, role, is_active, deleted_at')
    .eq('id', caller.id)
    .maybeSingle()

  if (
    actorError ||
    !actorProfile ||
    actorProfile.role !== 'admin' ||
    actorProfile.is_active !== true ||
    actorProfile.deleted_at !== null
  ) {
    return response(403, { message: 'لا يملك الحساب صلاحية إدارة الإشعارات.' })
  }

  let body: JsonRecord
  try {
    const parsed = await request.json()
    body = parsed && typeof parsed === 'object' ? parsed as JsonRecord : {}
  } catch {
    return response(400, { message: 'صيغة الطلب غير صالحة.' })
  }

  const action = text(body.action)

  try {
    if (action === 'user_options') {
      const queryText = safeSearch(body.query)
      let query = service
        .from('profiles')
        .select('id, full_name, email, phone')
        .eq('is_active', true)
        .is('deleted_at', null)
        .order('full_name', { ascending: true })
        .limit(100)

      if (queryText) {
        const pattern = `%${queryText.split(' ').join('%')}%`
        query = query.or(
          `full_name.ilike.${pattern},email.ilike.${pattern},phone.ilike.${pattern}`,
        )
      }

      const { data, error } = await query
      if (error) {
        throw error
      }
      return response(200, { users: data ?? [] })
    }

    if (action === 'history') {
      const limit = Math.min(50, Math.max(5, integer(body.limit, 30)))
      const { data: rows, error } = await service
        .from('app_notifications')
        .select(
          'id, title, body, target_type, target_user_id, navigation_type, '
          + 'business_id, delivery_status, delivery_attempt_count, '
          + 'delivery_success_count, error_message, created_at',
        )
        .is('admin_hidden_at', null)
        .order('created_at', { ascending: false })
        .limit(limit)
      if (error) {
        throw error
      }

      const values = rows ?? []
      const userIds = [...new Set(
        values.map((row) => text(row.target_user_id)).filter(Boolean),
      )]
      const businessIds = [...new Set(
        values.map((row) => text(row.business_id)).filter(Boolean),
      )]

      const userNames = new Map<string, string>()
      if (userIds.length > 0) {
        const { data, error: usersError } = await service
          .from('profiles')
          .select('id, full_name, email, phone')
          .in('id', userIds)
        if (usersError) {
          throw usersError
        }
        for (const row of data ?? []) {
          const id = text(row.id)
          const label = text(row.full_name) || text(row.email) || text(row.phone)
          if (id) {
            userNames.set(id, label || 'مستخدم')
          }
        }
      }

      const businessNames = new Map<string, string>()
      if (businessIds.length > 0) {
        const { data, error: businessesError } = await service
          .from('businesses')
          .select('id, name')
          .in('id', businessIds)
        if (businessesError) {
          throw businessesError
        }
        for (const row of data ?? []) {
          const id = text(row.id)
          if (id) {
            businessNames.set(id, text(row.name))
          }
        }
      }

      return response(200, {
        notifications: values.map((row) => ({
          ...row,
          target_user_name: userNames.get(text(row.target_user_id)) ?? null,
          business_name: businessNames.get(text(row.business_id)) ?? null,
        })),
      })
    }

    if (action === 'hide_history') {
      const notificationIds = uuidArray(body.notification_ids)
      if (notificationIds.length === 0) {
        return response(400, { message: 'اختر إشعارًا واحدًا على الأقل من السجل.' })
      }

      const { data, error } = await service
        .from('app_notifications')
        .update({ admin_hidden_at: new Date().toISOString() })
        .in('id', notificationIds)
        .is('admin_hidden_at', null)
        .select('id')
      if (error) {
        throw error
      }

      return response(200, {
        message: 'تم تنظيف السجل المحدد دون حذف إشعارات المستخدمين.',
        hidden_count: (data ?? []).length,
      })
    }

    if (action === 'clear_history') {
      const { data, error } = await service
        .from('app_notifications')
        .update({ admin_hidden_at: new Date().toISOString() })
        .is('admin_hidden_at', null)
        .select('id')
      if (error) {
        throw error
      }

      return response(200, {
        message: 'تم تنظيف سجل الإشعارات دون حذف إشعارات المستخدمين.',
        hidden_count: (data ?? []).length,
      })
    }

    if (action === 'send') {
      const title = text(body.title)
      const messageBody = text(body.body)
      const targetType = text(body.target_type)
      const targetUserId = text(body.target_user_id)
      const navigationType = text(body.navigation_type) || 'notifications'
      const businessId = text(body.business_id)

      if (title.length < 2 || title.length > 120) {
        return response(400, { message: 'عنوان الإشعار يجب أن يكون بين 2 و120 حرفًا.' })
      }
      if (messageBody.length < 1 || messageBody.length > 600) {
        return response(400, { message: 'نص الإشعار يجب ألا يتجاوز 600 حرف.' })
      }
      if (!['public', 'user'].includes(targetType)) {
        return response(400, { message: 'نوع مستلمي الإشعار غير صالح.' })
      }
      if (
        !['notifications', 'home', 'categories', 'search', 'account', 'business']
          .includes(navigationType)
      ) {
        return response(400, { message: 'وجهة الإشعار داخل التطبيق غير صالحة.' })
      }
      if (targetType === 'user' && !targetUserId) {
        return response(400, { message: 'اختر المستخدم المستهدف.' })
      }
      if (navigationType === 'business' && !businessId) {
        return response(400, { message: 'اختر النشاط الذي سيفتحه الإشعار.' })
      }

      if (targetType === 'user') {
        const { data: target, error } = await service
          .from('profiles')
          .select('id, is_active, deleted_at')
          .eq('id', targetUserId)
          .maybeSingle()
        if (error || !target || target.is_active !== true || target.deleted_at !== null) {
          return response(404, { message: 'المستخدم المستهدف غير موجود أو غير نشط.' })
        }
      }

      if (navigationType === 'business') {
        const { data: business, error } = await service
          .from('businesses')
          .select('id, deleted_at')
          .eq('id', businessId)
          .maybeSingle()
        if (error || !business || business.deleted_at !== null) {
          return response(404, { message: 'النشاط المرتبط بالإشعار غير متاح.' })
        }
      }

      const { data: inserted, error: insertError } = await service
        .from('app_notifications')
        .insert({
          title,
          body: messageBody,
          target_type: targetType,
          target_user_id: targetType === 'user' ? targetUserId : null,
          navigation_type: navigationType,
          business_id: navigationType === 'business' ? businessId : null,
          data: {},
          created_by: caller.id,
          delivery_status: 'pending',
        })
        .select('id, created_at')
        .single()
      if (insertError || !inserted) {
        throw insertError ?? new Error('Unable to create notification record.')
      }

      const notificationId = text(inserted.id)
      const credentials = serviceAccountFromSecret()
      const data = notificationData(notificationId, navigationType, businessId)
      const baseMessage = fcmPayload(title, messageBody, data)

      let attemptCount = 0
      let successCount = 0
      let deliveryStatus = 'sent'
      let storedError = ''

      if (targetType === 'public') {
        attemptCount = 1
        const result = await sendFcmMessage(credentials, {
          ...baseMessage,
          topic: 'dalil_alhami_public',
        })
        if (result.ok) {
          successCount = 1
        } else {
          deliveryStatus = 'failed'
          storedError = result.error ?? 'FCM topic send failed.'
        }
      } else {
        const { data: deviceRows, error: devicesError } = await service
          .from('push_notification_devices')
          .select('fcm_token')
          .eq('user_id', targetUserId)
          .eq('enabled', true)
        if (devicesError) {
          throw devicesError
        }

        const tokens = (deviceRows ?? [])
          .map((row) => text(row.fcm_token))
          .filter(Boolean)
        attemptCount = tokens.length

        if (tokens.length === 0) {
          deliveryStatus = 'no_devices'
        } else {
          const failures: string[] = []
          for (const deviceToken of tokens) {
            const result = await sendFcmMessage(credentials, {
              ...baseMessage,
              token: deviceToken,
            })
            if (result.ok) {
              successCount += 1
            } else {
              failures.push(result.error ?? 'FCM device send failed.')
              if (result.permanentInvalid) {
                await service
                  .from('push_notification_devices')
                  .update({ enabled: false, updated_at: new Date().toISOString() })
                  .eq('fcm_token', deviceToken)
              }
            }
          }
          if (successCount === 0) {
            deliveryStatus = 'failed'
          } else if (successCount < attemptCount) {
            deliveryStatus = 'partial'
          }
          storedError = failures.slice(0, 3).join(' | ')
        }
      }

      const { error: updateError } = await service
        .from('app_notifications')
        .update({
          delivery_status: deliveryStatus,
          delivery_attempt_count: attemptCount,
          delivery_success_count: successCount,
          error_message: storedError || null,
          sent_at: new Date().toISOString(),
        })
        .eq('id', notificationId)
      if (updateError) {
        throw updateError
      }

      if (deliveryStatus === 'failed') {
        return response(502, {
          message: 'تم حفظ الإشعار في المركز، لكن تعذر إرساله عبر Firebase.',
          notification_id: notificationId,
          delivery_status: deliveryStatus,
          attempt_count: attemptCount,
          success_count: successCount,
          error: storedError,
        })
      }

      const message = deliveryStatus === 'no_devices'
        ? 'تم حفظ الإشعار في مركز المستخدم، ولا يوجد جهاز نشط لاستقبال التنبيه الآن.'
        : deliveryStatus === 'partial'
        ? 'تم إرسال الإشعار إلى بعض أجهزة المستخدم وحفظه في المركز.'
        : 'تم إرسال الإشعار وحفظه في مركز الإشعارات.'

      return response(200, {
        message,
        notification_id: notificationId,
        delivery_status: deliveryStatus,
        attempt_count: attemptCount,
        success_count: successCount,
      })
    }

    return response(400, { message: 'عملية إدارة الإشعارات غير معروفة.' })
  } catch (error) {
    console.error('admin-notifications error', error)
    const message = errorMessage(error)
    if (message.includes('Firebase service-account')) {
      return response(500, {
        message: 'بيانات Firebase الآمنة غير مكتملة على الخادم.',
      })
    }
    if (message.includes('Unable to obtain Firebase access token')) {
      return response(502, {
        message: 'تعذر تفويض خدمة Firebase لإرسال الإشعار.',
      })
    }
    return response(500, {
      message: 'تعذر تنفيذ عملية الإشعارات. تحقق من إعدادات الخادم ثم أعد المحاولة.',
    })
  }
})
