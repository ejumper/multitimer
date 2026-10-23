# FINDINGS — UI Structure (Part 6)

Part 6 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Basis: `WORK/decompiled/apktool/res/` (198 layouts, manifest, styles, strings) + readable `com/persapps` classes in `WORK/decompiled/jadx/sources/` (R.layout bindings cited) + `REFERENCE-IMAGES/index.md` (23 iOS screenshots, ground truth for IA) + REFERENCE how-tos. Android is the rebuild target; iOS screenshots mark conceptual parity (platform-specific rows flagged). No Jetpack Navigation graphs exist (`res/navigation/` is absent) — navigation is activity-result + drawer + popups, evidenced per entry.

## 1.0 Screen map

Screens (activities) from the manifest (31; `AndroidManifest.xml`), bound to layouts via `R.layout.*` in the readable classes. Layout inventory: **198 files = 48 SDK/AndroidX + 71 `a_*` (app screens/rows) + 14 `scene_single_*` + 49 `c_*` (dialogs/components) + 15 widget/dot** — every file classified in §1.0/§3.0/§4.0.

| Screen | Class (`use.`…) | Layout(s) | Purpose (entity shown) | Nav parents → children |
| --- | --- | --- | --- | --- |
| Main workspace | `ui.scene.main.MainActivity` | `a_main_activity`, `a_main_activity_content` (toolbar + content frame), `a_main_activity_nav_menu{,_item,_item_add}`, `dot_layout` | Board pages (ViewPager of `c_board` pages, dots indicator), drawer (boards/commands/history/settings), dynamic board toolbar | Launcher (also `LAUNCHER` after Welcome) → Single view, full editor tree, History, Settings family, Pro, Sounds, Web share/Export dialogs; drawer → boards, board switch |
| Single timer view | `ui.scene.single.MTSingleViewActivity` | `scene_single_activity` (`MTInstrumentView` + control frame), panels: `scene_single_panel_{buttons,history{,_row,_section},note{,_section},stats{,_section,_stopwatch{,_row}},tab_bar,tab_item,control}` | One instrument full-screen + control row + tabbed panels (Buttons/History/Note/Stats) (IMG_6214 is the board-embedded variant of this view) | Main (long-press "Single view") / notification tap |
| Instrument editor (shell) | `ui.insteditor.MTInstrumentEditorActivity` | `a_editor_activity` (toolbar w/ Cancel+Done, content frame) | Edit one instrument (type decides content, below) | Main → per-type content; done/cancel back |
| — Countdown editor | same, type `g5vs` | `a_editor_countdown_timer` | Color/label/icon/duration/auto-repeat/autocompletion/alert | editor shell |
| — Quick editor | `y9wg` | `a_editor_quick_timer` | Same minus fixed duration | " |
| — Interval editor | `ok9y` | `a_editor_interval_timer`, `c_editor_intervals_toolbar` | Interval list w/ groups & repeats (IMG_6212/6229–6231) + per-interval entries | " → Interval entry, Alert, Repeats, Note |
| — Pomodoro editor | `hz3x` | `a_editor_pomodoro_timer` | work/break/long-break/repeats | " → Alert, Repeats |
| — CountUp editor | `s5lu` | `a_editor_countup_timer` | start-from + notices | " → Notices |
| — Stopwatch editor | `e2kh` | `a_editor_stopwatch` | laps/splits config | " |
| — Counter editor | `m6zp` | `a_editor_counter` | Mode/Initial/Step/Final (IMG_6219) | " → Add Value Buttons, History |
| — Clock editor | `pc5x` | `a_editor_clock` | time zone, format, dial | " → Time zone |
| — Buttons editor | `he5b` | `a_editor_buttons`, rows `c_editor_buttons_items_row`, `c_editor_button_commands_row` | buttons + their commands | " → Button item editor |
| — Button item editor | `ui.insteditor.buttons.MTButtonsItemActivity` | `a_editor_button_item_activity` | one button: label/color/commands | Buttons editor |
| — Container editor | `t5ql` | `a_editor_container` | pick which timers to embed | " → instrument picker dialog |
| Per-interval editor | `ui.insteditor.interval.MTIntervalTimerEntryActivity` | `a_editor_interval_entry_activity` | one interval: label/color/duration/start-alert/end-alert/repeat/note (IMG_6222/6232) | Interval editor |
| Duration entry | `ui.insteditor.countdown.TimeValueActivity` | `a_editor_time_activity`, `c_duration_picker`/`c_base_time_dialog_content` | D/H/M/S keypad duration (IMG_6222 center) | editor tree |
| Add Time Buttons | `ui.insteditor.base.actions.AddTimeButtonsActivity` | `a_editor_add_value_activity{,_list_item}` | preset ±time buttons list | editor tree |
| Add Value Buttons | `ui.insteditor.base.actions.AddAmountButtonsActivity` | `a_editor_add_value_activity{,_list_item}` (shared) | preset ±value buttons list (counter) | editor tree |
| Alert editor | `ui.insteditor.base.alert.AlertActivity` | `a_editor_alert_activity` | sound/vibration/warning/repeat (IMG_6223/6224) | editor tree / interval entry |
| Repeat editor | `ui.insteditor.base.alert.RepeatsActivity` | `a_editor_repeats_activity` | alert repeat policy (None/Times/Long — Part 5 §5.0) | Alert editor |
| Note editor | `ui.insteditor.base.note.NoteActivity` | `a_editor_note_activity` | free text (IMG_6233) | editor tree |
| Color picker | `ui.insteditor.base.color.ColorActivity` | `a_editor_color_activity`, `a_editor_color_user_collection{,_item}`, `c_color_palette_{1,2}` | gradient + saved colors (IMG_6220) | editor tree |
| Icon picker | `ui.scene.icon.IconsActivity` | `a_icons_activity` | instrument icon | editor tree |
| Time zone | `ui.insteditor.clock.TimeZoneActivity` | `a_editor_time_zone_activity{,_item}` | clock tool time zone | Clock editor |
| CountUp notices | `ui.insteditor.countup.{NoticesActivity,NoticeActivity}` | `a_countup_notice_list_activity{,_item}`, `a_countup_notice_activity` | scheduled notices list + one notice | CountUp editor |
| History | `ui.scene.history.HistoryActivity` | `a_history_activity`, `a_history_root`, `a_history_instruments{,_item}`, `a_history_sessions`, `a_history_{time,point,amount}_sessions_{header,footer,details}`, `a_history_details{,_entry_item,_group_item}`, `a_history_groups_item`, `a_history_container`, `a_history_limit_view` | runs grouped by date w/ totals; per-instrument; details (IMG_6234) | Main/single/editor "History" |
| Settings hub pages | `ui.scene.settings.{AlertSettingsActivity,ControlsSettingsActivity,HistorySettingsActivity,ExtraSettingsActivity,DeletedDataActivity}` | `a_settings_alert_settings_activity`, `a_settings_controls_activity`, `a_settings_history_activity`, `a_settings_extra_activity`, `a_settings_page` (shared shell), `a_deleted_data_activity{,_list_item}` | alerts/controls/history/optional; deleted-data restore | Main drawer → Settings |
| Sounds | `ui.scene.sounds.SoundsActivity` | `a_sound_list_activity{,_item}` | sound library incl. custom import (Part 5 §5.0) | Settings |
| Text-to-speech | `ui.scene.sounds.TextToSpeechActivity` | (no dedicated layout; decor-view/theme based — `TextToSpeechActivity.java:32-54`) | create TTS sound | Sounds |
| Pro | `ui.scene.pro.ProVersionActivity` | `a_pro_version_activity`, `a_pro_version_{view,feature,offer,ex_dialog_content}` | paywall features/offers | gating flows |
| Welcome (first run) | `ui.scene.welcome.WelcomeActivity` | `a_welcome_activity`, `a_welcome_{simple,end}_fragment` | onboarding | → Main |
| Notice instrument screen | `use.notice.MTInstrumentActivity` | `a_notice_instrument_activity` (`MTInstrumentView`) | instrument shown from a notification/alert tap; extra `vi1r` = instrument id, else "next event within 1 h" pick (`MTInstrumentActivity.java:26-40`) | notification tap |
| Widget config | `appwidget.{mini1.AWMini1SettingsActivity, mini2.AWMini2SettingsActivity, single.AWSingleSettingsActivity}` | `widget_mini_settings_activity`, `widget_single_settings_activity` | pick timer/actions for widget | widget add flow |
| Widget quick start | `appwidget.quick.AWQuickStartActivity` | (transparent, `Theme.App.WidgetQuickStart`) | one-tap action dispatcher from widget | widget |

