import { useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import {
  BadgeCheck,
  ChevronRight,
  KeyRound,
  LogOut,
  Menu as MenuIcon,
  Monitor,
  Moon,
  ImageUp,
  PanelLeft,
  RefreshCw,
  Shield,
  Sun,
  Trash2,
  UserCog,
  Users,
} from 'lucide-react'
import './App.css'

type Entity = 'users' | 'roles' | 'menus'

type User = {
  id: number
  username: string
  nickname: string
  roleIds: number[]
}

type Role = {
  id: number
  name: string
  key: string
  menuIds: number[]
}

type Menu = {
  id: number
  name: string
  path: string
  parentId: number
  type: 'menu' | 'button'
  permission: string
}

type ApiResponse<T> = {
  code: number
  msg: string
  data?: T
}

type LoginResponse = {
  token: string
  username: string
  client: string
  menuPaths?: string[]
  permissions?: string[]
  theme?: ThemeMode
  avatarUrl?: string
  thumbnailUrl?: string
}

type AdminSession = LoginResponse
type ThemeMode = 'system' | 'light' | 'dark'
type Profile = {
  username: string
  menuPaths: string[]
  permissions: string[]
  theme: ThemeMode
  avatarUrl: string
  thumbnailUrl: string
}

type UserForm = Omit<User, 'id'> & { id?: number; password: string }
type RoleForm = Omit<Role, 'id'> & { id?: number }
type MenuForm = Omit<Menu, 'id'> & { id?: number }
type ConfirmDialogState = {
  title: string
  message: string
  confirmLabel: string
  onConfirm: () => void
}

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

const tabs: Array<{ key: Entity; label: string; icon: typeof Users }> = [
  { key: 'users', label: '用户', icon: Users },
  { key: 'roles', label: '角色', icon: Shield },
  { key: 'menus', label: '菜单', icon: MenuIcon },
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
        .filter((tab) => tab.key !== 'users' || menuPaths.has('/system/user'))
        .filter((tab) => tab.key !== 'roles' || menuPaths.has('/system/role'))
        .filter((tab) => tab.key !== 'menus' || menuPaths.has('/system/menu')),
    [menuPaths],
  )
  const can = (permission: string) => permissions.has(permission)

  async function loadAll() {
    setLoading(true)
    setError('')
    try {
      const [nextUsers, nextRoles, nextMenus] = await Promise.all([
        request<User[]>('/api/admin/users'),
        request<Role[]>('/api/admin/roles'),
        request<Menu[]>('/api/admin/menus'),
      ])
      setUsers(nextUsers ?? [])
      setRoles(nextRoles ?? [])
      setMenus(nextMenus ?? [])
      setNotice('数据已同步')
    } catch (err) {
      setError(err instanceof Error ? err.message : '加载失败')
      setNotice('数据加载失败')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadAll()
  }, [])

  useEffect(() => {
    if (visibleTabs.length > 0 && !visibleTabs.some((tab) => tab.key === active)) {
      setActive(visibleTabs[0].key)
    }
  }, [active, visibleTabs])

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
            return (
              <button
                className={active === tab.key ? 'active' : ''}
                key={tab.key}
                type="button"
                onClick={() => setActive(tab.key)}
              >
                <Icon size={16} />
                <span>{tab.label}</span>
                <ChevronRight className="nav-chevron" size={15} />
              </button>
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
      </section>

      <ConfirmDialog
        state={confirmDialog}
        busy={saving}
        onCancel={() => setConfirmDialog(null)}
      />
    </main>
  )
}

