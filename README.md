# GoJa — Ứng dụng iOS học ngoại ngữ từ nhiều nguồn & Web API

Ứng dụng SwiftUI thuần (giao diện iOS chuẩn), hỗ trợ từ **iOS 16.0+** trở lên, không cần thư viện bên ngoài hay API key trả phí.

## Tính năng chính
1. **Đọc & Nguồn (`ExploreView`, `ArticleReaderView`)**:
   - Đọc bài ngẫu nhiên từ **Wikipedia REST API** theo ngôn ngữ đang học.
   - Đọc tin tức từ các nguồn **RSS / Atom Feed** (BBC, NHK, VOA...) hoặc tự thêm nguồn mới.
   - Nhập **URL trang web bất kỳ** để trích xuất văn bản sạch, chạm trực tiếp vào từng từ trong bài để tra nghĩa, nghe phát âm và lưu thành Flashcard.
2. **Tra từ & Dịch (`DictionaryView`)**:
   - Tích hợp **Free Dictionary API** (phiên âm, audio phát âm, nghĩa theo từ loại, ví dụ) và **MyMemory Translation API** (dịch từ/câu đa ngôn ngữ).
3. **Ôn tập Flashcard (`FlashcardsView`)**:
   - Lưu từ vựng cục bộ (`Documents/flashcards.json`), theo dõi mục tiêu ngày và ôn tập theo 3 mức (`Quên`, `Nhớ tạm`, `Đã thuộc`).
4. **Cài đặt (`SettingsView`)**:
   - Chọn ngôn ngữ đang học / ngôn ngữ mẹ đẻ (Anh, Nhật, Hàn, Trung, Pháp, Đức, Tây Ban Nha, Việt), quản lý nguồn web/RSS.

## Cách mở và chạy
1. Mở `GoJa.xcodeproj` bằng **Xcode 14+** trên macOS.
2. Chọn Simulator hoặc iPhone chạy **iOS 16.0** trở lên.
3. Nhấn **Run (Cmd + R)**.