## 2.0 Per-screen detail (cross-checked against `REFERENCE-IMAGES/index.md`)

- **Main workspace** — Toolbar (menu icon / board name / gear), paged board area (one `c_board` FrameLayout per page; page dots via `dot_layout`; ViewPager-style horizontal paging), dynamic toolbar (`c_dynamic_toolbar{,_button}` — per-state quick action row), drawer (`a_main_activity_nav_menu*`: boards list + Edit + "add" row, Commands section, History, Settings — matches IMG_6215; Android side-menu Commands = deprecated predecessor of Buttons per `REFERENCE/guides-buttons.md`). Gear popover = board menu (Rename/Edit board/Add a timer/Web Share/Export/Undo/Copy/Delete — IMG_6217 ↔ `c_webshare_dialog_content`, `c_export_dialog_content`, board-layouts dialog `c_board_layouts_dialog_content`). Instrument long-press menu (Start/Delay/Lock/History/Single view/Edit — IMG_6221) = popup (`c_popup_instrument_element`). Each board renders instruments via `MTInstrumentView` custom view (dial/counter/buttons/container variants) — the same view class as Single view (`scene_single_activity:23`).
- **Board instruments (from screenshots, structure)**: dial timers (ring + big time + tap control zones + lock), counter (ring, − value +, tap zones), buttons element (pill rows), container (hosts other boards' instruments), clock. Overlay quick-buttons per state are gated by state (`zd.java:82-110`, Part 4 §4.3).
- **Editor tree** — shell with Cancel/Done; per-type property list built from `c_editor_property_*` rows (name, icon, color → ColorActivity, duration → keypad, switch, number, bigtext, custom). Interval editor embeds the intervals toolbar (`c_editor_intervals_toolbar`: add / group / ungroup / duplicate / delete / reorder — matches IMG_6212 toolbar icons) and interval chips with **group brackets carrying a repeat count**, groups **nest** (IMG_6229/6230), and a compact edit mode with per-row delete + drag handles and a collapsed "1 | 5 intervals | 9h 10m" row (IMG_6231). Interval chips open `MTIntervalTimerEntryActivity` (label/color/duration keypad/start alert/end alert/repeat/note — IMG_6222/6232; repeat stepper popover IMG_6225 = number dialog). Extra info / Units of Time (IMG_6213) = picker rows in interval/countdown editors.
- **Single view** — `MTInstrumentView` (weight 1.2) over control frame (weight 1.0) with tab bar (`scene_single_panel_tab_bar`) switching Buttons / History / Note / Stats panels (stats incl. stopwatch lap rows). Control row = same per-state actions as board overlay (Part 4 §2.5).
- **History** — three levels (instruments → sessions → details), date-grouped sessions with per-run start-time + `*elapsed` + per-day TOTAL (IMG_6234 ↔ `a_history_*_sessions_header/footer/details`), free-tier limit view (`a_history_limit_view` — Part 4 §3.0 history asymmetry **(PRO)**), share/export (CSV per Part 3 §4.0) + edit (delete) actions (IMG_6234 top-right).
- **Settings** — hub lists into Alert Settings (`a_settings_alert_settings_activity`: default alert sound/vibration/lead — Part 5 §5.0 defaults), Controls (`a_settings_controls_activity`: quick-action customization), History settings (retention **(PRO)** per REFERENCE), Optional (`a_settings_extra_activity`), Deleted data (restore). iOS-only rows in screenshots (iCloud Sync, Live Activity, Use as System Alarm, Badge) have **no Android counterparts** — no matching settings activities/layout strings (cross-check negative; platform difference).
- **Welcome / Pro / Deleted data / Sounds / TTS** — inventory above; Pro shows feature list + offers (`a_pro_version_{feature,offer}`); Sounds lists built-ins + custom (import → cacheDir file, Part 5 §5.0).
- **Notice instrument screen** — full-screen `MTInstrumentView` for the alerting timer (see map row); exists so an alert tap lands on the timer, not the workspace.

## 3.0 Dialogs & item layouts (`c_*`, one line each)

| Layout | Purpose |
| --- | --- |
| `c_addtime_dialog_content` | Add-time (±duration) dialog on running timer |
| `c_alert_dialog_content` | Alert event picker (which alert to edit/hear) |
| `c_base_time_dialog_content` | Shared D/H/M/S time-entry dialog base (delayed start, start-for — IMG_6227) |
| `c_board`, `c_board_container` | Board page frame / container embedding |
| `c_board_layouts_dialog_content` | Board layout mode chooser (default/adaptive/flexible — Part 4 §5.0) |
| `c_calculator` | In-dialog time calculator component (duration math) |
| `c_checked_view` | Checkable row (multi-select lists) |
| `c_color_palette_1/2`, `c_editor_property_color_item` | Saved-color palette grids |
| `c_counter_value_dialog_content` | Set counter value (counter `ix` action) |
| `c_duration_dialog_content`, `c_duration_picker` | Duration entry keypad dialog (IMG_6222/6227) |
| `c_dynamic_toolbar{,_button}` | Board bottom quick-action toolbar |
| `c_edit_text_dialog_content` | Single-line text input (rename board/timer) |
| `c_editor_button_commands_row` | One command row inside a button editor |
| `c_editor_buttons_items_row` | One button row in the Buttons editor |
| `c_editor_intervals_toolbar` | Interval add/group/ungroup/duplicate/delete/reorder bar |
| `c_editor_property_bigtext/color/custom/duration/duration_edit/icon/name/number_edit/simple/switch` | Editor property-row library |
| `c_export_dialog_content`, `c_export_item` | Board export dialog (format/options; `.mtb` — Part 3 §4.0) |
| `c_instruments_dialog_content{,_item}` | Instrument picker (container targets, command targets) |
| `c_number_dialog_content`, `c_number_picker` | Numeric entry + stepper (repeat counts — IMG_6225) |
| `c_popup_actions_element_{1,2}`, `c_popup_instrument_element`, `c_popup_interval_element` | Popup menus: element actions, instrument long-press menu (IMG_6221), running-interval list overlay (IMG_6226) |
| `c_popup_simple_styled_element_{1,2}`, `c_popup_styled_section`, `c_popup_styled_view` | Styled popup chrome |
| `c_progress_window` | Loading overlay |
| `c_web_share_button`, `c_webshare_dialog_content` | Web-share (upload board for sharing link) dialog |
| `dot_layout` | Board page indicator dots |
| `n_state_notification` | Ongoing countdown notification views (Part 5 §4.0) |

## 4.0 Home-screen widgets

Three widgets (providers `id.AppWidget_{m5rb,sz2x,u7lv}`; provider files `res/xml/app_widget_{mini1,mini2,single}_info.xml`; layouts `widget_*`):

| Widget | Cells (target) | Config activity | Layouts |
| --- | --- | --- | --- |
| mini1 | 1×1 (`targetCellWidth/Height 1/1`) | `AWMini1SettingsActivity` | `widget_mini1_view_{default,empty,preview}` |
| mini2 | 2×1 | `AWMini2SettingsActivity` | `widget_mini2_view_{default,empty,preview}` |
| single | 2×2 | `AWSingleSettingsActivity` | `widget_single_view_{default,empty,preview}`, `widget_single_view_actions`, rows `widget_action_item_{def,small}` |

Structure (from `widget_single_view_default.xml`): full-bleed circular progress image, center value (`Chronometer` **or** TextView, condensed font) + name; corner buttons: open-app (top-left), instrument icon (top-right), actions menu (bottom-left → `widget_single_view_actions` action list = per-action rows), settings (bottom-right → config activity). `updatePeriodMillis=0` (updates driven by the app/scheduler, not the system tick); `widgetCategory=home_screen|keyguard` (mini1); resize both axes; themes `Theme.AppWidget.{Base,Default}` on **Material 3 dynamic colors**. `app_widget_desc` = "One timer widget"; `AWQuickStartActivity` = transparent dispatcher for one-tap widget actions.

## 5.0 Theming & display modes

- Base: `Theme.App` parent **`Theme.Material3.DayNight.NoActionBar`** (`values/styles.xml`) — day/night aware; explicit "Light theme"/"Dark theme" strings (`hm4u`/`xi8b`, Appearance picker with description `y2du` "Choose between light or dark themes."). Widgets: `Theme.Material3.DynamicColors.DayNight` (Material You dynamic color).
- App-custom color attributes used throughout layouts: `app_backgroundPrimary`, `app_board_background`, `app_contentPrimary`, `app_rowEdgeIndent{Start,End}`, `appWidget_content{Primary,Secondary}` (theme-brand palette + board background tokens).
- Typography: single custom family in use — `@font/condensed_regular` (timer digits, widget values).
- Actions bar style `Widget.App.ActionBar` (+ `.MainMenu.*`, `.TimeDuration.*` button styles for the keypad); iOS screenshots show color *themes* ("Blue theme") — Android equivalents are the Light/Dark + Material3 dynamic palette only (no per-color app themes found in styles/strings; platform difference, GAPS G4).

## GAPS

- **G1 — Layout↔class bindings inside `defpackage`**: adapters/fragments inflate most `a_history_*`, `c_*` rows by raw int R ids (R8-inlined), so row→consumer mapping is by naming + the 25 readable `R.layout` bindings cited; no per-row citation beyond that (bounded per plan §3.1).
- **G2 — `a_settings_page` consumer**: shared settings shell; which of the 4 settings activities inflate it directly vs reuse their own root was not pinned (name + family strongly imply hub/extra pages).
- **G3 — `c_calculator` exact placement**: time-calculator component exists; whether it is reachable from the duration dialog only or also editor numeric rows was not traced.
- **G4 — Android color-theme parity**: iOS "Blue theme" has no Android settings counterpart found; possible it lives inside Appearance/Extra settings under obfuscated ids. Unverified beyond string/style sweep.
- **G5 — Welcome flow steps**: `a_welcome_simple_fragment`/`end_fragment` content (permission priming order) not read (first-run only; low rebuild value).

## CONFIDENCE

**High** for: the screen map (manifest + readable `R.layout` bindings + semantic layout names — three consistent sources), full layout classification (198/198 accounted: 48 SDK + 140 app by prefix/name), widget inventory (provider XMLs read), navigation (no nav graphs; activity/drawer/popup evidence), theming base (styles.xml read).

**Medium** for: per-row dialog↔trigger assignments where naming is the only evidence (marked above), the notice-screen fallback semantics (single read, cited), and any claim transferred from iOS screenshots to Android specifics (flags: board gear menu = popover; interval list overlay = `c_popup_interval_element`).
