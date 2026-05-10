package mobile

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"flutter-admin-go/internal/common"
	"flutter-admin-go/internal/store"
	"github.com/minio/minio-go/v7"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type profilePayload struct {
	Name      string `json:"name"`
	Gender    string `json:"gender"`
	City      string `json:"city"`
	Age       int    `json:"age"`
	Height    int    `json:"height"`
	Education string `json:"education"`
	Job       string `json:"job"`
	Income    string `json:"income"`
	Marriage  string `json:"marriage"`
	Intention string `json:"intention"`
	Bio       string `json:"bio"`
}

type photoPayload struct {
	Label string `json:"label"`
}

type likePayload struct {
	TargetUserID int `json:"targetUserId"`
}

type passPayload struct {
	TargetUserID int `json:"targetUserId"`
}

type messagePayload struct {
	Text string `json:"text"`
}

type photoDTO struct {
	ID        int    `json:"id"`
	UserID    int    `json:"userId,omitempty"`
	Label     string `json:"label"`
	Status    string `json:"status"`
	URL       string `json:"url"`
	CreatedAt string `json:"createdAt,omitempty"`
}

type profileDTO struct {
	UserID     int        `json:"userId"`
	Username   string     `json:"username,omitempty"`
	Name       string     `json:"name"`
	Gender     string     `json:"gender"`
	City       string     `json:"city"`
	Age        int        `json:"age"`
	Height     int        `json:"height"`
	Education  string     `json:"education"`
	Job        string     `json:"job"`
	Income     string     `json:"income"`
	Marriage   string     `json:"marriage"`
	Intention  string     `json:"intention"`
	Bio        string     `json:"bio"`
	Completion int        `json:"completion"`
	Photos     []photoDTO `json:"photos"`
}

type candidateDTO struct {
	profileDTO
	MatchScore int      `json:"matchScore"`
	LikesMe    bool     `json:"likesMe"`
	Verified   bool     `json:"verified"`
	Tags       []string `json:"tags"`
}

type matchDTO struct {
	ID          int          `json:"id"`
	Candidate   candidateDTO `json:"candidate"`
	Messages    []messageDTO `json:"messages,omitempty"`
	UnreadCount int          `json:"unreadCount"`
	CreatedAt   string       `json:"createdAt"`
}

type messageDTO struct {
	ID        int    `json:"id"`
	MatchID   int    `json:"matchId"`
	SenderID  int    `json:"senderId"`
	Text      string `json:"text"`
	Mine      bool   `json:"mine"`
	CreatedAt string `json:"createdAt"`
}

func RegisterHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
		return
	}
	req.Username = strings.TrimSpace(req.Username)
	if req.Username == "" || req.Password == "" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "username and password required"})
		return
	}
	user := store.MobileUser{Username: req.Username, Password: req.Password, Nickname: req.Username}
	err := store.DB().Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&user).Error; err != nil {
			return err
		}
		return tx.Create(&store.MobileProfile{
			UserID: user.ID, Name: req.Username, City: "上海", Age: 28, Height: 168,
			Education: "本科", Job: "待完善", Income: "待完善", Marriage: "未婚", Intention: "认真婚恋",
		}).Error
	})
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	token := BuildToken(req.Username)
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: map[string]interface{}{
		"token": token, "username": req.Username, "client": "mobile",
	}})
}

func ProfileHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	switch r.Method {
	case http.MethodGet:
		profile, err := buildProfileDTO(user.ID, true)
		writeResult(w, profile, err)
	case http.MethodPut:
		var req profilePayload
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid body"})
			return
		}
		record := store.MobileProfile{
			UserID: user.ID, Name: req.Name, Gender: req.Gender, City: req.City, Age: req.Age, Height: req.Height,
			Education: req.Education, Job: req.Job, Income: req.Income, Marriage: req.Marriage,
			Intention: req.Intention, Bio: req.Bio,
		}
		err := store.DB().Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "user_id"}},
			UpdateAll: true,
		}).Create(&record).Error
		if err == nil && req.Name != "" {
			err = store.DB().Model(&store.MobileUser{}).Where("id = ?", user.ID).Updates(map[string]interface{}{"nickname": req.Name}).Error
		}
		if err != nil {
			common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
			return
		}
		invalidateRecommendationCache()
		profile, err := buildProfileDTO(user.ID, true)
		writeResult(w, profile, err)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func PhotosHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodPost {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	if err := r.ParseMultipartForm(8 << 20); err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid multipart form"})
		return
	}
	file, header, err := r.FormFile("photo")
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "photo file required"})
		return
	}
	defer file.Close()

	raw, err := io.ReadAll(io.LimitReader(file, 8<<20))
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "read photo failed"})
		return
	}
	contentType := http.DetectContentType(raw)
	if contentType != "image/jpeg" && contentType != "image/png" {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "only jpeg and png are supported"})
		return
	}

	label := strings.TrimSpace(r.FormValue("label"))
	if label == "" {
		label = strings.TrimSuffix(header.Filename, fmt.Sprintf(".%s", strings.Split(contentType, "/")[1]))
		if label == "" {
			label = "个人照片"
		}
	}

	stamp := time.Now().UnixNano()
	ext := ".jpg"
	if contentType == "image/png" {
		ext = ".png"
	}
	objectKey := fmt.Sprintf("mobile/photos/%d/%d%s", user.ID, stamp, ext)

	client := store.ObjectClient()
	ctx := context.Background()
	if _, err = client.PutObject(ctx, store.AvatarBucket(), objectKey, bytes.NewReader(raw), int64(len(raw)), minio.PutObjectOptions{ContentType: contentType}); err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}

	photoURL := fmt.Sprintf("/api/mobile/photos/assets/%s", objectKey)
	status := "pending"
	if !photoReviewEnabled() {
		status = "approved"
	}
	photo := store.MobilePhoto{UserID: user.ID, Label: label, Status: status, URL: photoURL}
	if err := store.DB().Create(&photo).Error; err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	invalidateRecommendationCache()
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: toPhotoDTO(photo)})
}

func PhotoAssetHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	objectKey := strings.TrimPrefix(r.URL.Path, "/api/mobile/photos/assets/")
	if objectKey == "" {
		common.WriteJSON(w, http.StatusNotFound, common.APIResponse{Code: 404, Msg: "not found"})
		return
	}
	// Verify ownership: the key starts with "mobile/photos/<userID>/"
	expectedPrefix := fmt.Sprintf("mobile/photos/%d/", user.ID)
	if !strings.HasPrefix(objectKey, expectedPrefix) {
		common.WriteJSON(w, http.StatusForbidden, common.APIResponse{Code: 403, Msg: "forbidden"})
		return
	}
	object, err := store.ObjectClient().GetObject(context.Background(), store.AvatarBucket(), objectKey, minio.GetObjectOptions{})
	if err != nil {
		common.WriteJSON(w, http.StatusNotFound, common.APIResponse{Code: 404, Msg: "not found"})
		return
	}
	defer object.Close()
	info, err := object.Stat()
	if err != nil {
		common.WriteJSON(w, http.StatusNotFound, common.APIResponse{Code: 404, Msg: "not found"})
		return
	}
	w.Header().Set("Content-Type", info.ContentType)
	w.Header().Set("Cache-Control", "private, max-age=300")
	_, _ = io.Copy(w, object)
}

func DeletePhotoHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodDelete {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	rawID := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/mobile/photos/"), "/")
	photoID, err := strconv.Atoi(rawID)
	if err != nil || photoID <= 0 {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid photo id"})
		return
	}
	result := store.DB().Where("id = ? AND user_id = ?", photoID, user.ID).Delete(&store.MobilePhoto{})
	if result.Error != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: result.Error.Error()})
		return
	}
	if result.RowsAffected == 0 {
		common.WriteJSON(w, http.StatusNotFound, common.APIResponse{Code: 404, Msg: "photo not found"})
		return
	}
	invalidateRecommendationCache()
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func RecommendationsHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodGet {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	city := strings.TrimSpace(r.URL.Query().Get("city"))
	minScore, _ := strconv.Atoi(r.URL.Query().Get("minScore"))
	verifiedOnly := r.URL.Query().Get("verifiedOnly") == "true"
	cacheKey := fmt.Sprintf("dating:recommendations:%d:%s:%d:%t", user.ID, city, minScore, verifiedOnly)
	if raw, err := store.Redis().Get(context.Background(), cacheKey).Result(); err == nil && raw != "" {
		var cached []candidateDTO
		if json.Unmarshal([]byte(raw), &cached) == nil {
			filtered := make([]candidateDTO, 0, len(cached))
			for _, candidate := range cached {
				if candidate.UserID != user.ID {
					filtered = append(filtered, candidate)
				}
			}
			common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: filtered})
			return
		}
	}

	var profiles []store.MobileProfile
	query := store.DB().Where(`
		user_id <> ?
		AND user_id NOT IN (SELECT to_user_id FROM mobile_passes WHERE from_user_id = ?)
		AND user_id NOT IN (SELECT to_user_id FROM mobile_likes WHERE from_user_id = ?)
	`, user.ID, user.ID, user.ID).Order("user_id ASC")
	if city != "" && city != "全部" {
		query = query.Where("city = ?", city)
	}
	if err := query.Find(&profiles).Error; err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	result := []candidateDTO{}
	for _, profile := range profiles {
		dto, err := buildCandidateDTO(user.ID, profile.UserID)
		if err != nil {
			continue
		}
		if dto.MatchScore < minScore || (verifiedOnly && !dto.Verified) {
			continue
		}
		result = append(result, dto)
	}
	if raw, err := json.Marshal(result); err == nil {
		_ = store.Redis().Set(context.Background(), cacheKey, string(raw), 5*time.Minute).Err()
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func LikesHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodPost {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	var req likePayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TargetUserID <= 0 || req.TargetUserID == user.ID {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid target"})
		return
	}
	var matched *matchDTO
	err := store.DB().Transaction(func(tx *gorm.DB) error {
		like := store.MobileLike{FromUserID: user.ID, ToUserID: req.TargetUserID}
		if err := tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&like).Error; err != nil {
			return err
		}
		var count int64
		if err := tx.Model(&store.MobileLike{}).Where("from_user_id = ? AND to_user_id = ?", req.TargetUserID, user.ID).Count(&count).Error; err != nil {
			return err
		}
		if count == 0 {
			return nil
		}
		a, b := orderedPair(user.ID, req.TargetUserID)
		match := store.MobileMatch{UserAID: a, UserBID: b}
		if err := tx.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "user_a_id"}, {Name: "user_b_id"}}, DoNothing: true}).Create(&match).Error; err != nil {
			return err
		}
		if match.ID == 0 {
			if err := tx.Where("user_a_id = ? AND user_b_id = ?", a, b).First(&match).Error; err != nil {
				return err
			}
		}
		dto, err := buildMatchDTO(user.ID, match)
		if err != nil {
			return err
		}
		matched = &dto
		return nil
	})
	if err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	invalidateRecommendationCache()
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: map[string]interface{}{"matched": matched != nil, "match": matched}})
}

func PassesHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodPost {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	var req passPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.TargetUserID <= 0 || req.TargetUserID == user.ID {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid target"})
		return
	}
	record := store.MobilePass{FromUserID: user.ID, ToUserID: req.TargetUserID}
	if err := store.DB().Clauses(clause.OnConflict{DoNothing: true}).Create(&record).Error; err != nil {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
		return
	}
	invalidateRecommendationCache()
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok"})
}

func MatchesHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodGet {
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
		return
	}
	var records []store.MobileMatch
	if err := store.DB().Where("user_a_id = ? OR user_b_id = ?", user.ID, user.ID).Order("created_at DESC").Find(&records).Error; err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	result := make([]matchDTO, 0, len(records))
	for _, record := range records {
		dto, err := buildMatchDTO(user.ID, record)
		if err == nil {
			result = append(result, dto)
		}
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: result})
}

func ChatMessagesHandler(w http.ResponseWriter, r *http.Request) {
	user, ok := currentUser(w, r)
	if !ok {
		return
	}
	rawID := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/mobile/chats/"), "/")
	rawID = strings.TrimSuffix(rawID, "/messages")
	matchID, err := strconv.Atoi(rawID)
	if err != nil || matchID <= 0 {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid match"})
		return
	}
	match, ok := requireMatchMember(w, matchID, user.ID)
	if !ok {
		return
	}
	switch r.Method {
	case http.MethodGet:
		messages, err := listMessages(match.ID, user.ID)
		if err == nil {
			err = markMatchRead(match.ID, user.ID)
		}
		writeResult(w, messages, err)
	case http.MethodPost:
		var req messagePayload
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Text) == "" {
			common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "message required"})
			return
		}
		text := strings.TrimSpace(req.Text)
		if err := store.DB().Create(&store.MobileMessage{MatchID: match.ID, SenderID: user.ID, Content: text}).Error; err != nil {
			common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: err.Error()})
			return
		}
		messages, err := listMessages(match.ID, user.ID)
		writeResult(w, messages, err)
	default:
		common.WriteJSON(w, http.StatusMethodNotAllowed, common.APIResponse{Code: 405, Msg: "method not allowed"})
	}
}

