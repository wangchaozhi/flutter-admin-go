package admin

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"flutter-admin-go/internal/common"
	"flutter-admin-go/internal/store"
)

type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Nickname string `json:"nickname"`
	RoleIDs  []int  `json:"roleIds"`
}

type Role struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	Key     string `json:"key"`
	MenuIDs []int  `json:"menuIds"`
}

type Menu struct {
	ID       int    `json:"id"`
	Name     string `json:"name"`
	Path     string `json:"path"`
	ParentID int    `json:"parentId"`
}

type userPayload struct {
	Username string `json:"username"`
	Password string `json:"password,omitempty"`
	Nickname string `json:"nickname"`
	RoleIDs  []int  `json:"roleIds"`
}

type rolePayload struct {
	Name    string `json:"name"`
	Key     string `json:"key"`
	MenuIDs []int  `json:"menuIds"`
}

type menuPayload struct {
	Name     string `json:"name"`
	Path     string `json:"path"`
	ParentID int    `json:"parentId"`
}

func UsersHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		listUsers(w)
	case http.MethodPost:
		createUser(w, r)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func UserByIDHandler(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(r.URL.Path, "/api/admin/users/")
	if !ok {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid id"})
		return
	}
	switch r.Method {
	case http.MethodPut:
		updateUser(w, r, id)
	case http.MethodDelete:
		deleteByID(w, "admin_users", id)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func RolesHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		listRoles(w)
	case http.MethodPost:
		createRole(w, r)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func RoleByIDHandler(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(r.URL.Path, "/api/admin/roles/")
	if !ok {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid id"})
		return
	}
	switch r.Method {
	case http.MethodPut:
		updateRole(w, r, id)
	case http.MethodDelete:
		deleteByID(w, "admin_roles", id)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func MenusHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		listMenus(w)
	case http.MethodPost:
		createMenu(w, r)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func MenuByIDHandler(w http.ResponseWriter, r *http.Request) {
	id, ok := parseID(r.URL.Path, "/api/admin/menus/")
	if !ok {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid id"})
		return
	}
	switch r.Method {
	case http.MethodPut:
		updateMenu(w, r, id)
	case http.MethodDelete:
		deleteByID(w, "admin_menus", id)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func listUsers(w http.ResponseWriter) {
	rows, err := store.DB().Query(`SELECT id, username, nickname, role_ids FROM admin_users ORDER BY id ASC`)
	if err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	defer rows.Close()

	result := make([]User, 0)
	for rows.Next() {
		var u User
		var roleIDs string
		if err = rows.Scan(&u.ID, &u.Username, &u.Nickname, &roleIDs); err != nil {
			common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
			return
		}
		u.RoleIDs = parseIntArray(roleIDs)
		result = append(result, u)
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func createUser(w http.ResponseWriter, r *http.Request) {
	var req userPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if req.Username == "" || req.Password == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "username and password required"})
		return
	}
	roleJSON := toJSON(req.RoleIDs)
	_, err := store.DB().Exec(`INSERT INTO admin_users(username, password, nickname, role_ids) VALUES (?, ?, ?, ?)`, req.Username, req.Password, req.Nickname, roleJSON)
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func updateUser(w http.ResponseWriter, r *http.Request, id int) {
	var req userPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if req.Username == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "username required"})
		return
	}
	args := []interface{}{req.Username, req.Nickname, toJSON(req.RoleIDs), id}
	query := `UPDATE admin_users SET username=?, nickname=?, role_ids=?`
	if req.Password != "" {
		query += `, password=? WHERE id=?`
		args = []interface{}{req.Username, req.Nickname, toJSON(req.RoleIDs), req.Password, id}
	} else {
		query += ` WHERE id=?`
	}
	_, err := store.DB().Exec(query, args...)
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func listRoles(w http.ResponseWriter) {
	rows, err := store.DB().Query(`SELECT id, name, role_key, menu_ids FROM admin_roles ORDER BY id ASC`)
	if err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	defer rows.Close()

	result := make([]Role, 0)
	for rows.Next() {
		var role Role
		var menuIDs string
		if err = rows.Scan(&role.ID, &role.Name, &role.Key, &menuIDs); err != nil {
			common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
			return
		}
		role.MenuIDs = parseIntArray(menuIDs)
		result = append(result, role)
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func createRole(w http.ResponseWriter, r *http.Request) {
	var req rolePayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if req.Name == "" || req.Key == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "name and key required"})
		return
	}
	_, err := store.DB().Exec(`INSERT INTO admin_roles(name, role_key, menu_ids) VALUES (?, ?, ?)`, req.Name, req.Key, toJSON(req.MenuIDs))
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func updateRole(w http.ResponseWriter, r *http.Request, id int) {
	var req rolePayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Key) == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "name and key required"})
		return
	}
	_, err := store.DB().Exec(`UPDATE admin_roles SET name=?, role_key=?, menu_ids=? WHERE id=?`, req.Name, req.Key, toJSON(req.MenuIDs), id)
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func listMenus(w http.ResponseWriter) {
	rows, err := store.DB().Query(`SELECT id, name, path, parent_id FROM admin_menus ORDER BY id ASC`)
	if err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	defer rows.Close()

	result := make([]Menu, 0)
	for rows.Next() {
		var menu Menu
		if err = rows.Scan(&menu.ID, &menu.Name, &menu.Path, &menu.ParentID); err != nil {
			common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
			return
		}
		result = append(result, menu)
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func createMenu(w http.ResponseWriter, r *http.Request) {
	var req menuPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if req.Name == "" || req.Path == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "name and path required"})
		return
	}
	_, err := store.DB().Exec(`INSERT INTO admin_menus(name, path, parent_id) VALUES (?, ?, ?)`, req.Name, req.Path, req.ParentID)
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func updateMenu(w http.ResponseWriter, r *http.Request, id int) {
	var req menuPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if strings.TrimSpace(req.Name) == "" || strings.TrimSpace(req.Path) == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "name and path required"})
		return
	}
	if req.ParentID == id {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "parent can not be self"})
		return
	}
	_, err := store.DB().Exec(`UPDATE admin_menus SET name=?, path=?, parent_id=? WHERE id=?`, req.Name, req.Path, req.ParentID, id)
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func deleteByID(w http.ResponseWriter, table string, id int) {
	tx, err := store.DB().Begin()
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	defer tx.Rollback()

	if _, err = tx.Exec("DELETE FROM "+table+" WHERE id=?", id); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	if err = cleanupDeletedReference(tx, table, id); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	if err = tx.Commit(); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func cleanupDeletedReference(tx *sql.Tx, table string, id int) error {
	switch table {
	case "admin_roles":
		return removeIDFromJSONColumn(tx, "admin_users", "role_ids", id)
	case "admin_menus":
		if err := removeIDFromJSONColumn(tx, "admin_roles", "menu_ids", id); err != nil {
			return err
		}
		_, err := tx.Exec(`UPDATE admin_menus SET parent_id=0 WHERE parent_id=?`, id)
		return err
	default:
		return nil
	}
}

func removeIDFromJSONColumn(tx *sql.Tx, table, column string, id int) error {
	rows, err := tx.Query("SELECT id, " + column + " FROM " + table)
	if err != nil {
		return err
	}
	defer rows.Close()

	updates := make(map[int]string)
	for rows.Next() {
		var rowID int
		var raw string
		if err = rows.Scan(&rowID, &raw); err != nil {
			return err
		}
		filtered := removeInt(parseIntArray(raw), id)
		if toJSON(filtered) != raw {
			updates[rowID] = toJSON(filtered)
		}
	}
	if err = rows.Err(); err != nil {
		return err
	}

	for rowID, raw := range updates {
		if _, err = tx.Exec("UPDATE "+table+" SET "+column+"=? WHERE id=?", raw, rowID); err != nil {
			return err
		}
	}
	return nil
}

func removeInt(values []int, target int) []int {
	result := make([]int, 0, len(values))
	for _, value := range values {
		if value != target {
			result = append(result, value)
		}
	}
	return result
}

func parseID(path, prefix string) (int, bool) {
	raw := strings.TrimPrefix(path, prefix)
	if raw == path || raw == "" {
		return 0, false
	}
	id, err := strconv.Atoi(raw)
	if err != nil || id <= 0 {
		return 0, false
	}
	return id, true
}

func parseIntArray(raw string) []int {
	if raw == "" {
		return []int{}
	}
	result := make([]int, 0)
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		return []int{}
	}
	return result
}

func toJSON(ids []int) string {
	if ids == nil {
		ids = []int{}
	}
	b, _ := json.Marshal(ids)
	return string(b)
}

func MustGetAdminUser(username, password string) (bool, error) {
	var id int
	err := store.DB().QueryRow(`SELECT id FROM admin_users WHERE username=? AND password=?`, username, password).Scan(&id)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

func MustGetMobileUser(username, password string) (bool, error) {
	var id int
	err := store.DB().QueryRow(`SELECT id FROM mobile_users WHERE username=? AND password=?`, username, password).Scan(&id)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}
