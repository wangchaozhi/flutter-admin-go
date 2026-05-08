import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
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
}

type AdminSession = LoginResponse

type UserForm = Omit<User, 'id'> & { id?: number; password: string }
type RoleForm = Omit<Role, 'id'> & { id?: number }
type MenuForm = Omit<Menu, 'id'> & { id?: number }

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
}

const tabs: Array<{ key: Entity; label: string }> = [
  { key: 'users', label: '用户' },
  { key: 'roles', label: '角色' },
  { key: 'menus', label: '菜单' },
]

const adminRememberKey = 'admin.remember'
const adminUsernameKey = 'admin.username'
const adminPasswordKey = 'admin.password'
const adminSessionKey = 'admin.session'

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...init?.headers,
    },
  })
  const body = (await res.json()) as ApiResponse<T>
  if (!res.ok || body.code !== 0) {
    throw new Error(body.msg || '请求失败')
  }
  return body.data as T
}

function App() {
  const [session, setSession] = useState<AdminSession | null>(() => {
    const raw = localStorage.getItem(adminSessionKey)
    if (!raw) return null
    try {
      return JSON.parse(raw) as AdminSession
    } catch {
      localStorage.removeItem(adminSessionKey)
      return null
    }
  })

  function handleLoggedIn(nextSession: AdminSession) {
    localStorage.setItem(adminSessionKey, JSON.stringify(nextSession))
    setSession(nextSession)
  }

  function handleLogout() {
    localStorage.removeItem(adminSessionKey)
    setSession(null)
  }

  if (!session) {
    return <AdminLogin onLoggedIn={handleLoggedIn} />
  }

  return <AdminDashboard session={session} onLogout={handleLogout} />
}

function AdminLogin({ onLoggedIn }: { onLoggedIn: (session: AdminSession) => void }) {
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
      <form className="login-card" onSubmit={login}>
        <span className="brand-mark">AG</span>
        <div>
          <p className="eyebrow">Admin Go</p>
          <h1>后台登录</h1>
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
          {loading ? '登录中...' : '登录'}
        </button>
      </form>
    </main>
  )
}

