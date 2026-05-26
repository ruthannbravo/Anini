import SwiftUI

struct NotchWidgetView: View {
    @ObservedObject var notchState: NotchState
    @ObservedObject var nowPlaying: NowPlayingService
    let onOpenChat: (String, TodoTask?) -> Void
    let onOpenSettings: () -> Void

    @ObservedObject private var config = WorkspaceConfig.shared
    @State private var floating = false
    @State private var chatInput: String = ""

    private let pill = RoundedRectangle(cornerRadius: 20, style: .continuous)
    @State private var newTaskText = ""
    @State private var editingTaskId: UUID? = nil
    @State private var editText: String = ""
    @State private var expandedTaskId: UUID? = nil
    @State private var schedulingTaskId: UUID? = nil
    @State private var schedulingDate: Date = Date()
    @State private var keepAwakePromptTaskId: UUID? = nil
    private let scheduleTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    @State private var showFrenchPopover = false
    @State private var showFrenchVerbPopover = false
    @State private var showNotchSettings = false
    @State private var wordIndexOverride: Int? = nil
    @State private var practiceIndexOverride: Int? = nil
    @State private var verbIndexOverride: Int? = nil
    @State private var verbPracticeIndexOverride: Int? = nil
    // false = showing word, true = showing verb in the shared pill
    @State private var pillShowsVerb: Bool = false

    @State private var showItalianPopover = false
    @State private var showItalianVerbPopover = false
    @State private var italianWordIndexOverride: Int? = nil
    @State private var italianPracticeIndexOverride: Int? = nil
    @State private var italianVerbIndexOverride: Int? = nil
    @State private var italianVerbPracticeIndexOverride: Int? = nil
    @State private var italianPillShowsVerb: Bool = false

    var body: some View {
        Group {
            if notchState.isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                pill.fill(.thinMaterial)
                pill.fill(Color.black.opacity(0.35))
                pill.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        }
        .clipShape(pill)
        .ignoresSafeArea(.all, edges: .top)
    }

