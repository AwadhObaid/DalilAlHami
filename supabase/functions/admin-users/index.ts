import { createClient, type User } from 'npm:@supabase/supabase-js@2'

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

type AuditRow = {
  id: string
  actor_id: string | null
  action: string
  reason: string | null
  created_at: string
}

type ProfileRow = {
  id: string
  full_name: string | null
  email: string | null
  phone: string | null
  avatar_url: string | null
  role: string | null
  is_active: boolean | null
  suspension_reason: string | null
  suspended_at: string | null
  deleted_at: string | null
  created_at: string | null
  updated_at: string | null
}

function response(status: number, body: JsonRecord): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : ''
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message
  }
  if (error && typeof error === 'object' && 'message' in error) {
    const message = text((error as JsonRecord).message)
    if (message) {
      return message
    }
  }
  return String(error)
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

function previousBanDuration(user: User): string {
  const bannedUntil = Date.parse(user.banned_until ?? '')
  const remainingMilliseconds = bannedUntil - Date.now()
  if (!Number.isFinite(bannedUntil) || remainingMilliseconds <= 0) {
    return 'none'
  }
  return `${Math.max(1, Math.ceil(remainingMilliseconds / 1000))}s`
}

function providers(user: User | null): string[] {
  const values = user?.identities
    ?.map((identity: { provider?: string | null }) => text(identity.provider))
    .filter((value: string) => value.length > 0) ?? []
  return [...new Set<string>(values)]
}

