"use client";

import { Button } from "@heroui/react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { ThemeSwitch } from "@/components/theme-switch";

type Locale = "zh-CN" | "zh-TW" | "en" | "he" | "ar";
type Medication = {
  id: string;
  name: string;
  defaultDose: number;
  unit: string;
  halfLifeHours: number;
  timeToPeakHours: number;
  createdAt: string;
};
type Dose = { id: string; medicationId: string; amount: number; takenAt: string };
type Reminder = {
  id: string;
  medicationId: string;
  type: "duration" | "threshold";
  value: number;
  snoozeMinutes: number;
  nextFire?: string;
};
type Snapshot = { medications: Medication[]; doses: Dose[]; reminders: Reminder[] };

const STORAGE_KEY = "meditrace.web.v1";
const localeNames: Record<Locale, string> = {
  "zh-CN": "简体中文",
  "zh-TW": "繁體中文",
  en: "English",
  he: "עברית",
  ar: "العربية",
};

const messages = {
  "zh-CN": {
    tagline: "记录剂量，理解药物在体内的变化",
    addMedication: "添加药物", empty: "还没有药物", emptyHint: "添加第一种药物，开始记录服用时间和估算趋势。",
    current: "当前估算剩余量", trend: "估算趋势", now: "现在", history: "服用记录", noDoses: "暂无服用记录",
    takeNow: "现在服用", recordDose: "记录服用", reminders: "用药提醒", noReminders: "暂无提醒", addReminder: "添加提醒",
    dose: "常用剂量", halfLife: "半衰期", peak: "达到峰值时间", hours: "小时", name: "药物名称", unit: "单位",
    save: "保存", cancel: "取消", delete: "删除", close: "关闭", amount: "剂量", takenAt: "服用时间",
    parameters: "药物参数", absorptionNote: "估算量在达到峰值前逐步上升，之后按半衰期衰减。每次服用会叠加。",
    disclaimer: "仅用于记录和数学趋势估算，不代表真实血药浓度，也不能替代医疗建议。",
    duration: "固定时长", threshold: "低于指定剩余量", trigger: "触发条件", afterDose: "服药后", below: "低于",
    snooze: "延长时间", minutes: "分钟", next: "下次提醒", notification: "允许浏览器通知",
    browserLimit: "请保持此网页或已安装的 PWA 运行。普通网页完全关闭后，浏览器无法保证定时提醒。",
    alarmTitle: "服药提醒", alarmBody: "该记录新的服药剂量了。", ignore: "忽略并延长", stop: "停止并记录剂量",
    required: "停止提醒后，请记录本次服药剂量。", validation: "请填写所有字段，并确保数值有效。",
    notificationDenied: "浏览器通知未获授权，仍会显示网页内提醒。", language: "语言", lightDark: "外观",
    deleteMedication: "删除药物及其全部记录？", deleteDose: "删除这条服用记录？", type: "提醒方式",
  },
  "zh-TW": {
    tagline: "記錄劑量，瞭解藥物在體內的變化",
    addMedication: "新增藥物", empty: "尚未新增藥物", emptyHint: "新增第一種藥物，開始記錄服用時間和估算趨勢。",
    current: "目前估算剩餘量", trend: "估算趨勢", now: "現在", history: "服用記錄", noDoses: "暫無服用記錄",
    takeNow: "現在服用", recordDose: "記錄服用", reminders: "用藥提醒", noReminders: "暫無提醒", addReminder: "新增提醒",
    dose: "常用劑量", halfLife: "半衰期", peak: "達到峰值時間", hours: "小時", name: "藥物名稱", unit: "單位",
    save: "儲存", cancel: "取消", delete: "刪除", close: "關閉", amount: "劑量", takenAt: "服用時間",
    parameters: "藥物參數", absorptionNote: "估算量在達到峰值前逐步上升，之後按半衰期衰減。每次服用會疊加。",
    disclaimer: "僅用於記錄和數學趨勢估算，不代表真實血藥濃度，也不能取代醫療建議。",
    duration: "固定時長", threshold: "低於指定剩餘量", trigger: "觸發條件", afterDose: "服藥後", below: "低於",
    snooze: "延後時間", minutes: "分鐘", next: "下次提醒", notification: "允許瀏覽器通知",
    browserLimit: "請保持此網頁或已安裝的 PWA 執行。普通網頁完全關閉後，瀏覽器無法保證定時提醒。",
    alarmTitle: "服藥提醒", alarmBody: "該記錄新的服藥劑量了。", ignore: "忽略並延後", stop: "停止並記錄劑量",
    required: "停止提醒後，請記錄本次服藥劑量。", validation: "請填寫所有欄位，並確保數值有效。",
    notificationDenied: "瀏覽器通知未獲授權，仍會顯示網頁內提醒。", language: "語言", lightDark: "外觀",
    deleteMedication: "刪除藥物及其全部記錄？", deleteDose: "刪除這筆服用記錄？", type: "提醒方式",
  },
  en: {
    tagline: "Record doses. Understand how medication changes over time.",
    addMedication: "Add medication", empty: "No medications yet", emptyHint: "Add your first medication to record doses and view its estimated trend.",
    current: "Current estimated amount", trend: "Estimated trend", now: "Now", history: "Dose history", noDoses: "No doses recorded",
    takeNow: "Take now", recordDose: "Record dose", reminders: "Medication reminders", noReminders: "No reminders", addReminder: "Add reminder",
    dose: "Default dose", halfLife: "Half-life", peak: "Time to peak", hours: "hours", name: "Medication name", unit: "Unit",
    save: "Save", cancel: "Cancel", delete: "Delete", close: "Close", amount: "Amount", takenAt: "Time taken",
    parameters: "Medication parameters", absorptionNote: "The estimate rises until its peak, then decays by half-life. Every dose is added.",
    disclaimer: "For tracking and mathematical trends only. This is not a measured blood level or medical advice.",
    duration: "Elapsed time", threshold: "Below estimated amount", trigger: "Trigger", afterDose: "After dose", below: "Below",
    snooze: "Snooze duration", minutes: "minutes", next: "Next reminder", notification: "Allow browser notifications",
    browserLimit: "Keep this page or the installed PWA running. A normal web page cannot guarantee timers after it is fully closed.",
    alarmTitle: "Medication reminder", alarmBody: "It is time to record a new dose.", ignore: "Ignore and snooze", stop: "Stop and record dose",
    required: "After stopping the reminder, record the dose you took.", validation: "Complete every field with a valid value.",
    notificationDenied: "Browser notifications were not allowed. In-page reminders will still appear.", language: "Language", lightDark: "Appearance",
    deleteMedication: "Delete this medication and all its records?", deleteDose: "Delete this dose record?", type: "Reminder type",
  },
  he: {
    tagline: "תיעוד מנות והבנת השינוי ברמת התרופה לאורך זמן",
    addMedication: "הוספת תרופה", empty: "אין עדיין תרופות", emptyHint: "הוסיפו תרופה ראשונה כדי לתעד מנות ולראות מגמה משוערת.",
    current: "כמות משוערת נוכחית", trend: "מגמה משוערת", now: "עכשיו", history: "היסטוריית נטילה", noDoses: "אין מנות מתועדות",
    takeNow: "נטילה עכשיו", recordDose: "תיעוד מנה", reminders: "תזכורות לתרופות", noReminders: "אין תזכורות", addReminder: "הוספת תזכורת",
    dose: "מנה רגילה", halfLife: "זמן מחצית חיים", peak: "זמן עד לשיא", hours: "שעות", name: "שם התרופה", unit: "יחידה",
    save: "שמירה", cancel: "ביטול", delete: "מחיקה", close: "סגירה", amount: "כמות", takenAt: "זמן הנטילה",
    parameters: "פרמטרים של התרופה", absorptionNote: "האומדן עולה עד לשיא ולאחר מכן דועך לפי זמן מחצית החיים. כל מנה מתווספת.",
    disclaimer: "למעקב ולאומדן מתמטי בלבד. זו אינה רמה שנמדדה בדם או המלצה רפואית.",
    duration: "זמן קבוע", threshold: "מתחת לכמות", trigger: "תנאי הפעלה", afterDose: "לאחר הנטילה", below: "מתחת",
    snooze: "משך הנודניק", minutes: "דקות", next: "התזכורת הבאה", notification: "מתן הרשאה להתראות",
    browserLimit: "יש להשאיר את הדף או ה־PWA פעילים. דף שנסגר לחלוטין אינו יכול להבטיח תזכורת.",
    alarmTitle: "תזכורת לתרופה", alarmBody: "הגיע הזמן לתעד מנה חדשה.", ignore: "התעלמות ונודניק", stop: "עצירה ותיעוד מנה",
    required: "לאחר עצירת התזכורת יש לתעד את המנה שנלקחה.", validation: "יש למלא את כל השדות בערכים תקינים.",
    notificationDenied: "לא ניתנה הרשאה להתראות. תזכורות בתוך הדף עדיין יוצגו.", language: "שפה", lightDark: "מראה",
    deleteMedication: "למחוק את התרופה ואת כל הרשומות שלה?", deleteDose: "למחוק את רשומת המנה?", type: "סוג תזכורת",
  },
  ar: {
    tagline: "سجّل الجرعات وافهم تغير مستوى الدواء بمرور الوقت",
    addMedication: "إضافة دواء", empty: "لا توجد أدوية بعد", emptyHint: "أضف أول دواء لتسجيل الجرعات وعرض الاتجاه التقديري.",
    current: "الكمية التقديرية الحالية", trend: "الاتجاه التقديري", now: "الآن", history: "سجل الجرعات", noDoses: "لا توجد جرعات مسجلة",
    takeNow: "تناول الآن", recordDose: "تسجيل جرعة", reminders: "تذكيرات الدواء", noReminders: "لا توجد تذكيرات", addReminder: "إضافة تذكير",
    dose: "الجرعة المعتادة", halfLife: "عمر النصف", peak: "الوقت حتى الذروة", hours: "ساعات", name: "اسم الدواء", unit: "الوحدة",
    save: "حفظ", cancel: "إلغاء", delete: "حذف", close: "إغلاق", amount: "الكمية", takenAt: "وقت التناول",
    parameters: "معلمات الدواء", absorptionNote: "يرتفع التقدير حتى الذروة ثم ينخفض وفق عمر النصف. تضاف كل جرعة.",
    disclaimer: "للتسجيل والاتجاهات الرياضية فقط. لا يمثل مستوى مقاسًا في الدم أو نصيحة طبية.",
    duration: "مدة ثابتة", threshold: "أقل من كمية محددة", trigger: "شرط التشغيل", afterDose: "بعد الجرعة", below: "أقل من",
    snooze: "مدة الغفوة", minutes: "دقائق", next: "التذكير التالي", notification: "السماح بإشعارات المتصفح",
    browserLimit: "أبقِ الصفحة أو تطبيق PWA المثبت قيد التشغيل. لا تضمن الصفحة المغلقة بالكامل المؤقتات.",
    alarmTitle: "تذكير الدواء", alarmBody: "حان وقت تسجيل جرعة جديدة.", ignore: "تجاهل وغفوة", stop: "إيقاف وتسجيل جرعة",
    required: "بعد إيقاف التذكير، سجّل الجرعة التي تناولتها.", validation: "أكمل جميع الحقول بقيم صحيحة.",
    notificationDenied: "لم يُسمح بإشعارات المتصفح. ستظل التنبيهات داخل الصفحة ظاهرة.", language: "اللغة", lightDark: "المظهر",
    deleteMedication: "حذف الدواء وجميع سجلاته؟", deleteDose: "حذف سجل الجرعة؟", type: "نوع التذكير",
  },
} as const;

