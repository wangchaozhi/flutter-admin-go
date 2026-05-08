package store

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

var db *sql.DB

func Init(dbPath string) error {
	if err := os.MkdirAll(filepath.Dir(dbPath), 0o755); err != nil {
		return fmt.Errorf("create db dir: %w", err)
	}

	conn, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open sqlite: %w", err)
	}

	if err = conn.Ping(); err != nil {
		_ = conn.Close()
		return fmt.Errorf("ping sqlite: %w", err)
	}

	db = conn
	if err = migrate(); err != nil {
		return err
	}
	if err = seed(); err != nil {
		return err
	}
	return nil
}

func DB() *sql.DB {
	return db
}

func migrate() error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS admin_users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT NOT NULL UNIQUE,
			password TEXT NOT NULL,
			nickname TEXT NOT NULL,
			role_ids TEXT NOT NULL DEFAULT '[]'
		);`,
		`CREATE TABLE IF NOT EXISTS admin_roles (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			role_key TEXT NOT NULL UNIQUE,
			menu_ids TEXT NOT NULL DEFAULT '[]'
		);`,
		`CREATE TABLE IF NOT EXISTS admin_menus (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			path TEXT NOT NULL,
			parent_id INTEGER NOT NULL DEFAULT 0
		);`,
		`CREATE TABLE IF NOT EXISTS mobile_users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			username TEXT NOT NULL UNIQUE,
			password TEXT NOT NULL,
			nickname TEXT NOT NULL
		);`,
	}

	for _, stmt := range stmts {
		if _, err := db.Exec(stmt); err != nil {
			return fmt.Errorf("migrate schema: %w", err)
		}
	}
	return nil
}

func seed() error {
	if err := ensureAdminData(); err != nil {
		return err
	}
	if err := ensureMobileUser(); err != nil {
		return err
	}
	return nil
}

func ensureAdminData() error {
	var count int
	if err := db.QueryRow(`SELECT COUNT(1) FROM admin_roles`).Scan(&count); err != nil {
		return err
	}
	if count == 0 {
		if _, err := db.Exec(`INSERT INTO admin_roles(name, role_key, menu_ids) VALUES
			('super admin', 'super_admin', '[1,2,3,4,5]'),
			('operator', 'operator', '[1,2]')`); err != nil {
			return err
		}
	}

	if err := db.QueryRow(`SELECT COUNT(1) FROM admin_menus`).Scan(&count); err != nil {
		return err
	}
	if count == 0 {
		if _, err := db.Exec(`INSERT INTO admin_menus(name, path, parent_id) VALUES
			('dashboard', '/dashboard', 0),
			('system', '/system', 0),
			('user', '/system/user', 2),
			('role', '/system/role', 2),
			('menu', '/system/menu', 2)`); err != nil {
			return err
		}
	}

	if err := db.QueryRow(`SELECT COUNT(1) FROM admin_users`).Scan(&count); err != nil {
		return err
	}
	if count == 0 {
		if _, err := db.Exec(`INSERT INTO admin_users(username, password, nickname, role_ids) VALUES
			('admin', '123456', 'administrator', '[1]'),
			('operator', '123456', 'operator user', '[2]')`); err != nil {
			return err
		}
	}
	return nil
}

func ensureMobileUser() error {
	var count int
	if err := db.QueryRow(`SELECT COUNT(1) FROM mobile_users`).Scan(&count); err != nil {
		return err
	}
	if count == 0 {
		_, err := db.Exec(`INSERT INTO mobile_users(username, password, nickname) VALUES ('user', '123456', 'mobile user')`)
		return err
	}
	return nil
}
