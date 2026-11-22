#include "windows_assistant_overlay.h"

#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <windowsx.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <optional>
#include <string>
#include <utility>

#include "utils.h"
#include "windows_screen_capture.h"

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using List = flutter::EncodableList;
using Channel = flutter::MethodChannel<Value>;
using Reply = flutter::MethodResult<Value>;
using Call = flutter::MethodCall<Value>;
using Clock = std::chrono::steady_clock;
constexpr auto kClass = L"MissionBook.AssistantOverlay";
constexpr auto kPreferenceKey = L"Software\\MissionBook";
constexpr UINT_PTR kUsageTimer = 1;
constexpr UINT kRefreshLayout = WM_APP + 71;

void Trace(const std::string& message) {
  wchar_t directory[MAX_PATH]{};
  const DWORD length = GetModuleFileNameW(nullptr, directory, MAX_PATH);
  if (length == 0) return;
  std::wstring path(directory, length);
  const auto slash = path.find_last_of(L"\\/");
  path.resize(slash == std::wstring::npos ? 0 : slash + 1);
  path += L"missionbook-overlay.log";
  const HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA,
      FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS,
      FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return;
  const std::string line =
      std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::steady_clock::now().time_since_epoch()).count()) +
      ' ' + message + "\r\n";
  DWORD written = 0;
  WriteFile(file, line.data(), static_cast<DWORD>(line.size()), &written,
            nullptr);
  CloseHandle(file);
}

const Value* Field(const Value* args, const char* name) {
  const auto* map = args ? std::get_if<Map>(args) : nullptr;
  if (!map) return nullptr;
  const auto it = map->find(Value(name));
  return it == map->end() ? nullptr : &it->second;
}

std::string Text(const Value* args, const char* field) {
  const auto* value = Field(args, field);
  const auto* text = value ? std::get_if<std::string>(value) : nullptr;
  return text ? *text : std::string();
}

bool Flag(const Value* args, const char* field) {
  const auto* value = Field(args, field);
  const auto* flag = value ? std::get_if<bool>(value) : nullptr;
  return flag && *flag;
}

bool Preference(const wchar_t* name) {
  DWORD value = 0;
  DWORD bytes = sizeof(value);
  return RegGetValueW(HKEY_CURRENT_USER, kPreferenceKey, name, RRF_RT_REG_DWORD,
                      nullptr, &value, &bytes) == ERROR_SUCCESS && value != 0;
}

bool SavePreference(const wchar_t* name, bool enabled) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kPreferenceKey, 0, nullptr, 0,
                     KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const DWORD value = enabled ? 1 : 0;
  const auto status = RegSetValueExW(key, name, 0, REG_DWORD,
      reinterpret_cast<const BYTE*>(&value), sizeof(value));
  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

std::string ProcessLabel(DWORD pid) {
  const auto process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return {};
  wchar_t image[MAX_PATH * 4]{};
  DWORD length = static_cast<DWORD>(std::size(image));
  const bool ok = QueryFullProcessImageNameW(process, 0, image, &length);
  CloseHandle(process);
  if (!ok) return {};
  std::wstring path(image, length);
  path = path.substr(path.find_last_of(L"\\/") + 1);
  if (path.size() > 4 && _wcsicmp(path.c_str() + path.size() - 4, L".exe") == 0) {
    path.resize(path.size() - 4);
  }
  return Utf8FromUtf16(path.c_str());
}

int Width(RECT rect) { return rect.right - rect.left; }
int Height(RECT rect) { return rect.bottom - rect.top; }
LONG Clamp(LONG v, LONG low, LONG high) {
  return std::clamp(v, low, std::max(low, high));
}
RECT Box(LONG x, LONG y, LONG w, LONG h) { return {x, y, x + w, y + h}; }
LONG CenterX(RECT rect) { return rect.left + Width(rect) / 2; }
LONG CenterY(RECT rect) { return rect.top + Height(rect) / 2; }

struct Part {
  std::string id;
  RECT rect;
  bool circle = true;
};
}  // namespace

