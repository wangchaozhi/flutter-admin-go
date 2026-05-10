import { useEffect, useMemo, useState } from 'react'
import { CheckCircle2, Clock3, Eye, ImageOff, MessageSquareText, RefreshCw, RotateCcw, Trash2, UserRoundCheck, XCircle, KeyRound } from 'lucide-react'

import type { DatingMatch, DatingMessage, DatingPhoto, DatingSettings, DatingUser, Entity, MobileAccount } from '../../adminTypes'
import { PanelTitle } from '../../components/shared'

type DatingSection = Extract<Entity, 'dating-users' | 'dating-photos' | 'dating-matches' | 'dating-accounts'>

const statusLabel: Record<DatingPhoto['status'], string> = {
  pending: '待审核',
  approved: '已通过',
  rejected: '未通过',
}

const statusOptions: Array<{ value: 'all' | DatingPhoto['status']; label: string }> = [
  { value: 'pending', label: '待审核' },
  { value: 'all', label: '全部' },
  { value: 'approved', label: '已通过' },
  { value: 'rejected', label: '未通过' },
]

export function DatingOperationsSection({
  section,
  users,
  photos,
  matches,
  messages,
  settings,
  mobileAccounts,
  saving,
  canReview,
  selectedMatchId,
  onRefresh,
  onReviewPhoto,
  onSettingsChange,
  onSelectMatch,
  onDeleteMatch,
  onDeleteMobileUser,
  onResetMobilePassword,
  loadAssetObjectURL,
}: {
  section: DatingSection
  users: DatingUser[]
  photos: DatingPhoto[]
  matches: DatingMatch[]
  messages: DatingMessage[]
  settings: DatingSettings
  mobileAccounts: MobileAccount[]
  saving: boolean
  canReview: boolean
  selectedMatchId: number | null
  onRefresh: () => void
  onReviewPhoto: (id: number, status: DatingPhoto['status']) => void
  onSettingsChange: (settings: DatingSettings) => void
  onSelectMatch: (id: number) => void
  onDeleteMatch: (id: number) => void
  onDeleteMobileUser: (id: number) => void
  onResetMobilePassword: (id: number, password: string) => void
  loadAssetObjectURL: (url: string) => Promise<string>
}) {
  const pendingPhotos = photos.filter((photo) => photo.status === 'pending')
  const [photoStatus, setPhotoStatus] = useState<'all' | DatingPhoto['status']>('pending')
  const [previewPhoto, setPreviewPhoto] = useState<DatingPhoto | null>(null)
  const filteredPhotos = useMemo(
    () => photos.filter((photo) => photoStatus === 'all' || photo.status === photoStatus),
    [photoStatus, photos],
  )
  const approvedCount = photos.filter((photo) => photo.status === 'approved').length
  const rejectedCount = photos.filter((photo) => photo.status === 'rejected').length
  const showUsers = section === 'dating-users'
  const showPhotos = section === 'dating-photos'
  const showMatches = section === 'dating-matches'
  const showAccounts = section === 'dating-accounts'

  return (
    <section className={showPhotos ? 'dating-grid dating-review-page' : 'dating-grid'}>
      {showUsers && (
      <section className="table-panel dating-span">
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
                <th>性别</th>
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
                  <td>{user.gender || '-'}</td>
                  <td>
                    {user.city} · {user.age}岁 · {user.height}cm · {user.education}
                    <small>{user.job}</small>
                  </td>
                  <td>
                    {user.intention}
                    <small>{user.marriage} · {user.income}</small>
                  </td>
                  <td>
                    <CompletionBadge value={user.completion} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      )}

      {showPhotos && (
      <section className="editor-panel">
        <PanelTitle title="照片审核" count={pendingPhotos.length} />
        <div className="review-metrics">
          <SummaryItem icon={Clock3} label="待处理" value={pendingPhotos.length} />
          <SummaryItem icon={CheckCircle2} label="已通过" value={approvedCount} />
          <SummaryItem icon={XCircle} label="已拒绝" value={rejectedCount} />
        </div>
        <label className="setting-row">
          <span>
            <strong>开启照片审核</strong>
            <small>{settings.photoReviewEnabled ? '新上传照片需要审核后展示认证' : '新上传照片将直接通过认证'}</small>
          </span>
          <input
            checked={settings.photoReviewEnabled}
            disabled={saving || !canReview}
            type="checkbox"
            onChange={(event) => onSettingsChange({ photoReviewEnabled: event.target.checked })}
          />
        </label>
        <div className="review-toolbar">
          <div className="segmented-tabs" role="tablist" aria-label="照片审核状态">
            {statusOptions.map((option) => (
              <button
                className={photoStatus === option.value ? 'active' : ''}
                key={option.value}
                type="button"
                onClick={() => setPhotoStatus(option.value)}
              >
                {option.label}
              </button>
            ))}
          </div>
          <button className="ghost-button" type="button" onClick={onRefresh}>
            <RefreshCw size={15} />
            刷新
          </button>
        </div>
        <div className="review-list">
          {filteredPhotos.map((photo) => (
            <article className="review-card" key={photo.id}>
              <button
                className="review-thumb"
                disabled={!photo.url}
                type="button"
                onClick={() => setPreviewPhoto(photo)}
              >
                <PhotoThumb photo={photo} loadAssetObjectURL={loadAssetObjectURL} />
                <span className={`review-status ${photo.status}`}>{statusLabel[photo.status]}</span>
                {photo.url && (
                  <span className="review-view">
                    <Eye size={14} />
                  </span>
                )}
              </button>
              <div className="review-copy">
                <strong>{photo.name || photo.username}</strong>
                <small>{photo.username || `用户 ${photo.userId}`}</small>
                <span>{photo.label}</span>
                <time>{formatTime(photo.createdAt)}</time>
              </div>
              {canReview && (
                <div className="row-actions">
                  <button disabled={saving || photo.status === 'approved'} type="button" onClick={() => onReviewPhoto(photo.id, 'approved')}>
                    <CheckCircle2 size={14} />
                    通过
                  </button>
                  <button className="danger" disabled={saving || photo.status === 'rejected'} type="button" onClick={() => onReviewPhoto(photo.id, 'rejected')}>
                    <XCircle size={14} />
                    拒绝
                  </button>
                  {photo.status !== 'pending' && (
                    <button disabled={saving} type="button" onClick={() => onReviewPhoto(photo.id, 'pending')}>
                      <RotateCcw size={14} />
                      退回待审
                    </button>
                  )}
                </div>
              )}
            </article>
          ))}
          {filteredPhotos.length === 0 && <p className="empty">暂无{photoStatus === 'all' ? '' : statusLabel[photoStatus]}照片</p>}
        </div>
      </section>
      )}

      {showMatches && (
      <section className="table-panel dating-span">
        <PanelTitle title="匹配与聊天" count={matches.length} />
        <div className="match-layout">
          <div className="match-list">
            {matches.map((match) => (
              <div key={match.id} className="match-item-row">
                <button
                  className={selectedMatchId === match.id ? 'match-item active' : 'match-item'}
                  type="button"
                  onClick={() => onSelectMatch(match.id)}
                >
                  <strong>{match.userA} / {match.userB}</strong>
                  <span>{match.messages} 条消息</span>
                </button>
                {canReview && (
                  <button
                    className="icon-button danger"
                    disabled={saving}
                    title="删除匹配"
                    type="button"
                    onClick={() => onDeleteMatch(match.id)}
                  >
                    <Trash2 size={13} />
                  </button>
                )}
              </div>
            ))}
            {matches.length === 0 && <p className="empty">暂无匹配</p>}
          </div>
          <div className="message-list">
            {messages.map((message) => (
              <article className="message-card" key={message.id}>
                <div className="message-meta">
                  <strong>{message.sender}</strong>
                  <time>{formatTime(message.createdAt)}</time>
                </div>
                <p>{message.content}</p>
              </article>
            ))}
            {messages.length === 0 && <p className="empty">选择一个匹配查看聊天记录</p>}
          </div>
        </div>
      </section>
      )}

      {showAccounts && (
      <section className="table-panel dating-span">
        <PanelTitle title="移动端账号管理" count={mobileAccounts.length} />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>手机号 / 账号</th>
                <th>昵称</th>
                <th>资料状态</th>
                <th>完整度</th>
                {canReview && <th>操作</th>}
              </tr>
            </thead>
            <tbody>
              {mobileAccounts.map((account) => (
                <tr key={account.userId}>
                  <td>{account.username}</td>
                  <td>{account.nickname || '-'}</td>
                  <td>{account.hasProfile ? '已创建' : '未创建'}</td>
                  <td>
                    {account.hasProfile
                      ? <CompletionBadge value={account.completion} />
                      : <span style={{ color: 'var(--text-subtle)' }}>-</span>}
                  </td>
                  {canReview && (
                    <td>
                      <div className="row-actions">
                        <ResetPasswordButton
                          disabled={saving}
                          onReset={(password) => onResetMobilePassword(account.userId, password)}
                        />
                        <button
                          className="danger"
                          disabled={saving}
                          type="button"
                          onClick={() => onDeleteMobileUser(account.userId)}
                        >
                          <Trash2 size={13} />
                          删除账号
                        </button>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
              {mobileAccounts.length === 0 && (
                <tr>
                  <td colSpan={canReview ? 5 : 4} style={{ textAlign: 'center', color: 'var(--text-subtle)' }}>
                    暂无移动端用户
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
      )}

      {previewPhoto && (
        <PhotoPreviewDialog
          canReview={canReview}
          photo={previewPhoto}
          saving={saving}
          loadAssetObjectURL={loadAssetObjectURL}
          onClose={() => setPreviewPhoto(null)}
          onReviewPhoto={onReviewPhoto}
        />
      )}
    </section>
  )
}

function PhotoThumb({
  photo,
  loadAssetObjectURL,
}: {
  photo: DatingPhoto
  loadAssetObjectURL: (url: string) => Promise<string>
}) {
  const [src, setSrc] = useState('')
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let alive = true
    let objectURL = ''
    setSrc('')
    setFailed(false)
    if (!photo.url) return
    loadAssetObjectURL(`/api/admin/dating/photos/assets/${photo.id}`)
      .then((url) => {
        if (!alive) {
          URL.revokeObjectURL(url)
          return
        }
        objectURL = url
        setSrc(url)
      })
      .catch(() => {
        if (alive) setFailed(true)
      })
    return () => {
      alive = false
      if (objectURL) URL.revokeObjectURL(objectURL)
    }
  }, [loadAssetObjectURL, photo.id, photo.url])

  if (src) return <img alt={photo.label} src={src} />
  if (failed || !photo.url) {
    return (
      <span className="review-placeholder">
        <ImageOff size={22} />
      </span>
    )
  }
  return <span className="review-placeholder">{photo.label.slice(0, 1)}</span>
}

function PhotoPreviewDialog({
  photo,
  saving,
  canReview,
  loadAssetObjectURL,
  onClose,
  onReviewPhoto,
}: {
  photo: DatingPhoto
  saving: boolean
  canReview: boolean
  loadAssetObjectURL: (url: string) => Promise<string>
  onClose: () => void
  onReviewPhoto: (id: number, status: DatingPhoto['status']) => void
}) {
  return (
    <div className="photo-preview-backdrop" role="presentation" onMouseDown={onClose}>
      <div className="photo-preview-dialog" role="dialog" aria-modal="true" onMouseDown={(event) => event.stopPropagation()}>
        <div className="photo-preview-header">
          <div>
            <strong>{photo.name || photo.username}</strong>
            <small>{photo.label} · {statusLabel[photo.status]}</small>
          </div>
          <button className="icon-button" type="button" onClick={onClose}>
            <XCircle size={16} />
          </button>
        </div>
        <div className="photo-preview-body">
          <PhotoThumb photo={photo} loadAssetObjectURL={loadAssetObjectURL} />
        </div>
        {canReview && (
          <div className="photo-preview-actions">
            <button disabled={saving || photo.status === 'approved'} type="button" onClick={() => onReviewPhoto(photo.id, 'approved')}>
              <CheckCircle2 size={14} />
              通过
            </button>
            <button className="danger" disabled={saving || photo.status === 'rejected'} type="button" onClick={() => onReviewPhoto(photo.id, 'rejected')}>
              <XCircle size={14} />
              拒绝
            </button>
            {photo.status !== 'pending' && (
              <button disabled={saving} type="button" onClick={() => onReviewPhoto(photo.id, 'pending')}>
                <RotateCcw size={14} />
                退回待审
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

function ResetPasswordButton({
  disabled,
  onReset,
}: {
  disabled: boolean
  onReset: (password: string) => void
}) {
  function handleClick() {
    const password = window.prompt('请输入新密码（至少6位）')
    if (!password) return
    if (password.length < 6) {
      alert('密码至少需要6位')
      return
    }
    onReset(password)
  }

  return (
    <button disabled={disabled} type="button" onClick={handleClick}>
      <KeyRound size={13} />
      重置密码
    </button>
  )
}

function CompletionBadge({ value }: { value: number }) {
  const color = value >= 80 ? '#059669' : value >= 50 ? '#D97706' : '#DC2626'
  return (
    <span style={{ color, fontWeight: 700 }}>{value}%</span>
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

function formatTime(iso: string): string {
  const date = new Date(iso)
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const msgDay = new Date(date.getFullYear(), date.getMonth(), date.getDate())

  const hh = date.getHours().toString().padStart(2, '0')
  const mm = date.getMinutes().toString().padStart(2, '0')
  const timeStr = `${hh}:${mm}`

  if (msgDay.getTime() === today.getTime()) return timeStr
  if (msgDay.getTime() === today.getTime() - 86400000) return `昨天 ${timeStr}`
  return `${date.getMonth() + 1}/${date.getDate()} ${timeStr}`
}