    // ── Collapsed: three pulsing white hearts, full-area tap ──────────────
    private var collapsedContent: some View {
        Button(action: { notchState.isExpanded = true }) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Group {
                        if config.iconEmoji.isEmpty {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white)
                        } else {
                            Text(config.iconEmoji)
                                .font(.system(size: 11))
                        }
                    }
                    .scaleEffect(floating ? 1.25 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.65 + Double(i) * 0.1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: floating
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            floating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { floating = true }
        }
    }

    // ── Expanded ──────────────────────────────────────────────────────────
    private var expandedContent: some View {
        HStack(spacing: 0) {
            let hasAnyLang = config.learningLanguage != .none && (config.showLangWord || config.showLangVerb)
            let hasLeft = config.showNowPlaying || hasAnyLang
            if hasLeft {
                HStack(spacing: 8) {
                    if config.showNowPlaying {
                        musicSection
                            .frame(width: hasAnyLang ? 198 : nil,
                                   alignment: .leading)
                    }
                    if hasAnyLang {
                        switch config.learningLanguage {
                        case .french:  frenchLangSection
                        case .italian: italianLangSection
                        case .none:    EmptyView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 0.5)
            }

            if hasLeft {
                rightPanel
                    .frame(width: 222, alignment: .trailing)
                    .padding(.leading, 12)
            } else {
                rightPanel
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { notchState.isExpanded = false }
        )
        .onReceive(scheduleTimer) { _ in checkScheduledTasks() }
        .alert("Keep Mac awake?", isPresented: Binding(
            get: { keepAwakePromptTaskId != nil },
            set: { if !$0 { keepAwakePromptTaskId = nil } }
        )) {
            Button("Yes, keep awake") {
                if let id = keepAwakePromptTaskId,
                   let idx = notchState.tasks.firstIndex(where: { $0.id == id }) {
                    notchState.tasks[idx].keepAwake = true
                    notchState.saveTasks()
                }
                keepAwakePromptTaskId = nil
            }
            Button("No thanks", role: .cancel) {
                keepAwakePromptTaskId = nil
            }
        } message: {
            Text("Should Anini prevent your Mac from sleeping when this task runs?")
        }
    }

    // ── Right panel: Chat / To Do tabs ────────────────────────────────────
    private var rightPanel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    tabButton("chat",   tab: .chat)
                    tabButton("to do", tab: .todo, badge: notchState.tasks.filter { !$0.isDone }.count)
                }
                .padding(3)
                .background(Color(white: 0.14, opacity: 0.8).clipShape(Capsule()))

                Spacer()

                Button(action: { showNotchSettings.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 9))
                        .foregroundStyle(showNotchSettings ? config.accentColor : Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color(white: 0.14, opacity: 0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNotchSettings, arrowEdge: .bottom) {
                    notchSettingsPopover
                }
            }

            if notchState.activeTab == .chat {
                chatContent
            } else {
                todoContent
            }
        }
        .padding(.leading, 8)
    }

    // ── Notch settings popover ────────────────────────────────────────────
    private var notchSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notch Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Button(action: {
                showNotchSettings = false
                onOpenSettings()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                    Text("Open chat settings")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(white: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Open Anini's full settings panel")

            Divider().background(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 8) {
                Text("MEDIA")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)

                settingsToggleRow("Now playing", isOn: $config.showNowPlaying)
                    .help("Show the currently playing track")
            }

            Divider().background(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 8) {
                Text("LANGUAGE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Language")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        ForEach(WorkspaceConfig.LearningLanguage.allCases, id: \.rawValue) { lang in
                            Button(action: { config.learningLanguage = lang }) {
                                Text(lang.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(config.learningLanguage == lang ? .white : Color.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(config.learningLanguage == lang
                                                ? config.accentColor.opacity(0.35)
                                                : Color(white: 0.2))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if config.learningLanguage != .none {
                    Divider().background(Color.white.opacity(0.08))

                    settingsToggleRow("Word of the week", isOn: $config.showLangWord)
                        .help("Weekly rotating vocabulary with pronunciation")

                    settingsToggleRow("Verb of the week", isOn: $config.showLangVerb)
                        .help("Essential verbs with conjugation and daily exercises")

                    Divider().background(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("My gender")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .help("Personalizes phrases like \u{201C}Je suis gourmand(e)\u{201D} / \u{201C}Sono contento/a\u{201D}")
                        HStack(spacing: 6) {
                            ForEach(WorkspaceConfig.UserGender.allCases, id: \.rawValue) { g in
                                Button(action: { config.userGender = g }) {
                                    Text(g.label)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(config.userGender == g ? .white : Color.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(config.userGender == g
                                                    ? config.accentColor.opacity(0.35)
                                                    : Color(white: 0.2))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(Color(white: 0.12))
        .preferredColorScheme(.dark)
    }

    private func settingsToggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private func tabButton(_ label: String, tab: NotchTab, badge: Int = 0) -> some View {
        Button(action: { notchState.activeTab = tab }) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(notchState.activeTab == tab ? .white : Color.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(notchState.activeTab == tab
                            ? Color(white: 0.32, opacity: 0.9) : Color.clear)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(x: 6, y: -6)
            }
        }
    }

    // ── Chat tab ──────────────────────────────────────────────────────────
    private var chatContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 6) {
                TextField("how can I help today", text: $chatInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white)
                    .onSubmit { submitChat() }

                Button(action: submitChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(chatInput.isEmpty ? Color.secondary : config.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(chatInput.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(white: 0.18, opacity: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: { notchState.isExpanded = false; onOpenChat("", nil) }) {
                Label("Open Chat", systemImage: "bubble.left.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    // ── To Do tab ─────────────────────────────────────────────────────────
    private var todoContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(notchState.tasks) { task in
                todoRow(task)
            }

            if notchState.tasks.count < 5 {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    TextField("add task…", text: $newTaskText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .onSubmit { addTask() }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color(white: 0.16, opacity: 0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if notchState.tasks.contains(where: { $0.isDone }) {
                HStack {
                    Spacer()
                    Button(action: clearDone) {
                        Text("clear")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todoRow(_ task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: { toggleDone(task) }) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(task.isDone ? config.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                if editingTaskId == task.id {
                    TextField("", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white)
                        .onSubmit { commitEdit(task) }
                    Button(action: { commitEdit(task) }) {
                        Text("save")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(config.accentColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    let isExpanded = expandedTaskId == task.id
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title)
                            .font(.system(size: 11))
                            .foregroundStyle(task.isDone ? Color.secondary : Color.white)
                            .strikethrough(task.isDone, color: .secondary)
                            .lineLimit(isExpanded ? nil : 1)
                            .fixedSize(horizontal: false, vertical: isExpanded)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedTaskId = isExpanded ? nil : task.id
                                }
                            }
                        if let date = task.scheduledDate {
                            Text(scheduledLabel(date))
                                .font(.system(size: 8))
                                .foregroundStyle(date < Date() ? Color.orange : config.accentColor)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button(action: { startEditing(task) }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: {
                        schedulingDate = task.scheduledDate ?? Date().addingTimeInterval(3600)
                        schedulingTaskId = task.id
                    }) {
                        Label(task.scheduledDate == nil ? "Let Anini do this later" : "Change scheduled time",
                              systemImage: "calendar.badge.clock")
                    }
                    if task.scheduledDate != nil {
                        Button(action: { removeSchedule(task) }) {
                            Label("Remove schedule", systemImage: "calendar.badge.minus")
                        }
                    }
                    Button(action: { askAnini(task) }) {
                        Label("Let Anini complete now", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 16, height: 16)
            }

            // Inline date picker when scheduling this task
            if schedulingTaskId == task.id {
                VStack(alignment: .leading, spacing: 6) {
                    DatePicker("", selection: $schedulingDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                    HStack(spacing: 8) {
                        Button("Cancel") { schedulingTaskId = nil }
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Set schedule") { saveSchedule(task) }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(config.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
                .padding(.leading, 18)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(white: 0.16, opacity: 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // ── Todo helpers ──────────────────────────────────────────────────────
    private func addTask() {
        let text = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, notchState.tasks.count < 5 else { return }
        notchState.tasks.append(TodoTask(title: text))
        notchState.saveTasks()
        newTaskText = ""
    }

    private func toggleDone(_ task: TodoTask) {
        guard let idx = notchState.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        notchState.tasks[idx].isDone.toggle()
        notchState.saveTasks()
    }

    private func startEditing(_ task: TodoTask) {
        editText = task.title
        editingTaskId = task.id
    }

    private func commitEdit(_ task: TodoTask) {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let idx = notchState.tasks.firstIndex(where: { $0.id == task.id }) {
            notchState.tasks[idx].title = trimmed
            notchState.saveTasks()
        }
        editingTaskId = nil
        editText = ""
    }

    private func clearDone() {
        notchState.tasks.removeAll { $0.isDone }
        notchState.saveTasks()
    }

    private func saveSchedule(_ task: TodoTask) {
        guard let idx = notchState.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        notchState.tasks[idx].scheduledDate = schedulingDate
        notchState.saveTasks()
        schedulingTaskId = nil
        keepAwakePromptTaskId = task.id
    }

    private func removeSchedule(_ task: TodoTask) {
        guard let idx = notchState.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        notchState.tasks[idx].scheduledDate = nil
        notchState.saveTasks()
    }

    private func checkScheduledTasks() {
        let now = Date()
        for task in notchState.tasks where !task.isDone {
            guard let scheduled = task.scheduledDate, scheduled <= now else { continue }
            if let idx = notchState.tasks.firstIndex(where: { $0.id == task.id }) {
                notchState.tasks[idx].scheduledDate = nil
                notchState.saveTasks()
            }
            if task.keepAwake {
                BackendManager.shared.forceNextCaffeinate = true
            }
            askAnini(task)
            break
        }
    }

    private func scheduledLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let time = fmt.string(from: date)
        if cal.isDateInToday(date)    { return "today \(time)" }
        if cal.isDateInTomorrow(date) { return "tomorrow \(time)" }
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: date)
    }

    private func askAnini(_ task: TodoTask) {
        notchState.isExpanded = false
        onOpenChat("Please help me with this task: \(task.title)", task)
    }

    private func openMusic() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Music.app"))
        }
    }

    private func submitChat() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chatInput = ""
        notchState.isExpanded = false
        onOpenChat(text, nil)
    }

    // ── French word display state ─────────────────────────────────────────
    private var displayWordIndex: Int {
        if let i = wordIndexOverride { return i }
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return week % FrenchWordService.shared.allWords.count
    }
    private var displayWord: FrenchWord { FrenchWordService.shared.allWords[displayWordIndex] }
    private var displayPracticeIndex: Int {
        if let i = practiceIndexOverride { return i }
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        return min(day, displayWord.practiceQuestions.count - 1)
    }
    private func prevWord() {
        let c = FrenchWordService.shared.allWords.count
        wordIndexOverride = (displayWordIndex - 1 + c) % c
        practiceIndexOverride = nil
    }
    private func nextWord() {
        let c = FrenchWordService.shared.allWords.count
        wordIndexOverride = (displayWordIndex + 1) % c
        practiceIndexOverride = nil
    }
    private func prevExercise() {
        let c = displayWord.practiceQuestions.count
        practiceIndexOverride = (displayPracticeIndex - 1 + c) % c
    }
    private func nextExercise() {
        let c = displayWord.practiceQuestions.count
        practiceIndexOverride = (displayPracticeIndex + 1) % c
    }

    // ── Verb navigation helpers ───────────────────────────────────────────
    private var displayVerbIndex: Int {
        if let i = verbIndexOverride { return i }
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return week % FrenchVerbService.shared.allVerbs.count
    }
    private var displayVerb: FrenchVerb { FrenchVerbService.shared.allVerbs[displayVerbIndex] }
    private var displayVerbPracticeIndex: Int {
        if let i = verbPracticeIndexOverride { return i }
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        return min(day, displayVerb.practiceQuestions.count - 1)
    }
    private func prevVerb() {
        let c = FrenchVerbService.shared.allVerbs.count
        verbIndexOverride = (displayVerbIndex - 1 + c) % c
        verbPracticeIndexOverride = nil
    }
    private func nextVerb() {
        let c = FrenchVerbService.shared.allVerbs.count
        verbIndexOverride = (displayVerbIndex + 1) % c
        verbPracticeIndexOverride = nil
    }
    private func prevVerbExercise() {
        let c = displayVerb.practiceQuestions.count
        verbPracticeIndexOverride = (displayVerbPracticeIndex - 1 + c) % c
    }
    private func nextVerbExercise() {
        let c = displayVerb.practiceQuestions.count
        verbPracticeIndexOverride = (displayVerbPracticeIndex + 1) % c
    }

    // ── Italian word display state ────────────────────────────────────────
    private var displayItalianWordIndex: Int {
        if let i = italianWordIndexOverride { return i }
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return week % ItalianWordService.shared.allWords.count
    }
    private var displayItalianWord: ItalianWord { ItalianWordService.shared.allWords[displayItalianWordIndex] }
    private var displayItalianPracticeIndex: Int {
        if let i = italianPracticeIndexOverride { return i }
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        return min(day, displayItalianWord.practiceQuestions.count - 1)
    }
    private func prevItalianWord() {
        let c = ItalianWordService.shared.allWords.count
        italianWordIndexOverride = (displayItalianWordIndex - 1 + c) % c
        italianPracticeIndexOverride = nil
    }
    private func nextItalianWord() {
        let c = ItalianWordService.shared.allWords.count
        italianWordIndexOverride = (displayItalianWordIndex + 1) % c
        italianPracticeIndexOverride = nil
    }
    private func prevItalianExercise() {
        let c = displayItalianWord.practiceQuestions.count
        italianPracticeIndexOverride = (displayItalianPracticeIndex - 1 + c) % c
    }
    private func nextItalianExercise() {
        let c = displayItalianWord.practiceQuestions.count
        italianPracticeIndexOverride = (displayItalianPracticeIndex + 1) % c
    }

    // ── Italian verb navigation helpers ───────────────────────────────────
    private var displayItalianVerbIndex: Int {
        if let i = italianVerbIndexOverride { return i }
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return week % ItalianVerbService.shared.allVerbs.count
    }
    private var displayItalianVerb: ItalianVerb { ItalianVerbService.shared.allVerbs[displayItalianVerbIndex] }
    private var displayItalianVerbPracticeIndex: Int {
        if let i = italianVerbPracticeIndexOverride { return i }
        let day = Calendar.current.component(.weekday, from: Date()) - 1
        return min(day, displayItalianVerb.practiceQuestions.count - 1)
    }
    private func prevItalianVerb() {
        let c = ItalianVerbService.shared.allVerbs.count
        italianVerbIndexOverride = (displayItalianVerbIndex - 1 + c) % c
        italianVerbPracticeIndexOverride = nil
    }
    private func nextItalianVerb() {
        let c = ItalianVerbService.shared.allVerbs.count
        italianVerbIndexOverride = (displayItalianVerbIndex + 1) % c
        italianVerbPracticeIndexOverride = nil
    }
    private func prevItalianVerbExercise() {
        let c = displayItalianVerb.practiceQuestions.count
        italianVerbPracticeIndexOverride = (displayItalianVerbPracticeIndex - 1 + c) % c
    }
    private func nextItalianVerbExercise() {
        let c = displayItalianVerb.practiceQuestions.count
        italianVerbPracticeIndexOverride = (displayItalianVerbPracticeIndex + 1) % c
    }

    // ── Combined French language section ──────────────────────────────────
    private var frenchLangSection: some View {
        let showBoth = config.showLangWord && config.showLangVerb
        let showingVerb = showBoth ? pillShowsVerb : config.showLangVerb
        return VStack(spacing: 3) {
            // Mini tab — only shown when both are enabled
            if showBoth {
                HStack(spacing: 0) {
                    Button(action: { pillShowsVerb = false }) {
                        Text("mot")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(!pillShowsVerb ? config.accentColor : Color(white: 0.45))
                    }
                    .buttonStyle(.plain)
                    Text(" · ")
                        .font(.system(size: 7))
                        .foregroundStyle(Color(white: 0.35))
                    Button(action: { pillShowsVerb = true }) {
                        Text("verbe")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(pillShowsVerb ? config.accentColor : Color(white: 0.45))
                    }
                    .buttonStyle(.plain)
                }
            }

            if showingVerb {
                frenchVerbPill
            } else {
                frenchWordPill
            }
        }
    }

    // ── French Word pill ─────────────────────────────────────────────────
    private var frenchWordPill: some View {
        let word = displayWord
        return VStack(spacing: 4) {
            if !(config.showLangWord && config.showLangVerb) {
                Text("mot de la\nsemaine")
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showFrenchPopover.toggle() }) {
                Text(word.word)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFrenchPopover, arrowEdge: .bottom) {
                frenchWordPopover(word, practiceIndex: displayPracticeIndex)
            }

            Button(action: { FrenchWordService.shared.speak(text: word.word) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear pronunciation (French Canadian)")
        }
        .padding(8)
        .frame(width: 84, height: 84)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── French Verb pill ─────────────────────────────────────────────────
    private var frenchVerbPill: some View {
        let verb = displayVerb
        return VStack(spacing: 4) {
            if !(config.showLangWord && config.showLangVerb) {
                Text("verbe de la\nsemaine")
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showFrenchVerbPopover.toggle() }) {
                Text(verb.verb)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFrenchVerbPopover, arrowEdge: .bottom) {
                frenchVerbPopover(verb, practiceIndex: displayVerbPracticeIndex)
            }

            Button(action: { FrenchVerbService.shared.speak(text: verb.verb) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear pronunciation (French Canadian)")
        }
        .padding(8)
        .frame(width: 84, height: 84)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── French Verb popover ───────────────────────────────────────────────
    private func frenchVerbPopover(_ verb: FrenchVerb, practiceIndex: Int) -> some View {
        let totalVerbs = FrenchVerbService.shared.allVerbs.count
        let totalExercises = verb.practiceQuestions.count
        let practicePhrase = FrenchVerbService.shared.listenPhrase(for: verb, practiceIndex: practiceIndex)
        let isVerbOverridden = verbIndexOverride != nil

        return VStack(alignment: .leading, spacing: 12) {
            // ── Verb navigation ───────────────────────────────────────────
            HStack(spacing: 0) {
                Button(action: prevVerb) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isVerbOverridden
                     ? "\(displayVerbIndex + 1) / \(totalVerbs)"
                     : "verbe de la semaine")
                    .font(.system(size: 9))
                    .foregroundStyle(isVerbOverridden ? config.accentColor.opacity(0.8) : Color(white: 0.4))

                Spacer()

                Button(action: nextVerb) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Verb header ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(verb.verb)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text(verb.meaning)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(verb.verbType)
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor.opacity(0.8))
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Conjugaison présent ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text("CONJUGAISON — présent")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(verb.conjugation.enumerated()), id: \.offset) { _, form in
                        HStack(spacing: 0) {
                            Text(form.label)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 78, alignment: .leading)
                            Text(form.value)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white)
                            Spacer()
                            Button(action: {
                                let subject = form.label.components(separatedBy: " / ").first ?? form.label
                                FrenchVerbService.shared.speak(text: "\(subject) \(form.value)")
                            }) {
                                Image(systemName: "speaker.wave.1.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Hear \(form.label) form")
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Example ───────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("EXEMPLE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    listenButtons(text: verb.example)
                }
                Text(verb.example)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verb.exampleTranslation)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Practice ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 9))
                        .foregroundStyle(config.accentColor)
                    Text("EXERCISE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(action: prevVerbExercise) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Text("\(practiceIndex + 1) / \(totalExercises)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(verbPracticeIndexOverride != nil ? config.accentColor.opacity(0.8) : Color(white: 0.4))
                    Button(action: nextVerbExercise) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    if let phrase = practicePhrase {
                        listenButtons(text: phrase)
                    }
                }
                Text(verb.practiceQuestions[practiceIndex])
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
    }

    // ── French Word of the Week ───────────────────────────────────────────
    private var frenchWordSection: some View {
        let word = displayWord
        return VStack(spacing: 4) {
            Text("mot de la\nsemaine")
                .font(.system(size: 6.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button(action: { showFrenchPopover.toggle() }) {
                Text(word.word)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFrenchPopover, arrowEdge: .bottom) {
                frenchWordPopover(word, practiceIndex: displayPracticeIndex)
            }

            Button(action: { FrenchWordService.shared.speak(text: word.word) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear pronunciation (French Canadian)")
        }
        .padding(8)
        .frame(width: 84, height: 84)
        .background(
            ZStack {
                Circle().fill(.thinMaterial)
                Circle().fill(Color.black.opacity(0.35))
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        )
        .clipShape(Circle())
    }

    // ── Combined Italian language section ────────────────────────────────
    private var italianLangSection: some View {
        let showBoth = config.showLangWord && config.showLangVerb
        let showingVerb = showBoth ? italianPillShowsVerb : config.showLangVerb
        return VStack(spacing: 3) {
            if showBoth {
                HStack(spacing: 0) {
                    Button(action: { italianPillShowsVerb = false }) {
                        Text("parola")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(!italianPillShowsVerb ? config.accentColor : Color(white: 0.45))
                    }
                    .buttonStyle(.plain)
                    Text(" · ")
                        .font(.system(size: 7))
                        .foregroundStyle(Color(white: 0.35))
                    Button(action: { italianPillShowsVerb = true }) {
                        Text("verbo")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(italianPillShowsVerb ? config.accentColor : Color(white: 0.45))
                    }
                    .buttonStyle(.plain)
                }
            }

            if showingVerb {
                italianVerbPill
            } else {
                italianWordPill
            }
        }
    }

    // ── Italian Word pill ────────────────────────────────────────────────
    private var italianWordPill: some View {
        let word = displayItalianWord
        return VStack(spacing: 4) {
            if !(config.showLangWord && config.showLangVerb) {
                Text("parola della\nsettimana")
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showItalianPopover.toggle() }) {
                Text(word.word)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showItalianPopover, arrowEdge: .bottom) {
                italianWordPopover(word, practiceIndex: displayItalianPracticeIndex)
            }

            Button(action: { ItalianWordService.shared.speak(text: word.word) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear pronunciation (Italian)")
        }
        .padding(8)
        .frame(width: 84, height: 84)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── Italian Verb pill ────────────────────────────────────────────────
    private var italianVerbPill: some View {
        let verb = displayItalianVerb
        return VStack(spacing: 4) {
            if !(config.showLangWord && config.showLangVerb) {
                Text("verbo della\nsettimana")
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showItalianVerbPopover.toggle() }) {
                Text(verb.verb)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showItalianVerbPopover, arrowEdge: .bottom) {
                italianVerbPopover(verb, practiceIndex: displayItalianVerbPracticeIndex)
            }

            Button(action: { ItalianVerbService.shared.speak(text: verb.verb) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear pronunciation (Italian)")
        }
        .padding(8)
        .frame(width: 84, height: 84)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.thinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.35))
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── Italian Verb popover ──────────────────────────────────────────────
    private func italianVerbPopover(_ verb: ItalianVerb, practiceIndex: Int) -> some View {
        let totalVerbs = ItalianVerbService.shared.allVerbs.count
        let totalExercises = verb.practiceQuestions.count
        let practicePhrase = ItalianVerbService.shared.listenPhrase(for: verb, practiceIndex: practiceIndex)
        let isVerbOverridden = italianVerbIndexOverride != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Button(action: prevItalianVerb) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isVerbOverridden
                     ? "\(displayItalianVerbIndex + 1) / \(totalVerbs)"
                     : "verbo della settimana")
                    .font(.system(size: 9))
                    .foregroundStyle(isVerbOverridden ? config.accentColor.opacity(0.8) : Color(white: 0.4))

                Spacer()

                Button(action: nextItalianVerb) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(verb.verb)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text(verb.meaning)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(verb.verbType)
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor.opacity(0.8))
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 5) {
                Text("CONIUGAZIONE — presente")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(verb.conjugation.enumerated()), id: \.offset) { _, form in
                        HStack(spacing: 0) {
                            Text(form.label)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 78, alignment: .leading)
                            Text(form.value)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white)
                            Spacer()
                            Button(action: {
                                let subject = form.label.components(separatedBy: " / ").first ?? form.label
                                ItalianVerbService.shared.speak(text: "\(subject) \(form.value)")
                            }) {
                                Image(systemName: "speaker.wave.1.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Hear \(form.label) form")
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("ESEMPIO")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    italianListenButtons(text: verb.example)
                }
                Text(verb.example)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verb.exampleTranslation)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 9))
                        .foregroundStyle(config.accentColor)
                    Text("ESERCIZIO")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(action: prevItalianVerbExercise) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Text("\(practiceIndex + 1) / \(totalExercises)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(italianVerbPracticeIndexOverride != nil ? config.accentColor.opacity(0.8) : Color(white: 0.4))
                    Button(action: nextItalianVerbExercise) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    if let phrase = practicePhrase {
                        italianListenButtons(text: phrase)
                    }
                }
                Text(verb.practiceQuestions[practiceIndex])
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
    }

    // ── Italian Word popover ──────────────────────────────────────────────
    private func italianWordPopover(_ word: ItalianWord, practiceIndex: Int) -> some View {
        let totalWords = ItalianWordService.shared.allWords.count
        let totalExercises = word.practiceQuestions.count
        let resolvedEx = ItalianWordService.shared.resolvedExample(for: word)
        let practicePhrase = ItalianWordService.shared.listenPhrase(for: word, practiceIndex: practiceIndex)
        let isWordOverridden = italianWordIndexOverride != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Button(action: prevItalianWord) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isWordOverridden
                     ? "\(displayItalianWordIndex + 1) / \(totalWords)"
                     : "parola della settimana")
                    .font(.system(size: 9))
                    .foregroundStyle(isWordOverridden ? config.accentColor.opacity(0.8) : Color(white: 0.4))

                Spacer()

                Button(action: nextItalianWord) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                    if let gender = word.gender {
                        Text(gender.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(gender == .masculine ? Color(red: 0.45, green: 0.75, blue: 1.0) : Color(red: 1.0, green: 0.6, blue: 0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(
                                    gender == .masculine
                                        ? Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.18)
                                        : Color(red: 1.0, green: 0.6, blue: 0.75).opacity(0.18)
                                )
                            )
                    } else {
                        Text(word.type)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                if word.gender != nil {
                    Text(word.type)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(word.definition)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            if !word.forms.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FORME")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(word.forms.enumerated()), id: \.offset) { _, form in
                            HStack(spacing: 0) {
                                Text(form.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 78, alignment: .leading)
                                Text(form.value)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white)
                                Spacer()
                                Button(action: { ItalianWordService.shared.speak(text: form.value) }) {
                                    Image(systemName: "speaker.wave.1.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .help("Hear \(form.label)")
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.1))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("ESEMPIO")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    italianListenButtons(text: resolvedEx)
                }
                Text(resolvedEx)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(word.exampleTranslation)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 9))
                        .foregroundStyle(config.accentColor)
                    Text("ESERCIZIO")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button(action: prevItalianExercise) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Text("\(practiceIndex + 1) / \(totalExercises)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(italianPracticeIndexOverride != nil ? config.accentColor.opacity(0.8) : Color(white: 0.4))
                    Button(action: nextItalianExercise) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    if let phrase = practicePhrase {
                        italianListenButtons(text: phrase)
                    }
                }
                Text(word.practiceQuestions[practiceIndex])
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
    }

    private func italianListenButtons(text: String) -> some View {
        HStack(spacing: 8) {
            Button(action: { ItalianWordService.shared.speak(text: text) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear phrase")

            Button(action: { ItalianWordService.shared.speak(text: text, slow: true) }) {
                HStack(spacing: 3) {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: 9))
                    Text("slow")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Hear slowly")
        }
    }

    private func listenButtons(text: String) -> some View {
        HStack(spacing: 8) {
            Button(action: { FrenchWordService.shared.speak(text: text) }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(config.accentColor)
            }
            .buttonStyle(.plain)
            .help("Hear phrase")

            Button(action: { FrenchWordService.shared.speak(text: text, slow: true) }) {
                HStack(spacing: 3) {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: 9))
                    Text("slow")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Hear slowly")
        }
    }

    private func frenchWordPopover(_ word: FrenchWord, practiceIndex: Int) -> some View {
        let totalWords = FrenchWordService.shared.allWords.count
        let totalExercises = word.practiceQuestions.count
        let resolvedEx = FrenchWordService.shared.resolvedExample(for: word)
        let practicePhrase = FrenchWordService.shared.listenPhrase(for: word, practiceIndex: practiceIndex)
        let isWordOverridden = wordIndexOverride != nil

        return VStack(alignment: .leading, spacing: 12) {
            // ── Word navigation ───────────────────────────────────────────
            HStack(spacing: 0) {
                Button(action: prevWord) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isWordOverridden
                     ? "\(displayWordIndex + 1) / \(totalWords)"
                     : "mot de la semaine")
                    .font(.system(size: 9))
                    .foregroundStyle(isWordOverridden ? config.accentColor.opacity(0.8) : Color(white: 0.4))

                Spacer()

                Button(action: nextWord) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Word header ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(word.word)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                    if let gender = word.gender {
                        Text(gender.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(gender == .masculine ? Color(red: 0.45, green: 0.75, blue: 1.0) : Color(red: 1.0, green: 0.6, blue: 0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(
                                    gender == .masculine
                                        ? Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.18)
                                        : Color(red: 1.0, green: 0.6, blue: 0.75).opacity(0.18)
                                )
                            )
                    } else {
                        Text(word.type)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                if word.gender != nil {
                    Text(word.type)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(word.definition)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Forms ─────────────────────────────────────────────────────
            if !word.forms.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FORMES")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(word.forms.enumerated()), id: \.offset) { _, form in
                            HStack(spacing: 0) {
                                Text(form.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 78, alignment: .leading)
                                Text(form.value)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white)
                                Spacer()
                                Button(action: { FrenchWordService.shared.speak(text: form.value) }) {
                                    Image(systemName: "speaker.wave.1.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                                .help("Hear \(form.label)")
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.1))
            }

            // ── Example ───────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("EXEMPLE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    listenButtons(text: resolvedEx)
                }
                Text(resolvedEx)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(word.exampleTranslation)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.1))

            // ── Practice ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 9))
                        .foregroundStyle(config.accentColor)
                    Text("EXERCISE")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    // Exercise navigation
                    Button(action: prevExercise) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Text("\(practiceIndex + 1) / \(totalExercises)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(practiceIndexOverride != nil ? config.accentColor.opacity(0.8) : Color(white: 0.4))
                    Button(action: nextExercise) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    // Listen buttons when a phrase exists for this exercise
                    if let phrase = practicePhrase {
                        listenButtons(text: phrase)
                    }
                }
                Text(word.practiceQuestions[practiceIndex])
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(white: 0.11))
        .preferredColorScheme(.dark)
    }

    // ── Music ─────────────────────────────────────────────────────────────
    @ViewBuilder
    private var musicSection: some View {
        let display = nowPlaying.track ?? nowPlaying.lastTrack
        let isLastPlayed = nowPlaying.track == nil && display != nil

        if let t = display {
            HStack(spacing: 10) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.2))
                    if let img = t.artwork {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundStyle(config.accentColor)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .opacity(isLastPlayed ? 0.55 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    if isLastPlayed {
                        Text("last played")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    Text(t.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isLastPlayed ? Color.secondary : Color.white)
                        .lineLimit(1)
                    Text(t.artist)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    // Playback controls + open Music
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 18) {
                            Button(action: { nowPlaying.previousTrack() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Button(action: { nowPlaying.playPause() }) {
                                Image(systemName: t.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 17))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.white)

                            Button(action: { nowPlaying.nextTrack() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        Button(action: openMusic) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                                .foregroundStyle(config.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Open Music")
                    }
                    .padding(.top, 3)
                }
            }
            .padding(.horizontal, 8)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text("Nothing playing")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    Button(action: { nowPlaying.playPause() }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                    .help("Play")

                    Button(action: openMusic) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13))
                            .foregroundStyle(config.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Open Music")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
    }

}