class WindowsAssistantOverlay::Host {
 public:
  Host(HWND main_window, flutter::BinaryMessenger* messenger,
       const flutter::DartProject& project)
      : main_window_(main_window), project_(project),
        workspace_(messenger, "mission_book/assistant_workspace",
                   &flutter::StandardMethodCodec::GetInstance()),
        navigation_(messenger, "mission_book/assistant_overlay",
                    &flutter::StandardMethodCodec::GetInstance()),
        enabled_(Preference(L"AssistantOverlay")),
        usage_(Preference(L"AssistantUsage")) {
    workspace_.SetMethodCallHandler([this](const Call& call, auto result) {
      WorkspaceEvent(call, std::move(result));
    });
    navigation_.SetMethodCallHandler([this](const Call& call, auto result) {
      if (call.method_name() == "consumePendingOpen") {
        result->Success(Value(std::exchange(pending_open_, false)));
      } else if (call.method_name() == "consumeAssistantSession") {
        result->Success();
      } else if (call.method_name() == "consumePendingMission") {
        Consume(pending_mission_, *result);
      } else if (call.method_name() == "consumeAssistantRecord") {
        Consume(pending_record_, *result);
      } else {
        result->NotImplemented();
      }
    });
    Trace("Host created enabled=" + std::to_string(enabled_));
  }

  ~Host() {
    life_.reset();
    enabled_ = false;
    capture_.Cancel();
    workspace_.SetMethodCallHandler(nullptr);
    navigation_.SetMethodCallHandler(nullptr);
    if (client_) client_->SetMethodCallHandler(nullptr);
    if (window_) {
      Hide();
      DestroyWindow(window_);
    }
    client_.reset();
    controller_.reset();
  }

  bool enabled() const { return enabled_; }
  void SetAppearance(const char* field, const Value& value) {
    appearance_.insert_or_assign(Value(field), value);
    Publish(field, value);
  }

  bool SetEnabled(bool enabled) {
    Trace("SetEnabled " + std::to_string(enabled));
    if (enabled && !EnsureWindow()) return false;
    if (!SavePreference(L"AssistantOverlay", enabled)) return false;
    enabled_ = enabled;
    if (!enabled) {
      ++capture_sequence_;
      capturing_ = false;
      UpdateTimer();
      InvalidateUsage();
      CancelVoice();
      Invoke("unwatch");
      mode_ = "closed";
      Hide();
      capture_.Cancel();
    } else {
      UpdateTimer();
      Layout();
      if (client_ready_) RequestWatch(true);
    }
    return true;
  }

 private:
  static void Consume(std::string& value, Reply& result) {
    if (value.empty()) result.Success();
    else result.Success(Value(std::exchange(value, {})));
  }

