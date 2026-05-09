package mobile

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"flutter-admin-go/internal/common"
	"flutter-admin-go/internal/store"
	"github.com/gorilla/websocket"
)

type wsIncomingMessage struct {
	Text string `json:"text"`
}

type wsPublishedMessage struct {
	ID        int       `json:"id"`
	MatchID   int       `json:"matchId"`
	SenderID  int       `json:"senderId"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"createdAt"`
}

var chatUpgrader = websocket.Upgrader{
	CheckOrigin: func(*http.Request) bool { return true },
}

func ChatWebSocketHandler(w http.ResponseWriter, r *http.Request) {
	username, ok := usernameFromToken(r.URL.Query().Get("token"))
	if !ok {
		common.WriteJSON(w, http.StatusUnauthorized, common.APIResponse{Code: 401, Msg: "unauthorized"})
		return
	}
	var user store.MobileUser
	if err := store.DB().Where("username = ?", username).First(&user).Error; err != nil {
		common.WriteJSON(w, http.StatusUnauthorized, common.APIResponse{Code: 401, Msg: "unauthorized"})
		return
	}

	rawID := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/mobile/ws/chats/"), "/")
	matchID, err := strconv.Atoi(rawID)
	if err != nil || matchID <= 0 {
		common.WriteJSON(w, http.StatusBadRequest, common.APIResponse{Code: 400, Msg: "invalid match"})
		return
	}
	match, member := requireMatchMember(w, matchID, user.ID)
	if !member {
		return
	}

	conn, err := chatUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	channelName := chatChannel(match.ID)
	pubsub := store.Redis().Subscribe(ctx, channelName)
	defer pubsub.Close()
	_ = markMatchRead(match.ID, user.ID)

	go func() {
		ch := pubsub.Channel()
		for item := range ch {
			var published wsPublishedMessage
			if err := json.Unmarshal([]byte(item.Payload), &published); err != nil {
				continue
			}
			out := messageDTO{
				ID:        published.ID,
				MatchID:   published.MatchID,
				SenderID:  published.SenderID,
				Text:      published.Text,
				Mine:      published.SenderID == user.ID,
				CreatedAt: published.CreatedAt.Format(time.RFC3339),
			}
			if !out.Mine {
				_ = markMatchRead(match.ID, user.ID)
			}
			if err := conn.WriteJSON(out); err != nil {
				cancel()
				return
			}
		}
	}()

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		var incoming wsIncomingMessage
		if err := conn.ReadJSON(&incoming); err != nil {
			return
		}
		text := strings.TrimSpace(incoming.Text)
		if text == "" {
			continue
		}
		record := store.MobileMessage{MatchID: match.ID, SenderID: user.ID, Content: text}
		if err := store.DB().Create(&record).Error; err != nil {
			_ = conn.WriteJSON(map[string]string{"error": err.Error()})
			continue
		}
		published := wsPublishedMessage{
			ID:        record.ID,
			MatchID:   record.MatchID,
			SenderID:  record.SenderID,
			Text:      record.Content,
			CreatedAt: record.CreatedAt,
		}
		if raw, err := json.Marshal(published); err == nil {
			_ = store.Redis().Publish(ctx, channelName, string(raw)).Err()
		}
	}
}

func chatChannel(matchID int) string {
	return "dating:chat:" + strconv.Itoa(matchID)
}