function authMap(user: User | null): JsonRecord {
  if (!user) {
    return {
      last_sign_in_at: null,
      email_confirmed_at: null,
      banned_until: null,
      providers: [],
    }
  }
  return {
    last_sign_in_at: user.last_sign_in_at ?? null,
    email_confirmed_at: user.email_confirmed_at ?? null,
    banned_until: user.banned_until ?? null,
    providers: providers(user),
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
    return response(403, { message: 'لا يملك الحساب صلاحية إدارة المستخدمين.' })
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
    if (action === 'list') {
      const page = Math.max(1, integer(body.page, 1))
      const perPage = Math.min(50, Math.max(5, integer(body.per_page, 20)))
      const from = (page - 1) * perPage
      const to = from + perPage - 1
      const status = ['active', 'suspended', 'deleted'].includes(text(body.status))
        ? text(body.status)
        : 'all'
      const role = ['user', 'admin'].includes(text(body.role))
        ? text(body.role)
        : 'all'
      const queryText = safeSearch(body.query)

      let profilesQuery = service
        .from('profiles')
        .select(
          'id, full_name, email, phone, avatar_url, role, is_active, '
          + 'suspension_reason, suspended_at, deleted_at, created_at, updated_at',
          { count: 'exact' },
        )
        .order('created_at', { ascending: false })
        .range(from, to)

      if (status === 'active') {
        profilesQuery = profilesQuery.eq('is_active', true).is('deleted_at', null)
      } else if (status === 'suspended') {
        profilesQuery = profilesQuery.eq('is_active', false).is('deleted_at', null)
      } else if (status === 'deleted') {
        profilesQuery = profilesQuery.not('deleted_at', 'is', null)
      }
      if (role !== 'all') {
        profilesQuery = profilesQuery.eq('role', role)
      }
      if (queryText) {
        const pattern = `%${queryText.split(' ').join('%')}%`
        profilesQuery = profilesQuery.or(
          `full_name.ilike.${pattern},email.ilike.${pattern},phone.ilike.${pattern}`,
        )
      }

      const [
        profilesResult,
        activeResult,
        suspendedResult,
        deletedResult,
        adminResult,
      ] = await Promise.all([
        profilesQuery,
        service
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('is_active', true)
          .is('deleted_at', null),
        service
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('is_active', false)
          .is('deleted_at', null),
        service
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .not('deleted_at', 'is', null),
        service
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('role', 'admin')
          .eq('is_active', true)
          .is('deleted_at', null),
      ])

      if (profilesResult.error) {
        throw profilesResult.error
      }
      for (const result of [
        activeResult,
        suspendedResult,
        deletedResult,
        adminResult,
      ]) {
        if (result.error) {
          throw result.error
        }
      }

      const profiles = (profilesResult.data ?? []) as ProfileRow[]
      const ids = profiles.map((profile) => profile.id)
      const businessCounts = new Map<string, number>()
      if (ids.length > 0) {
        const { data: businessRows, error: businessesError } = await service
          .from('businesses')
          .select('owner_id')
          .in('owner_id', ids)
        if (businessesError) {
          throw businessesError
        }
        for (const row of businessRows ?? []) {
          const ownerId = text(row.owner_id)
          if (ownerId) {
            businessCounts.set(ownerId, (businessCounts.get(ownerId) ?? 0) + 1)
          }
        }
      }

      const authUsers = await Promise.all(
        ids.map(async (id) => {
          const { data, error } = await service.auth.admin.getUserById(id)
          return error ? null : data.user
        }),
      )
      const authById = new Map<string, User | null>()
      for (let index = 0; index < ids.length; index += 1) {
        authById.set(ids[index], authUsers[index])
      }

      const users = profiles.map((profile) => {
        const authUser = authById.get(profile.id) ?? null
        return {
          ...profile,
          email: profile.email ?? authUser?.email ?? '',
          phone: profile.phone ?? authUser?.phone ?? '',
          business_count: businessCounts.get(profile.id) ?? 0,
          is_current_user: profile.id === caller.id,
          ...authMap(authUser),
        }
      })

      return response(200, {
        users,
        page,
        per_page: perPage,
        total: profilesResult.count ?? 0,
        active_count: activeResult.count ?? 0,
        suspended_count: suspendedResult.count ?? 0,
        deleted_count: deletedResult.count ?? 0,
        admin_count: adminResult.count ?? 0,
      })
    }

    if (action === 'detail') {
      const userId = text(body.user_id)
      if (!userId) {
        return response(400, { message: 'معرّف المستخدم مطلوب.' })
      }

      const [{ data: profile, error: profileError }, authResult, businessesResult, auditsResult] =
        await Promise.all([
          service
            .from('profiles')
            .select(
              'id, full_name, email, phone, avatar_url, role, is_active, '
              + 'suspension_reason, suspended_at, deleted_at, created_at, updated_at',
            )
            .eq('id', userId)
            .maybeSingle(),
          service.auth.admin.getUserById(userId),
          service
            .from('businesses')
            .select('id, name, status, is_active, created_at')
            .eq('owner_id', userId)
            .order('created_at', { ascending: false }),
          service
            .from('admin_user_actions')
            .select('id, actor_id, action, reason, created_at')
            .eq('target_user_id', userId)
            .order('created_at', { ascending: false })
            .limit(30),
        ])

      if (profileError || !profile) {
        return response(404, { message: 'لم يعد المستخدم موجودًا.' })
      }
      if (businessesResult.error) {
        throw businessesResult.error
      }
      if (auditsResult.error) {
        throw auditsResult.error
      }

      const authUser = authResult.error ? null : authResult.data.user
      const auditRows = (auditsResult.data ?? []) as AuditRow[]
      const actorIds = [...new Set(auditRows.map((row) => text(row.actor_id)).filter(Boolean))]
      const actorNames = new Map<string, string>()
      if (actorIds.length > 0) {
        const { data: actors } = await service
          .from('profiles')
          .select('id, full_name, email')
          .in('id', actorIds)
        for (const actor of actors ?? []) {
          actorNames.set(
            text(actor.id),
            text(actor.full_name) || text(actor.email) || 'مدير النظام',
          )
        }
      }

      return response(200, {
        user: {
          ...profile,
          email: profile.email ?? authUser?.email ?? '',
          phone: profile.phone ?? authUser?.phone ?? '',
          business_count: businessesResult.data?.length ?? 0,
          is_current_user: profile.id === caller.id,
          ...authMap(authUser),
        },
        businesses: businessesResult.data ?? [],
        audit_entries: auditRows.map((row) => ({
          ...row,
          actor_name: actorNames.get(text(row.actor_id)) ?? 'مدير النظام',
        })),
      })
    }

    if (
      action === 'set_status' ||
      action === 'set_role' ||
      action === 'set_deleted'
    ) {
      const userId = text(body.user_id)
      if (!userId) {
        return response(400, { message: 'معرّف المستخدم مطلوب.' })
      }
      if (userId === caller.id) {
        return response(409, { message: 'لا يمكنك تغيير دور حسابك أو حالته بنفسك.' })
      }

      const { data: targetProfile, error: targetProfileError } = await service
        .from('profiles')
        .select('id, role, is_active, deleted_at')
        .eq('id', userId)
        .maybeSingle()
      if (targetProfileError || !targetProfile) {
        return response(404, { message: 'لم يعد المستخدم موجودًا.' })
      }

      const authBeforeResult = await service.auth.admin.getUserById(userId)
      if (authBeforeResult.error || !authBeforeResult.data.user) {
        return response(404, { message: 'حساب المصادقة غير موجود.' })
      }
      const authBefore = authBeforeResult.data.user

      if (action === 'set_status') {
        if (targetProfile.deleted_at) {
          return response(409, {
            message: 'استعد الحساب المحذوف ظاهريًا قبل تغيير حالته.',
          })
        }
        const isActive = body.is_active === true
        const reason = text(body.reason)
        if (!isActive && reason.length < 5) {
          return response(400, { message: 'اكتب سببًا واضحًا لا يقل عن خمسة أحرف.' })
        }

        const desiredBan = isActive ? 'none' : '876000h'
        const rollbackBan = previousBanDuration(authBefore)
        const authUpdate = await service.auth.admin.updateUserById(userId, {
          ban_duration: desiredBan,
        })
        if (authUpdate.error) {
          throw authUpdate.error
        }

        const dbAction = isActive ? 'activate' : 'suspend'
        const dbResult = await service.rpc('admin_apply_user_change', {
          p_actor_id: caller.id,
          p_target_user_id: userId,
          p_action: dbAction,
          p_reason: isActive ? null : reason,
        })
        if (dbResult.error) {
          await service.auth.admin.updateUserById(userId, {
            ban_duration: rollbackBan,
          })
          throw dbResult.error
        }
        return response(200, dbResult.data as JsonRecord)
      }

      if (action === 'set_deleted') {
        const isDeleted = body.is_deleted === true
        const reason = text(body.reason)
        if (isDeleted && reason.length < 5) {
          return response(400, {
            message: 'اكتب سببًا واضحًا لا يقل عن خمسة أحرف.',
          })
        }

        const desiredBan = isDeleted ? '876000h' : 'none'
        const rollbackBan = previousBanDuration(authBefore)
        const authUpdate = await service.auth.admin.updateUserById(userId, {
          ban_duration: desiredBan,
        })
        if (authUpdate.error) {
          throw authUpdate.error
        }

        const dbResult = await service.rpc('admin_apply_user_change', {
          p_actor_id: caller.id,
          p_target_user_id: userId,
          p_action: isDeleted ? 'soft_delete' : 'restore',
          p_reason: isDeleted ? reason : null,
        })
        if (dbResult.error) {
          await service.auth.admin.updateUserById(userId, {
            ban_duration: rollbackBan,
          })
          throw dbResult.error
        }
        return response(200, dbResult.data as JsonRecord)
      }

      if (targetProfile.deleted_at) {
        return response(409, {
          message: 'استعد الحساب المحذوف ظاهريًا قبل تغيير دوره.',
        })
      }

      const role = text(body.role)
      if (!['user', 'admin'].includes(role)) {
        return response(400, { message: 'الدور المطلوب غير صالح.' })
      }

      const previousMetadata = { ...(authBefore.app_metadata ?? {}) }
      const nextMetadata = { ...previousMetadata, app_role: role }
      const authUpdate = await service.auth.admin.updateUserById(userId, {
        app_metadata: nextMetadata,
      })
      if (authUpdate.error) {
        throw authUpdate.error
      }

      const dbResult = await service.rpc('admin_apply_user_change', {
        p_actor_id: caller.id,
        p_target_user_id: userId,
        p_action: role === 'admin' ? 'promote' : 'demote',
        p_reason: null,
      })
      if (dbResult.error) {
        await service.auth.admin.updateUserById(userId, {
          app_metadata: previousMetadata,
        })
        throw dbResult.error
      }
      return response(200, dbResult.data as JsonRecord)
    }

    return response(400, { message: 'عملية إدارة المستخدم غير معروفة.' })
  } catch (error) {
    const message = errorMessage(error)
    if (message.includes('last active administrator')) {
      return response(409, { message: 'لا يمكن إيقاف أو تخفيض صلاحية آخر مدير نشط.' })
    }
    if (message.includes('cannot change their own')) {
      return response(409, { message: 'لا يمكنك تغيير دور حسابك أو حالته بنفسك.' })
    }
    if (message.includes('soft-deleted')) {
      return response(409, {
        message: 'استعد الحساب المحذوف ظاهريًا قبل تنفيذ العملية.',
      })
    }
    if (message.includes('Administrator access')) {
      return response(403, { message: 'لا يملك الحساب صلاحية تنفيذ العملية.' })
    }
    if (message.includes('not found')) {
      return response(404, { message: 'لم يعد المستخدم موجودًا.' })
    }
    console.error('admin-users error', error)
    return response(500, { message: 'تعذر تنفيذ عملية إدارة المستخدم.' })
  }
})
