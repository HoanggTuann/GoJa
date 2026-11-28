# GoJa — Ứng dụng iOS học ngoại ngữ đa nguồn & Web API

Ứng dụng SwiftUI thuần (giao diện iOS chuẩn), hỗ trợ từ **iOS 16.0+** trở lên, không cần thư viện bên ngoài hay API key trả phí.

## Cấu trúc gói `.japack` (JSON đổi đuôi)
Bạn có thể tạo file `.japack` mới hoặc nối thêm từ vựng vào cuối mảng `items` theo cấu trúc **`từ - nghĩa - cách đọc`**:

```json
{
  "format": "JaPack",
  "version": 1,
  "name": "Tiếng Nhật Giao Tiếp",
  "language": "ja",
  "nativeLanguage": "vi",
  "items": [
    { "tu": "おはようございます", "nghia": "Chào buổi sáng", "cachDoc": "ohayō gozaimasu" },
    { "tu": "ありがとう", "nghia": "Cảm ơn", "cachDoc": "arigatō" }
  ]
}
```

- Khi nhập file `.japack` (qua tab **Học tập**, **Cài đặt**, **Ôn tập**, hoặc URL web), GoJa sẽ:
  1. Nạp toàn bộ danh sách `items` vào **Flashcard**.
  2. Tự động chia nhóm và cập nhật **Lộ trình bài học** (trắc nghiệm, nghe, ghép câu) cho ngôn ngữ của gói đó.
- Có sẵn 3 gói mẫu để test ngay trong thư mục `SampleJaPacks/` và tích hợp sẵn bên trong app (`japanese-starter.japack`, `english-daily.japack`, `korean-starter.japack`).

## Tính năng chính
1. **Học tập kiểu Duolingo & Streak (`LearnView`)**: Lộ trình bài học theo ngôn ngữ, bài luyện tập từ Flashcard & `.japack`, chuỗi Streak, XP mỗi ngày và lịch 7 ngày.
2. **Đọc & Nguồn (`ExploreView`, `ArticleReaderView`)**: Wikipedia REST API, RSS Feed, đọc URL web bất kỳ; chạm từng từ để mở **Tra cứu nhanh** có tuỳ chọn ngôn ngữ từ điển (**Đang học → Chính**, **Chính → Đang học**, **Từ điển đơn ngữ**).
3. **Tra từ & Dịch (`DictionaryView`)**: Free Dictionary API + MyMemory Translation API, đổi tự do mọi cặp ngôn ngữ, đảo chiều nhanh, lịch sử tra cứu.
4. **Cài đặt (`SettingsView`)**: Đề xuất ngôn ngữ học, thanh trượt tuỳ chỉnh tốc độ phát âm (mặc định `0.40` chậm rõ), quản lý `.japack` và nguồn web/RSS.
