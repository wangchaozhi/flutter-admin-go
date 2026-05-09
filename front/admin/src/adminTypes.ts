export type Entity = 'users' | 'roles' | 'menus' | 'dating'

export type User = {
  id: number
  username: string
  nickname: string
  roleIds: number[]
}

export type Role = {
  id: number
  name: string
  key: string
  menuIds: number[]
}

export type Menu = {
  id: number
  name: string
  path: string
  parentId: number
  type: 'menu' | 'button'
  permission: string
}

export type ApiResponse<T> = {
  code: number
  msg: string
  data?: T
}

export type LoginResponse = {
  token: string
  username: string
  client: string
  menuPaths?: string[]
  permissions?: string[]
  theme?: ThemeMode
  avatarUrl?: string
  thumbnailUrl?: string
}

export type AdminSession = LoginResponse
export type ThemeMode = 'system' | 'light' | 'dark'
export type Profile = {
  username: string
  menuPaths: string[]
  permissions: string[]
  theme: ThemeMode
  avatarUrl: string
  thumbnailUrl: string
}

export type UserForm = Omit<User, 'id'> & { id?: number; password: string }
export type RoleForm = Omit<Role, 'id'> & { id?: number }
export type MenuForm = Omit<Menu, 'id'> & { id?: number }
export type ConfirmDialogState = {
  title: string
  message: string
  confirmLabel: string
  onConfirm: () => void
}

export type DatingPhoto = {
  id: number
  userId: number
  username?: string
  name?: string
  label: string
  status: 'pending' | 'approved' | 'rejected'
  createdAt: string
}

export type DatingUser = {
  userId: number
  username: string
  name: string
  city: string
  age: number
  height: number
  education: string
  job: string
  income: string
  marriage: string
  intention: string
  bio: string
  completion: number
  photos: DatingPhoto[]
}

export type DatingMatch = {
  id: number
  userA: string
  userB: string
  createdAt: string
  messages: number
}

export type DatingMessage = {
  id: number
  matchId: number
  sender: string
  content: string
  createdAt: string
}

export type DatingSettings = {
  photoReviewEnabled: boolean
}