const id = () => crypto.randomUUID();
const localInputDate = (date = new Date()) => {
  const adjusted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return adjusted.toISOString().slice(0, 16);
};
const amountAt = (date: Date, medication: Medication, doses: Dose[]) =>
  doses.filter((dose) => dose.medicationId === medication.id && new Date(dose.takenAt) <= date).reduce((total, dose) => {
    const elapsed = (date.getTime() - new Date(dose.takenAt).getTime()) / 3_600_000;
    const peak = Math.max(0, medication.timeToPeakHours);
    const amount = peak > 0 && elapsed < peak
      ? dose.amount * elapsed / peak
      : dose.amount * Math.pow(0.5, Math.max(0, elapsed - peak) / medication.halfLifeHours);
    return total + amount;
  }, 0);

function firstDateBelow(threshold: number, medication: Medication, doses: Dose[], now = new Date()) {
  const relevant = doses.filter((dose) => dose.medicationId === medication.id && new Date(dose.takenAt) <= now);
  if (!relevant.length) return undefined;
  const latestPeak = Math.max(...relevant.map((dose) => new Date(dose.takenAt).getTime() + medication.timeToPeakHours * 3_600_000));
  let previous = new Date(Math.max(now.getTime(), latestPeak));
  if (amountAt(previous, medication, relevant) <= threshold) return new Date(now.getTime() + 60_000);
  const end = previous.getTime() + Math.max(24, medication.halfLifeHours * 20) * 3_600_000;
  for (let time = previous.getTime() + 900_000; time <= end; time += 900_000) {
    const next = new Date(time);
    if (amountAt(next, medication, relevant) <= threshold) {
      let low = previous.getTime(); let high = time;
      for (let iteration = 0; iteration < 24; iteration += 1) {
        const middle = (low + high) / 2;
        if (amountAt(new Date(middle), medication, relevant) > threshold) low = middle;
        else high = middle;
      }
      return new Date(high);
    }
    previous = next;
  }
  return undefined;
}

