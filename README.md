# flutter-admin-go

一个全栈婚恋配对应用示例，包含 Go 后端、React 运营管理端和 Flutter 移动端。

## 技术栈

| 层次 | 技术 |
|------|------|
| 后端 | Go 1.26 · GORM · gorilla/websocket · go-redis · minio-go |
| 数据库 | PostgreSQL 16 · Redis 7.4 |
| 对象存储 | MinIO |
| 管理端 | React 19 · TypeScript 6 · Vite 8 · lucide-react |
| 移动端 | Flutter 3.10 · forui · web_socket_channel · http |
| 基础设施 | Docker Compose |

## 项目结构

```text
.
├── docker-compose.yml          # PostgreSQL + MinIO + Redis 本地开发环境
├── backend/                    # Go 后端模块
│   ├── cmd/server/main.go      # 服务入口
│   └── internal/
│       ├── auth/               # 登录认证（管理端 + 移动端）
│       ├── admin/              # 管理端接口（用户/角色/菜单/婚恋运营）
│       ├── mobile/             # 移动端接口（资料/推荐/点赞/配对/聊天）
│       ├── server/             # 路由注册与 CORS 配置
│       ├── store/              # GORM 连接、Redis、MinIO、SQL 迁移
│       └── common/             # 统一响应格式
├── front/admin/                # React 管理端
│   └── src/
│       ├── features/           # 用户 / 角色 / 菜单 / 婚恋运营功能模块
│       └── components/         # 共享组件
└── front/mobile/               # Flutter 移动端（心遇婚恋）
    └── lib/
        ├── core/               # API 客户端
        └── features/           # 登录 / 首页（推荐·聊天·我的）
```

## 功能概览

### 管理端
- 登录认证，基于角色的按钮级权限控制（RBAC）
- 用户、角色、菜单管理（CRUD）
- 婚恋运营：照片审核、配对会话查看、消息浏览、应用设置
- 头像上传（MinIO）、主题切换（system / light / dark）

### 移动端（心遇婚恋）
- 用户注册与登录
- 个人资料编辑（城市、年龄、身高、学历、职位、收入、婚恋意向）
- 照片上传（支持审核流程）
- 推荐卡片（支持城市/分数/认证过滤）、点赞 / Pass
- 配对列表（含未读消息数）
- 实时聊天（WebSocket + Redis Pub/Sub）

## 环境要求

- Docker / Docker Compose
- Go 1.26+
- Node.js 18+ 与 npm
- Flutter SDK 3.10+

## 快速启动

### 1. 启动基础服务

```bash
docker compose up -d postgres minio redis
```

默认连接信息：

| 服务 | 地址 | 账号/密码 |
|------|------|-----------|
| PostgreSQL | localhost:5432 · 库名 flutter_admin_go | admin_go / admin_go_password |
| MinIO API | localhost:9000 | admin_go / admin_go_password |
| MinIO Console | localhost:9001 | admin_go / admin_go_password |
| Redis | localhost:6379 | — |

### 2. 启动后端

```bash
cd backend
go mod download
go run ./cmd/server
```

服务运行在 `http://localhost:8080`，首次启动自动执行 `internal/store/migrations/` 下的 SQL 文件。

可通过环境变量覆盖默认配置：

```bash
DATABASE_DSN="host=localhost port=5432 user=admin_go password=admin_go_password dbname=flutter_admin_go sslmode=disable TimeZone=Asia/Shanghai"
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=admin_go
MINIO_SECRET_KEY=admin_go_password
MINIO_USE_SSL=false
MINIO_AVATAR_BUCKET=admin-avatars
```

健康检查：`GET /api/health`

### 3. 启动管理端

```bash
cd front/admin
npm install
npm run dev
```

默认账号：

| 账号 | 密码 | 说明 |
|------|------|------|
| admin | admin | 拥有全部菜单和按钮权限 |
| operator | 123456 | 受限权限 |

### 4. 启动移动端

```bash
cd front/mobile
flutter pub get
flutter run
```

默认账号：

| 账号 | 密码 |
|------|------|
| 13800000000 | 123456 |

