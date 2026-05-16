#include "native_channels.h"

#include <bcrypt.h>
#include <gdiplus.h>
#include <psapi.h>
#include <shlobj.h>
#include <uiautomation.h>
#include <wincrypt.h>
#include <windows.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdio>
#include <iomanip>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <variant>
#include <vector>

#pragma comment(lib, "bcrypt.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "version.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")

namespace {

constexpr const wchar_t* kRegistryRoot       = L"Software\\Jasnita\\ScreenRecorder";
constexpr const wchar_t* kPasswordValueName  = L"AdminPasswordHash";
constexpr const wchar_t* kRunRoot            = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr const wchar_t* kRunValueName       = L"JasnitaScreenRecorder";

// ──────────────────────────────────────────────────────────────────────────
// String conversions
// ──────────────────────────────────────────────────────────────────────────

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int needed = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                   static_cast<int>(utf8.size()), nullptr, 0);
  if (needed <= 0) return std::wstring();
  std::wstring w(needed, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      w.data(), needed);
  return w;
}

std::string WideToUtf8(const std::wstring& w) {
  if (w.empty()) return std::string();
  int needed = WideCharToMultiByte(CP_UTF8, 0, w.data(),
                                   static_cast<int>(w.size()), nullptr, 0,
                                   nullptr, nullptr);
  if (needed <= 0) return std::string();
  std::string s(needed, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()),
                      s.data(), needed, nullptr, nullptr);
  return s;
}

// ──────────────────────────────────────────────────────────────────────────
// Registry helpers (HKCU)
// ──────────────────────────────────────────────────────────────────────────

bool RegSetStringHKCU(const wchar_t* subkey, const wchar_t* name,
                      const std::wstring& value) {
  HKEY key = nullptr;
  LONG rc = RegCreateKeyExW(HKEY_CURRENT_USER, subkey, 0, nullptr,
                            REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr,
                            &key, nullptr);
  if (rc != ERROR_SUCCESS) return false;
  rc = RegSetValueExW(
      key, name, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(value.c_str()),
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  return rc == ERROR_SUCCESS;
}

bool RegGetStringHKCU(const wchar_t* subkey, const wchar_t* name,
                      std::wstring* out) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, subkey, 0, KEY_QUERY_VALUE, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  DWORD type = 0;
  DWORD size = 0;
  LONG rc = RegQueryValueExW(key, name, nullptr, &type, nullptr, &size);
  if (rc != ERROR_SUCCESS || type != REG_SZ || size == 0) {
    RegCloseKey(key);
    return false;
  }
  std::wstring buf(size / sizeof(wchar_t), L'\0');
  rc = RegQueryValueExW(key, name, nullptr, &type,
                        reinterpret_cast<BYTE*>(buf.data()), &size);
  RegCloseKey(key);
  if (rc != ERROR_SUCCESS) return false;
  while (!buf.empty() && buf.back() == L'\0') buf.pop_back();
  *out = std::move(buf);
  return true;
}

bool RegDeleteValueHKCU(const wchar_t* subkey, const wchar_t* name) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, subkey, 0, KEY_SET_VALUE, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  LONG rc = RegDeleteValueW(key, name);
  RegCloseKey(key);
  return rc == ERROR_SUCCESS || rc == ERROR_FILE_NOT_FOUND;
}

// ──────────────────────────────────────────────────────────────────────────
// SHA-256 via BCrypt
// ──────────────────────────────────────────────────────────────────────────

std::string Sha256Hex(const std::string& utf8) {
  BCRYPT_ALG_HANDLE alg = nullptr;
  if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) !=
      0) {
    return {};
  }
  DWORD hash_size = 0;
  DWORD cb = 0;
  BCryptGetProperty(alg, BCRYPT_HASH_LENGTH,
                    reinterpret_cast<PUCHAR>(&hash_size), sizeof(hash_size),
                    &cb, 0);
  std::vector<unsigned char> digest(hash_size);
  BCRYPT_HASH_HANDLE hash = nullptr;
  if (BCryptCreateHash(alg, &hash, nullptr, 0, nullptr, 0, 0) != 0) {
    BCryptCloseAlgorithmProvider(alg, 0);
    return {};
  }
  BCryptHashData(hash,
                 reinterpret_cast<PUCHAR>(const_cast<char*>(utf8.data())),
                 static_cast<ULONG>(utf8.size()), 0);
  BCryptFinishHash(hash, digest.data(), static_cast<ULONG>(digest.size()), 0);
  BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(alg, 0);
  std::ostringstream oss;
  for (auto b : digest) {
    oss << std::hex << std::setw(2) << std::setfill('0')
        << static_cast<int>(b);
  }
  return oss.str();
}