function LevelChart({ medication, doses, locale, nowLabel }: { medication: Medication; doses: Dose[]; locale: Locale; nowLabel: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ratio = window.devicePixelRatio || 1; const width = canvas.clientWidth; const height = canvas.clientHeight;
    canvas.width = width * ratio; canvas.height = height * ratio;
    const context = canvas.getContext("2d"); if (!context) return;
    context.scale(ratio, ratio); context.clearRect(0, 0, width, height);
    const now = new Date(); const start = now.getTime() - 24 * 3_600_000;
    const end = now.getTime() + Math.max(24, medication.halfLifeHours * 5) * 3_600_000;
    const points = Array.from({ length: 181 }, (_, index) => {
      const date = new Date(start + (end - start) * index / 180);
      return { date, amount: amountAt(date, medication, doses) };
    });
    const maximum = Math.max(1, ...points.map((point) => point.amount));
    const pad = { left: 46, right: 12, top: 16, bottom: 34 }; const chartW = width - pad.left - pad.right; const chartH = height - pad.top - pad.bottom;
    const styles = getComputedStyle(document.documentElement); const line = styles.getPropertyValue("--chart-line").trim() || "#16845b";
    const grid = styles.getPropertyValue("--chart-grid").trim() || "#d8e1dc"; const text = styles.getPropertyValue("--chart-text").trim() || "#64746b";
    context.font = "12px system-ui"; context.strokeStyle = grid; context.fillStyle = text; context.lineWidth = 1;
    for (let row = 0; row <= 4; row += 1) { const y = pad.top + chartH * row / 4; context.beginPath(); context.moveTo(pad.left, y); context.lineTo(width - pad.right, y); context.stroke(); context.fillText((maximum * (1 - row / 4)).toFixed(1), 4, y + 4); }
    context.beginPath(); points.forEach((point, index) => { const x = pad.left + chartW * index / 180; const y = pad.top + chartH * (1 - point.amount / maximum); if (!index) context.moveTo(x, y); else context.lineTo(x, y); });
    context.strokeStyle = line; context.lineWidth = 3; context.lineJoin = "round"; context.stroke();
    const nowX = pad.left + chartW * (now.getTime() - start) / (end - start); context.setLineDash([5, 5]); context.strokeStyle = text; context.beginPath(); context.moveTo(nowX, pad.top); context.lineTo(nowX, pad.top + chartH); context.stroke(); context.setLineDash([]);
    context.fillStyle = text; context.textAlign = "center"; context.fillText(nowLabel, nowX, height - 7);
    context.fillText(new Intl.DateTimeFormat(locale, { weekday: "short", hour: "numeric" }).format(new Date(start)), pad.left, height - 7);
    context.fillText(new Intl.DateTimeFormat(locale, { weekday: "short", hour: "numeric" }).format(new Date(end)), width - pad.right - 20, height - 7);
  }, [medication, doses, locale, nowLabel]);
  return <canvas ref={canvasRef} className="level-chart" role="img" aria-label={nowLabel} />;
}

