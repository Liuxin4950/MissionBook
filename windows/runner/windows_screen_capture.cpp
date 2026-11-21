#include "windows_screen_capture.h"

#include <dwmapi.h>
#include <objidl.h>
#include <gdiplus.h>
#include <windowsx.h>

#include <algorithm>
#include <cmath>
#include <chrono>
#include <limits>
#include <string>
#include <utility>

#include <flutter_windows.h>

namespace {
constexpr auto kSelectionClass = L"MissionBook.ScreenSelection";
constexpr COLORREF kGreen = RGB(36, 77, 61);
constexpr COLORREF kPaper = RGB(247, 248, 245);
constexpr COLORREF kWhite = RGB(255, 255, 255);
constexpr size_t kMaxAttachmentBytes = 4 * 1024 * 1024;
constexpr long long kMaxFramePixels = 40000000;
constexpr UINT_PTR kScrollTimer = 1;
constexpr int kMaxScrollFrames = 12;
constexpr int kMaxScrollHeight = 20000;
constexpr int kScrollWidth = 1440;

int Width(const RECT& rect) { return rect.right - rect.left; }
int Height(const RECT& rect) { return rect.bottom - rect.top; }

struct Frame {
  Frame() = default;
  Frame(const Frame&) = delete;
  Frame& operator=(const Frame&) = delete;
  ~Frame() { Reset(); }

  void Reset() {
    if (dc) DeleteDC(std::exchange(dc, nullptr));
    if (bitmap) DeleteObject(std::exchange(bitmap, nullptr));
    pixels = nullptr;
  }

  bool Read(const RECT& bounds) {
    Reset();
    width = Width(bounds);
    height = Height(bounds);
    if (width <= 0 || height <= 0 ||
        static_cast<long long>(width) * height > kMaxFramePixels) {
      return false;
    }
    HDC screen = GetDC(nullptr);
    if (!screen) return false;
    dc = CreateCompatibleDC(screen);
    BITMAPINFO info{};
    auto& header = info.bmiHeader;
    header.biSize = sizeof(header);
    header.biWidth = width;
    header.biHeight = -height;
    header.biPlanes = 1;
    header.biBitCount = 32;
    header.biCompression = BI_RGB;
    void* buffer = nullptr;
    bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &buffer,
                              nullptr, 0);
    pixels = static_cast<std::uint8_t*>(buffer);
    const bool ok = dc && bitmap && SelectObject(dc, bitmap) &&
        BitBlt(dc, 0, 0, width, height, screen, bounds.left, bounds.top,
               SRCCOPY | CAPTUREBLT);
    GdiFlush();
    ReleaseDC(nullptr, screen);
    if (!ok) Reset();
    return ok;
  }

  HDC dc = nullptr;
  HBITMAP bitmap = nullptr;
  std::uint8_t* pixels = nullptr;
  int width = 0;
  int height = 0;
};