// ──────────────────────────────────────────────────────────────────────────
// Idle time
// ──────────────────────────────────────────────────────────────────────────

double IdleSeconds() {
  LASTINPUTINFO info{};
  info.cbSize = sizeof(info);
  if (!GetLastInputInfo(&info)) return 0.0;
  DWORD now = GetTickCount();
  DWORD idle_ms = now - info.dwTime;  // wraps cleanly via unsigned subtraction
  return static_cast<double>(idle_ms) / 1000.0;
}

// ──────────────────────────────────────────────────────────────────────────
// Foreground app name (ProductName from FileVersionInfo, fallback to basename)
// ──────────────────────────────────────────────────────────────────────────

std::wstring ProductNameFor(const std::wstring& exe_path) {
  DWORD handle = 0;
  DWORD size = GetFileVersionInfoSizeW(exe_path.c_str(), &handle);
  if (size == 0) return {};
  std::vector<BYTE> buf(size);
  if (!GetFileVersionInfoW(exe_path.c_str(), 0, size, buf.data())) return {};

  struct LangCp { WORD lang; WORD code_page; };
  LangCp* translations = nullptr;
  UINT translations_size = 0;
  if (!VerQueryValueW(buf.data(), L"\\VarFileInfo\\Translation",
                      reinterpret_cast<LPVOID*>(&translations),
                      &translations_size) ||
      translations == nullptr || translations_size < sizeof(LangCp)) {
    return {};
  }

  wchar_t sub_block[64];
  swprintf_s(sub_block, L"\\StringFileInfo\\%04x%04x\\ProductName",
             translations[0].lang, translations[0].code_page);
  wchar_t* value = nullptr;
  UINT value_size = 0;
  if (VerQueryValueW(buf.data(), sub_block, reinterpret_cast<LPVOID*>(&value),
                     &value_size) &&
      value != nullptr && value_size > 0) {
    return std::wstring(value, value_size - 1);
  }
  return {};
}

std::wstring ExePathFromHwnd(HWND hwnd) {
  if (!hwnd) return {};
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0) return {};
  HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!proc) return {};
  wchar_t path[MAX_PATH] = {0};
  DWORD len = MAX_PATH;
  std::wstring exe;
  if (QueryFullProcessImageNameW(proc, 0, path, &len)) {
    exe.assign(path, len);
  }
  CloseHandle(proc);
  return exe;
}

std::wstring AppNameFromHwnd(HWND hwnd) {
  if (!hwnd) return L"Unknown";
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  if (pid == 0) return L"Unknown";

  HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!proc) return L"Unknown";

  wchar_t path[MAX_PATH] = {0};
  DWORD len = MAX_PATH;
  std::wstring exe_path;
  if (QueryFullProcessImageNameW(proc, 0, path, &len)) {
    exe_path.assign(path, len);
  }
  CloseHandle(proc);

  if (exe_path.empty()) return L"Unknown";

  auto product = ProductNameFor(exe_path);
  if (!product.empty()) return product;

  size_t slash = exe_path.find_last_of(L"\\/");
  std::wstring base = (slash == std::wstring::npos) ? exe_path
                                                    : exe_path.substr(slash + 1);
  if (base.size() > 4) {
    std::wstring lower = base;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::towlower);
    if (lower.size() >= 4 && lower.compare(lower.size() - 4, 4, L".exe") == 0) {
      base.resize(base.size() - 4);
    }
  }
  return base.empty() ? L"Unknown" : base;
}

// ──────────────────────────────────────────────────────────────────────────
// Active browser tab URL via IUIAutomation
// ──────────────────────────────────────────────────────────────────────────

Microsoft::WRL::ComPtr<IUIAutomation> g_uia;

IUIAutomation* EnsureUIAutomation() {
  if (!g_uia) {
    CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                     IID_PPV_ARGS(&g_uia));
  }
  return g_uia.Get();
}

