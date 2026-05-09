package store

import (
	"context"
	"database/sql/driver"
	"embed"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"flutter-admin-go/internal/config"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/redis/go-redis/v9"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

var db *gorm.DB
var objectClient *minio.Client
var redisClient *redis.Client
var avatarBucket string

type IntArray []int

func (ids IntArray) Value() (driver.Value, error) {
	if ids == nil {
		ids = IntArray{}
	}
	b, err := json.Marshal(ids)
	if err != nil {
		return nil, err
	}
	return string(b), nil
}

func (ids *IntArray) Scan(value interface{}) error {
	if value == nil {
		*ids = IntArray{}
		return nil
	}

	var raw []byte
	switch v := value.(type) {
	case []byte:
		raw = v
	case string:
		raw = []byte(v)
	default:
		return fmt.Errorf("unsupported IntArray value %T", value)
	}

	if len(raw) == 0 {
		*ids = IntArray{}
		return nil
	}
	return json.Unmarshal(raw, ids)
}

type AdminUser struct {
	ID           int      `gorm:"primaryKey;column:id"`
	Username     string   `gorm:"column:username"`
	Password     string   `gorm:"column:password"`
	Nickname     string   `gorm:"column:nickname"`
	RoleIDs      IntArray `gorm:"column:role_ids;type:jsonb"`
	Theme        string   `gorm:"column:theme"`
	AvatarKey    string   `gorm:"column:avatar_key"`
	ThumbnailKey string   `gorm:"column:thumbnail_key"`
}

func (AdminUser) TableName() string {
	return "admin_users"
}

type AdminRole struct {
	ID      int      `gorm:"primaryKey;column:id"`
	Name    string   `gorm:"column:name"`
	Key     string   `gorm:"column:role_key"`
	MenuIDs IntArray `gorm:"column:menu_ids;type:jsonb"`
}

func (AdminRole) TableName() string {
	return "admin_roles"
}

type AdminMenu struct {
	ID         int    `gorm:"primaryKey;column:id"`
	Name       string `gorm:"column:name"`
	Path       string `gorm:"column:path"`
	ParentID   int    `gorm:"column:parent_id"`
	Type       string `gorm:"column:type"`
	Permission string `gorm:"column:permission"`
}

func (AdminMenu) TableName() string {
	return "admin_menus"
}

type MobileUser struct {
	ID       int    `gorm:"primaryKey;column:id"`
	Username string `gorm:"column:username"`
	Password string `gorm:"column:password"`
	Nickname string `gorm:"column:nickname"`
}

func (MobileUser) TableName() string {
	return "mobile_users"
}

type MobileProfile struct {
	UserID    int    `gorm:"primaryKey;column:user_id"`
	Name      string `gorm:"column:name"`
	City      string `gorm:"column:city"`
	Age       int    `gorm:"column:age"`
	Height    int    `gorm:"column:height"`
	Education string `gorm:"column:education"`
	Job       string `gorm:"column:job"`
	Income    string `gorm:"column:income"`
	Marriage  string `gorm:"column:marriage"`
	Intention string `gorm:"column:intention"`
	Bio       string `gorm:"column:bio"`
}

func (MobileProfile) TableName() string {
	return "mobile_profiles"
}

type MobilePhoto struct {
	ID        int       `gorm:"primaryKey;column:id"`
	UserID    int       `gorm:"column:user_id"`
	Label     string    `gorm:"column:label"`
	Status    string    `gorm:"column:status"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

func (MobilePhoto) TableName() string {
	return "mobile_photos"
}

type MobileLike struct {
	ID         int       `gorm:"primaryKey;column:id"`
	FromUserID int       `gorm:"column:from_user_id"`
	ToUserID   int       `gorm:"column:to_user_id"`
	CreatedAt  time.Time `gorm:"column:created_at"`
}

func (MobileLike) TableName() string {
	return "mobile_likes"
}

type MobilePass struct {
	ID         int       `gorm:"primaryKey;column:id"`
	FromUserID int       `gorm:"column:from_user_id"`
	ToUserID   int       `gorm:"column:to_user_id"`
	CreatedAt  time.Time `gorm:"column:created_at"`
}

func (MobilePass) TableName() string {
	return "mobile_passes"
}

type MobileMatch struct {
	ID        int       `gorm:"primaryKey;column:id"`
	UserAID   int       `gorm:"column:user_a_id"`
	UserBID   int       `gorm:"column:user_b_id"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

func (MobileMatch) TableName() string {
	return "mobile_matches"
}

type MobileMessage struct {
	ID        int       `gorm:"primaryKey;column:id"`
	MatchID   int       `gorm:"column:match_id"`
	SenderID  int       `gorm:"column:sender_id"`
	Content   string    `gorm:"column:content"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

func (MobileMessage) TableName() string {
	return "mobile_messages"
}

type MobileMessageRead struct {
	MatchID    int       `gorm:"primaryKey;column:match_id"`
	UserID     int       `gorm:"primaryKey;column:user_id"`
	LastReadAt time.Time `gorm:"column:last_read_at"`
}

func (MobileMessageRead) TableName() string {
	return "mobile_message_reads"
}

type AppSetting struct {
	Key       string    `gorm:"primaryKey;column:key"`
	Value     string    `gorm:"column:value"`
	UpdatedAt time.Time `gorm:"column:updated_at"`
}

func (AppSetting) TableName() string {
	return "app_settings"
}

func Init(cfg *config.Config) error {
	conn, err := gorm.Open(postgres.Open(cfg.Database.DSN), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("open postgres: %w", err)
	}

	sqlDB, err := conn.DB()
	if err != nil {
		return fmt.Errorf("get postgres connection: %w", err)
	}
	if err = sqlDB.Ping(); err != nil {
		_ = sqlDB.Close()
		return fmt.Errorf("ping postgres: %w", err)
	}

	db = conn
	if err = migrate(); err != nil {
		return err
	}
	if err = initObjectStore(cfg.MinIO); err != nil {
		return err
	}
	if err = initRedis(cfg.Redis); err != nil {
		return err
	}
	return nil
}

func DB() *gorm.DB {
	return db
}

func ObjectClient() *minio.Client {
	return objectClient
}

func AvatarBucket() string {
	return avatarBucket
}

func Redis() *redis.Client {
	return redisClient
}

func initRedis(cfg config.RedisConfig) error {
	client := redis.NewClient(&redis.Options{Addr: cfg.Addr, Password: cfg.Password})
	if err := client.Ping(context.Background()).Err(); err != nil {
		return fmt.Errorf("ping redis: %w", err)
	}
	redisClient = client
	return nil
}

func initObjectStore(cfg config.MinIOConfig) error {
	avatarBucket = cfg.AvatarBucket
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return fmt.Errorf("create minio client: %w", err)
	}

	ctx := context.Background()
	exists, err := client.BucketExists(ctx, avatarBucket)
	if err != nil {
		return fmt.Errorf("check minio bucket: %w", err)
	}
	if !exists {
		if err = client.MakeBucket(ctx, avatarBucket, minio.MakeBucketOptions{}); err != nil {
			return fmt.Errorf("create minio bucket: %w", err)
		}
	}
	objectClient = client
	return nil
}

func migrate() error {
	if err := db.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version TEXT PRIMARY KEY,
		applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	)`).Error; err != nil {
		return fmt.Errorf("create migrations table: %w", err)
	}

	entries, err := migrationFiles.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		version := entry.Name()

		var count int64
		if err := db.Table("schema_migrations").Where("version = ?", version).Count(&count).Error; err != nil {
			return fmt.Errorf("check migration %s: %w", version, err)
		}
		if count > 0 {
			continue
		}

		sqlBytes, err := migrationFiles.ReadFile("migrations/" + version)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", version, err)
		}

		err = db.Transaction(func(tx *gorm.DB) error {
			if err := tx.Exec(string(sqlBytes)).Error; err != nil {
				return err
			}
			return tx.Exec(`INSERT INTO schema_migrations(version) VALUES (?)`, version).Error
		})
		if err != nil {
			return fmt.Errorf("apply migration %s: %w", version, err)
		}
	}
	return nil
}