std::vector<std::uint8_t> EncodeSelection(const std::uint8_t* pixels,
                                           int stride_width, const RECT& crop) {
  ULONG_PTR token = 0;
  Gdiplus::GdiplusStartupInput init;
  if (Gdiplus::GdiplusStartup(&token, &init, nullptr) != Gdiplus::Ok) return {};
  const auto encode = [&]() -> std::vector<std::uint8_t> {
    const int width = Width(crop);
    const size_t row_bytes = static_cast<size_t>(width) * 4;
    const size_t stride = static_cast<size_t>(stride_width) * 4;
    const auto* first = pixels + static_cast<size_t>(crop.top) * stride + crop.left * 4;
    std::vector<std::uint8_t> cropped;
    if (width != stride_width) {
      cropped.resize(row_bytes * Height(crop));
      for (int row = 0; row < Height(crop); ++row) {
        std::copy_n(first + row * stride, row_bytes, cropped.data() + row * row_bytes);
      }
      first = cropped.data();
    }
    Gdiplus::Bitmap source(width, Height(crop), width * 4,
                           PixelFormat32bppRGB, const_cast<BYTE*>(first));
    // System JPEG encoder. Preserve the original pixels unless the image
    // needs to be reduced to fit the attachment limit.
    constexpr CLSID jpeg_encoder = {
        0x557cf401, 0x1a04, 0x11d3, {0x9a, 0x73, 0, 0, 0xf8, 0x1e, 0xf3, 0x2e}};
    for (int edge : {20000, 14000, 8192, 4800, 3200, 2200, 1600, 1000}) {
      const int longest = std::max(Width(crop), Height(crop));
      const double scale = std::min(1.0, static_cast<double>(edge) / longest);
      const int w = std::max(1, static_cast<int>(Width(crop) * scale));
      const int h = std::max(1, static_cast<int>(Height(crop) * scale));
      Gdiplus::Bitmap output(w, h, PixelFormat32bppRGB);
      {
        Gdiplus::Graphics graphics(&output);
        graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        if (graphics.DrawImage(&source, Gdiplus::Rect(0, 0, w, h),
                               0, 0, Width(crop), Height(crop),
                               Gdiplus::UnitPixel) != Gdiplus::Ok) {
          continue;
        }
      }
      IStream* stream = nullptr;
      if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) return {};
      ULONG quality = 90;
      Gdiplus::EncoderParameters options{};
      options.Count = 1;
      options.Parameter[0] = {Gdiplus::EncoderQuality, 1,
                              Gdiplus::EncoderParameterValueTypeLong, &quality};
      std::vector<std::uint8_t> bytes;
      STATSTG stat{};
      if (output.Save(stream, &jpeg_encoder, &options) == Gdiplus::Ok &&
          SUCCEEDED(stream->Stat(&stat, STATFLAG_NONAME)) &&
          stat.cbSize.QuadPart > 0 && stat.cbSize.QuadPart <= kMaxAttachmentBytes) {
        bytes.resize(static_cast<size_t>(stat.cbSize.QuadPart));
        ULONG read = 0;
        LARGE_INTEGER origin{};
        if (FAILED(stream->Seek(origin, STREAM_SEEK_SET, nullptr)) ||
            FAILED(stream->Read(bytes.data(), static_cast<ULONG>(bytes.size()), &read)) ||
            read != bytes.size()) {
          bytes.clear();
        }
      }
      stream->Release();
      if (!bytes.empty()) return bytes;
    }
    return {};
  };
  auto bytes = encode();
  Gdiplus::GdiplusShutdown(token);
  return bytes;
}

// Compare reduced-width frames at the original row spacing. This keeps the
// displacement exact and rejects ambiguous joins on sparse or repeated content.
class ScrollImage {
 public:
  enum class AppendResult { unchanged, joined, ambiguous, limit };

  void Begin(const Frame& frame, const RECT& crop) {
    width_ = std::min(kScrollWidth, Width(crop));
    frame_height_ = std::min(kMaxScrollHeight, Height(crop));
    previous_ = Sample(frame, crop);
    stitched_ = previous_;
    frames_ = 1;
  }

  AppendResult Append(const Frame& frame, const RECT& crop) {
    if (frames_ >= kMaxScrollFrames) return AppendResult::limit;
    auto next = Sample(frame, crop);
    if (next == previous_) return AppendResult::unchanged;
    const int sample_step = std::max(1, width_ / 48);
    auto row_score = [&](int old_y, int new_y) {
      int total = 0;
      int samples = 0;
      for (int x = sample_step / 2; x < width_; x += sample_step) {
        const auto a = (static_cast<size_t>(old_y) * width_ + x) * 4;
        const auto b = (static_cast<size_t>(new_y) * width_ + x) * 4;
        for (size_t channel = 0; channel < 3; ++channel) {
          total += std::abs(static_cast<int>(previous_[a + channel]) - next[b + channel]);
        }
        ++samples;
      }
      return static_cast<double>(total) / samples;
    };
    int top = 0;
    while (top < frame_height_ / 3 && row_score(top, top) < 1) ++top;
    int bottom = 0;
    while (bottom < frame_height_ / 3 &&
           row_score(frame_height_ - bottom - 1, frame_height_ - bottom - 1) < 1) ++bottom;
    const int content = frame_height_ - top - bottom;
    if (content < 24) return AppendResult::ambiguous;
    double aligned = 0;
    for (int y = top; y < frame_height_ - bottom; y += std::max(1, content / 32)) {
      aligned = std::max(aligned, row_score(y, y));
    }
    if (aligned < 2) return AppendResult::unchanged;
    std::vector<double> scores(content * 4 / 5 + 1,
                               std::numeric_limits<double>::infinity());
    for (int shift = 1; shift < static_cast<int>(scores.size()); ++shift) {
      const int overlap = content - shift;
      double score = 0;
      for (int row = 0; row < 32; ++row) {
        const int y = top + row * (overlap - 1) / 31;
        score += row_score(y + shift, y);
      }
      scores[shift] = score / 32;
    }
    const auto winner = std::min_element(scores.begin() + 1, scores.end());
    const int shift = static_cast<int>(winner - scores.begin());
    double alternative = std::numeric_limits<double>::infinity();
    for (int i = 1; i < static_cast<int>(scores.size()); ++i) {
      if (std::abs(i - shift) > 3) alternative = std::min(alternative, scores[i]);
    }
    if (*winner >= 10 || alternative <= *winner + 1 || aligned <= *winner + 2) {
      return AppendResult::ambiguous;
    }
    if (height() + shift > kMaxScrollHeight) return AppendResult::limit;
    const auto bytes_per_row = static_cast<size_t>(width_) * 4;
    stitched_.resize(stitched_.size() - bytes_per_row * bottom);
    const auto tail = bytes_per_row * (frame_height_ - bottom - shift);
    stitched_.insert(stitched_.end(), next.begin() + tail, next.end());
    previous_ = std::move(next);
    ++frames_;
    return AppendResult::joined;
  }