  bool EnsureWindow() {
    Trace("EnsureWindow begin");
    if (window_) return true;
    const auto module = GetModuleHandleW(nullptr);
    WNDCLASSW klass{};
    klass.hInstance = module;
    klass.lpszClassName = kClass;
    klass.lpfnWndProc = &WindowProc;
    klass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    klass.hbrBackground = static_cast<HBRUSH>(GetStockObject(WHITE_BRUSH));
    RegisterClassW(&klass);
    MONITORINFO monitor_info{sizeof(monitor_info)};
    auto monitor = MonitorFromWindow(main_window_, MONITOR_DEFAULTTONEAREST);
    if (!GetMonitorInfoW(monitor, &monitor_info)) return false;
    const auto work = monitor_info.rcWork;
    const int size = MulDiv(56, static_cast<int>(FlutterDesktopGetDpiForMonitor(monitor)), 96);
    center_ = {work.right - size, work.top + Height(work) * 2 / 3};
    window_ = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kClass, L"书祺悬浮球",
        WS_POPUP | WS_CLIPCHILDREN, center_.x - size / 2, center_.y - size / 2,
        size, size, nullptr, nullptr, module, this);
    Trace("EnsureWindow window=" + std::to_string(window_ != nullptr));
    if (!window_) return false;
    auto overlay_project = project_;
    overlay_project.set_dart_entrypoint("windowsAssistantOverlayMain");
    controller_ = std::make_unique<flutter::FlutterViewController>(size, size, overlay_project);
    Trace("EnsureWindow controller=" + std::to_string(controller_->engine() != nullptr) +
          "," + std::to_string(controller_->view() != nullptr));
    if (!controller_->engine() || !controller_->view()) {
      controller_.reset();
      DestroyWindow(window_);
      return false;
    }
    UrlLauncherWindowsRegisterWithRegistrar(
        controller_->engine()->GetRegistrarForPlugin("UrlLauncherWindows"));
    Trace("EnsureWindow url_launcher registered");
    child_ = controller_->view()->GetNativeWindow();
    SetParent(child_, window_);
    MoveWindow(child_, 0, 0, size, size, TRUE);
    client_ = std::make_unique<Channel>(controller_->engine()->messenger(),
        "mission_book/windows_overlay", &flutter::StandardMethodCodec::GetInstance());
    client_->SetMethodCallHandler([this](const Call& call, auto result) {
      ClientCall(call, std::move(result));
    });
    controller_->ForceRedraw();
    Trace("EnsureWindow done");
    return true;
  }

  void Hide() {
    if (window_) ShowWindow(window_, SW_HIDE);
  }

  void Publish(const char* method, Value value) {
    if (client_ && client_ready_ && life_) {
      client_->InvokeMethod(method, std::make_unique<Value>(std::move(value)));
    }
  }

  void WorkspaceEvent(const Call& call, std::unique_ptr<Reply> result) {
    const auto& method = call.method_name();
    const auto* args = call.arguments();
    Trace("WorkspaceEvent " + method);
    if (method == "ready" && args) {
      generation_ = *args;
      if (enabled_ && !EnsureWindow()) {
        enabled_ = false;
      }
      UpdateTimer();
      Layout();
      if (enabled_ && client_ready_) RequestWatch(mode_ != "chat");
    } else if (method == "unavailable" && args && *args == generation_) {
      generation_ = Value();
      InvalidateUsage();
      ++capture_sequence_;
      capturing_ = false;
      capture_.Cancel();
      UpdateTimer();
      mode_ = "closed";
      ResetClient();
      Layout();
    } else if (method == "resetObservation") {
      InvalidateUsage();
    } else if (method == "state" && args) {
      RenderState(*args);
    } else if (method == "error" && args) {
      Publish("error", *args);
    } else if (method == "currentUse") {
      if (enabled_ && usage_ && args && *args == generation_) {
        Sample();
        if (!foreground_app_.empty()) {
          result->Success(Value(Map{{Value("app"), Value(foreground_app_)},
              {Value("seconds"), Value(DwellSeconds())}}));
          return;
        }
      }
    } else if (method == "verifyObservation") {
      Sample();
      const auto* generation = Field(args, "generation");
      const auto* revision = Field(args, "revision");
      result->Success(Value(enabled_ && usage_ && generation && *generation == generation_ &&
          revision && *revision == Value(observation_revision_) &&
          !foreground_app_.empty() && Text(args, "observationId") == observation_id_));
      return;
    } else {
      result->NotImplemented();
      return;
    }
    result->Success();
  }

  void Invoke(const char* method, Map args = {},
              std::function<void(const Value*)> success = {},
              std::function<void(const std::string&)> failure = {}) {
    if (generation_.IsNull()) {
      if (failure) failure("助手工作区正在准备，请重试");
      return;
    }
    args.insert_or_assign(Value("generation"), generation_);
    const std::weak_ptr<int> alive = life_;
    const auto generation = generation_;
    workspace_.InvokeMethod(method, std::make_unique<Value>(std::move(args)),
        std::make_unique<flutter::MethodResultFunctions<Value>>(
            [this, alive, generation, success, failure](const Value* value) {
              if (alive.expired()) return;
              if (!(generation == generation_)) {
                if (failure) failure("助手工作区已切换，请重试");
              } else if (success) {
                success(value);
              }
            },
            [alive, failure](const auto&, const auto& message, const auto*) {
              if (!alive.expired() && failure) failure(message);
            },
            [alive, failure]() {
              if (!alive.expired() && failure) failure("当前助手操作不可用");
            }));
  }

  void ClientCall(const Call& call, std::unique_ptr<Reply> result) {
    const auto& method = call.method_name();
    const auto* args = call.arguments();
    Trace("ClientCall " + method);
    if (method == "ready") {
      client_ready_ = true;
      result->Success();
      for (const auto& entry : appearance_) {
        Publish(std::get<std::string>(entry.first).c_str(), entry.second);
      }
      Layout();
      if (enabled_) RequestWatch(mode_ != "chat");
      return;
    }
    if (method == "painted") {
      client_painted_ = true;
      // Reveal only after the Flutter view has rendered the initial geometry.
      if (enabled_ && !capturing_ && window_) ShowWindow(window_, SW_SHOWNOACTIVATE);
      result->Success();
      return;
    }
    if (!enabled_ || capturing_) {
      result->Error("overlay_inactive", "悬浮球暂不可用");
      return;
    }
    if (method == "dragStart" || method == "dragMove" || method == "dragEnd") {
      Drag(method, Flag(args, "cancel"));
    } else if (method == "reveal") {
      Reveal();
    } else if (method == "mode") {
      const auto next = Text(args, "value");
      if (next == "closed" || next == "tools" || next == "more" || next == "chat") {
        Mode(next, Flag(args, "focus"));
      }
    } else if (method == "capture") {
      BeginCapture();
    } else if (method == "usage") {
      if (!SavePreference(L"AssistantUsage", !usage_)) {
        result->Error("usage_preference", "无法保存应用感知开关");
        return;
      }
      usage_ = !usage_;
      InvalidateUsage();
      UpdateTimer();
      Layout();
    } else if (method == "openMain") {
      OpenMain(Text(args, "missionId"), Text(args, "recordId"));
    } else if (method == "workspace") {
      const auto name = Text(args, "method");
      const auto* parameters = Field(args, "args");
      const auto* fields = parameters ? std::get_if<Map>(parameters) : nullptr;
      // The peer can issue assistant UI actions, not arbitrary platform calls.
      if (!fields || !Allowed(name)) {
        result->NotImplemented();
        return;
      }
      auto reply = std::shared_ptr<Reply>(std::move(result));
      Invoke(name.c_str(), *fields,
          [this, reply, name](const Value* value) {
            if (name == "openNotice" || name == "dismissNotice") ClearNotice();
            if (value) reply->Success(*value);
            else reply->Success();
          },
          [reply](const std::string& error) { reply->Error("assistant_request", error); });
      return;
    } else {
      result->NotImplemented();
      return;
    }
    result->Success();
  }

  static bool Allowed(const std::string& name) {
    return name == "draft" || name == "send" || name == "stop" || name == "image" ||
        name == "removeImage" || name == "stageRecord" || name == "confirm" ||
        name == "reject" || name == "checkOutcome" || name == "newSession" ||
        name == "voiceStart" || name == "voiceFinish" || name == "voiceCancel" ||
        name == "openNotice" || name == "dismissNotice";
  }

  void Mode(const std::string& next, bool focus = false) {
    const bool leaving_chat = mode_ == "chat" && next != "chat";
    const bool entering_chat = mode_ != "chat" && next == "chat";
    mode_ = next;
    if (leaving_chat) {
      CancelVoice();
      RequestWatch(true);
      if (GetForegroundWindow() == window_ && previous_ && IsWindow(previous_) &&
          IsWindowVisible(previous_) && !IsIconic(previous_)) {
        SetForegroundWindow(previous_);
      }
    }
    Layout();
    if (entering_chat) RequestWatch();
    if (focus && next == "chat" && window_) {
      RememberForeground();
      if (SetForegroundWindow(window_) && child_) SetFocus(child_);
    }
  }

  void CancelVoice() {
    if (has_state_) Invoke("voiceCancel", {{Value("key"), Value(draft_key_)}});
  }

  void ResetClient() {
    state_revision_ = 0;
    has_state_ = false;
    image_count_ = 0;
    Publish("reset", Value());
  }

  void RenderState(const Value& value) {
    const auto* generation = Field(&value, "generation");
    if (!enabled_ || !generation || !(*generation == generation_)) return;
    const auto* revision = Field(&value, "revision");
    const auto serial = revision ? revision->TryGetLongValue().value_or(0) : 0;
    if (serial <= state_revision_) return;
    state_revision_ = serial;
    has_state_ = true;
    draft_key_ = Text(&value, "key");
    const auto* images = Field(&value, "images");
    const auto* list = images ? std::get_if<List>(images) : nullptr;
    const int count = list ? static_cast<int>(list->size()) : 0;
    const bool changed = image_count_ != count;
    image_count_ = count;
    Publish("state", value);
    if (changed) Layout();
  }

  void RequestWatch(bool compact = false) {
    Invoke("watch", {{Value("compact"), Value(compact)}}, [this](const Value* state) {
      if (state) RenderState(*state);
    }, [this](const std::string& error) { Publish("error", Value(error)); });
  }

  void BeginCapture() {
    if (capturing_) return;
    RememberForeground();
    const auto monitor = MonitorFromPoint(center_, MONITOR_DEFAULTTONEAREST);
    capturing_ = true;
    const auto sequence = ++capture_sequence_;
    const auto valid = [this, sequence] { return capturing_ && sequence == capture_sequence_; };
    const auto fail = [this, valid](const std::string& error) {
      if (!valid()) return;
      capturing_ = false;
      Mode("chat");
      Publish("error", Value(error));
    };
    Invoke("beginCapture", {}, [this, monitor, valid, fail](const Value* value) {
      const auto* ticket = value ? std::get_if<std::string>(value) : nullptr;
      if (!ticket) return fail("无法开始截图");
      if (!valid() || !enabled_) {
        Invoke("capture", {{Value("ticket"), Value(*ticket)}});
        return;
      }
      Hide();
      capture_.Start(monitor, previous_, [this, valid, fail, ticket = *ticket](auto outcome) {
        if (!life_) return;
        const bool added = !outcome.jpeg.empty();
        const auto restore = [this, valid, fail, added, error = outcome.error](const Value* result) {
          if (!valid()) return;
          if (added && (!result || !(*result == Value(true)))) {
            fail("这次截图交接已过期，请重试");
            return;
          }
          capturing_ = false;
          if (!enabled_) return;
          if (added) RequestWatch(mode_ != "chat");
          if (error) Mode("chat");
          else if (mode_ == "tools" || mode_ == "more") Mode("closed");
          else Layout();
          if (error) Publish("error", Value(error));
        };
        Map args{{Value("ticket"), Value(ticket)}};
        if (added) args[Value("bytes")] = Value(std::move(outcome.jpeg));
        Invoke("capture", std::move(args), restore, fail);
      });
    }, fail);
  }

  void OpenMain(const std::string& mission, const std::string& record) {
    Mode("closed");
    if (IsIconic(main_window_)) ShowWindow(main_window_, SW_RESTORE);
    SetForegroundWindow(main_window_);
    if (!mission.empty()) {
      pending_mission_ = mission;
      navigation_.InvokeMethod("pendingMission", nullptr);
    } else if (!record.empty()) {
      pending_record_ = record;
      navigation_.InvokeMethod("pendingRecord", nullptr);
    } else {
      pending_open_ = true;
      navigation_.InvokeMethod("pendingOpen", nullptr);
    }
  }

  void RememberForeground() {
    const auto current = GetForegroundWindow();
    if (current && current != window_) previous_ = current;
  }

  void ClearNotice() {
    if (!notice_active_) return;
    notice_active_ = false;
    Publish("notice", Value());
    Layout();
  }

  void InvalidateUsage() {
    foreground_pid_ = 0;
    foreground_app_.clear();
    observation_id_.clear();
    ++observation_revision_;
    ClearNotice();
    Invoke("invalidateObservation");
  }

  void UpdateTimer() {
    if (!window_) return;
    if (usage_ && enabled_ && !generation_.IsNull()) SetTimer(window_, kUsageTimer, 2000, nullptr);
    else KillTimer(window_, kUsageTimer);
  }

  int DwellSeconds() const {
    const auto end = paused_at_ == Clock::time_point{} ? Clock::now() : paused_at_;
    return static_cast<int>(std::min<long long>(86400,
        std::chrono::duration_cast<std::chrono::seconds>(end - since_).count()));
  }

  void Sample() {
    if (!usage_ || !enabled_) return;
    const auto foreground = GetForegroundWindow();
    DWORD pid = 0;
    if (foreground) GetWindowThreadProcessId(foreground, &pid);
    // Our own editor / toolbar does not start an app-use observation.
    if (pid == GetCurrentProcessId() && foreground != main_window_) {
      if (paused_at_ == Clock::time_point{}) paused_at_ = Clock::now();
      return;
    }
    if (pid == GetCurrentProcessId()) pid = 0;
    if (pid == foreground_pid_) {
      if (paused_at_ != Clock::time_point{}) {
        since_ += Clock::now() - paused_at_;
        paused_at_ = {};
      }
      return;
    }
    paused_at_ = {};
    foreground_pid_ = pid;
    foreground_app_ = pid == 0 ? std::string() : ProcessLabel(pid);
    since_ = Clock::now();
    observation_id_ = std::to_string(++observation_revision_);
    last_checked_ = {};
  }

  void Observe() {
    Sample();
    const auto now = Clock::now();
    if (!enabled_ || !usage_ || foreground_app_.empty() || DwellSeconds() < 90 ||
        now - last_checked_ < std::chrono::seconds(30)) return;
    DWORD pid = 0;
    GetWindowThreadProcessId(GetForegroundWindow(), &pid);
    if (pid != foreground_pid_) return;
    last_checked_ = now;
    const int revision = observation_revision_;
    Invoke("observation", {{Value("app"), Value(foreground_app_)},
        {Value("seconds"), Value(DwellSeconds())}, {Value("revision"), Value(revision)},
        {Value("observationId"), Value(observation_id_)}},
        [this, revision](const Value* notice) {
          if (!notice || notice->IsNull() || !enabled_ || !usage_ || revision != observation_revision_) return;
          // The bubble carries the notice. The user chooses whether to open it.
          notice_active_ = true;
          Publish("notice", *notice);
          Layout();
        });
  }

  int Dp(double value) const { return static_cast<int>(std::lround(scale_ * value)); }

  void Reveal() {
    if (dock_ == 0) return;
    center_.x = dock_ < 0 ? work_.left + Dp(44) : work_.right - Dp(44);
    dock_ = 0;
    Mode("tools");
  }

  void Drag(const std::string& method, bool cancelled) {
    POINT pointer{};
    if (!GetCursorPos(&pointer)) return;
    if (method == "dragStart") {
      drag_origin_ = pointer;
      drag_center_ = center_;
      dragging_ = false;
      return;
    }
    if (method == "dragMove") {
      const int dx = pointer.x - drag_origin_.x;
      const int dy = pointer.y - drag_origin_.y;
      if (!dragging_ && std::abs(dx) + std::abs(dy) < Dp(6)) return;
      if (!dragging_) {
        if (dock_ != 0) {
          const bool inward = (dock_ < 0 && dx > 0) || (dock_ > 0 && dx < 0);
          if (!inward) return;
          Reveal();
          drag_center_ = center_;
        } else {
          Mode("closed");
        }
      }
      dragging_ = true;
      center_ = {drag_center_.x + dx, drag_center_.y + dy};
      Layout();
    } else if (dragging_ && !cancelled) {
      dragging_ = false;
      if (pointer.x < work_.left + Dp(18)) dock_ = -1;
      if (pointer.x >= work_.right - Dp(18)) dock_ = 1;
      Layout();
    } else if (!dragging_ && !cancelled && dock_ != 0) {
      Reveal();
    }
    dragging_ = false;
  }

  void AddTools(RECT ball, RECT safe, std::vector<Part>& parts) const {
    static constexpr const char* primary[] = {"text", "voice", "capture", "more"};
    static constexpr const char* more[] = {"main", "capture", "usage", "back"};
    const auto& names = mode_ == "more" ? more : primary;
    const LONG size = Dp(50);
    const LONG gap = Dp(7);
    const bool left = CenterX(ball) >= CenterX(safe);
    if ((left ? ball.left - safe.left : safe.right - ball.right) >= 2 * size + gap &&
        Height(safe) >= size * 4 + gap * 3) {
      const LONG top = Clamp(CenterY(ball) - (size * 4 + gap * 3) / 2,
                             safe.top, safe.bottom - size * 4 - gap * 3);
      for (int i = 0; i < 4; ++i) {
        const LONG out = Dp(i == 0 || i == 3 ? 12 : 38);
        const LONG x = left ? ball.left - gap - out - size : ball.right + gap + out;
        parts.push_back({names[i], Box(x, top + i * (size + gap), size, size)});
      }
      return;
    }
    const LONG above = ball.top - gap - safe.top;
    const LONG below = safe.bottom - ball.bottom - gap;
    const LONG side = left ? ball.left - gap - safe.left : safe.right - ball.right - gap;
    if (std::max(above, below) < 2 * size + gap &&
        side >= 2 * size + gap && Height(safe) >= 2 * size + gap) {
      const LONG span = 2 * size + gap;
      const LONG x = left ? ball.left - gap - span : ball.right + gap;
      const LONG y = Clamp(CenterY(ball) - span / 2, safe.top, safe.bottom - span);
      for (int i = 0; i < 4; ++i) {
        parts.push_back({names[i], Box(x + (i % 2) * (size + gap),
                                      y + (i / 2) * (size + gap), size, size)});
      }
      return;
    }
    // Short displays put the tools in a row if there is space on either side
    // of the ball vertically. Every circle keeps a separate hit target.
    const LONG columns = Width(safe) >= 4 * size + 3 * gap ? 4 : 2;
    const LONG rows = 4 / columns;
    const LONG available_height = std::max(above, below);
    const LONG fitted = std::max(1L, std::min({size,
        (available_height - (rows - 1) * gap) / rows,
        (Width(safe) - (columns - 1) * gap) / columns}));
    const LONG width = columns * fitted + (columns - 1) * gap;
    const LONG height = rows * fitted + (rows - 1) * gap;
    const LONG x = Clamp(CenterX(ball) - width / 2, safe.left, safe.right - width);
    const LONG y = above >= below ? ball.top - gap - height : ball.bottom + gap;
    for (int i = 0; i < 4; ++i) {
      parts.push_back({names[i], Box(x + (i % columns) * (fitted + gap),
                                    y + (i / columns) * (fitted + gap), fitted, fitted)});
    }
  }

  RECT ChatRect(RECT ball, RECT safe) const {
    const LONG gap = Dp(10);
    const LONG left = ball.left - gap - safe.left;
    const LONG right = safe.right - ball.right - gap;
    const LONG width = std::min(static_cast<LONG>(Dp(368)), static_cast<LONG>(Width(safe)));
    const LONG height = std::min(static_cast<LONG>(Dp(478)), static_cast<LONG>(Height(safe)));
    const LONG min_side = Dp(280);
    if (std::max(left, right) >= min_side) {
      const LONG w = std::min(width, std::max(left, right));
      const LONG x = left >= right ? ball.left - gap - w : ball.right + gap;
      return Box(x, Clamp(ball.top, safe.top, safe.bottom - height), w, height);
    }
    const LONG above = ball.top - gap - safe.top;
    const LONG below = safe.bottom - ball.bottom - gap;
    if (std::max(above, below) >= Dp(230)) {
      const LONG h = std::min(height, std::max(above, below));
      return Box(Clamp(CenterX(ball) - width / 2, safe.left, safe.right - width),
                 above >= below ? ball.top - gap - h : ball.bottom + gap, width, h);
    }
    // A short work area gives the chat the full usable height. The ball stays
    // at the nearest edge and the narrower chat still leaves it a clear gap.
    const LONG w = std::max(1L, std::min(width, std::max(left, right)));
    return Box(left >= right ? ball.left - gap - w : ball.right + gap,
               safe.top, w, height);
  }

  void Layout() {
    if (!enabled_ || !window_ || !client_ready_ || capturing_) {
      Trace("Layout skipped");
      return;
    }
    Trace("Layout begin mode=" + mode_);
    const auto monitor = MonitorFromPoint(center_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{sizeof(info)};
    if (!GetMonitorInfoW(monitor, &info)) return;
    work_ = info.rcWork;
    scale_ = FlutterDesktopGetDpiForMonitor(monitor) / 96.0;
    RECT safe = work_;
    InflateRect(&safe, -Dp(10), -Dp(10));
    const LONG size = Dp(56);
    const LONG x = Clamp(center_.x - size / 2, safe.left, safe.right - size);
    const LONG y = Clamp(center_.y - size / 2, safe.top, safe.bottom - size);
    if (!dragging_) center_ = {x + size / 2, y + size / 2};
    RECT ball = Box(x, y, size, size);
    std::vector<Part> parts;
    if (dock_ != 0) {
      const LONG width = Dp(4);
      const LONG height = Dp(42);
      parts.push_back({"handle", Box(dock_ < 0 ? safe.left : safe.right - width,
                                    y + (size - height) / 2, width, height), false});
    } else {
      if (mode_ == "chat") parts.push_back({"chat", ChatRect(ball, safe), false});
      else if (mode_ == "tools" || mode_ == "more") AddTools(ball, safe, parts);
      else if (notice_active_) {
        const auto slot = ChatRect(ball, safe);
        parts.push_back({"notice", Box(slot.left, slot.top,
            std::min(Width(slot), Dp(276)), std::min(Height(slot), Dp(112))), false});
      }
      parts.push_back({"ball", ball});
      if (image_count_ > 0) {
        const LONG badge_width = Dp(36);
        const LONG badge_height = Dp(23);
        const auto fits = [&](const RECT& rect) {
          if (rect.top < safe.top || rect.bottom > safe.bottom) return false;
          for (const auto& part : parts) {
            RECT overlap{};
            if (IntersectRect(&overlap, &rect, &part.rect)) return false;
          }
          return true;
        };
        const LONG badge_x = CenterX(ball) - badge_width / 2;
        auto badge = Box(badge_x, ball.top - badge_height - Dp(5), badge_width, badge_height);
        if (!fits(badge)) badge = Box(badge_x, ball.bottom + Dp(5), badge_width, badge_height);
        if (!fits(badge)) badge = Box(CenterX(ball) - Dp(14), ball.bottom - Dp(22), Dp(28), Dp(17));
        parts.push_back({"badge", badge, false});
      }
    }
    RECT bounds = parts.front().rect;
    for (const auto& part : parts) UnionRect(&bounds, &bounds, &part.rect);
    HRGN region = CreateRectRgn(0, 0, 0, 0);
    List shapes;
    chat_hit_ = {};
    for (auto& part : parts) {
      OffsetRect(&part.rect, -bounds.left, -bounds.top);
      const auto& r = part.rect;
      const int radius = Dp(part.id == "chat" ? 22 : part.id == "badge" ? 20 : part.id == "handle" ? 4 : 10);
      HRGN piece = part.circle ? CreateEllipticRgn(r.left, r.top, r.right + 1, r.bottom + 1)
          : CreateRoundRectRgn(r.left, r.top, r.right + 1, r.bottom + 1, radius, radius);
      if (piece) {
        CombineRgn(region, region, piece, RGN_OR);
        DeleteObject(piece);
      }
      if (part.id == "chat") chat_hit_ = r;
      shapes.emplace_back(Map{{Value("id"), Value(part.id)},
          {Value("x"), Value(static_cast<int>(r.left))}, {Value("y"), Value(static_cast<int>(r.top))},
          {Value("w"), Value(Width(r))}, {Value("h"), Value(Height(r))}});
    }
    if (region && !SetWindowRgn(window_, region, TRUE)) DeleteObject(region);
    SetWindowPos(window_, HWND_TOPMOST, bounds.left, bounds.top, Width(bounds), Height(bounds),
                 SWP_NOACTIVATE | SWP_NOOWNERZORDER);
    Publish("layout", Value(Map{{Value("parts"), Value(std::move(shapes))},
        {Value("w"), Value(Width(bounds))}, {Value("h"), Value(Height(bounds))},
        {Value("dock"), Value(dock_)}, {Value("usage"), Value(usage_)}}));
    Trace("Layout published");
    if (client_painted_ && !IsWindowVisible(window_)) ShowWindow(window_, SW_SHOWNOACTIVATE);
    Trace("Layout done");
  }

  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      auto* self = static_cast<Host*>(reinterpret_cast<CREATESTRUCTW*>(lparam)->lpCreateParams);
      self->window_ = hwnd;
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    auto* self = reinterpret_cast<Host*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (!self) return DefWindowProcW(hwnd, message, wparam, lparam);
    return self->WindowMessage(hwnd, message, wparam, lparam);
  }

  LRESULT WindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
      case WM_MOUSEACTIVATE: {
        RememberForeground();
        POINT point{};
        GetCursorPos(&point);
        ScreenToClient(hwnd, &point);
        return PtInRect(&chat_hit_, point) ? MA_ACTIVATE : MA_NOACTIVATE;
      }
      case WM_ACTIVATE:
        if (LOWORD(wparam) != WA_INACTIVE && child_) SetFocus(child_);
        break;
      case WM_SIZE:
        if (child_) {
          RECT bounds{};
          GetClientRect(hwnd, &bounds);
          MoveWindow(child_, 0, 0, Width(bounds), Height(bounds), TRUE);
        }
        break;
      case WM_TIMER:
        if (wparam == kUsageTimer) { Observe(); return 0; }
        break;
      case WM_DISPLAYCHANGE:
      case WM_SETTINGCHANGE:
      case WM_DPICHANGED:
        PostMessageW(hwnd, kRefreshLayout, 0, 0);
        break;
      case kRefreshLayout:
        Layout();
        return 0;
      case WM_CLOSE:
        Mode("closed");
        return 0;
      case WM_NCDESTROY:
        window_ = nullptr;
        child_ = nullptr;
        break;
    }
    if (controller_) {
      auto handled = controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
      if (handled) return *handled;
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }

  HWND main_window_;
  flutter::DartProject project_;
  Channel workspace_;
  Channel navigation_;
  std::unique_ptr<flutter::FlutterViewController> controller_;
  std::unique_ptr<Channel> client_;
  std::shared_ptr<int> life_ = std::make_shared<int>(0);
  WindowsScreenCapture capture_;
  HWND window_ = nullptr;
  HWND child_ = nullptr;
  HWND previous_ = nullptr;
  RECT work_{};
  RECT chat_hit_{};
  POINT center_{};
  POINT drag_origin_{};
  POINT drag_center_{};
  double scale_ = 1;
  int dock_ = 0;
  int image_count_ = 0;
  int capture_sequence_ = 0;
  int64_t state_revision_ = 0;
  bool dragging_ = false;
  bool client_ready_ = false;
  bool client_painted_ = false;
  bool capturing_ = false;
  bool has_state_ = false;
  bool pending_open_ = false;
  std::string pending_mission_;
  std::string pending_record_;
  std::string mode_ = "closed";
  std::string draft_key_;
  Value generation_;
  Map appearance_;
  bool notice_active_ = false;
  bool enabled_;
  bool usage_;
  DWORD foreground_pid_ = 0;
  int observation_revision_ = 0;
  Clock::time_point since_{};
  Clock::time_point paused_at_{};
  Clock::time_point last_checked_{};
  std::string observation_id_;
  std::string foreground_app_;
};

WindowsAssistantOverlay::WindowsAssistantOverlay(HWND main_window,
    flutter::BinaryMessenger* messenger, const flutter::DartProject& project)
    : host_(std::make_unique<Host>(main_window, messenger, project)) {}
WindowsAssistantOverlay::~WindowsAssistantOverlay() = default;
bool WindowsAssistantOverlay::enabled() const { return host_->enabled(); }
bool WindowsAssistantOverlay::SetEnabled(bool enabled) { return host_->SetEnabled(enabled); }

void WindowsAssistantOverlay::SetAppearance(const char* field, const Value& value) {
  host_->SetAppearance(field, value);
}
