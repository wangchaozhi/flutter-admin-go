package admin

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"flutter-admin-go/internal/common"
	"flutter-admin-go/internal/store"
	"gorm.io/gorm/clause"
)

type DatingUser struct {
	UserID     int           `json:"userId"`
	Username   string        `json:"username"`
	Name       string        `json:"name"`
	City       string        `json:"city"`
	Age        int           `json:"age"`
	Height     int           `json:"height"`
	Education  string        `json:"education"`
	Job        string        `json:"job"`
	Income     string        `json:"income"`
	Marriage   string        `json:"marriage"`
	Intention  string        `json:"intention"`
	Bio        string        `json:"bio"`
	Photos     []DatingPhoto `json:"photos"`
	Completion int           `json:"completion"`
}

type DatingPhoto struct {
	ID        int    `json:"id"`
	UserID    int    `json:"userId"`
	Username  string `json:"username,omitempty"`
	Name      string `json:"name,omitempty"`
	Label     string `json:"label"`
	Status    string `json:"status"`
	CreatedAt string `json:"createdAt"`
}

type DatingMatch struct {
	ID        int    `json:"id"`
	UserA     string `json:"userA"`
	UserB     string `json:"userB"`
	CreatedAt string `json:"createdAt"`
	Messages  int    `json:"messages"`
}

type DatingMessage struct {
	ID        int    `json:"id"`
	MatchID   int    `json:"matchId"`
	Sender    string `json:"sender"`
	Content   string `json:"content"`
	CreatedAt string `json:"createdAt"`
}

type reviewPayload struct {
	Status string `json:"status"`
}

type DatingSettings struct {
	PhotoReviewEnabled bool `json:"photoReviewEnabled"`
}

type datingSettingsPayload struct {
	PhotoReviewEnabled bool `json:"photoReviewEnabled"`
}

func DatingUsersHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	if !authorize(w, r, "") {
		return
	}
	var profiles []store.MobileProfile
	if err := store.DB().Order("user_id ASC").Find(&profiles).Error; err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	result := make([]DatingUser, 0, len(profiles))
	for _, profile := range profiles {
		user, err := datingUserDTO(profile)
		if err == nil {
			result = append(result, user)
		}
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func DatingPhotosHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	if !authorize(w, r, "") {
		return
	}
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	var photos []store.MobilePhoto
	query := store.DB().Order("created_at DESC, id DESC")
	if status != "" && status != "all" {
		query = query.Where("status = ?", status)
	}
	if err := query.Find(&photos).Error; err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	result := make([]DatingPhoto, 0, len(photos))
	for _, photo := range photos {
		result = append(result, datingPhotoDTO(photo))
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func DatingPhotoReviewHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	if !authorize(w, r, "dating:review") {
		return
	}
	id, ok := parseID(r.URL.Path, "/api/admin/dating/photos/")
	if !ok {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid id"})
		return
	}
	var req reviewPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	if req.Status != "approved" && req.Status != "rejected" && req.Status != "pending" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid status"})
		return
	}
	if err := store.DB().Model(&store.MobilePhoto{}).Where("id = ?", id).Update("status", req.Status).Error; err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	invalidateDatingCache()
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func DatingMatchesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	if !authorize(w, r, "") {
		return
	}
	var matches []store.MobileMatch
	if err := store.DB().Order("created_at DESC").Find(&matches).Error; err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	result := make([]DatingMatch, 0, len(matches))
	for _, match := range matches {
		var count int64
		_ = store.DB().Model(&store.MobileMessage{}).Where("match_id = ?", match.ID).Count(&count).Error
		result = append(result, DatingMatch{
			ID: match.ID, UserA: mobileDisplayName(match.UserAID), UserB: mobileDisplayName(match.UserBID),
			CreatedAt: match.CreatedAt.Format(time.RFC3339), Messages: int(count),
		})
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func DatingMessagesHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	if !authorize(w, r, "") {
		return
	}
	matchID, _ := strconv.Atoi(r.URL.Query().Get("matchId"))
	var messages []store.MobileMessage
	query := store.DB().Order("created_at ASC, id ASC")
	if matchID > 0 {
		query = query.Where("match_id = ?", matchID)
	}
	if err := query.Find(&messages).Error; err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	result := make([]DatingMessage, 0, len(messages))
	for _, message := range messages {
		result = append(result, DatingMessage{
			ID: message.ID, MatchID: message.MatchID, Sender: mobileDisplayName(message.SenderID),
			Content: message.Content, CreatedAt: message.CreatedAt.Format(time.RFC3339),
		})
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func DatingSettingsHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		if !authorize(w, r, "") {
			return
		}
		common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: loadDatingSettings()})
	case http.MethodPut:
		if !authorize(w, r, "dating:review") {
			return
		}
		var req datingSettingsPayload
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
			return
		}
		value := "false"
		if req.PhotoReviewEnabled {
			value = "true"
		}
		record := store.AppSetting{Key: "dating.photo_review_enabled", Value: value, UpdatedAt: time.Now()}
		if err := store.DB().Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "key"}},
			DoUpdates: clause.AssignmentColumns([]string{"value", "updated_at"}),
		}).Create(&record).Error; err != nil {
			common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
			return
		}
		invalidateDatingCache()
		common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: loadDatingSettings()})
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func loadDatingSettings() DatingSettings {
	var setting store.AppSetting
	if err := store.DB().Where("key = ?", "dating.photo_review_enabled").First(&setting).Error; err != nil {
		return DatingSettings{PhotoReviewEnabled: true}
	}
	return DatingSettings{PhotoReviewEnabled: strings.ToLower(strings.TrimSpace(setting.Value)) != "false"}
}

