package server

import (
	"net/http"

	"flutter-admin-go/internal/admin"
	"flutter-admin-go/internal/auth"
	"flutter-admin-go/internal/common"
	"flutter-admin-go/internal/mobile"
)

func NewRouter() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/api/admin/login", auth.AdminLoginHandler)
	mux.HandleFunc("/api/mobile/login", auth.MobileLoginHandler)

	mux.HandleFunc("/api/admin/profile", admin.ProfileHandler)
	mux.HandleFunc("/api/admin/profile/theme", admin.ProfileThemeHandler)
	mux.HandleFunc("/api/admin/profile/avatar", admin.ProfileAvatarHandler)
	mux.HandleFunc("/api/admin/profile/assets/", admin.ProfileAssetHandler)
	mux.HandleFunc("/api/admin/users", admin.UsersHandler)
	mux.HandleFunc("/api/admin/users/", admin.UserByIDHandler)
	mux.HandleFunc("/api/admin/roles", admin.RolesHandler)
	mux.HandleFunc("/api/admin/roles/", admin.RoleByIDHandler)
	mux.HandleFunc("/api/admin/menus", admin.MenusHandler)
	mux.HandleFunc("/api/admin/menus/", admin.MenuByIDHandler)
	mux.HandleFunc("/api/admin/dating/users", admin.DatingUsersHandler)
	mux.HandleFunc("/api/admin/dating/photos", admin.DatingPhotosHandler)
	mux.HandleFunc("/api/admin/dating/photos/assets/", admin.DatingPhotoAssetHandler)
	mux.HandleFunc("/api/admin/dating/photos/", admin.DatingPhotoReviewHandler)
	mux.HandleFunc("/api/admin/dating/matches", admin.DatingMatchesHandler)
	mux.HandleFunc("/api/admin/dating/matches/", admin.DatingMatchByIDHandler)
	mux.HandleFunc("/api/admin/dating/messages", admin.DatingMessagesHandler)
	mux.HandleFunc("/api/admin/dating/settings", admin.DatingSettingsHandler)
	mux.HandleFunc("/api/admin/dating/mobile-users", admin.DatingMobileUsersHandler)
	mux.HandleFunc("/api/admin/dating/mobile-users/", admin.DatingMobileUserByIDHandler)

	mux.HandleFunc("/api/mobile/register", mobile.RegisterHandler)
	mux.HandleFunc("/api/mobile/profile", mobile.ProfileHandler)
	mux.HandleFunc("/api/mobile/photos", mobile.PhotosHandler)
	mux.HandleFunc("/api/mobile/photos/assets/", mobile.PhotoAssetHandler)
	mux.HandleFunc("/api/mobile/photos/", mobile.DeletePhotoHandler)
	mux.HandleFunc("/api/mobile/recommendations", mobile.RecommendationsHandler)
	mux.HandleFunc("/api/mobile/likes", mobile.LikesHandler)
	mux.HandleFunc("/api/mobile/passes", mobile.PassesHandler)
	mux.HandleFunc("/api/mobile/matches", mobile.MatchesHandler)
	mux.HandleFunc("/api/mobile/chats/", mobile.ChatMessagesHandler)
	mux.HandleFunc("/api/mobile/ws/chats/", mobile.ChatWebSocketHandler)

	mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: map[string]string{"status": "up"}})
	})

	return withCORS(mux)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