> Android 模拟器中访问后端会自动将地址替换为 `10.0.2.2`。

## 后端接口

### 认证

```
POST /api/admin/login        管理端登录
POST /api/mobile/login       移动端登录
POST /api/mobile/register    移动端注册
```

### 管理端（需 Authorization token）

```
GET  /api/admin/profile                     获取当前用户资料及权限
PUT  /api/admin/profile/theme               修改主题（system/light/dark）
POST /api/admin/profile/avatar              上传头像
GET  /api/admin/profile/assets/avatar       获取原始头像
GET  /api/admin/profile/assets/thumbnail    获取缩略图

GET    /api/admin/users          用户列表
POST   /api/admin/users          创建用户（需 user:create）
PUT    /api/admin/users/{id}     编辑用户（需 user:edit）
DELETE /api/admin/users/{id}     删除用户（需 user:delete）

GET    /api/admin/roles          角色列表
POST   /api/admin/roles          创建角色（需 role:create）
PUT    /api/admin/roles/{id}     编辑角色（需 role:edit）
DELETE /api/admin/roles/{id}     删除角色（需 role:delete）

GET    /api/admin/menus          菜单列表
POST   /api/admin/menus          创建菜单（需 menu:create）
PUT    /api/admin/menus/{id}     编辑菜单（需 menu:edit）
DELETE /api/admin/menus/{id}     删除菜单（需 menu:delete）

GET /api/admin/dating/users          婚恋用户列表
GET /api/admin/dating/photos         待审核照片
PUT /api/admin/dating/photos/{id}    审核照片（approved/rejected，需 dating:review）
GET /api/admin/dating/matches        配对会话列表
GET /api/admin/dating/messages       消息列表
GET /api/admin/dating/settings       应用设置
```

### 移动端（需 Authorization token）

```
GET  /api/mobile/profile              获取个人资料及照片
PUT  /api/mobile/profile              更新资料
POST /api/mobile/photos               上传照片

GET  /api/mobile/recommendations      推荐用户（支持 city/minScore/verifiedOnly 过滤）
GET  /api/mobile/likes                赞过的用户
POST /api/mobile/likes                点赞
GET  /api/mobile/passes               Pass 的用户
POST /api/mobile/passes               Pass

GET  /api/mobile/matches              配对列表（含未读消息数）
GET  /api/mobile/chats/{matchId}      聊天历史
POST /api/mobile/chats/{matchId}      发送消息
WS   /api/mobile/ws/chats/{matchId}   WebSocket 实时聊天
```

统一响应格式：

```json
{ "code": 0, "msg": "ok", "data": {} }
```

## 数据库迁移

迁移文件位于 `backend/internal/store/migrations/`，服务启动时自动按序执行，已执行版本记录在 `schema_migrations` 表中。

| 文件 | 内容 |
|------|------|
| 001_schema.sql | 管理端表（admin_users/roles/menus）和移动端基础表 |
| 002_seed.sql | 默认用户、角色、菜单、权限数据 |
| 003_admin_user_profile.sql | admin_users 扩展字段（theme/avatar_key/thumbnail_key） |
| 004_dating.sql | 婚恋模块全部表（profiles/photos/likes/matches/messages）及测试数据 |
| 005_fix_role_menu_ids.sql | 修复 role menu_ids 数据格式 |
| 006_mobile_passes.sql | mobile_passes 表（Pass 记录） |
| 007_mobile_default_account.sql | 默认移动端账号及资料/照片 |
| 008_dating_reads_and_settings.sql | 消息已读表与应用设置表 |

## 常用命令

```bash
# 基础服务
docker compose up -d postgres minio redis
docker compose logs -f postgres
docker compose logs -f redis

# 后端
cd backend
go run ./cmd/server
go test ./...

# 管理端
cd front/admin
npm run dev
npm run build

# 移动端
cd front/mobile
flutter run
flutter build apk
```

## 协作说明

本项目由 wangchaozhi 维护，Codex 作为 AI 编程协作者参与代码实现、文档更新与问题排查。