func datingUserDTO(profile store.MobileProfile) (DatingUser, error) {
	var user store.MobileUser
	if err := store.DB().First(&user, profile.UserID).Error; err != nil {
		return DatingUser{}, err
	}
	var photos []store.MobilePhoto
	if err := store.DB().Where("user_id = ?", profile.UserID).Order("id ASC").Find(&photos).Error; err != nil {
		return DatingUser{}, err
	}
	dto := DatingUser{
		UserID: profile.UserID, Username: user.Username, Name: profile.Name, City: profile.City,
		Age: profile.Age, Height: profile.Height, Education: profile.Education, Job: profile.Job,
		Income: profile.Income, Marriage: profile.Marriage, Intention: profile.Intention, Bio: profile.Bio,
	}
	for _, photo := range photos {
		dto.Photos = append(dto.Photos, datingPhotoDTO(photo))
	}
	dto.Completion = datingCompletion(dto)
	return dto, nil
}

func datingPhotoDTO(photo store.MobilePhoto) DatingPhoto {
	return DatingPhoto{
		ID: photo.ID, UserID: photo.UserID, Username: mobileUsername(photo.UserID), Name: mobileDisplayName(photo.UserID),
		Label: photo.Label, Status: photo.Status, CreatedAt: photo.CreatedAt.Format(time.RFC3339),
	}
}

func mobileUsername(userID int) string {
	var user store.MobileUser
	if err := store.DB().First(&user, userID).Error; err != nil {
		return "-"
	}
	return user.Username
}

func mobileDisplayName(userID int) string {
	var profile store.MobileProfile
	if err := store.DB().Where("user_id = ?", userID).First(&profile).Error; err == nil && profile.Name != "" {
		return profile.Name
	}
	return mobileUsername(userID)
}

func datingCompletion(user DatingUser) int {
	fields := []string{
		user.Name, user.City, strconv.Itoa(user.Age), strconv.Itoa(user.Height),
		user.Education, user.Job, user.Income, user.Marriage, user.Intention, user.Bio,
	}
	filled := 0
	for _, field := range fields {
		if strings.TrimSpace(field) != "" && field != "0" {
			filled++
		}
	}
	if len(user.Photos) > 0 {
		filled++
	}
	return filled * 100 / 11
}

func invalidateDatingCache() {
	ctx := context.Background()
	iter := store.Redis().Scan(ctx, 0, "dating:recommendations:*", 100).Iterator()
	for iter.Next(ctx) {
		_ = store.Redis().Del(ctx, iter.Val()).Err()
	}
}