export function MediTraceApp() {
  const [locale, setLocale] = useState<Locale>("en"); const t = messages[locale];
  const [data, setData] = useState<Snapshot>({ medications: [], doses: [], reminders: [] });
  const [selectedId, setSelectedId] = useState<string>(); const [hydrated, setHydrated] = useState(false); const [tick, setTick] = useState(0);
  const [modal, setModal] = useState<"medication" | "dose" | "reminder" | null>(null); const [requiredDose, setRequiredDose] = useState(false);
  const [activeReminder, setActiveReminder] = useState<Reminder>(); const [notice, setNotice] = useState<string>();
  const [medDraft, setMedDraft] = useState({ name: "", dose: 100, unit: "mg", halfLife: 8, peak: 2 });
  const [doseDraft, setDoseDraft] = useState({ amount: 100, takenAt: localInputDate() });
  const [reminderDraft, setReminderDraft] = useState({ type: "duration" as "duration" | "threshold", value: 8, snooze: 10 });

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY); if (stored) { try { setData(JSON.parse(stored)); } catch {} }
    const preferred = localStorage.getItem("meditrace.locale") as Locale | null;
    const browser = navigator.language; const detected: Locale = browser.startsWith("zh-TW") || browser.startsWith("zh-HK") ? "zh-TW" : browser.startsWith("zh") ? "zh-CN" : browser.startsWith("he") ? "he" : browser.startsWith("ar") ? "ar" : "en";
    setLocale(preferred && preferred in messages ? preferred : detected); setHydrated(true);
  }, []);
  useEffect(() => { if (hydrated) localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); }, [data, hydrated]);
  useEffect(() => { localStorage.setItem("meditrace.locale", locale); document.documentElement.lang = locale; document.documentElement.dir = locale === "he" || locale === "ar" ? "rtl" : "ltr"; }, [locale]);
  useEffect(() => { const timer = window.setInterval(() => setTick((value) => value + 1), 15_000); return () => clearInterval(timer); }, []);

  const selected = data.medications.find((medication) => medication.id === selectedId) ?? data.medications[0];
  const medicationDoses = useMemo(() => selected ? data.doses.filter((dose) => dose.medicationId === selected.id).sort((a, b) => +new Date(b.takenAt) - +new Date(a.takenAt)) : [], [data.doses, selected]);
  const medicationReminders = useMemo(() => selected ? data.reminders.filter((reminder) => reminder.medicationId === selected.id) : [], [data.reminders, selected]);
  const currentAmount = selected ? amountAt(new Date(), selected, medicationDoses) : 0;

  useEffect(() => {
    if (activeReminder) return;
    const due = data.reminders.find((reminder) => reminder.nextFire && new Date(reminder.nextFire) <= new Date());
    if (!due) return; setActiveReminder(due);
    if ("Notification" in window && Notification.permission === "granted") new Notification(t.alarmTitle, { body: t.alarmBody, tag: due.id });
  }, [tick, data.reminders, activeReminder, t.alarmBody, t.alarmTitle]);

  const reschedule = useCallback((snapshot: Snapshot, medication: Medication, reference = new Date()) => ({
    ...snapshot,
    reminders: snapshot.reminders.map((reminder) => {
      if (reminder.medicationId !== medication.id) return reminder;
      const fire = reminder.type === "duration" ? new Date(reference.getTime() + reminder.value * 3_600_000) : firstDateBelow(reminder.value, medication, snapshot.doses, reference);
      return { ...reminder, nextFire: fire?.toISOString() };
    }),
  }), []);

  const addMedication = () => {
    if (!medDraft.name.trim() || !medDraft.unit.trim() || medDraft.dose <= 0 || medDraft.halfLife <= 0 || medDraft.peak < 0) return setNotice(t.validation);
    const medication: Medication = { id: id(), name: medDraft.name.trim(), defaultDose: medDraft.dose, unit: medDraft.unit.trim(), halfLifeHours: medDraft.halfLife, timeToPeakHours: medDraft.peak, createdAt: new Date().toISOString() };
    setData((value) => ({ ...value, medications: [...value.medications, medication] })); setSelectedId(medication.id); setModal(null); setNotice(undefined);
  };
  const openDose = (required = false) => { if (!selected) return; setDoseDraft({ amount: selected.defaultDose, takenAt: localInputDate() }); setRequiredDose(required); setModal("dose"); };
  const addDose = (amount = doseDraft.amount, takenAt = new Date(doseDraft.takenAt)) => {
    if (!selected || amount <= 0 || Number.isNaN(takenAt.getTime())) return setNotice(t.validation);
    setData((value) => { const next = { ...value, doses: [...value.doses, { id: id(), medicationId: selected.id, amount, takenAt: takenAt.toISOString() }] }; return reschedule(next, selected, takenAt); });
    setModal(null); setRequiredDose(false); setNotice(undefined);
  };
  const addReminder = async () => {
    if (!selected || reminderDraft.value < 0 || reminderDraft.snooze <= 0) return setNotice(t.validation);
    if ("Notification" in window && Notification.permission === "default") { const permission = await Notification.requestPermission(); if (permission !== "granted") setNotice(t.notificationDenied); }
    const fire = reminderDraft.type === "duration" ? new Date(Date.now() + reminderDraft.value * 3_600_000) : firstDateBelow(reminderDraft.value, selected, data.doses);
    if (!fire) return setNotice(t.validation);
    setData((value) => ({ ...value, reminders: [...value.reminders, { id: id(), medicationId: selected.id, type: reminderDraft.type, value: reminderDraft.value, snoozeMinutes: reminderDraft.snooze, nextFire: fire.toISOString() }] })); setModal(null);
  };
  const format = (value: number) => new Intl.NumberFormat(locale, { maximumFractionDigits: 2 }).format(value);
  const formatDate = (value: string) => new Intl.DateTimeFormat(locale, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));

  if (!hydrated) return <main className="loading-shell"><div className="brand-mark">M</div></main>;
  return (
    <main className="app-shell">
      <header className="topbar">
        <div className="brand"><span className="brand-mark">M</span><span><strong>MediTrace</strong><small>{t.tagline}</small></span></div>
        <div className="top-actions"><label className="language"><span>{t.language}</span><select value={locale} onChange={(event) => setLocale(event.target.value as Locale)}>{Object.entries(localeNames).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><ThemeSwitch /></div>
      </header>
      <div className="workspace">
        <aside className="sidebar">
          <div className="section-heading"><span>{t.parameters}</span><Button size="sm" variant="primary" onPress={() => { setMedDraft({ name: "", dose: 100, unit: "mg", halfLife: 8, peak: 2 }); setModal("medication"); }}>＋ {t.addMedication}</Button></div>
          <div className="medication-list">{data.medications.map((medication) => <button key={medication.id} className={`medication-item ${selected?.id === medication.id ? "selected" : ""}`} onClick={() => setSelectedId(medication.id)}><span className="pill-dot">●</span><span><strong>{medication.name}</strong><small>{format(medication.defaultDose)} {medication.unit} · t½ {format(medication.halfLifeHours)}h</small></span></button>)}</div>
          <p className="sidebar-note">{t.disclaimer}</p>
        </aside>
        <section className="content">
          {!selected ? <div className="empty-state"><div className="empty-icon">＋</div><h1>{t.empty}</h1><p>{t.emptyHint}</p><Button variant="primary" onPress={() => setModal("medication")}>{t.addMedication}</Button></div> : <>
            <div className="content-header"><div><p className="eyebrow">{t.parameters}</p><h1>{selected.name}</h1><p>{t.dose} {format(selected.defaultDose)} {selected.unit} · {t.halfLife} {format(selected.halfLifeHours)} {t.hours} · {t.peak} {format(selected.timeToPeakHours)} {t.hours}</p></div><div className="action-row"><Button variant="secondary" onPress={() => { setReminderDraft({ type: "duration", value: 8, snooze: 10 }); setModal("reminder"); }}>◷ {t.reminders}</Button><Button variant="primary" onPress={() => openDose(false)}>＋ {t.recordDose}</Button></div></div>
            <section className="metric-card"><div><span>{t.current}</span><strong>{format(currentAmount)} <small>{selected.unit}</small></strong></div><Button variant="primary" onPress={() => addDose(selected.defaultDose, new Date())}>{t.takeNow} · {format(selected.defaultDose)} {selected.unit}</Button></section>
            <div className="main-grid"><section className="panel chart-panel"><div className="panel-title"><h2>{t.trend}</h2><span className="live-dot">● {t.now}</span></div><LevelChart medication={selected} doses={medicationDoses} locale={locale} nowLabel={t.now} /><p className="supporting">{t.absorptionNote}</p></section>
            <section className="panel"><div className="panel-title"><h2>{t.reminders}</h2><button className="text-button" onClick={() => setModal("reminder")}>＋ {t.addReminder}</button></div>{medicationReminders.length ? <div className="record-list">{medicationReminders.map((reminder) => <article key={reminder.id} className="record-row"><div><strong>{reminder.type === "duration" ? `${t.afterDose} ${format(reminder.value)} ${t.hours}` : `${t.below} ${format(reminder.value)} ${selected.unit}`}</strong><small>{reminder.nextFire ? `${t.next}: ${formatDate(reminder.nextFire)}` : "—"}</small></div><button className="delete-button" aria-label={t.delete} onClick={() => setData((value) => ({ ...value, reminders: value.reminders.filter((item) => item.id !== reminder.id) }))}>×</button></article>)}</div> : <p className="empty-copy">{t.noReminders}</p>}<p className="browser-limit">{t.browserLimit}</p></section></div>
            <section className="panel history-panel"><div className="panel-title"><h2>{t.history}</h2><span>{medicationDoses.length}</span></div>{medicationDoses.length ? <div className="record-list">{medicationDoses.map((dose) => <article key={dose.id} className="record-row"><div><strong>{format(dose.amount)} {selected.unit}</strong><small>{formatDate(dose.takenAt)}</small></div><button className="delete-button" aria-label={t.delete} onClick={() => { if (confirm(t.deleteDose)) setData((value) => reschedule({ ...value, doses: value.doses.filter((item) => item.id !== dose.id) }, selected)); }}>×</button></article>)}</div> : <p className="empty-copy">{t.noDoses}</p>}<button className="danger-link" onClick={() => { if (confirm(t.deleteMedication)) { setData((value) => ({ medications: value.medications.filter((item) => item.id !== selected.id), doses: value.doses.filter((item) => item.medicationId !== selected.id), reminders: value.reminders.filter((item) => item.medicationId !== selected.id) })); setSelectedId(undefined); } }}>{t.delete} {selected.name}</button></section>
          </>}
        </section>
      </div>
      {modal === "medication" && <Modal title={t.addMedication} onClose={() => setModal(null)} closeLabel={t.cancel}><div className="form-grid"><Field label={t.name}><input autoFocus value={medDraft.name} onChange={(e) => setMedDraft({ ...medDraft, name: e.target.value })} /></Field><Field label={t.dose}><input type="number" min="0" value={medDraft.dose} onChange={(e) => setMedDraft({ ...medDraft, dose: +e.target.value })} /></Field><Field label={t.unit}><input value={medDraft.unit} onChange={(e) => setMedDraft({ ...medDraft, unit: e.target.value })} /></Field><Field label={`${t.halfLife} (${t.hours})`}><input type="number" min="0.01" step="0.1" value={medDraft.halfLife} onChange={(e) => setMedDraft({ ...medDraft, halfLife: +e.target.value })} /></Field><Field label={`${t.peak} (${t.hours})`}><input type="number" min="0" step="0.1" value={medDraft.peak} onChange={(e) => setMedDraft({ ...medDraft, peak: +e.target.value })} /></Field></div>{notice && <p className="form-error">{notice}</p>}<ModalActions cancel={t.cancel} save={t.save} onCancel={() => setModal(null)} onSave={addMedication} /></Modal>}
      {modal === "dose" && selected && <Modal title={t.recordDose} onClose={requiredDose ? undefined : () => setModal(null)} closeLabel={t.cancel}>{requiredDose && <p className="required-note">{t.required}</p>}<div className="form-grid"><Field label={`${t.amount} (${selected.unit})`}><input autoFocus type="number" min="0.01" step="0.1" value={doseDraft.amount} onChange={(e) => setDoseDraft({ ...doseDraft, amount: +e.target.value })} /></Field><Field label={t.takenAt}><input type="datetime-local" max={localInputDate()} value={doseDraft.takenAt} onChange={(e) => setDoseDraft({ ...doseDraft, takenAt: e.target.value })} /></Field></div>{notice && <p className="form-error">{notice}</p>}<ModalActions cancel={requiredDose ? undefined : t.cancel} save={t.save} onCancel={() => setModal(null)} onSave={() => addDose()} /></Modal>}
      {modal === "reminder" && selected && <Modal title={t.addReminder} onClose={() => setModal(null)} closeLabel={t.cancel}><div className="form-grid"><Field label={t.type}><select value={reminderDraft.type} onChange={(e) => setReminderDraft({ ...reminderDraft, type: e.target.value as "duration" | "threshold" })}><option value="duration">{t.duration}</option><option value="threshold">{t.threshold}</option></select></Field><Field label={reminderDraft.type === "duration" ? `${t.afterDose} (${t.hours})` : `${t.below} (${selected.unit})`}><input type="number" min="0" step="0.1" value={reminderDraft.value} onChange={(e) => setReminderDraft({ ...reminderDraft, value: +e.target.value })} /></Field><Field label={`${t.snooze} (${t.minutes})`}><input type="number" min="1" value={reminderDraft.snooze} onChange={(e) => setReminderDraft({ ...reminderDraft, snooze: +e.target.value })} /></Field></div><p className="browser-limit">{t.browserLimit}</p>{notice && <p className="form-error">{notice}</p>}<ModalActions cancel={t.cancel} save={t.save} onCancel={() => setModal(null)} onSave={addReminder} /></Modal>}
      {activeReminder && <Modal title={t.alarmTitle}><p className="alarm-copy">{t.alarmBody}</p><div className="alarm-actions"><Button variant="secondary" onPress={() => { setData((value) => ({ ...value, reminders: value.reminders.map((item) => item.id === activeReminder.id ? { ...item, nextFire: new Date(Date.now() + item.snoozeMinutes * 60_000).toISOString() } : item) })); setActiveReminder(undefined); }}>{t.ignore} · {activeReminder.snoozeMinutes} {t.minutes}</Button><Button variant="primary" onPress={() => { const medication = data.medications.find((item) => item.id === activeReminder.medicationId); if (medication) { setSelectedId(medication.id); setDoseDraft({ amount: medication.defaultDose, takenAt: localInputDate() }); setRequiredDose(true); setModal("dose"); } setData((value) => ({ ...value, reminders: value.reminders.map((item) => item.id === activeReminder.id ? { ...item, nextFire: undefined } : item) })); setActiveReminder(undefined); }}>{t.stop}</Button></div></Modal>}
    </main>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) { return <label className="field"><span>{label}</span>{children}</label>; }
function Modal({ title, children, onClose, closeLabel }: { title: string; children: React.ReactNode; onClose?: () => void; closeLabel?: string }) { return <div className="modal-backdrop" role="presentation"><section className="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div className="modal-heading"><h2 id="modal-title">{title}</h2>{onClose && <button onClick={onClose} aria-label={closeLabel}>×</button>}</div>{children}</section></div>; }
function ModalActions({ cancel, save, onCancel, onSave }: { cancel?: string; save: string; onCancel: () => void; onSave: () => void }) { return <div className="modal-actions">{cancel && <Button variant="secondary" onPress={onCancel}>{cancel}</Button>}<Button variant="primary" onPress={onSave}>{save}</Button></div>; }
