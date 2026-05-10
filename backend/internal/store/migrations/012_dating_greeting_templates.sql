INSERT INTO app_settings(key, value) VALUES
  (
    'dating.greeting_templates',
    '[
      "很开心和你互相喜欢，想先和你打个招呼。",
      "看到我们匹配成功了，期待慢慢了解你。",
      "你好呀，感觉我们的资料挺合拍，想和你聊聊。",
      "谢谢你的喜欢，我们从一个轻松的问候开始吧。"
    ]'
  )
ON CONFLICT (key) DO NOTHING;
