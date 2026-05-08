# flutter-admin-go

一个包含 Go 后端、React 管理端和 Flutter 移动端的全栈示例项目。后端提供登录、用户、角色、菜单等基础接口，并使用 SQLite 做本地数据存储。

## 项目结构

```text
.
├── main.go                  # Go 服务入口
├── internal/                # 后端接口、路由、数据存储
├── front/admin/             # React + TypeScript + Vite 管理端
├── front/mobile/            # Flutter 移动端
└── data/                    # 本地 SQLite 数据库目录，已加入 .gitignore
```

## 环境要求

- Go 1.26+
- Node.js 和 npm
- Flutter SDK 3.10+

## 启动后端

```bash
go mod download
go run .
```

服务默认运行在：

```text
http://localhost:8080
```

健康检查：

```text
GET /api/health
```

首次启动会自动创建 `data/app.db`，并初始化默认数据。

## 启动管理端

```bash
cd front/admin
npm install
npm run dev
```

管理端默认账号：

```text
admin / 123456
operator / 123456
```

## 启动移动端

```bash
cd front/mobile
flutter pub get
flutter run
```

移动端默认账号：

```text
user / 123456
```

## 后端接口

```text
POST   /api/admin/login
POST   /api/mobile/login
GET    /api/admin/users
POST   /api/admin/users
PUT    /api/admin/users/{id}
DELETE /api/admin/users/{id}
GET    /api/admin/roles
POST   /api/admin/roles
PUT    /api/admin/roles/{id}
DELETE /api/admin/roles/{id}
GET    /api/admin/menus
POST   /api/admin/menus
PUT    /api/admin/menus/{id}
DELETE /api/admin/menus/{id}
```

统一响应格式：

```json
{
  "code": 0,
  "msg": "ok",
  "data": {}
}
```

## 常用命令

```bash
# 后端
go run .

# 管理端开发
cd front/admin
npm run dev

# 管理端构建
cd front/admin
npm run build

# 移动端
cd front/mobile
flutter run
```