bool IsKnownBrowser(const std::wstring& exe_path) {
  size_t slash = exe_path.find_last_of(L"\\/");
  std::wstring base = (slash == std::wstring::npos) ? exe_path
                                                    : exe_path.substr(slash + 1);
  std::transform(base.begin(), base.end(), base.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(::towlower(c)); });
  static const wchar_t* kBrowsers[] = {
      L"chrome.exe", L"msedge.exe", L"firefox.exe", L"brave.exe",
      L"opera.exe",  L"vivaldi.exe", L"arc.exe",     L"librewolf.exe",
  };
  for (auto b : kBrowsers) {
    if (base == b) return true;
  }
  return false;
}

bool LooksLikeUrl(const std::wstring& s) {
  if (s.empty()) return false;
  if (s.find(L' ') != std::wstring::npos) return false;
  if (s.find(L"://") != std::wstring::npos) return true;
  if (s.size() >= 4 && s.compare(0, 4, L"www.") == 0) return true;
  // Domain heuristic: at least one dot, last component looks like a TLD.
  size_t last_dot = s.find_last_of(L'.');
  if (last_dot == std::wstring::npos || last_dot == s.size() - 1) return false;
  size_t tld_len = s.size() - last_dot - 1;
  if (tld_len < 2 || tld_len > 24) return false;
  for (size_t i = last_dot + 1; i < s.size(); ++i) {
    wchar_t c = s[i];
    // Allow letters / digits / hyphen in the TLD portion (covers '.co.id',
    // path-like strings get rejected because the path slash appears earlier).
    if (!(iswalnum(c) || c == L'-' || c == L'/' || c == L':')) return false;
  }
  return true;
}

std::wstring GetActiveBrowserUrl(HWND hwnd) {
  if (!hwnd) return {};
  auto exe = ExePathFromHwnd(hwnd);
  if (!IsKnownBrowser(exe)) return {};

  auto* uia = EnsureUIAutomation();
  if (!uia) return {};

  Microsoft::WRL::ComPtr<IUIAutomationElement> root;
  if (FAILED(uia->ElementFromHandle(hwnd, &root)) || !root) return {};

  VARIANT prop_val;
  prop_val.vt = VT_I4;
  prop_val.lVal = UIA_EditControlTypeId;
  Microsoft::WRL::ComPtr<IUIAutomationCondition> is_edit;
  if (FAILED(uia->CreatePropertyCondition(UIA_ControlTypePropertyId, prop_val,
                                          &is_edit)) ||
      !is_edit) {
    return {};
  }

  Microsoft::WRL::ComPtr<IUIAutomationElementArray> edits;
  if (FAILED(root->FindAll(TreeScope_Descendants, is_edit.Get(), &edits)) ||
      !edits) {
    return {};
  }

  int count = 0;
  edits->get_Length(&count);
  for (int i = 0; i < count; ++i) {
    Microsoft::WRL::ComPtr<IUIAutomationElement> edit;
    if (FAILED(edits->GetElement(i, &edit)) || !edit) continue;

    VARIANT val_var;
    VariantInit(&val_var);
    if (FAILED(edit->GetCurrentPropertyValue(UIA_ValueValuePropertyId,
                                             &val_var))) {
      VariantClear(&val_var);
      continue;
    }
    std::wstring value;
    if (val_var.vt == VT_BSTR && val_var.bstrVal) {
      value.assign(val_var.bstrVal, SysStringLen(val_var.bstrVal));
    }
    VariantClear(&val_var);

    if (LooksLikeUrl(value)) {
      // Normalise to fully-qualified URL so the Dart side has consistent data.
      if (value.find(L"://") == std::wstring::npos) {
        value = L"https://" + value;
      }
      return value;
    }
  }
  return {};
}

// ──────────────────────────────────────────────────────────────────────────
// Screenshot via BitBlt + GDI+ JPEG encoder
// ──────────────────────────────────────────────────────────────────────────

ULONG_PTR g_gdiplus_token = 0;
std::once_flag g_gdiplus_once;

void EnsureGdiplus() {
  std::call_once(g_gdiplus_once, []() {
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&g_gdiplus_token, &input, nullptr);
  });
}

int GetJpegEncoderClsid(CLSID* clsid) {
  UINT num = 0, size = 0;
  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;
  std::vector<BYTE> buf(size);
  auto* codecs = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buf.data());
  Gdiplus::GetImageEncoders(num, size, codecs);
  for (UINT i = 0; i < num; ++i) {
    if (wcscmp(codecs[i].MimeType, L"image/jpeg") == 0) {
      *clsid = codecs[i].Clsid;
      return 0;
    }
  }
  return -1;
}