func BuildToken(username string) string {
	token := fmt.Sprintf("mobile-token:%s:%d", username, time.Now().UnixNano())
	_ = store.Redis().Set(context.Background(), "session:"+token, username, 7*24*time.Hour).Err()
	return token
}

func CurrentUsername(r *http.Request) (string, bool) {
	raw := strings.TrimSpace(r.Header.Get("Authorization"))
	raw = strings.TrimPrefix(raw, "Bearer ")
	return usernameFromToken(raw)
}

func usernameFromToken(raw string) (string, bool) {
	raw = strings.TrimSpace(raw)
	if strings.HasPrefix(raw, "mobile-token:") {
		if username, err := store.Redis().Get(context.Background(), "session:"+raw).Result(); err == nil && username != "" {
			_ = store.Redis().Expire(context.Background(), "session:"+raw, 7*24*time.Hour).Err()
			return username, true
		}
		parts := strings.Split(raw, ":")
		if len(parts) >= 2 {
			return parts[1], parts[1] != ""
		}
	}
	return "", false
}

func currentUser(w http.ResponseWriter, r *http.Request) (store.MobileUser, bool) {
	username, ok := CurrentUsername(r)
	if !ok {
		common.WriteJSON(w, http.StatusUnauthorized, common.APIResponse{Code: 401, Msg: "unauthorized"})
		return store.MobileUser{}, false
	}
	var user store.MobileUser
	if err := store.DB().Where("username = ?", username).First(&user).Error; err != nil {
		common.WriteJSON(w, http.StatusUnauthorized, common.APIResponse{Code: 401, Msg: "unauthorized"})
		return store.MobileUser{}, false
	}
	return user, true
}

func buildProfileDTO(userID int, includePhotos bool) (profileDTO, error) {
	var user store.MobileUser
	if err := store.DB().First(&user, userID).Error; err != nil {
		return profileDTO{}, err
	}
	var profile store.MobileProfile
	if err := store.DB().Where("user_id = ?", userID).First(&profile).Error; err != nil {
		return profileDTO{}, err
	}
	dto := profileDTO{
		UserID: userID, Username: user.Username, Name: profile.Name, Gender: profile.Gender, City: profile.City,
		Age: profile.Age, Height: profile.Height, Education: profile.Education, Job: profile.Job, Income: profile.Income,
		Marriage: profile.Marriage, Intention: profile.Intention, Bio: profile.Bio,
	}
	if includePhotos {
		var photos []store.MobilePhoto
		if err := store.DB().Where("user_id = ?", userID).Order("id ASC").Find(&photos).Error; err != nil {
			return profileDTO{}, err
		}
		for _, photo := range photos {
			dto.Photos = append(dto.Photos, toPhotoDTO(photo))
		}
	}
	dto.Completion = completion(dto)
	return dto, nil
}

func buildCandidateDTO(viewerID, targetID int) (candidateDTO, error) {
	profile, err := buildProfileDTO(targetID, true)
	if err != nil {
		return candidateDTO{}, err
	}
	var inboundLikes int64
	_ = store.DB().Model(&store.MobileLike{}).Where("from_user_id = ? AND to_user_id = ?", targetID, viewerID).Count(&inboundLikes).Error
	approved := false
	for _, photo := range profile.Photos {
		if photo.Status == "approved" {
			approved = true
			break
		}
	}
	score := 76 + targetID*3
	if profile.City == "上海" {
		score += 8
	}
	if score > 96 {
		score = 96
	}
	return candidateDTO{
		profileDTO: profile,
		MatchScore: score,
		LikesMe:    inboundLikes > 0,
		Verified:   approved,
		Tags:       []string{profile.City, profile.Intention, profile.Education},
	}, nil
}

