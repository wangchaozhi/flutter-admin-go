import { useState } from 'react'
import type { FormEvent } from 'react'
import { BadgeCheck, ChevronRight, Trash2, UserCog } from 'lucide-react'

import type { ConfirmDialogState, Menu, MenuForm, Role, RoleForm, User, UserForm } from '../adminTypes'

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

export function UserManagementSection({
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

export function RoleManagementSection({
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

export function MenuManagementSection({
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

export function ConfirmDialog({
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

export type MenuNodeType = Menu & { children: MenuNodeType[] }

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

export function buildMenuTree(menus: Menu[]): MenuNodeType[] {
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