bool TakeScreenshotJpeg(const std::wstring& output_path) {
  EnsureGdiplus();

  HDC screen_dc = GetDC(nullptr);
  if (!screen_dc) return false;
  int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  int x = GetSystemMetrics(SM_XVIRTUALSCREEN);
  int y = GetSystemMetrics(SM_YVIRTUALSCREEN);
  if (width <= 0 || height <= 0) {
    ReleaseDC(nullptr, screen_dc);
    return false;
  }

  HDC mem_dc = CreateCompatibleDC(screen_dc);
  HBITMAP bitmap = CreateCompatibleBitmap(screen_dc, width, height);
  HGDIOBJ old = SelectObject(mem_dc, bitmap);
  BitBlt(mem_dc, 0, 0, width, height, screen_dc, x, y, SRCCOPY | CAPTUREBLT);

  CLSID jpeg_clsid;
  bool ok = false;
  if (GetJpegEncoderClsid(&jpeg_clsid) == 0) {
    Gdiplus::Bitmap gdi_bmp(bitmap, nullptr);
    Gdiplus::EncoderParameters params;
    params.Count = 1;
    params.Parameter[0].Guid = Gdiplus::EncoderQuality;
    params.Parameter[0].Type = Gdiplus::EncoderParameterValueTypeLong;
    ULONG quality = 75;
    params.Parameter[0].NumberOfValues = 1;
    params.Parameter[0].Value = &quality;
    ok = (gdi_bmp.Save(output_path.c_str(), &jpeg_clsid, &params) ==
          Gdiplus::Ok);
  }

  SelectObject(mem_dc, old);
  DeleteObject(bitmap);
  DeleteDC(mem_dc);
  ReleaseDC(nullptr, screen_dc);
  return ok;
}

// ──────────────────────────────────────────────────────────────────────────
// EncodableValue helpers
// ──────────────────────────────────────────────────────────────────────────

template <typename T>
const T* GetIf(const flutter::EncodableValue* v) {
  return v ? std::get_if<T>(v) : nullptr;
}

bool GetMapString(const flutter::EncodableMap& map, const char* key,
                  std::string* out) {
  auto it = map.find(flutter::EncodableValue(std::string(key)));
  if (it == map.end()) return false;
  if (auto* s = std::get_if<std::string>(&it->second)) {
    *out = *s;
    return true;
  }
  return false;
}

}  // namespace

// ──────────────────────────────────────────────────────────────────────────
// NativeChannels
// ──────────────────────────────────────────────────────────────────────────

NativeChannels* NativeChannels::instance_ = nullptr;

NativeChannels::NativeChannels(flutter::FlutterEngine* engine)
    : engine_(engine) {
  instance_ = this;
  RegisterActivityMonitorChannel();
  RegisterAdminChannel();
}

NativeChannels::~NativeChannels() {
  StopMonitoring();
  if (instance_ == this) instance_ = nullptr;
}

void NativeChannels::RegisterActivityMonitorChannel() {
  monitor_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine_->messenger(), "com.jasnita/activity_monitor",
          &flutter::StandardMethodCodec::GetInstance());

  monitor_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();

        if (method == "startActivityMonitoring") {
          StartMonitoring();
          result->Success();
        } else if (method == "stopActivityMonitoring") {
          StopMonitoring();
          result->Success();
        } else if (method == "getIdleSeconds") {
          result->Success(flutter::EncodableValue(IdleSeconds()));
        } else if (method == "getForegroundApp") {
          auto name = WideToUtf8(AppNameFromHwnd(GetForegroundWindow()));
          result->Success(flutter::EncodableValue(name));
        } else if (method == "getActiveBrowserUrl") {
          auto url =
              WideToUtf8(GetActiveBrowserUrl(GetForegroundWindow()));
          result->Success(flutter::EncodableValue(url));
        } else if (method == "takeScreenshot") {
          auto* map = GetIf<flutter::EncodableMap>(call.arguments());
          std::string output_path;
          if (!map || !GetMapString(*map, "outputPath", &output_path)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          bool ok = TakeScreenshotJpeg(Utf8ToWide(output_path));
          result->Success(flutter::EncodableValue(ok));
        } else {
          result->NotImplemented();
        }
      });
}