func buildMatchDTO(viewerID int, match store.MobileMatch) (matchDTO, error) {
	otherID := match.UserAID
	if otherID == viewerID {
		otherID = match.UserBID
	}
	candidate, err := buildCandidateDTO(viewerID, otherID)
	if err != nil {
		return matchDTO{}, err
	}
	messages, err := listMessages(match.ID, viewerID)
	if err != nil {
		return matchDTO{}, err
	}
	unread, err := unreadMessageCount(match.ID, viewerID)
	if err != nil {
		return matchDTO{}, err
	}
	return matchDTO{ID: match.ID, Candidate: candidate, Messages: messages, UnreadCount: unread, CreatedAt: match.CreatedAt.Format(time.RFC3339)}, nil
}

func listMessages(matchID, viewerID int) ([]messageDTO, error) {
	var records []store.MobileMessage
	if err := store.DB().Where("match_id = ?", matchID).Order("created_at ASC, id ASC").Find(&records).Error; err != nil {
		return nil, err
	}
	result := make([]messageDTO, 0, len(records))
	for _, record := range records {
		result = append(result, messageDTO{
			ID: record.ID, MatchID: record.MatchID, SenderID: record.SenderID,
			Text: record.Content, Mine: record.SenderID == viewerID, CreatedAt: record.CreatedAt.Format(time.RFC3339),
		})
	}
	return result, nil
}

func unreadMessageCount(matchID, viewerID int) (int, error) {
	var count int64
	query := store.DB().Model(&store.MobileMessage{}).
		Where("match_id = ? AND sender_id <> ?", matchID, viewerID).
		Where(`created_at > COALESCE(
			(SELECT last_read_at FROM mobile_message_reads WHERE match_id = ? AND user_id = ?),
			to_timestamp(0)
		)`, matchID, viewerID)
	if err := query.Count(&count).Error; err != nil {
		return 0, err
	}
	return int(count), nil
}

func markMatchRead(matchID, userID int) error {
	record := store.MobileMessageRead{MatchID: matchID, UserID: userID, LastReadAt: time.Now()}
	return store.DB().Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "match_id"}, {Name: "user_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"last_read_at"}),
	}).Create(&record).Error
}

func photoReviewEnabled() bool {
	var setting store.AppSetting
	if err := store.DB().Where("key = ?", "dating.photo_review_enabled").First(&setting).Error; err != nil {
		return true
	}
	return strings.ToLower(strings.TrimSpace(setting.Value)) != "false"
}

func requireMatchMember(w http.ResponseWriter, matchID, userID int) (store.MobileMatch, bool) {
	var match store.MobileMatch
	err := store.DB().Where("id = ? AND (user_a_id = ? OR user_b_id = ?)", matchID, userID, userID).First(&match).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		common.WriteJSON(w, http.StatusNotFound, common.APIResponse{Code: 404, Msg: "match not found"})
		return store.MobileMatch{}, false
	}
	if err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return store.MobileMatch{}, false
	}
	return match, true
}

func orderedPair(a, b int) (int, int) {
	values := []int{a, b}
	sort.Ints(values)
	return values[0], values[1]
}

func toPhotoDTO(photo store.MobilePhoto) photoDTO {
	return photoDTO{
		ID:        photo.ID,
		UserID:    photo.UserID,
		Label:     photo.Label,
		Status:    photo.Status,
		URL:       photo.URL,
		CreatedAt: photo.CreatedAt.Format(time.RFC3339),
	}
}

func completion(profile profileDTO) int {
	fields := []string{
		profile.Name, profile.Gender, profile.City, strconv.Itoa(profile.Age), strconv.Itoa(profile.Height),
		profile.Education, profile.Job, profile.Income, profile.Marriage, profile.Intention, profile.Bio,
	}
	filled := 0
	for _, field := range fields {
		if strings.TrimSpace(field) != "" && field != "0" {
			filled++
		}
	}
	if len(profile.Photos) > 0 {
		filled++
	}
	return filled * 100 / 12
}

func writeResult(w http.ResponseWriter, data interface{}, err error) {
	if err != nil {
		common.WriteJSON(w, http.StatusInternalServerError, common.APIResponse{Code: 500, Msg: err.Error()})
		return
	}
	common.WriteJSON(w, http.StatusOK, common.APIResponse{Code: 0, Msg: "ok", Data: data})
}

func invalidateRecommendationCache() {
	ctx := context.Background()
	iter := store.Redis().Scan(ctx, 0, "dating:recommendations:*", 100).Iterator()
	for iter.Next(ctx) {
		_ = store.Redis().Del(ctx, iter.Val()).Err()
	}
}
