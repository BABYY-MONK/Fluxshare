#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"
#include <shellapi.h>

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  static constexpr UINT kTrayMessage = WM_APP + 1;
  static constexpr UINT kTrayOpenCommand = 41001;
  static constexpr UINT kTrayExitCommand = 41002;

  bool AddTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu();
  void ShowFromTray();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  NOTIFYICONDATAW tray_icon_{};
  bool tray_icon_added_ = false;
  bool exit_requested_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