  int frames() const { return frames_; }
  int height() const { return static_cast<int>(stitched_.size() / width_ / 4); }
  std::vector<std::uint8_t> Encode() const {
    return EncodeSelection(stitched_.data(), width_, {0, 0, width_, height()});
  }

 private:
  std::vector<std::uint8_t> Sample(const Frame& frame, const RECT& crop) const {
    std::vector<std::uint8_t> pixels(static_cast<size_t>(width_) * frame_height_ * 4);
    for (int y = 0; y < frame_height_; ++y) {
      const auto* row = frame.pixels +
          (static_cast<size_t>(crop.top + y) * frame.width + crop.left) * 4;
      for (int x = 0; x < width_; ++x) {
        const int source_x = x * Width(crop) / width_;
        const auto index = (static_cast<size_t>(y) * width_ + x) * 4;
        // Ignore the padding/alpha byte from the desktop DIB.
        std::copy_n(row + source_x * 4, 3, pixels.begin() + index);
      }
    }
    return pixels;
  }

  int width_ = 0;
  int frame_height_ = 0;
  int frames_ = 0;
  std::vector<std::uint8_t> previous_;
  std::vector<std::uint8_t> stitched_;
};
}  // namespace

class WindowsScreenCapture::Selection {
 public:
  Selection() = default;
  ~Selection() { Close({}); }

