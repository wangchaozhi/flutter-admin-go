import { CheckCircle2, MessageSquareText, RefreshCw, UserRoundCheck, XCircle } from 'lucide-react'

import type { DatingMatch, DatingMessage, DatingPhoto, DatingUser } from '../../adminTypes'
import { PanelTitle } from '../../components/shared'

const statusLabel: Record<DatingPhoto['status'], string> = {
  pending: '待审核',
  approved: '已通过',
  rejected: '未通过',
}

export function DatingOperationsSection({
  users,
  photos,
  matches,
  messages,
  saving,
  canReview,
  selectedMatchId,
  onRefresh,
  onReviewPhoto,
  onSelectMatch,
}: {
  users: DatingUser[]
  photos: DatingPhoto[]
  matches: DatingMatch[]
  messages: DatingMessage[]
  saving: boolean
  canReview: boolean
  selectedMatchId: number | null
  onRefresh: () => void
  onReviewPhoto: (id: number, status: DatingPhoto['status']) => void
  onSelectMatch: (id: number) => void
}) {
  const pendingPhotos = photos.filter((photo) => photo.status === 'pending')

  return (
    <section className="dating-grid">
      <section className="table-panel">
        <PanelTitle title="婚恋用户" count={users.length} />
        <div className="dating-summary">
          <SummaryItem icon={UserRoundCheck} label="资料用户" value={users.length} />
          <SummaryItem icon={CheckCircle2} label="待审照片" value={pendingPhotos.length} />
          <SummaryItem icon={MessageSquareText} label="匹配会话" value={matches.length} />
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>用户</th>
                <th>基础资料</th>
                <th>意向</th>
                <th>完整度</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.userId}>
                  <td>
                    <strong>{user.name || user.username}</strong>
                    <small>{user.username}</small>
                  </td>
                  <td>
                    {user.city} · {user.age}岁 · {user.height}cm · {user.education}
                    <small>{user.job}</small>
                  </td>
                  <td>
                    {user.intention}
                    <small>{user.marriage} · {user.income}</small>
                  </td>
                  <td>{user.completion}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="editor-panel">
        <PanelTitle title="照片审核" count={pendingPhotos.length} />
        <button className="ghost-button" type="button" onClick={onRefresh}>
          <RefreshCw size={15} />
          刷新运营数据
        </button>
        <div className="review-list">
          {photos.map((photo) => (
            <article className="review-card" key={photo.id}>
              <div className="review-thumb">
                <span>{photo.label.slice(0, 1)}</span>
              </div>
              <div>
                <strong>{photo.name || photo.username}</strong>
                <small>{photo.label} · {statusLabel[photo.status]}</small>
              </div>
              {canReview && (
                <div className="row-actions">
                  <button disabled={saving} type="button" onClick={() => onReviewPhoto(photo.id, 'approved')}>
                    <CheckCircle2 size={14} />
                    通过
                  </button>
                  <button className="danger" disabled={saving} type="button" onClick={() => onReviewPhoto(photo.id, 'rejected')}>
                    <XCircle size={14} />
                    拒绝
                  </button>
                </div>
              )}
            </article>
          ))}
          {photos.length === 0 && <p className="empty">暂无照片</p>}
        </div>
      </section>

      <section className="table-panel dating-span">
        <PanelTitle title="匹配与聊天" count={matches.length} />
        <div className="match-layout">
          <div className="match-list">
            {matches.map((match) => (
              <button
                className={selectedMatchId === match.id ? 'match-item active' : 'match-item'}
                key={match.id}
                type="button"
                onClick={() => onSelectMatch(match.id)}
              >
                <strong>{match.userA} / {match.userB}</strong>
                <span>{match.messages} 条消息</span>
              </button>
            ))}
          </div>
          <div className="message-list">
            {messages.map((message) => (
              <article className="message-card" key={message.id}>
                <strong>{message.sender}</strong>
                <p>{message.content}</p>
              </article>
            ))}
            {messages.length === 0 && <p className="empty">选择一个匹配查看聊天记录</p>}
          </div>
        </div>
      </section>
    </section>
  )
}

function SummaryItem({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof UserRoundCheck
  label: string
  value: number
}) {
  return (
    <div className="summary-item">
      <Icon size={16} />
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

