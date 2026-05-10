import { useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import {
  BadgeCheck,
  ChevronRight,
  KeyRound,
  LogOut,
  Menu as MenuIcon,
  HeartHandshake,
  Monitor,
  Moon,
  ImageUp,
  PanelLeft,
  RefreshCw,
  Shield,
  Sun,
  Users,
} from 'lucide-react'
import './App.css'

import type {
  AdminSession,
  ApiResponse,
  ConfirmDialogState,
  DatingMatch,
  DatingMessage,
  DatingPhoto,
  DatingSettings,
  DatingUser,
  Entity,
  LoginResponse,
  Menu,
  MenuForm,
  MobileAccount,
  Profile,
  Role,
  RoleForm,
  ThemeMode,
  User,
  UserForm,
} from './adminTypes'
import { ConfirmDialog } from './components/confirm'
import { MenuManagementSection, buildMenuTree } from './features/menus'
import { RoleManagementSection } from './features/roles'
import { UserManagementSection } from './features/users'
import { DatingOperationsSection } from './features/dating'

const emptyUser: UserForm = {
  username: '',
  nickname: '',
  password: '',
  roleIds: [],
}

const emptyRole: RoleForm = {
  name: '',
  key: '',
  menuIds: [],
}

const emptyMenu: MenuForm = {
  name: '',
  path: '',
  parentId: 0,
  type: 'menu',
  permission: '',
}

type ChildNavItem = {
  key: Entity
  label: string
  icon: typeof Users
  path: string
}

type NavItem = {
  key: Entity | 'dating'
  label: string
  icon: typeof Users
  path: string
  children?: ChildNavItem[]
}

const tabs: NavItem[] = [
  { key: 'users', label: '用户', icon: Users, path: '/system/user' },
  { key: 'roles', label: '角色', icon: Shield, path: '/system/role' },
  { key: 'menus', label: '菜单', icon: MenuIcon, path: '/system/menu' },
  {
    key: 'dating',
    label: '婚恋运营',
    icon: HeartHandshake,
    path: '/dating',
    children: [
      { key: 'dating-users', label: '婚恋用户', icon: Users, path: '/dating/users' },
      { key: 'dating-photos', label: '照片审核', icon: ImageUp, path: '/dating/photos' },
      { key: 'dating-matches', label: '匹配与聊天', icon: HeartHandshake, path: '/dating/matches' },
      { key: 'dating-accounts', label: '移动端账号', icon: KeyRound, path: '/dating/accounts' },
    ],
  },
]

const adminRememberKey = 'admin.remember'
const adminUsernameKey = 'admin.username'
const adminPasswordKey = 'admin.password'
const adminSessionKey = 'admin.session'
const adminThemeKey = 'admin.theme'
const themeOrder: ThemeMode[] = ['system', 'light', 'dark']

function getStoredTheme(): ThemeMode {
  const value = localStorage.getItem(adminThemeKey)
  return value === 'light' || value === 'dark' || value === 'system' ? value : 'system'
}

function getThemeLabel(theme: ThemeMode) {
  if (theme === 'light') return '明亮'
  if (theme === 'dark') return '暗色'
  return '跟随系统'
}

function getThemeIcon(theme: ThemeMode) {
  if (theme === 'light') return Sun
  if (theme === 'dark') return Moon
  return Monitor
}

function nextTheme(theme: ThemeMode): ThemeMode {
  return themeOrder[(themeOrder.indexOf(theme) + 1) % themeOrder.length]
}

function isDatingSection(active: Entity): active is Extract<Entity, 'dating-users' | 'dating-photos' | 'dating-matches' | 'dating-accounts'> {
  return active.startsWith('dating-')
}

function isEntityKey(key: NavItem['key']): key is Entity {
  return key !== 'dating'
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const headers: Record<string, string> = {
    ...authHeaders(),
  }
  if (!(init?.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json'
  }
  const res = await fetch(url, {
    ...init,
    headers: {
      ...headers,
      ...(init?.headers as Record<string, string> | undefined),
    },
  })
  const body = (await res.json()) as ApiResponse<T>
  if (!res.ok || body.code !== 0) {
    throw new Error(body.msg || '请求失败')
  }
  return body.data as T
}

function authHeaders(): Record<string, string> {
  const rawSession = localStorage.getItem(adminSessionKey)
  let session: AdminSession | null = null
  try {
    session = rawSession ? (JSON.parse(rawSession) as AdminSession) : null
  } catch {
    localStorage.removeItem(adminSessionKey)
  }
  const authHeaders: Record<string, string> = session?.token
    ? { Authorization: `Bearer ${session.token}` }
    : {}
  return authHeaders
}

async function fetchAssetObjectURL(url: string): Promise<string> {
  const res = await fetch(url, { headers: authHeaders() })
  if (!res.ok) {
    throw new Error('加载头像失败')
  }
  return URL.createObjectURL(await res.blob())
}

function App() {
  const [theme, setTheme] = useState<ThemeMode>(getStoredTheme)
  const [session, setSession] = useState<AdminSession | null>(() => {
    const raw = localStorage.getItem(adminSessionKey)
    if (!raw) return null
    try {
      const stored = JSON.parse(raw) as AdminSession
      if (!stored.permissions || !stored.menuPaths) {
        localStorage.removeItem(adminSessionKey)
        return null
      }
      return stored
    } catch {
      localStorage.removeItem(adminSessionKey)
      return null
    }
  })

  function handleLoggedIn(nextSession: AdminSession) {
    const nextThemeValue = nextSession.theme ?? getStoredTheme()
    localStorage.setItem(adminSessionKey, JSON.stringify(nextSession))
    setTheme(nextThemeValue)
    setSession(nextSession)
  }

  function handleLogout() {
    localStorage.removeItem(adminSessionKey)
    setSession(null)
  }

  function handleThemeChange() {
    const next = nextTheme(theme)
    setTheme(next)
    if (!session) return
    const nextSession = { ...session, theme: next }
    localStorage.setItem(adminSessionKey, JSON.stringify(nextSession))
    setSession(nextSession)
    void request('/api/admin/profile/theme', {
      method: 'PUT',
      body: JSON.stringify({ theme: next }),
    })
  }

  function handleSessionChange(nextSession: AdminSession) {
    localStorage.setItem(adminSessionKey, JSON.stringify(nextSession))
    setSession(nextSession)
  }

  useEffect(() => {
    localStorage.setItem(adminThemeKey, theme)
    document.documentElement.dataset.theme = theme
  }, [theme])

  useEffect(() => {
    if (session?.theme) {
      setTheme(session.theme)
    }
  }, [session?.username])

  if (!session) {
    return <AdminLogin theme={theme} onThemeChange={handleThemeChange} onLoggedIn={handleLoggedIn} />
  }

  return (
    <AdminDashboard
      session={session}
      theme={theme}
      onSessionChange={handleSessionChange}
      onThemeChange={handleThemeChange}
      onLogout={handleLogout}
    />
  )
}

function AdminLogin({
  theme,
  onThemeChange,
  onLoggedIn,
}: {
  theme: ThemeMode
  onThemeChange: () => void
  onLoggedIn: (session: AdminSession) => void
}) {
  const [username, setUsername] = useState(() => localStorage.getItem(adminUsernameKey) ?? 'admin')
  const [password, setPassword] = useState(() => localStorage.getItem(adminPasswordKey) ?? '')
  const [remember, setRemember] = useState(() => localStorage.getItem(adminRememberKey) === 'true')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function login(event: FormEvent) {
    event.preventDefault()
    if (!username.trim() || !password) {
      setError('请输入用户名和密码')
      return
    }
    setLoading(true)
    setError('')
    try {
      const data = await request<LoginResponse>('/api/admin/login', {
        method: 'POST',
        body: JSON.stringify({ username: username.trim(), password }),
      })
      if (remember) {
        localStorage.setItem(adminRememberKey, 'true')
        localStorage.setItem(adminUsernameKey, username.trim())
        localStorage.setItem(adminPasswordKey, password)
      } else {
        localStorage.removeItem(adminRememberKey)
        localStorage.removeItem(adminUsernameKey)
        localStorage.removeItem(adminPasswordKey)
      }
      onLoggedIn(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : '登录失败')
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="login-shell">
      <ThemeButton theme={theme} onThemeChange={onThemeChange} className="login-theme" />
      <form className="login-card" onSubmit={login}>
        <span className="brand-mark">
          <PanelLeft size={18} strokeWidth={2.2} />
        </span>
        <div className="login-heading">
          <p className="eyebrow">Admin Go</p>
          <h1>后台登录</h1>
          <p>使用角色和按钮权限管理后台操作。</p>
        </div>
        <label>
          用户名
          <input value={username} onChange={(event) => setUsername(event.target.value)} />
        </label>
        <label>
          密码
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
        </label>
        <label className="remember-row">
          <input
            checked={remember}
            type="checkbox"
            onChange={(event) => setRemember(event.target.checked)}
          />
          <span>记住密码</span>
        </label>
        {error && <span className="status error">{error}</span>}
        <button className="primary-button" disabled={loading} type="submit">
          <KeyRound size={15} />
          {loading ? '登录中...' : '登录'}
        </button>
      </form>
    </main>
  )
}

function AdminDashboard({
  session,
  theme,
  onSessionChange,
  onThemeChange,
  onLogout,
}: {
  session: AdminSession
  theme: ThemeMode
  onSessionChange: (session: AdminSession) => void
  onThemeChange: () => void
  onLogout: () => void
}) {
  const [active, setActive] = useState<Entity>('users')
  const [users, setUsers] = useState<User[]>([])
  const [roles, setRoles] = useState<Role[]>([])
  const [menus, setMenus] = useState<Menu[]>([])
  const [datingUsers, setDatingUsers] = useState<DatingUser[]>([])
  const [datingPhotos, setDatingPhotos] = useState<DatingPhoto[]>([])
  const [datingMatches, setDatingMatches] = useState<DatingMatch[]>([])
  const [datingMessages, setDatingMessages] = useState<DatingMessage[]>([])
  const [datingSettings, setDatingSettings] = useState<DatingSettings>({ photoReviewEnabled: true })
  const [mobileAccounts, setMobileAccounts] = useState<MobileAccount[]>([])
  const [selectedDatingMatchId, setSelectedDatingMatchId] = useState<number | null>(null)
  const [userForm, setUserForm] = useState<UserForm>(emptyUser)
  const [roleForm, setRoleForm] = useState<RoleForm>(emptyRole)
  const [menuForm, setMenuForm] = useState<MenuForm>(emptyMenu)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [notice, setNotice] = useState('正在加载管理数据')
  const [error, setError] = useState('')
  const [avatarPreview, setAvatarPreview] = useState('')
  const [avatarRefreshKey, setAvatarRefreshKey] = useState(0)
  const [confirmDialog, setConfirmDialog] = useState<ConfirmDialogState | null>(null)
  const [userMenuOpen, setUserMenuOpen] = useState(false)
  const userMenuRef = useRef<HTMLDivElement | null>(null)

  const roleNameByID = useMemo(
    () => new Map(roles.map((role) => [role.id, role.name])),
    [roles],
  )
  const menuNameByID = useMemo(
    () => new Map(menus.map((menu) => [menu.id, menu.name])),
    [menus],
  )
  const pageMenus = useMemo(() => menus.filter((menu) => menu.type !== 'button'), [menus])
  const buttonMenus = useMemo(() => menus.filter((menu) => menu.type === 'button'), [menus])
  const menuTree = useMemo(() => buildMenuTree(menus), [menus])
  const permissions = useMemo(() => new Set(session.permissions ?? []), [session.permissions])
  const menuPaths = useMemo(() => new Set(session.menuPaths ?? []), [session.menuPaths])
  const visibleTabs = useMemo(
    () =>
      tabs
        .map((tab) => {
          if (!tab.children) return tab
          const children = menuPaths.has(tab.path)
            ? tab.children
            : tab.children.filter((child) => menuPaths.has(child.path))
          return children.length > 0 ? { ...tab, children } : tab
        })
        .filter((tab) => menuPaths.has(tab.path) || Boolean(tab.children?.length)),
    [menuPaths],
  )
  const flatVisibleTabs = useMemo<ChildNavItem[]>(
    () =>
      visibleTabs.flatMap((tab) => {
        if (tab.children?.length) return tab.children
        return isEntityKey(tab.key) ? [{ key: tab.key, label: tab.label, icon: tab.icon, path: tab.path }] : []
      }),
    [visibleTabs],
  )
  const can = (permission: string) => permissions.has(permission)

  useEffect(() => {
    if (flatVisibleTabs.length === 0) return
    if (!flatVisibleTabs.some((tab) => tab.key === active)) {
      setActive(flatVisibleTabs[0].key)
    }
  }, [active, flatVisibleTabs])

  async function loadAll() {
    setLoading(true)
    setError('')
    try {
      const [
        nextUsers,
        nextRoles,
        nextMenus,
        nextDatingUsers,
        nextDatingPhotos,
        nextDatingMatches,
        nextDatingSettings,
        nextMobileAccounts,
      ] = await Promise.all([
        request<User[]>('/api/admin/users'),
        request<Role[]>('/api/admin/roles'),
        request<Menu[]>('/api/admin/menus'),
        request<DatingUser[]>('/api/admin/dating/users'),
        request<DatingPhoto[]>('/api/admin/dating/photos'),
        request<DatingMatch[]>('/api/admin/dating/matches'),
        request<DatingSettings>('/api/admin/dating/settings'),
        request<MobileAccount[]>('/api/admin/dating/mobile-users'),
      ])
      setUsers(nextUsers ?? [])
      setRoles(nextRoles ?? [])
      setMenus(nextMenus ?? [])
      setDatingUsers(nextDatingUsers ?? [])
      setDatingPhotos(nextDatingPhotos ?? [])
      setDatingMatches(nextDatingMatches ?? [])
      setDatingSettings(nextDatingSettings ?? { photoReviewEnabled: true })
      setMobileAccounts(nextMobileAccounts ?? [])
      if (!selectedDatingMatchId && nextDatingMatches?.[0]) {
        setSelectedDatingMatchId(nextDatingMatches[0].id)
        void loadDatingMessages(nextDatingMatches[0].id)
      }
      setNotice('数据已同步')
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载失败')
      setNotice('数据加载失败')
    } finally {
      setLoading(false)
    }
  }

  async function loadDatingMessages(matchId: number) {
    try {
      const nextMessages = await request<DatingMessage[]>(`/api/admin/dating/messages?matchId=${matchId}`)
      setDatingMessages(nextMessages ?? [])
      setSelectedDatingMatchId(matchId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '聊天记录加载失败')
    }
  }

  async function reviewDatingPhoto(id: number, status: DatingPhoto['status']) {
    setSaving(true)
    setError('')
    try {
      await request(`/api/admin/dating/photos/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ status }),
      })
      await loadAll()
      setNotice('照片审核状态已更新')
    } catch (err) {
      setError(err instanceof Error ? err.message : '照片审核失败')
    } finally {
      setSaving(false)
    }
  }

  async function deleteMatch(id: number) {
    setConfirmDialog({
      title: '确认删除匹配',
      message: '删除后双方聊天记录将一并清除，无法恢复，确定删除吗？',
      confirmLabel: '删除',
      onConfirm: () => void performDeleteMatch(id),
    })
  }

  async function performDeleteMatch(id: number) {
    setConfirmDialog(null)
    setSaving(true)
    setError('')
    try {
      await request(`/api/admin/dating/matches/${id}`, { method: 'DELETE' })
      if (selectedDatingMatchId === id) {
        setSelectedDatingMatchId(null)
        setDatingMessages([])
      }
      await loadAll()
      setNotice('匹配已删除')
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除失败')
    } finally {
      setSaving(false)
    }
  }

  async function deleteMobileUser(id: number) {
    setConfirmDialog({
      title: '确认删除账号',
      message: '删除后该用户的所有资料、照片及聊天记录将被清除，无法恢复。确定删除吗？',
      confirmLabel: '删除',
      onConfirm: () => void performDeleteMobileUser(id),
    })
  }

  async function performDeleteMobileUser(id: number) {
    setConfirmDialog(null)
    setSaving(true)
    setError('')
    try {
      await request(`/api/admin/dating/mobile-users/${id}`, { method: 'DELETE' })
      await loadAll()
      setNotice('账号已删除')
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除失败')
    } finally {
      setSaving(false)
    }
  }

  async function resetMobilePassword(id: number, password: string) {
    setSaving(true)
    setError('')
    try {
      await request(`/api/admin/dating/mobile-users/${id}`, {
        method: 'PUT',
        body: JSON.stringify({ password }),
      })
      setNotice('密码已重置')
    } catch (err) {
      setError(err instanceof Error ? err.message : '重置密码失败')
    } finally {
      setSaving(false)
    }
  }

  async function saveDatingSettings(settings: DatingSettings) {
    setSaving(true)
    setError('')
    try {
      const nextSettings = await request<DatingSettings>('/api/admin/dating/settings', {
        method: 'PUT',
        body: JSON.stringify(settings),
      })
      setDatingSettings(nextSettings ?? settings)
      await loadAll()
      setNotice(settings.photoReviewEnabled ? '照片审核已开启' : '照片审核已关闭，新照片将自动认证')
    } catch (err) {
      setError(err instanceof Error ? err.message : '配置保存失败')
    } finally {
      setSaving(false)
    }
  }

  useEffect(() => {
    void loadAll()
  }, [])

  useEffect(() => {
    if (!userMenuOpen) return

    function closeUserMenu(event: Event) {
      const menu = userMenuRef.current
      if (!menu) return

      const path = event.composedPath()
      if (!path.includes(menu)) {
        setUserMenuOpen(false)
      }
    }

    document.addEventListener('mousedown', closeUserMenu, true)
    document.addEventListener('touchstart', closeUserMenu, true)
    return () => {
      document.removeEventListener('mousedown', closeUserMenu, true)
      document.removeEventListener('touchstart', closeUserMenu, true)
    }
  }, [userMenuOpen])

  useEffect(() => {
    if (!session.thumbnailUrl) {
      setAvatarPreview('')
      return
    }
    let revoked = false
    const separator = session.thumbnailUrl.includes('?') ? '&' : '?'
    const thumbnailUrl = `${session.thumbnailUrl}${separator}v=${avatarRefreshKey}`
    void fetchAssetObjectURL(thumbnailUrl)
      .then((url) => {
        if (revoked) {
          URL.revokeObjectURL(url)
          return
        }
        setAvatarPreview(url)
      })
      .catch(() => setAvatarPreview(''))
    return () => {
      revoked = true
      setAvatarPreview((current) => {
        if (current) URL.revokeObjectURL(current)
        return ''
      })
    }
  }, [avatarRefreshKey, session.thumbnailUrl])

  async function saveUser(event: FormEvent) {
    event.preventDefault()
    if (!userForm.username.trim()) {
      setError('请输入用户名')
      return
    }
    if (!userForm.id && !userForm.password.trim()) {
      setError('新增用户需要设置密码')
      return
    }
    await saveRecord(
      'users',
      userForm.id,
      {
        username: userForm.username.trim(),
        nickname: userForm.nickname.trim(),
        password: userForm.password.trim(),
        roleIds: userForm.roleIds,
      },
      () => setUserForm(emptyUser),
    )
  }

  async function saveRole(event: FormEvent) {
    event.preventDefault()
    if (!roleForm.name.trim() || !roleForm.key.trim()) {
      setError('请输入角色名称和标识')
      return
    }
    await saveRecord(
      'roles',
      roleForm.id,
      {
        name: roleForm.name.trim(),
        key: roleForm.key.trim(),
        menuIds: roleForm.menuIds,
      },
      () => setRoleForm(emptyRole),
    )
  }

  async function saveMenu(event: FormEvent) {
    event.preventDefault()
    if (
      !menuForm.name.trim() ||
      (menuForm.type !== 'button' && !menuForm.path.trim()) ||
      (menuForm.type === 'button' && !menuForm.permission.trim())
    ) {
      setError('请输入菜单名称和路径')
      return
    }
    if (menuForm.id && menuForm.parentId === menuForm.id) {
      setError('上级菜单不能选择自己')
      return
    }
    await saveRecord(
      'menus',
      menuForm.id,
      {
        name: menuForm.name.trim(),
        path: menuForm.path.trim(),
        parentId: menuForm.parentId,
        type: menuForm.type,
        permission: menuForm.permission.trim(),
      },
      () => setMenuForm(emptyMenu),
    )
  }

  async function saveRecord(
    entity: Entity,
    id: number | undefined,
    payload: unknown,
    reset: () => void,
  ) {
    setSaving(true)
    setError('')
    try {
      await request(`/api/admin/${entity}${id ? `/${id}` : ''}`, {
        method: id ? 'PUT' : 'POST',
        body: JSON.stringify(payload),
      })
      reset()
      await loadAll()
      setNotice(id ? '修改已保存' : '新增成功')
    } catch (err) {
      setError(err instanceof Error ? err.message : '保存失败')
    } finally {
      setSaving(false)
    }
  }

  function deleteRecord(entity: Entity, id: number) {
    setConfirmDialog({
      title: '确认删除',
      message: '删除后无法恢复，确定要删除这条数据吗？',
      confirmLabel: '删除',
      onConfirm: () => void performDeleteRecord(entity, id),
    })
  }

  async function performDeleteRecord(entity: Entity, id: number) {
    setConfirmDialog(null)
    setSaving(true)
    setError('')
    try {
      await request(`/api/admin/${entity}/${id}`, { method: 'DELETE' })
      await loadAll()
      setNotice('删除成功')
    } catch (err) {
      setError(err instanceof Error ? err.message : '删除失败')
    } finally {
      setSaving(false)
    }
  }

  async function uploadAvatar(file: File | undefined) {
    if (!file) return
    setUserMenuOpen(false)
    setSaving(true)
    setError('')
    try {
      const form = new FormData()
      form.append('avatar', file)
      const profile = await request<Profile>('/api/admin/profile/avatar', {
        method: 'POST',
        body: form,
      })
      onSessionChange({
        ...session,
        theme: profile.theme,
        avatarUrl: profile.avatarUrl,
        thumbnailUrl: profile.thumbnailUrl,
      })
      setAvatarRefreshKey(Date.now())
      setNotice('头像已更新')
    } catch (err) {
      setError(err instanceof Error ? err.message : '头像上传失败')
    } finally {
      setSaving(false)
    }
  }

  return (
    <main className="admin-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">
            <PanelLeft size={18} strokeWidth={2.2} />
          </span>
          <div>
            <strong>Admin Go</strong>
            <small>系统管理</small>
          </div>
        </div>
        <nav className="nav-tabs" aria-label="系统管理">
          {visibleTabs.map((tab) => {
            const Icon = tab.icon
            const children = tab.children ?? []
            const activeChild = children.some((child) => child.key === active)
            return (
              <div className="nav-group" key={tab.key}>
                <button
                  className={active === tab.key || activeChild ? 'active' : ''}
                  type="button"
                  onClick={() => {
                    if (children[0]) {
                      setActive(children[0].key)
                      return
                    }
                    if (isEntityKey(tab.key)) {
                      setActive(tab.key)
                    }
                  }}
                >
                  <Icon size={16} />
                  <span>{tab.label}</span>
                  <ChevronRight className="nav-chevron" size={15} />
                </button>
                {children.length > 0 && (
                  <div className="nav-subtabs">
                    {children.map((child) => (
                      <button
                        className={active === child.key ? 'active' : ''}
                        key={child.key}
                        type="button"
                        onClick={() => setActive(child.key)}
                      >
                        <span>{child.label}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )
          })}
        </nav>
      </aside>

      <section className="workspace">
        <header className="toolbar">
          <div>
            <p className="eyebrow">权限中心</p>
            <h1>用户、菜单、角色管理</h1>
            <p className="toolbar-subtitle">PostgreSQL + GORM 驱动的后台权限面板。</p>
          </div>
          <div className="toolbar-actions">
            <button className="ghost-button" type="button" onClick={loadAll}>
              <RefreshCw size={15} />
              刷新
            </button>
            <ThemeButton theme={theme} onThemeChange={onThemeChange} />
            <div className="user-menu" ref={userMenuRef}>
              <button
                className="session-pill"
                type="button"
                aria-expanded={userMenuOpen}
                onClick={() => setUserMenuOpen((open) => !open)}
              >
                {avatarPreview ? (
                  <img alt={`${session.username} 头像`} src={avatarPreview} />
                ) : (
                  <BadgeCheck size={14} />
                )}
                <span>{session.username}</span>
                <ChevronRight className={userMenuOpen ? 'menu-chevron open' : 'menu-chevron'} size={15} />
              </button>
              {userMenuOpen && (
                <div className="user-menu-popover">
                  <label className="user-menu-item">
                    <ImageUp size={15} />
                    更换头像
                    <input
                      accept="image/png,image/jpeg"
                      type="file"
                      onChange={(event) => {
                        void uploadAvatar(event.target.files?.[0])
                        event.target.value = ''
                      }}
                    />
                  </label>
                  <button className="user-menu-item danger" type="button" onClick={onLogout}>
                    <LogOut size={15} />
                    退出登录
                  </button>
                </div>
              )}
            </div>
          </div>
        </header>

        <div className="status-row">
          <span className={error ? 'status error' : 'status'}>{error || notice}</span>
          {loading && <span className="status subtle">加载中...</span>}
        </div>

        {active === 'users' && (
          <UserManagementSection
            users={users}
            roles={roles}
            roleNameByID={roleNameByID}
            userForm={userForm}
            saving={saving}
            can={can}
            onUserFormChange={setUserForm}
            onSaveUser={saveUser}
            onDeleteUser={(id) => deleteRecord('users', id)}
          />
        )}

        {active === 'roles' && (
          <RoleManagementSection
            roles={roles}
            pageMenus={pageMenus}
            buttonMenus={buttonMenus}
            menuNameByID={menuNameByID}
            roleForm={roleForm}
            saving={saving}
            can={can}
            onRoleFormChange={setRoleForm}
            onSaveRole={saveRole}
            onDeleteRole={(id) => deleteRecord('roles', id)}
          />
        )}

        {active === 'menus' && (
          <MenuManagementSection
            menus={menus}
            menuTree={menuTree}
            pageMenus={pageMenus}
            menuForm={menuForm}
            saving={saving}
            can={can}
            onMenuFormChange={setMenuForm}
            onSaveMenu={saveMenu}
            onDeleteMenu={(id) => deleteRecord('menus', id)}
          />
        )}

        {isDatingSection(active) && (
          <DatingOperationsSection
            section={active}
            users={datingUsers}
            photos={datingPhotos}
            matches={datingMatches}
            messages={datingMessages}
            settings={datingSettings}
            mobileAccounts={mobileAccounts}
            saving={saving}
            canReview={can('dating:review')}
            selectedMatchId={selectedDatingMatchId}
            onRefresh={loadAll}
            onReviewPhoto={reviewDatingPhoto}
            onSettingsChange={(settings) => void saveDatingSettings(settings)}
            onSelectMatch={(id) => void loadDatingMessages(id)}
            onDeleteMatch={(id) => void deleteMatch(id)}
            onDeleteMobileUser={(id) => void deleteMobileUser(id)}
            onResetMobilePassword={(id, password) => void resetMobilePassword(id, password)}
            loadAssetObjectURL={fetchAssetObjectURL}
          />
        )}
      </section>

      <ConfirmDialog
        state={confirmDialog}
        busy={saving}
        onCancel={() => setConfirmDialog(null)}
      />
    </main>
  )
}

function ThemeButton({
  theme,
  onThemeChange,
  className = '',
}: {
  theme: ThemeMode
  onThemeChange: () => void
  className?: string
}) {
  const Icon = getThemeIcon(theme)
  return (
    <button
      className={`ghost-button theme-button ${className}`.trim()}
      type="button"
      title={`主题：${getThemeLabel(theme)}`}
      onClick={onThemeChange}
    >
      <Icon size={15} />
      <span>{getThemeLabel(theme)}</span>
    </button>
  )
}

export default App
