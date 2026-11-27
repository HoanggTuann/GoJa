# GoJa — Ứng dụng iOS học ngoại ngữ đa nguồn & Web API

Ứng dụng SwiftUI thuần (giao diện iOS chuẩn), hỗ trợ từ **iOS 16.0+** trở lên, không cần thư viện bên ngoài hay API key trả phí.

## Tính năng chính
1. **Học tập kiểu Duolingo & Streak (`LearnView`)**:
   - Lộ trình bài học theo từng ngôn ngữ (Anh, Nhật, Hàn, Trung, Pháp, Đức, Tây Ban Nha, Việt) với các dạng bài tập tương tác: Chọn nghĩa, Nghe & chọn, Ghép câu từ vựng, Điền đáp án.
   - Bài luyện tập tự động sinh từ Flashcard đã lưu.
   - Theo dõi **Chuỗi Streak**, **XP hằng ngày**, lịch sử hoạt động 7 ngày gần nhất.
2. **Đọc & Nguồn (`ExploreView`, `ArticleReaderView`)**:
   - Đọc bài từ **Wikipedia REST API**, **RSS/Atom Feed**, hoặc nhập bất kỳ **URL trang web** nào.
   - **Tra từ nhanh (`WordLookupSheet`)** ngay khi chạm vào từ trong bài đọc: cho phép chọn nhanh chế độ từ điển (**Đang học → Chính**, **Chính → Đang học**, **Từ điển đơn ngữ**) hoặc chọn bất kỳ cặp ngôn ngữ nào, nghe phát âm tốc độ thường/chậm và lưu Flashcard.
3. **Tra từ & Dịch (`DictionaryView`)**:
   - Linh hoạt chuyển đổi mọi cặp ngôn ngữ, nút đảo chiều nhanh, dán/sao chép, nghe phát âm chuẩn/chậm và lịch sử tra cứu.
   - Tích hợp **Free Dictionary API** và **MyMemory Translation API** (hỗ trợ chia đoạn dài).
4. **Định dạng JaPack (`.japack`)**:
   - Lưu trữ cục bộ (`GoJaLibrary.japack`) và hỗ trợ xuất/nhập/chia sẻ gói học tập (`.japack` — định dạng JSON đổi đuôi) gồm từ vựng, nguồn web và bài học từ tệp hoặc URL.
5. **Cài đặt (`SettingsView`)**:
   - Tuỳ chọn **Đề xuất ngôn ngữ học** nổi bật.
   - Thanh trượt tuỳ chỉnh **Tốc độ phát âm** (mặc định chậm rõ `0.40` phù hợp người học) kèm nút nghe thử.
   - Quản lý nguồn RSS/Web và mục tiêu XP/Flashcard mỗi ngày.