function AdminDashboard({
  session,
  onLogout,
}: {
  session: AdminSession
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

  const roleNameByID = useMemo(
    () => new Map(roles.map((role) => [role.id, role.name])),
    [roles],
  )
  const menuNameByID = useMemo(
    () => new Map(menus.map((menu) => [menu.id, menu.name])),
    [menus],
  )
  const menuTree = useMemo(() => buildMenuTree(menus), [menus])

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
    if (!menuForm.name.trim() || !menuForm.path.trim()) {
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

  async function deleteRecord(entity: Entity, id: number) {
    if (!window.confirm('确定删除这条数据吗？')) return
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

  return (
    <main className="admin-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">AG</span>
          <div>
            <strong>Admin Go</strong>
            <small>系统管理</small>
          </div>
        </div>
        <nav className="nav-tabs" aria-label="系统管理">
          {tabs.map((tab) => (
            <button
              className={active === tab.key ? 'active' : ''}
              key={tab.key}
              type="button"
              onClick={() => setActive(tab.key)}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </aside>

      <section className="workspace">
        <header className="toolbar">
          <div>
            <p className="eyebrow">权限中心</p>
            <h1>用户、菜单、角色管理</h1>
          </div>
          <div className="toolbar-actions">
            <span>{session.username}</span>
            <button className="ghost-button" type="button" onClick={loadAll}>
              刷新
            </button>
            <button className="ghost-button" type="button" onClick={onLogout}>
              退出
            </button>
          </div>
        </header>

        <div className="status-row">
          <span className={error ? 'status error' : 'status'}>{error || notice}</span>
          {loading && <span className="status subtle">加载中...</span>}
        </div>

        {active === 'users' && (
          <section className="content-grid">
            <form className="editor-panel" onSubmit={saveUser}>
              <PanelTitle title={userForm.id ? '编辑用户' : '新增用户'} />
              <label>
                用户名
                <input
                  value={userForm.username}
                  onChange={(event) =>
                    setUserForm({ ...userForm, username: event.target.value })
                  }
                  placeholder="admin"
                />
              </label>
              <label>
                昵称
                <input
                  value={userForm.nickname}
                  onChange={(event) =>
                    setUserForm({ ...userForm, nickname: event.target.value })
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
                    setUserForm({ ...userForm, password: event.target.value })
                  }
                  placeholder={userForm.id ? '留空不修改' : '请输入密码'}
                />
              </label>
              <CheckboxGroup
                label="分配角色"
                items={roles}
                selected={userForm.roleIds}
                getLabel={(role) => role.name}
                onChange={(roleIds) => setUserForm({ ...userForm, roleIds })}
              />
              <FormActions
                busy={saving}
                editing={Boolean(userForm.id)}
                onReset={() => setUserForm(emptyUser)}
              />
            </form>

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
                            onEdit={() => setUserForm({ ...user, password: '' })}
                            onDelete={() => deleteRecord('users', user.id)}
                          />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          </section>
        )}

        {active === 'roles' && (
          <section className="content-grid">
            <form className="editor-panel" onSubmit={saveRole}>
              <PanelTitle title={roleForm.id ? '编辑角色' : '新增角色'} />
              <label>
                角色名称
                <input
                  value={roleForm.name}
                  onChange={(event) =>
                    setRoleForm({ ...roleForm, name: event.target.value })
                  }
                  placeholder="运营管理员"
                />
              </label>
              <label>
                角色标识
                <input
                  value={roleForm.key}
                  onChange={(event) =>
                    setRoleForm({ ...roleForm, key: event.target.value })
                  }
                  placeholder="operator"
                />
              </label>
              <CheckboxGroup
                label="菜单权限"
                items={menus}
                selected={roleForm.menuIds}
                getLabel={(menu) => menu.name}
                onChange={(menuIds) => setRoleForm({ ...roleForm, menuIds })}
              />
              <FormActions
                busy={saving}
                editing={Boolean(roleForm.id)}
                onReset={() => setRoleForm(emptyRole)}
              />
            </form>

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
                            onEdit={() => setRoleForm(role)}
                            onDelete={() => deleteRecord('roles', role.id)}
                          />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          </section>
        )}

        {active === 'menus' && (
          <section className="content-grid">
            <form className="editor-panel" onSubmit={saveMenu}>
              <PanelTitle title={menuForm.id ? '编辑菜单' : '新增菜单'} />
              <label>
                菜单名称
                <input
                  value={menuForm.name}
                  onChange={(event) =>
                    setMenuForm({ ...menuForm, name: event.target.value })
                  }
                  placeholder="系统管理"
                />
              </label>
              <label>
                路由路径
                <input
                  value={menuForm.path}
                  onChange={(event) =>
                    setMenuForm({ ...menuForm, path: event.target.value })
                  }
                  placeholder="/system/user"
                />
              </label>
              <label>
                上级菜单
                <select
                  value={menuForm.parentId}
                  onChange={(event) =>
                    setMenuForm({ ...menuForm, parentId: Number(event.target.value) })
                  }
                >
                  <option value={0}>顶级菜单</option>
                  {menus
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
                onReset={() => setMenuForm(emptyMenu)}
              />
            </form>

            <section className="table-panel">
              <PanelTitle title="菜单结构" count={menus.length} />
              <div className="menu-tree">
                {menuTree.map((node) => (
                  <MenuNode
                    key={node.id}
                    node={node}
                    onEdit={(menu) => setMenuForm(menu)}
                    onDelete={(id) => deleteRecord('menus', id)}
                  />
                ))}
              </div>
            </section>
          </section>
        )}
      </section>
    </main>
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
  onReset,
}: {
  busy: boolean
  editing: boolean
  onReset: () => void
}) {
  return (
    <div className="form-actions">
      <button className="primary-button" disabled={busy} type="submit">
        {editing ? '保存' : '新增'}
      </button>
      <button className="ghost-button" type="button" onClick={onReset}>
        重置
      </button>
    </div>
  )
}

function RowActions({
  onEdit,
  onDelete,
}: {
  onEdit: () => void
  onDelete: () => void
}) {
  return (
    <div className="row-actions">
      <button type="button" onClick={onEdit}>
        编辑
      </button>
      <button className="danger" type="button" onClick={onDelete}>
        删除
      </button>
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
}: {
  node: MenuNodeType
  onEdit: (menu: Menu) => void
  onDelete: (id: number) => void
}) {
  return (
    <div className="menu-node">
      <div className="menu-node-row">
        <div>
          <strong>{node.name}</strong>
          <span>{node.path}</span>
        </div>
        <RowActions onEdit={() => onEdit(node)} onDelete={() => onDelete(node.id)} />
      </div>
      {node.children.length > 0 && (
        <div className="menu-children">
          {node.children.map((child) => (
            <MenuNode key={child.id} node={child} onEdit={onEdit} onDelete={onDelete} />
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
