import Foundation

// MARK: - Localization Helper

/// Type-safe localization wrapper using NSLocalizedString
/// Usage: L10n.Notification.Subtitle.complete
enum L10n {
    // MARK: - Helper

    private static func localized(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: Bundle.main, comment: comment)
    }

    private static func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: Bundle.main, comment: "")
        return String(format: format, arguments: args)
    }

    // MARK: - Notification Subtitles

    enum Notification {
        enum Subtitle {
            /// "응답 완료"
            static var complete: String { localized("notification.subtitle.complete") }
            /// "입력 대기"
            static var inputWaiting: String { localized("notification.subtitle.input_waiting") }
            /// "권한 요청"
            static var permissionRequest: String { localized("notification.subtitle.permission_request") }
            /// "권한 필요"
            static var permissionNeeded: String { localized("notification.subtitle.permission_needed") }
            /// "알림"
            static var notification: String { localized("notification.subtitle.notification") }
            /// "오류 발생"
            static var error: String { localized("notification.subtitle.error") }
        }

        enum Body {
            /// "응답을 확인하세요"
            static var checkResponse: String { localized("notification.body.check_response") }
            /// "사용자 입력을 기다리고 있습니다"
            static var waitingForInput: String { localized("notification.body.waiting_for_input") }
            /// "권한 승인이 필요합니다"
            static var permissionRequired: String { localized("notification.body.permission_required") }
            /// "상태가 변경되었습니다"
            static var statusChanged: String { localized("notification.body.status_changed") }
            /// "작업이 완료되었습니다"
            static var taskComplete: String { localized("notification.body.task_complete") }
            /// "세션에서 오류가 발생했습니다"
            static var sessionError: String { localized("notification.body.session_error") }
            /// "승인이 필요합니다"
            static var approvalNeeded: String { localized("notification.body.approval_needed") }
        }
    }

    // MARK: - Menu

    enum Menu {
        /// "설정..."
        static var settings: String { localized("menu.settings") }
        /// "종료"
        static var quit: String { localized("menu.quit") }
    }

    // MARK: - Settings Window

    enum Settings {
        /// "AI Notifier 설정"
        static var windowTitle: String { localized("settings.window_title") }
        /// "ntfy 푸시 알림"
        static var ntfyHeader: String { localized("settings.ntfy_header") }
        /// "ntfy 푸시 알림 활성화"
        static var enableNtfy: String { localized("settings.enable_ntfy") }
        /// "서버:"
        static var server: String { localized("settings.server") }
        /// "토픽:"
        static var topic: String { localized("settings.topic") }
        /// "테스트"
        static var test: String { localized("settings.test") }
        /// "테스트 중..."
        static var testing: String { localized("settings.testing") }
        /// "연결 성공!"
        static var connectionSuccess: String { localized("settings.connection_success") }
        /// "ntfy는 선택 사항입니다. 모바일 기기에서 알림을 받으려면 활성화하세요."
        static var ntfyInfo: String { localized("settings.ntfy_info") }
    }

    // MARK: - Buttons

    enum Button {
        /// "저장"
        static var save: String { localized("button.save") }
        /// "취소"
        static var cancel: String { localized("button.cancel") }
        /// "확인"
        static var ok: String { localized("button.ok") }
        /// "설정 열기"
        static var openSettings: String { localized("button.open_settings") }
        /// "닫기"
        static var close: String { localized("button.close") }
    }

    // MARK: - Alerts

    enum Alert {
        /// "설정 저장 완료"
        static var settingsSaved: String { localized("alert.settings_saved") }
        /// "설정 저장 실패"
        static var settingsSaveFailed: String { localized("alert.settings_save_failed") }
        /// "ntfy 알림이 활성화되었습니다."
        static var ntfyEnabled: String { localized("alert.ntfy_enabled") }
        /// "ntfy 알림이 비활성화되었습니다."
        static var ntfyDisabled: String { localized("alert.ntfy_disabled") }
    }

    // MARK: - Ntfy Errors

    enum NtfyError {
        /// "잘못된 서버 URL입니다."
        static var invalidURL: String { localized("ntfy.error.invalid_url") }
        /// "서버 연결 시간이 초과되었습니다."
        static var timeout: String { localized("ntfy.error.timeout") }
        /// "네트워크 오류: %@"
        static func networkError(_ message: String) -> String { localized("ntfy.error.network", message) }
        /// "서버 응답을 처리할 수 없습니다."
        static var invalidResponse: String { localized("ntfy.error.invalid_response") }
        /// "인증이 필요한 토픽입니다."
        static var unauthorized: String { localized("ntfy.error.unauthorized") }
        /// "토픽을 찾을 수 없습니다."
        static var topicNotFound: String { localized("ntfy.error.topic_not_found") }
        /// "서버 오류 (%d)"
        static func serverError(_ code: Int) -> String { localized("ntfy.error.server", code) }
        /// "서버 URL을 입력하세요"
        static var enterServerURL: String { localized("ntfy.error.enter_server_url") }
        /// "토픽을 입력하세요"
        static var enterTopic: String { localized("ntfy.error.enter_topic") }
    }

    // MARK: - Ntfy Test

    enum NtfyTest {
        /// "AI Notifier 테스트"
        static var title: String { localized("ntfy.test.title") }
        /// "ntfy 연결 테스트 성공! 🎉"
        static var successMessage: String { localized("ntfy.test.success_message") }
    }

    // MARK: - Setup

    enum Setup {
        /// "설정 준비 중..."
        static var preparing: String { localized("setup.preparing") }
        /// "CLI 훅 설치 중..."
        static var installingHooks: String { localized("setup.installing_hooks") }
        /// "AI Notifier 설정 완료"
        static var complete: String { localized("setup.complete") }
        /// "알림 권한이 필요합니다.\n\n시스템 설정 > 알림 > AI Notifier에서 '알림 허용'을 켜주세요."
        static var permissionRequired: String { localized("setup.permission_required") }
        /// "알림 권한: 활성화됨"
        static var permissionEnabled: String { localized("setup.permission_enabled") }
        /// "CLI 훅 설정:"
        static var cliHookSettings: String { localized("setup.cli_hook_settings") }
        /// "이제 CLI 응답 완료 시 알림을 받을 수 있습니다!"
        static var setupSuccessMessage: String { localized("setup.success_message") }
        /// "설치된 CLI가 없습니다. Claude Code, Gemini CLI, Codex CLI, 또는 OpenCode를 설치한 후 다시 실행해주세요."
        static var noCLIInstalled: String { localized("setup.no_cli_installed") }
        /// "💡 메뉴바 🔔 아이콘에서 ntfy 푸시 알림을 설정할 수 있습니다."
        static var ntfyTip: String { localized("setup.ntfy_tip") }
    }

    // MARK: - Hook Installation Results

    enum HookResult {
        /// "훅 설치 완료"
        static var installed: String { localized("hook.result.installed") }
        /// "이미 설정됨"
        static var alreadyInstalled: String { localized("hook.result.already_installed") }
        /// "미설치 (건너뜀)"
        static var notFound: String { localized("hook.result.not_found") }
        /// "오류 - %@"
        static func error(_ message: String) -> String { localized("hook.result.error", message) }
    }
}