void NativeChannels::RegisterAdminChannel() {
  admin_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine_->messenger(), "com.jasnita/admin",
          &flutter::StandardMethodCodec::GetInstance());

  admin_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        const std::string& method = call.method_name();

        // Password helpers
        auto store_hash = [](const std::string& pw) {
          auto hash = Sha256Hex(pw);
          return RegSetStringHKCU(kRegistryRoot, kPasswordValueName,
                                  Utf8ToWide(hash));
        };
        auto has_password = []() {
          std::wstring stored;
          return RegGetStringHKCU(kRegistryRoot, kPasswordValueName, &stored) &&
                 !stored.empty();
        };
        auto verify_password = [](const std::string& input) -> bool {
          std::wstring stored;
          if (!RegGetStringHKCU(kRegistryRoot, kPasswordValueName, &stored) ||
              stored.empty()) {
            return false;
          }
          return Utf8ToWide(Sha256Hex(input)) == stored;
        };

        if (method == "setAdminPassword") {
          auto* s = GetIf<std::string>(call.arguments());
          result->Success(flutter::EncodableValue(s ? store_hash(*s) : false));
        } else if (method == "changeAdminPassword") {
          auto* map = GetIf<flutter::EncodableMap>(call.arguments());
          std::string old_pw, new_pw;
          if (!map || !GetMapString(*map, "old", &old_pw) ||
              !GetMapString(*map, "new", &new_pw)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          if (has_password() && !verify_password(old_pw)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          result->Success(flutter::EncodableValue(store_hash(new_pw)));
        } else if (method == "clearAdminPassword") {
          RegDeleteValueHKCU(kRegistryRoot, kPasswordValueName);
          result->Success(flutter::EncodableValue(true));
        } else if (method == "hasAdminPassword") {
          result->Success(flutter::EncodableValue(has_password()));
        } else if (method == "verifyAdminPassword") {
          auto* s = GetIf<std::string>(call.arguments());
          result->Success(
              flutter::EncodableValue(s ? verify_password(*s) : false));
        } else if (method == "installAutoStart") {
          wchar_t exe[MAX_PATH] = {0};
          DWORD len = GetModuleFileNameW(nullptr, exe, MAX_PATH);
          if (len == 0 || len >= MAX_PATH) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          // Quote the path so spaces don't break the Run command.
          std::wstring quoted = L"\"";
          quoted.append(exe, len);
          quoted.append(L"\"");
          bool ok = RegSetStringHKCU(kRunRoot, kRunValueName, quoted);
          result->Success(flutter::EncodableValue(ok));
        } else if (method == "uninstallAutoStart") {
          bool ok = RegDeleteValueHKCU(kRunRoot, kRunValueName);
          result->Success(flutter::EncodableValue(ok));
        } else if (method == "getAutoStartStatus") {
          std::wstring v;
          bool present =
              RegGetStringHKCU(kRunRoot, kRunValueName, &v) && !v.empty();
          result->Success(flutter::EncodableValue(present));
        } else if (method == "quitApp") {
          PostQuitMessage(0);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void NativeChannels::StartMonitoring() {
  if (is_monitoring_) return;
  is_monitoring_ = true;
  foreground_hook_ = SetWinEventHook(
      EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr,
      &NativeChannels::OnForegroundChanged, 0, 0,
      WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);

  // Report the currently-focused window immediately, mirroring the macOS impl.
  ReportApp(GetForegroundWindow());
}

void NativeChannels::StopMonitoring() {
  if (!is_monitoring_) return;
  is_monitoring_ = false;
  if (foreground_hook_) {
    UnhookWinEvent(foreground_hook_);
    foreground_hook_ = nullptr;
  }
}

void NativeChannels::OnForegroundChanged(HWINEVENTHOOK, DWORD, HWND hwnd, LONG,
                                          LONG, DWORD, DWORD) {
  if (instance_) instance_->ReportApp(hwnd);
}

void NativeChannels::ReportApp(HWND hwnd) {
  if (!monitor_channel_) return;
  auto name = AppNameFromHwnd(hwnd);
  if (name.empty() || name == last_reported_app_) return;
  last_reported_app_ = name;
  auto utf8 = WideToUtf8(name);
  monitor_channel_->InvokeMethod(
      "onAppChanged",
      std::make_unique<flutter::EncodableValue>(utf8));
}

void NativeChannels::RequestQuit() {
  if (!admin_channel_) return;
  admin_channel_->InvokeMethod("onQuitRequested", nullptr);
}