function UserManagementSection({
  users,
  roles,
  roleNameByID,
  userForm,
  saving,
  can,
  onUserFormChange,
  onSaveUser,
  onDeleteUser,
}: {
  users: User[]
  roles: Role[]
  roleNameByID: Map<number, string>
  userForm: UserForm
  saving: boolean
  can: (permission: string) => boolean
  onUserFormChange: (form: UserForm) => void
  onSaveUser: (event: FormEvent) => void
  onDeleteUser: (id: number) => void
}) {
  return (
    <section className="content-grid">
      <section className="table-panel">
        <PanelTitle title="用户列表" count={users.length} />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>用户名</th>
                <th>昵称</th>
                <th>角色</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.username}</td>
                  <td>{user.nickname || '-'}</td>
                  <td>{formatNames(user.roleIds, roleNameByID)}</td>
                  <td>
                    <RowActions
                      canEdit={can('user:edit')}
                      canDelete={can('user:delete')}
                      onEdit={() => onUserFormChange({ ...user, password: '' })}
                      onDelete={() => onDeleteUser(user.id)}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <form className="editor-panel" onSubmit={onSaveUser}>
        <PanelTitle title={userForm.id ? '编辑用户' : '新增用户'} />
        <label>
          用户名
          <input
            value={userForm.username}
            onChange={(event) =>
              onUserFormChange({ ...userForm, username: event.target.value })
            }
            placeholder="admin"
          />
        </label>
        <label>
          昵称
          <input
            value={userForm.nickname}
            onChange={(event) =>
              onUserFormChange({ ...userForm, nickname: event.target.value })
            }
            placeholder="管理员"
          />
        </label>
        <label>
          密码
          <input
            type="password"
            value={userForm.password}
            onChange={(event) =>
              onUserFormChange({ ...userForm, password: event.target.value })
            }
            placeholder={userForm.id ? '留空不修改' : '请输入密码'}
          />
        </label>
        <CheckboxGroup
          label="分配角色"
          items={roles}
          selected={userForm.roleIds}
          getLabel={(role) => role.name}
          onChange={(roleIds) => onUserFormChange({ ...userForm, roleIds })}
        />
        <FormActions
          busy={saving}
          editing={Boolean(userForm.id)}
          createPermission="user:create"
          editPermission="user:edit"
          can={can}
          onReset={() => onUserFormChange(emptyUser)}
        />
      </form>
    </section>
  )
}