  void Start(HMONITOR monitor, HWND previous, Completion completion) {
    completion_ = std::move(completion);
    previous_ = previous;
    MONITORINFO info{sizeof(info)};
    if (!GetMonitorInfoW(monitor, &info)) {
      return Close({{}, "找不到截图所在的显示器"});
    }
    screen_ = info.rcMonitor;
    scale_ = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
    // Wait for DWM to compose the desktop after the assistant window was hidden.
    DwmFlush();
    if (!frame_.Read(screen_)) return Close({{}, "无法读取当前屏幕画面"});
    dim_.resize(static_cast<size_t>(frame_.width) * frame_.height * 4);
    for (size_t i = 0; i < dim_.size(); i += 4) {
      for (size_t channel = 0; channel < 3; ++channel) {
        dim_[i + channel] = static_cast<std::uint8_t>(frame_.pixels[i + channel] / 2);
      }
      dim_[i + 3] = 0;
    }
    const auto module = GetModuleHandleW(nullptr);
    WNDCLASSW klass{};
    klass.hInstance = module;
    klass.lpszClassName = kSelectionClass;
    klass.lpfnWndProc = &WindowProc;
    RegisterClassW(&klass);
    window_ = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, kSelectionClass,
        L"书祺截图", WS_POPUP, screen_.left, screen_.top, Width(screen_),
        Height(screen_), nullptr, nullptr, module, this);
    if (!window_) return Close({{}, "无法打开截图选区"});
    ShowWindow(window_, SW_SHOW);
    SetForegroundWindow(window_);
    SetFocus(window_);
    UpdateWindow(window_);
  }

  void Close(WindowsScreenCaptureResult result) {
    auto done = std::move(completion_);
    const bool restore_focus = window_ && GetForegroundWindow() == window_;
    if (window_) {
      KillTimer(window_, kScrollTimer);
      DestroyWindow(window_);
      window_ = nullptr;
    }
    scroll_.reset();
    frame_.Reset();
    std::vector<std::uint8_t>().swap(dim_);
    if (restore_focus && previous_ && IsWindow(previous_) &&
        IsWindowVisible(previous_) && !IsIconic(previous_)) {
      SetForegroundWindow(previous_);
    }
    if (done) done(std::move(result));
  }

  bool active() const { return static_cast<bool>(completion_); }

 private:
  enum class Drag { none, draw, move, resize };
  enum Edge { left = 1, top = 2, right = 4, bottom = 8 };
  enum class Action { area, screen, scrolling, finish, cancel };
  struct Tool { RECT rect; Action action; const wchar_t* label; };

  int Dp(double value) const { return static_cast<int>(std::lround(value * scale_)); }
  RECT EntireFrame() const { return {0, 0, frame_.width, frame_.height}; }
  bool ValidSelection() const { return Width(region_) >= 2 && Height(region_) >= 2; }

  std::vector<Tool> Tools() const {
    if (scroll_) {
      const int width = Width(scroll_bar_);
      return {{BoxAt(width - Dp(145), Dp(5), Dp(68), Dp(34)), Action::finish, L"完成"},
              {BoxAt(width - Dp(73), Dp(5), Dp(68), Dp(34)), Action::cancel, L"取消"}};
    }
    const int button = std::min(Dp(72), std::max(1, (frame_.width - Dp(52)) / 5));
    const int gap = Dp(4);
    const int start = (frame_.width - 5 * button - 4 * gap) / 2;
    const int y = Dp(14);
    const auto rect = [&](int index) {
      const int x = start + index * (button + gap);
      return RECT{x, y, x + button, y + Dp(34)};
    };
    return {{rect(0), Action::area, L"局部"},
            {rect(1), Action::screen, L"全屏"},
            {rect(2), Action::scrolling, L"长截图"},
            {rect(3), Action::finish, L"完成"},
            {rect(4), Action::cancel, L"取消"}};
  }

  static RECT BoxAt(int x, int y, int w, int h) {
    return {x, y, x + w, y + h};
  }

  void Paint() {
    PAINTSTRUCT paint{};
    HDC dc = BeginPaint(window_, &paint);
    if (scroll_) {
      PaintToolbar(dc);
      EndPaint(window_, &paint);
      return;
    }
    BITMAPINFO info{};
    auto& header = info.bmiHeader;
    header.biSize = sizeof(header);
    header.biWidth = frame_.width;
    header.biHeight = -frame_.height;
    header.biPlanes = 1;
    header.biBitCount = 32;
    SetDIBitsToDevice(dc, 0, 0, frame_.width, frame_.height, 0, 0, 0,
                       frame_.height, dim_.data(), &info, DIB_RGB_COLORS);
    if (ValidSelection()) {
      BitBlt(dc, region_.left, region_.top, Width(region_), Height(region_),
             frame_.dc, region_.left, region_.top, SRCCOPY);
      HBRUSH green = CreateSolidBrush(kGreen);
      FrameRect(dc, &region_, green);
      if (!full_) {
        const int radius = Dp(4);
        for (LONG x : {region_.left, region_.right - 1}) {
          for (LONG y : {region_.top, region_.bottom - 1}) {
            RECT handle{x - radius, y - radius, x + radius + 1, y + radius + 1};
            FillRect(dc, &handle, green);
            FrameRect(dc, &handle, static_cast<HBRUSH>(GetStockObject(WHITE_BRUSH)));
          }
        }
      }
      DeleteObject(green);
    }
    PaintToolbar(dc);
    EndPaint(window_, &paint);
  }

  void PaintToolbar(HDC dc) {
    auto tools = Tools();
    RECT bar{tools.front().rect.left - Dp(6), Dp(8),
             tools.back().rect.right + Dp(6), tools.front().rect.bottom + Dp(6)};
    auto rounded = [&](const RECT& rect, COLORREF color) {
      HBRUSH brush = CreateSolidBrush(color);
      const auto prior_brush = SelectObject(dc, brush);
      const auto prior_pen = SelectObject(dc, GetStockObject(NULL_PEN));
      RoundRect(dc, rect.left, rect.top, rect.right, rect.bottom, Dp(14), Dp(14));
      SelectObject(dc, prior_pen);
      SelectObject(dc, prior_brush);
      DeleteObject(brush);
    };
    if (scroll_) {
      bar = BoxAt(0, 0, Width(scroll_bar_), Height(scroll_bar_));
      HBRUSH paper = CreateSolidBrush(kPaper);
      FillRect(dc, &bar, paper);
      DeleteObject(paper);
    } else {
      rounded(bar, kPaper);
    }
    const auto font = CreateFontW(-Dp(13), 0, 0, 0, FW_MEDIUM, FALSE, FALSE,
        FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Microsoft YaHei UI");
    const auto old_font = font ? SelectObject(dc, font) : nullptr;
    SetBkMode(dc, TRANSPARENT);
    if (scroll_) {
      RECT status = BoxAt(Dp(10), 0, Width(bar) - Dp(160), Height(bar));
      SetTextColor(dc, kGreen);
      DrawTextW(dc, scroll_text_.c_str(), -1, &status,
                DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    }
    for (auto& tool : tools) {
      const bool selected = (tool.action == Action::area && !full_) ||
          (tool.action == Action::screen && full_);
      const bool primary = tool.action == Action::finish && (scroll_ || ValidSelection());
      if (selected || primary) {
        rounded(tool.rect, primary ? kGreen : RGB(230, 237, 228));
      }
      SetTextColor(dc, primary ? kWhite : tool.action == Action::finish
          ? RGB(120, 128, 120) : kGreen);
      DrawTextW(dc, tool.label, -1, &tool.rect,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    }
    if (font) {
      SelectObject(dc, old_font);
      DeleteObject(font);
    }
  }

  unsigned int Edges(POINT point) const {
    const int grip = Dp(7);
    RECT hit = region_;
    InflateRect(&hit, grip, grip);
    if (!PtInRect(&hit, point)) return 0;
    unsigned int edges = 0;
    if (std::abs(point.x - region_.left) <= grip) edges |= left;
    else if (std::abs(point.x - region_.right) <= grip) edges |= right;
    if (std::abs(point.y - region_.top) <= grip) edges |= top;
    else if (std::abs(point.y - region_.bottom) <= grip) edges |= bottom;
    return edges;
  }

  void Down(POINT point) {
    for (const auto& tool : Tools()) {
      if (!PtInRect(&tool.rect, point)) continue;
      pressed_ = static_cast<int>(tool.action);
      SetCapture(window_);
      return;
    }
    if (scroll_ || full_) return;
    origin_ = point;
    original_ = region_;
    edges_ = ValidSelection() ? Edges(point) : 0;
    if (edges_ != 0) drag_ = Drag::resize;
    else if (ValidSelection() && PtInRect(&region_, point)) drag_ = Drag::move;
    else {
      drag_ = Drag::draw;
      region_ = {point.x, point.y, point.x, point.y};
    }
    SetCapture(window_);
  }

  void Move(POINT point) {
    if (drag_ == Drag::none) return;
    const auto frame = EntireFrame();
    point.x = std::clamp(point.x, 0L, frame.right);
    point.y = std::clamp(point.y, 0L, frame.bottom);
    RECT before = region_;
    region_ = original_;
    if (drag_ == Drag::draw) {
      region_ = {std::min(origin_.x, point.x), std::min(origin_.y, point.y),
                 std::max(origin_.x, point.x), std::max(origin_.y, point.y)};
    } else if (drag_ == Drag::move) {
      OffsetRect(&region_,
          std::clamp(point.x - origin_.x, -region_.left, frame.right - region_.right),
          std::clamp(point.y - origin_.y, -region_.top, frame.bottom - region_.bottom));
    } else {
      if (edges_ & left) region_.left = std::min(point.x, region_.right - 2);
      if (edges_ & right) region_.right = std::max(point.x, region_.left + 2);
      if (edges_ & top) region_.top = std::min(point.y, region_.bottom - 2);
      if (edges_ & bottom) region_.bottom = std::max(point.y, region_.top + 2);
    }
    RECT dirty{};
    UnionRect(&dirty, &before, &region_);
    InflateRect(&dirty, Dp(6), Dp(6));
    dirty.top = 0;  // The enabled state of Finish changes with the selection.
    dirty.left = 0;
    dirty.right = frame.right;
    dirty.bottom = std::max(dirty.bottom, static_cast<LONG>(Dp(56)));
    InvalidateRect(window_, &dirty, FALSE);
  }

  void Up(POINT point) {
    Move(point);
    const auto pressed = std::exchange(pressed_, -1);
    drag_ = Drag::none;
    if (GetCapture() == window_) ReleaseCapture();
    for (const auto& tool : Tools()) {
      if (pressed == static_cast<int>(tool.action) && PtInRect(&tool.rect, point)) {
        Activate(tool.action);
        return;
      }
    }
  }

  void Activate(Action action) {
    switch (action) {
      case Action::area:
        if (full_) region_ = last_region_;
        full_ = false;
        break;
      case Action::screen:
        if (!full_) last_region_ = region_;
        full_ = true;
        region_ = EntireFrame();
        break;
      case Action::scrolling:
        BeginScroll();
        return;
      case Action::finish:
        if (scroll_ || ValidSelection()) {
          auto bytes = scroll_ ? scroll_->Encode()
                               : EncodeSelection(frame_.pixels, frame_.width, region_);
          const auto error = bytes.empty() ? "无法保存此选区，请缩小区域后重试" : nullptr;
          Close({std::move(bytes), error});
        }
        return;
      case Action::cancel:
        Close({});
        return;
    }
    InvalidateRect(window_, nullptr, FALSE);
  }

  void BeginScroll() {
    const RECT crop = ValidSelection() ? region_ : EntireFrame();
    if (Height(crop) < Dp(80) || Width(crop) < Dp(100)) {
      MessageBeep(MB_OK);
      return;
    }
    scroll_ = std::make_unique<ScrollImage>();
    scroll_->Begin(frame_, crop);
    scroll_area_ = crop;
    OffsetRect(&scroll_area_, screen_.left, screen_.top);
    const int width = std::min(Dp(410), Width(screen_) - Dp(10));
    const int height = Dp(44);
    const LONG y = scroll_area_.top >= screen_.top + height + Dp(10)
        ? screen_.top + Dp(5)
        : scroll_area_.bottom + height + Dp(10) <= screen_.bottom
            ? screen_.bottom - height - Dp(5) : screen_.top + Dp(5);
    scroll_bar_ = BoxAt(screen_.left + (Width(screen_) - width) / 2, y, width, height);
    scroll_text_ = L"向下滚动 · 已捕获 1 屏";
    scroll_started_ = std::chrono::steady_clock::now();
    frame_.Reset();
    std::vector<std::uint8_t>().swap(dim_);
    SetWindowPos(window_, HWND_TOPMOST, scroll_bar_.left, scroll_bar_.top, width,
                 height, SWP_NOACTIVATE);
    if (previous_ && IsWindowVisible(previous_) && !IsIconic(previous_)) {
      SetForegroundWindow(previous_);
    }
    InvalidateRect(window_, nullptr, FALSE);
    SetTimer(window_, kScrollTimer, 1200, nullptr);
  }

  void SampleScroll() {
    if (!scroll_) return;
    if (std::chrono::steady_clock::now() - scroll_started_ > std::chrono::minutes(5)) {
      KillTimer(window_, kScrollTimer);
      scroll_text_ = L"已停止采集，可保存当前进度";
      InvalidateRect(window_, nullptr, FALSE);
      return;
    }
    if (GetCapture() == window_) return;
    const auto foreground = GetForegroundWindow();
    if (previous_ && foreground != previous_ && foreground != window_) {
      scroll_text_ = L"回到截图前的窗口继续";
      InvalidateRect(window_, nullptr, FALSE);
      return;
    }
    RECT overlap{};
    const bool mask = IntersectRect(&overlap, &scroll_area_, &scroll_bar_);
    if (mask) {
      ShowWindow(window_, SW_HIDE);
      DwmFlush();
    }
    Frame next;
    const bool read = next.Read(scroll_area_);
    if (mask) ShowWindow(window_, SW_SHOWNOACTIVATE);
    if (read) {
      switch (scroll_->Append(next, BoxAt(0, 0, next.width, next.height))) {
        case ScrollImage::AppendResult::unchanged:
        case ScrollImage::AppendResult::joined:
          scroll_text_ = L"向下滚动 · 已捕获 " + std::to_wstring(scroll_->frames()) + L" 屏";
          break;
        case ScrollImage::AppendResult::ambiguous:
          scroll_text_ = L"请少滚一点，保留上一屏的部分内容";
          break;
        case ScrollImage::AppendResult::limit:
          scroll_text_ = L"已达长度上限，可保存";
          KillTimer(window_, kScrollTimer);
          break;
      }
    } else {
      scroll_text_ = L"暂时无法读取屏幕，可保存当前进度";
    }
    InvalidateRect(window_, nullptr, FALSE);
  }

  LRESULT OnMessage(UINT message, WPARAM wparam, LPARAM lparam) {
    const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    switch (message) {
      case WM_MOUSEACTIVATE: if (scroll_) return MA_NOACTIVATE; break;
      case WM_TIMER: if (wparam == kScrollTimer) { SampleScroll(); return 0; } break;
      case WM_ERASEBKGND: return 1;
      case WM_PAINT: Paint(); return 0;
      case WM_LBUTTONDOWN: Down(point); return 0;
      case WM_MOUSEMOVE: Move(point); return 0;
      case WM_LBUTTONUP: Up(point); return 0;
      case WM_CAPTURECHANGED:
        drag_ = Drag::none;
        pressed_ = -1;
        return 0;
      case WM_SETCURSOR: {
        POINT pointer{};
        GetCursorPos(&pointer);
        ScreenToClient(window_, &pointer);
        auto cursor = full_ || scroll_ ? IDC_ARROW : IDC_CROSS;
        for (const auto& tool : Tools()) {
          if (PtInRect(&tool.rect, pointer)) {
            SetCursor(LoadCursorW(nullptr, IDC_HAND));
            return TRUE;
          }
        }
        if (!scroll_ && !full_ && ValidSelection()) {
          const auto edges = Edges(pointer);
          if (edges == (left | top) || edges == (right | bottom)) cursor = IDC_SIZENWSE;
          else if (edges == (right | top) || edges == (left | bottom)) cursor = IDC_SIZENESW;
          else if (edges & (left | right)) cursor = IDC_SIZEWE;
          else if (edges & (top | bottom)) cursor = IDC_SIZENS;
          else if (PtInRect(&region_, pointer)) cursor = IDC_SIZEALL;
        }
        SetCursor(LoadCursorW(nullptr, cursor));
        return TRUE;
      }
      case WM_KEYDOWN:
        if (wparam == VK_RETURN) { Activate(Action::finish); return 0; }
        if (wparam == VK_ESCAPE) { Close({}); return 0; }
        break;
      case WM_RBUTTONUP:
      case WM_CLOSE:
      case WM_DISPLAYCHANGE:
      case WM_DPICHANGED:
        Close({});
        return 0;
    }
    return DefWindowProcW(window_, message, wparam, lparam);
  }

  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      auto* self = static_cast<Selection*>(
          reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
      self->window_ = hwnd;
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    auto* self = reinterpret_cast<Selection*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (!self || message == WM_DESTROY || message == WM_NCDESTROY) {
      return DefWindowProcW(hwnd, message, wparam, lparam);
    }
    return self->OnMessage(message, wparam, lparam);
  }

  HWND window_ = nullptr;
  HWND previous_ = nullptr;
  Completion completion_;
  RECT screen_{};
  RECT region_{};
  RECT last_region_{};
  RECT original_{};
  POINT origin_{};
  Frame frame_;
  std::vector<std::uint8_t> dim_;
  std::unique_ptr<ScrollImage> scroll_;
  std::wstring scroll_text_;
  std::chrono::steady_clock::time_point scroll_started_;
  RECT scroll_area_{};
  RECT scroll_bar_{};
  Drag drag_ = Drag::none;
  unsigned int edges_ = 0;
  int pressed_ = -1;
  double scale_ = 1;
  bool full_ = false;
};

WindowsScreenCapture::WindowsScreenCapture() = default;
WindowsScreenCapture::~WindowsScreenCapture() = default;
void WindowsScreenCapture::Start(HMONITOR monitor, HWND previous_window,
                                 Completion completion) {
  if (selection_ && selection_->active()) {
    completion({{}, "已有截图正在编辑"});
    return;
  }
  selection_ = std::make_unique<Selection>();
  selection_->Start(monitor, previous_window, std::move(completion));
}
void WindowsScreenCapture::Cancel() {
  if (selection_) selection_->Close({});
}