function RoleManagementSection({
  roles,
  pageMenus,
  buttonMenus,
  menuNameByID,
  roleForm,
  saving,
  can,
  onRoleFormChange,
  onSaveRole,
  onDeleteRole,
}: {
  roles: Role[]
  pageMenus: Menu[]
  buttonMenus: Menu[]
  menuNameByID: Map<number, string>
  roleForm: RoleForm
  saving: boolean
  can: (permission: string) => boolean
  onRoleFormChange: (form: RoleForm) => void
  onSaveRole: (event: FormEvent) => void
  onDeleteRole: (id: number) => void
}) {
  return (
    <section className="content-grid">
      <section className="table-panel">
        <PanelTitle title="角色列表" count={roles.length} />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>角色</th>
                <th>标识</th>
                <th>菜单权限</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {roles.map((role) => (
                <tr key={role.id}>
                  <td>{role.name}</td>
                  <td>{role.key}</td>
                  <td>{formatNames(role.menuIds, menuNameByID)}</td>
                  <td>
                    <RowActions
                      canEdit={can('role:edit')}
                      canDelete={can('role:delete')}
                      onEdit={() => onRoleFormChange(role)}
                      onDelete={() => onDeleteRole(role.id)}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <form className="editor-panel" onSubmit={onSaveRole}>
        <PanelTitle title={roleForm.id ? '编辑角色' : '新增角色'} />
        <label>
          角色名称
          <input
            value={roleForm.name}
            onChange={(event) => onRoleFormChange({ ...roleForm, name: event.target.value })}
            placeholder="运营管理员"
          />
        </label>
        <label>
          角色标识
          <input
            value={roleForm.key}
            onChange={(event) => onRoleFormChange({ ...roleForm, key: event.target.value })}
            placeholder="operator"
          />
        </label>
        <CheckboxGroup
          label="菜单权限"
          items={pageMenus}
          selected={roleForm.menuIds}
          getLabel={(menu) => menu.name}
          onChange={(menuIds) => onRoleFormChange({ ...roleForm, menuIds })}
        />
        <CheckboxGroup
          label="按钮权限"
          items={buttonMenus}
          selected={roleForm.menuIds}
          getLabel={(menu) => `${menu.name} (${menu.permission})`}
          onChange={(menuIds) => onRoleFormChange({ ...roleForm, menuIds })}
        />
        <FormActions
          busy={saving}
          editing={Boolean(roleForm.id)}
          createPermission="role:create"
          editPermission="role:edit"
          can={can}
          onReset={() => onRoleFormChange(emptyRole)}
        />
      </form>
    </section>
  )
}

function MenuManagementSection({
  menus,
  menuTree,
  pageMenus,
  menuForm,
  saving,
  can,
  onMenuFormChange,
  onSaveMenu,
  onDeleteMenu,
}: {
  menus: Menu[]
  menuTree: MenuNodeType[]
  pageMenus: Menu[]
  menuForm: MenuForm
  saving: boolean
  can: (permission: string) => boolean
  onMenuFormChange: (form: MenuForm) => void
  onSaveMenu: (event: FormEvent) => void
  onDeleteMenu: (id: number) => void
}) {
  return (
    <section className="content-grid">
      <section className="table-panel">
        <PanelTitle title="菜单结构" count={menus.length} />
        <div className="menu-tree">
          {menuTree.map((node) => (
            <MenuNode
              key={node.id}
              node={node}
              onEdit={(menu) => onMenuFormChange(menu)}
              onDelete={onDeleteMenu}
              canEdit={can('menu:edit')}
              canDelete={can('menu:delete')}
            />
          ))}
        </div>
      </section>

      <form className="editor-panel" onSubmit={onSaveMenu}>
        <PanelTitle title={menuForm.id ? '编辑菜单' : '新增菜单'} />
        <label>
          类型
          <select
            value={menuForm.type}
            onChange={(event) =>
              onMenuFormChange({
                ...menuForm,
                type: event.target.value as MenuForm['type'],
                path: event.target.value === 'button' ? '' : menuForm.path,
                permission: event.target.value === 'menu' ? '' : menuForm.permission,
              })
            }
          >
            <option value="menu">菜单</option>
            <option value="button">按钮</option>
          </select>
        </label>
        <label>
          菜单名称
          <input
            value={menuForm.name}
            onChange={(event) => onMenuFormChange({ ...menuForm, name: event.target.value })}
            placeholder="系统管理"
          />
        </label>
        <label>
          路由路径
          <input
            disabled={menuForm.type === 'button'}
            value={menuForm.path}
            onChange={(event) => onMenuFormChange({ ...menuForm, path: event.target.value })}
            placeholder="/system/user"
          />
        </label>
        {menuForm.type === 'button' && (
          <label>
            权限标识
            <input
              value={menuForm.permission}
              onChange={(event) =>
                onMenuFormChange({ ...menuForm, permission: event.target.value })
              }
              placeholder="user:create"
            />
          </label>
        )}
        <label>
          上级菜单
          <select
            value={menuForm.parentId}
            onChange={(event) =>
              onMenuFormChange({ ...menuForm, parentId: Number(event.target.value) })
            }
          >
            <option value={0}>顶级菜单</option>
            {pageMenus
              .filter((menu) => menu.id !== menuForm.id)
              .map((menu) => (
                <option key={menu.id} value={menu.id}>
                  {menu.name}
                </option>
              ))}
          </select>
        </label>
        <FormActions
          busy={saving}
          editing={Boolean(menuForm.id)}
          createPermission="menu:create"
          editPermission="menu:edit"
          can={can}
          onReset={() => onMenuFormChange(emptyMenu)}
        />
      </form>
    </section>
  )
}

function ConfirmDialog({
  state,
  busy,
  onCancel,
}: {
  state: ConfirmDialogState | null
  busy: boolean
  onCancel: () => void
}) {
  if (!state) return null

  return (
    <div className="confirm-backdrop" role="presentation" onMouseDown={onCancel}>
      <section
        aria-modal="true"
        className="confirm-dialog"
        role="dialog"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div>
          <h2>{state.title}</h2>
          <p>{state.message}</p>
        </div>
        <div className="confirm-actions">
          <button className="ghost-button" disabled={busy} type="button" onClick={onCancel}>
            取消
          </button>
          <button className="primary-button danger-confirm" disabled={busy} type="button" onClick={state.onConfirm}>
            <Trash2 size={15} />
            {state.confirmLabel}
          </button>
        </div>
      </section>
    </div>
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

function PanelTitle({ title, count }: { title: string; count?: number }) {
  return (
    <div className="panel-title">
      <h2>{title}</h2>
      {typeof count === 'number' && <span>{count}</span>}
    </div>
  )
}

function FormActions({
  busy,
  editing,
  createPermission,
  editPermission,
  can,
  onReset,
}: {
  busy: boolean
  editing: boolean
  createPermission: string
  editPermission: string
  can: (permission: string) => boolean
  onReset: () => void
}) {
  const allowed = editing ? can(editPermission) : can(createPermission)
  return (
    <div className="form-actions">
      {allowed && (
        <button className="primary-button" disabled={busy} type="submit">
          <BadgeCheck size={15} />
          {editing ? '保存' : '新增'}
        </button>
      )}
      <button className="ghost-button" type="button" onClick={onReset}>
        重置
      </button>
    </div>
  )
}

function RowActions({
  canEdit,
  canDelete,
  onEdit,
  onDelete,
}: {
  canEdit: boolean
  canDelete: boolean
  onEdit: () => void
  onDelete: () => void
}) {
  return (
    <div className="row-actions">
      {canEdit && (
        <button type="button" onClick={onEdit}>
          <UserCog size={14} />
          编辑
        </button>
      )}
      {canDelete && (
        <button className="danger" type="button" onClick={onDelete}>
          <Trash2 size={14} />
          删除
        </button>
      )}
      {!canEdit && !canDelete && <span className="muted-action">无权限</span>}
    </div>
  )
}

function CheckboxGroup<T extends { id: number }>({
  label,
  items,
  selected,
  getLabel,
  onChange,
}: {
  label: string
  items: T[]
  selected: number[]
  getLabel: (item: T) => string
  onChange: (ids: number[]) => void
}) {
  function toggle(id: number) {
    onChange(selected.includes(id) ? selected.filter((item) => item !== id) : [...selected, id])
  }

  return (
    <fieldset className="check-group">
      <legend>{label}</legend>
      <div>
        {items.map((item) => (
          <label key={item.id}>
            <input
              checked={selected.includes(item.id)}
              type="checkbox"
              onChange={() => toggle(item.id)}
            />
            <span>{getLabel(item)}</span>
          </label>
        ))}
        {items.length === 0 && <p className="empty">暂无可选数据</p>}
      </div>
    </fieldset>
  )
}

type MenuNodeType = Menu & { children: MenuNodeType[] }

function MenuNode({
  node,
  onEdit,
  onDelete,
  canEdit,
  canDelete,
}: {
  node: MenuNodeType
  onEdit: (menu: Menu) => void
  onDelete: (id: number) => void
  canEdit: boolean
  canDelete: boolean
}) {
  const [expanded, setExpanded] = useState(false)
  const hasChildren = node.children.length > 0

  return (
    <div className="menu-node">
      <div className="menu-node-row">
        <div className="menu-node-main">
          {hasChildren ? (
            <button
              className="menu-expand"
              type="button"
              aria-label={expanded ? '收起菜单' : '展开菜单'}
              onClick={() => setExpanded((open) => !open)}
            >
              <ChevronRight className={expanded ? 'open' : ''} size={15} />
            </button>
          ) : (
            <span className="menu-expand-placeholder" />
          )}
          <div>
            <strong>{node.name}</strong>
            <span>{node.type === 'button' ? node.permission : node.path}</span>
          </div>
        </div>
        <RowActions
          canEdit={canEdit}
          canDelete={canDelete}
          onEdit={() => onEdit(node)}
          onDelete={() => onDelete(node.id)}
        />
      </div>
      {hasChildren && expanded && (
        <div className="menu-children">
          {node.children.map((child) => (
            <MenuNode
              key={child.id}
              node={child}
              onEdit={onEdit}
              onDelete={onDelete}
              canEdit={canEdit}
              canDelete={canDelete}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function buildMenuTree(menus: Menu[]): MenuNodeType[] {
  const map = new Map<number, MenuNodeType>()
  menus.forEach((menu) => map.set(menu.id, { ...menu, children: [] }))
  const roots: MenuNodeType[] = []

  map.forEach((node) => {
    const parent = map.get(node.parentId)
    if (parent) {
      parent.children.push(node)
      return
    }
    roots.push(node)
  })

  return roots
}

function formatNames(ids: number[], names: Map<number, string>) {
  if (ids.length === 0) return '-'
  return ids.map((id) => names.get(id) ?? `#${id}`).join('、')
}

export default App
