//
//  ContentView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI
import Combine
#if canImport(Orb)
import Orb
#endif

enum AssistantState {
    case idle
    case listening
    case thinking
    case responding
}

enum AppMode {
    case orbOnlyLaunch
    case projectFocus
}

struct ContentView: View {
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var flowManager = ConversationFlowManager()
    @StateObject private var memoryStore = MemoryStore()
    @StateObject private var globalContextStore = GlobalContextStore()
    @StateObject private var globalFileStore = GlobalFileStore()
    @StateObject private var globalConversationMemoryStore = GlobalConversationMemoryStore()
    @StateObject private var assistantRuntime = AssistantRuntime()
    @StateObject private var voiceSessionManager = VoiceSessionManager()
    @State private var appMode: AppMode = .orbOnlyLaunch
    @State private var assistantState: AssistantState = .idle
    @State private var prompt = ""
    @State private var currentTurn: AssistantTurn = .landing
    @State private var currentProjectId: UUID?
    @State private var appState = AxiumAppState()

    private let contextBuilder = AssistantContextBuilder()
    private let briefingEngine = AssistantBriefingEngine()
    private let contextRouter = ContextRouter()

    var body: some View {
        ZStack {
            AppBackground()

            Group {
                switch appMode {
                case .orbOnlyLaunch:
                    OrbOnlyLaunchView(
                        assistantState: visibleAssistantState,
                        onWake: wakeAxium
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .projectFocus:
                    ProjectWorkspaceView(
                        projectStore: projectStore,
                        memoryStore: memoryStore,
                        projectId: currentProjectId,
                        initialFocusMode: currentTurn.focusedMode,
                        messages: flowManager.messages,
                        turn: currentTurn,
                        prompt: $prompt,
                        assistantState: visibleAssistantState,
                        onSubmit: handlePromptSubmit,
                        onSuggestionSelected: handleSuggestedReply,
                        onCreateProject: { createBlankProject() },
                        onViewProjects: { Task { await handleUserMessage("Show my projects") } },
                        onOpenProject: openProject,
                        onReturnToLanding: returnToLanding
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }

            if appMode == .projectFocus {
                VStack {
                    HStack {
                        Spacer()
                        VoiceStatusIndicatorView(
                            manager: voiceSessionManager,
                            onToggleMute: { voiceSessionManager.toggleMute() },
                            onStop: { voiceSessionManager.stopSession() },
                            onRestart: { restartVoiceListening() }
                        )
                        .padding(.top, 24)
                        .padding(.trailing, 28)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(80)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.72, dampingFraction: 0.84), value: appMode)
        .animation(.easeInOut(duration: 0.28), value: assistantState)
        .onAppear {
            let storedState = AxiumPersistenceController().load(AxiumAppState.self, from: .appState, fallback: AxiumAppState())
            appState = storedState
            currentProjectId = storedState.selectedProjectId
        }
    }

    private var visibleAssistantState: AssistantState {
        guard voiceSessionManager.isActive || voiceSessionManager.state == .error else {
            return assistantState
        }

        switch voiceSessionManager.state {
        case .inactive, .error:
            return assistantState
        case .requestingPermission, .transcribing, .thinking, .interrupted:
            return .thinking
        case .listening:
            return .listening
        case .speaking:
            return .responding
        }
    }

    private func handlePromptSubmit() {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPrompt.isEmpty == false else { return }
        prompt = ""
        Task { await handleUserMessage(cleanPrompt) }
    }

    private func handleSuggestedReply(_ suggestion: SuggestedReply) {
        Task { await handleUserMessage(suggestion.payload) }
    }

    private func wakeAxium() {
        if let project = projectStore.project(id: currentProjectId) {
            openProject(project)
            startVoiceSessionIfNeeded()
            return
        }

        withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
            appMode = .projectFocus
            assistantState = .idle
        }

        startVoiceSessionIfNeeded()

        // Future wake-word hook: for now, clicking the landing orb explicitly starts voice mode.
    }

    private func startVoiceSessionIfNeeded() {
        guard voiceSessionManager.isActive == false else {
            voiceSessionManager.restartListening(manualActivation: true)
            return
        }

        Task {
            await voiceSessionManager.startSession { transcript in
                Task { await handleVoiceTranscript(transcript) }
            }
        }
    }

    private func restartVoiceListening() {
        if voiceSessionManager.isActive {
            voiceSessionManager.restartListening(manualActivation: true)
            return
        }

        Task {
            await voiceSessionManager.startSession(onFinalTranscript: { transcript in
                Task { await handleVoiceTranscript(transcript) }
            }, manualActivation: true)
        }
    }

    private func handleVoiceTranscript(_ transcript: String) async {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTranscript.isEmpty == false else { return }
        prompt = ""
        await handleUserMessage(cleanTranscript)
    }

    private func handleUserMessage(_ cleanPrompt: String) async {
        if flowManager.isFlowActive {
            handleFlowMessage(cleanPrompt)
            return
        }

        flowManager.appendUserMessage(cleanPrompt)
        globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .user, text: cleanPrompt))
        withAnimation(.easeInOut(duration: 0.22)) {
            appMode = .projectFocus
            assistantState = .thinking
        }

        let result = await assistantRuntime.handleUserInput(cleanPrompt, context: assistantContext())
        observeUserMemoryIfNeeded(cleanPrompt, decision: result.decision)
        applyRuntimeResult(result)
    }

    private func applyRuntimeResult(_ result: AssistantRuntimeResult) {
        applyAssistantState(for: result.decision)

        switch result.action {
        case .routeAIIntent(let aiResult):
            routeAIIntent(aiResult, userMessage: result.userMessage)
        case .routeDeterministicIntent(let intent, let fallbackNotice):
            routeDeterministicIntent(result.userMessage, intent: intent, fallbackNotice: fallbackNotice)
        case .saveMemory(let decision):
            handleMemoryDecision(result.userMessage, response: result.assistantResponse ?? decision.assistantResponse, decision: decision)
        case .showConversationReply(let response), .showConversationError(let response):
            flowManager.appendAssistantMessage(response)
            globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .assistant, text: response))
            showChatTurn(userMessage: result.userMessage, response: response)
        }
    }

    private func handleMemoryDecision(_ userMessage: String, response: String, decision: AssistantDecision) {
        switch decision.extractedContext["memoryType"] {
        case "preferredName":
            if let name = decision.extractedContext["preferredName"] {
                globalConversationMemoryStore.rememberPreferredName(name, sourceMessage: userMessage)
            }
        case "preference":
            if let preference = decision.extractedContext["preference"] {
                globalConversationMemoryStore.rememberPreference(preference, sourceMessage: userMessage)
            }
        default:
            globalConversationMemoryStore.observeUserMessage(
                userMessage,
                activeProjectName: projectStore.project(id: currentProjectId)?.name,
                availableProjectNames: projectStore.listProjects().map(\.name)
            )
        }

        flowManager.appendAssistantMessage(response)
        globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .assistant, text: response))
        updateTurn(
            userMessage: userMessage,
            intent: AssistantIntent(kind: .focusConversation, confidence: decision.confidence),
            response: response,
            modules: [],
            focusedProject: nil,
            focusedProjectId: currentProjectId,
            suggestions: []
        )
    }

    private func observeUserMemoryIfNeeded(_ message: String, decision: AssistantDecision) {
        guard decision.shouldSaveMemory else { return }

        globalConversationMemoryStore.observeUserMessage(
            message,
            activeProjectName: projectStore.project(id: currentProjectId)?.name,
            availableProjectNames: projectStore.listProjects().map(\.name)
        )
    }

    private func applyAssistantState(for decision: AssistantDecision) {
        // This is the first architecture hook for multi-speed orb behavior.
        // Later the orb can map .deep and .cloudRequired to longer progress states.
        withAnimation(.easeInOut(duration: 0.18)) {
            switch decision.reasoningLevel {
            case .instant:
                assistantState = .responding
            case .lightweight, .contextual, .deep, .cloudRequired:
                assistantState = .thinking
            }
        }
    }

    // TODO: Move these app-effect handlers into focused action executors once the runtime
    // owns project/global mutations directly. ContentView applies them for now because they
    // update SwiftUI state, stores, and module turns in one place.
    private func showChatTurn(userMessage: String, response: String) {
        let activeProject = projectStore.project(id: currentProjectId)
        updateTurn(
            userMessage: userMessage,
            intent: AssistantIntent(kind: .focusConversation, confidence: 0.95),
            response: response,
            modules: activeProject == nil ? [DynamicModule(kind: .briefing, message: response)] : [DynamicModule(kind: .projectWorkspace)],
            focusedProject: activeProject,
            focusedProjectId: activeProject?.id,
            suggestions: []
        )
    }

    private func routeAIIntent(_ result: AIIntentResult, userMessage: String) {
        let intent = AssistantIntent(kind: result.assistantIntentKind, confidence: result.confidence)
        trackRelevantMemories(for: userMessage, intent: intent)

        if result.shouldUseCloudAPI {
            showPlaceholderTurn(
                userMessage: userMessage,
                intent: intent,
                response: "This needs cloud reasoning."
            )
            return
        }

        if result.confidence < 0.62 || result.intent == .unknown {
            let response = result.assistantResponse.isEmpty
                ? "I need one more detail before I route that. Which project or module should this affect?"
                : result.assistantResponse
            showPlaceholderTurn(
                userMessage: userMessage,
                intent: AssistantIntent(kind: .unknown, confidence: result.confidence),
                response: response
            )
            return
        }

        switch result.intent {
        case .createProject:
            createProjectFromAI(result, userMessage: userMessage)
        case .openProject:
            if let project = targetProject(from: result, prompt: userMessage) {
                openProject(project)
            } else {
                routeIntentResult(intent, prompt: userMessage, responseOverride: result.assistantResponse)
            }
        case .addNote:
            saveNoteFromAI(result, userMessage: userMessage)
        case .addTask:
            saveTaskFromAI(result, userMessage: userMessage)
        case .saveToProject:
            saveConversationFromAI(result, userMessage: userMessage)
        case .addReminder:
            saveReminderFromAI(result, userMessage: userMessage)
        case .addCalendarItem:
            saveCalendarItemFromAI(result, userMessage: userMessage)
        case .rememberUserInfo, .updateUserProfile, .savePreference:
            saveMemoryFromAI(result, userMessage: userMessage)
        case .greeting, .viewProjects, .showNotes, .showTasks, .showMetrics, .showFiles, .showActivity, .showIntegrations:
            routeIntentResult(intent, prompt: userMessage, responseOverride: result.assistantResponse)
        case .unknown:
            showPlaceholderTurn(
                userMessage: userMessage,
                intent: intent,
                response: "I need one more detail before I route that."
            )
        }
    }

    private func saveMemoryFromAI(_ result: AIIntentResult, userMessage: String) {
        let response = result.assistantResponse.isEmpty
            ? "Got it. I’ll keep that as reviewable local context."
            : result.assistantResponse
        handleMemoryDecision(
            userMessage,
            response: response,
            decision: AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .saveMemory,
                selectedTool: "AIIntentInterpreter",
                confidence: result.confidence,
                shouldSaveMemory: true,
                suggestedModules: ["memory"],
                assistantResponse: response,
                extractedContext: ["memoryType": "general"]
            )
        )
    }

    private func routeDeterministicIntent(_ cleanPrompt: String, intent: AssistantIntent, fallbackNotice: String? = nil) {
        trackRelevantMemories(for: cleanPrompt, intent: intent)

        if handleGlobalContextRoute(contextRouter.route(cleanPrompt, currentProjectId: currentProjectId, projectStore: projectStore), prompt: cleanPrompt, intent: intent, fallbackNotice: fallbackNotice) {
            return
        }

        if intent.id == .createProject {
            createBlankProject(responsePrefix: fallbackNotice)
            return
        }

        routeIntentResult(intent, prompt: cleanPrompt, responsePrefix: fallbackNotice)
    }

    private func routeIntentResult(_ intent: AssistantIntent, prompt: String, responseOverride: String? = nil, responsePrefix: String? = nil) {
        let focusedProject = focusedProject(for: intent, prompt: prompt)
        if intent.id == .openProject, let focusedProject {
            openProject(focusedProject)
            return
        }

        let baseResponse = responseOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? responseOverride!
            : briefingEngine.response(for: intent, projectStore: projectStore, globalContextStore: globalContextStore)
        let response = [responsePrefix, baseResponse]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        let suggestions = suggestions(for: intent)
        let modules = modules(for: intent, focusedProject: focusedProject)
        let contextualProjectId = focusedProject?.id ?? contextualProjectId(for: intent, prompt: prompt)

        flowManager.appendAssistantMessage(response, suggestions: suggestions)
        updateTurn(
            userMessage: prompt,
            intent: intent,
            response: response,
            modules: modules,
            focusedProject: focusedProject,
            focusedProjectId: contextualProjectId,
            suggestions: suggestions
        )
    }

    private func showPlaceholderTurn(userMessage: String, intent: AssistantIntent, response: String) {
        let activeProject = projectStore.project(id: currentProjectId)
        flowManager.appendAssistantMessage(response, suggestions: suggestions(for: .init(kind: .unknown, confidence: intent.confidence)))
        updateTurn(
            userMessage: userMessage,
            intent: intent,
            response: response,
            modules: [DynamicModule(kind: .clarification, message: response)],
            focusedProject: activeProject,
            focusedProjectId: activeProject?.id,
            suggestions: suggestions(for: .init(kind: .unknown, confidence: intent.confidence))
        )
    }

    private func trackRelevantMemories(for message: String, intent: AssistantIntent) {
        let relevantMemories = memoryStore.retrieveRelevantMemories(
            for: MemoryRetrievalContext(userMessage: message, projectId: currentProjectId, intent: intent.id)
        )
        relevantMemories.forEach { memoryStore.trackUsage(memoryId: $0.id) }
    }

    private func createProjectFromAI(_ result: AIIntentResult, userMessage: String) {
        let name = cleanedAIValue(result.projectName) ?? cleanedAIValue(result.extractedTitle)
        guard let name else {
            createBlankProject()
            return
        }

        flowManager.reset()
        let project = projectStore.createProject(
            name: name,
            description: cleanedAIValue(result.extractedDetails) ?? "",
            currentObjective: cleanedAIValue(result.extractedDetails) ?? ""
        )
        let response = result.assistantResponse.isEmpty ? "Created \(project.name)." : result.assistantResponse
        flowManager.appendAssistantMessage(response)
        globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .assistant, text: response))
        updateTurn(
            userMessage: userMessage,
            intent: AssistantIntent(kind: .createProject, confidence: result.confidence),
            response: response,
            modules: [DynamicModule(kind: .projectWorkspace)],
            focusedProject: project,
            focusedProjectId: project.id,
            suggestions: suggestions(for: AssistantIntent(kind: .openProject))
        )
    }

    private func saveNoteFromAI(_ result: AIIntentResult, userMessage: String) {
        let title = cleanedAIValue(result.extractedTitle) ?? titleCandidate(from: userMessage)
        let details = cleanedAIValue(result.extractedDetails) ?? userMessage
        let intent = AssistantIntent(kind: .addNote, confidence: result.confidence)

        if let project = targetProject(from: result, prompt: userMessage) {
            projectStore.addNote(title: title, body: details, to: project.id, source: "Axium local interpreter")
            let updatedProject = projectStore.project(id: project.id) ?? project
            let response = result.assistantResponse.isEmpty ? "Saved that note to \(updatedProject.name)." : result.assistantResponse
            flowManager.appendAssistantMessage(response, suggestions: suggestions(for: intent))
            updateTurn(
                userMessage: userMessage,
                intent: intent,
                response: response,
                modules: [DynamicModule(kind: .projectWorkspace)],
                focusedProject: updatedProject,
                focusedProjectId: updatedProject.id,
                suggestions: suggestions(for: intent)
            )
            return
        }

        globalContextStore.addNote(title: title, body: details, source: "Axium local interpreter")
        let response = result.assistantResponse.isEmpty ? "Saved that as a global note." : result.assistantResponse
        respondToGlobalCapture(userMessage: userMessage, response: response, intent: intent)
    }

    private func saveTaskFromAI(_ result: AIIntentResult, userMessage: String) {
        let title = cleanedAIValue(result.extractedTitle) ?? titleCandidate(from: userMessage)
        let details = cleanedAIValue(result.extractedDetails) ?? userMessage
        let intent = AssistantIntent(kind: .addTask, confidence: result.confidence)

        if let project = targetProject(from: result, prompt: userMessage) {
            projectStore.addTask(title: title, details: details, to: project.id)
            let updatedProject = projectStore.project(id: project.id) ?? project
            let response = result.assistantResponse.isEmpty ? "Added that task to \(updatedProject.name)." : result.assistantResponse
            flowManager.appendAssistantMessage(response, suggestions: suggestions(for: intent))
            updateTurn(
                userMessage: userMessage,
                intent: intent,
                response: response,
                modules: [DynamicModule(kind: .projectWorkspace)],
                focusedProject: updatedProject,
                focusedProjectId: updatedProject.id,
                suggestions: suggestions(for: intent)
            )
            return
        }

        globalContextStore.addTask(title: title, details: details)
        let response = result.assistantResponse.isEmpty ? "Saved that as a global task." : result.assistantResponse
        respondToGlobalCapture(userMessage: userMessage, response: response, intent: intent)
    }

    private func saveConversationFromAI(_ result: AIIntentResult, userMessage: String) {
        if let project = targetProject(from: result, prompt: userMessage) {
            globalContextStore.saveCurrentSessionToExistingProject(projectId: project.id, projectStore: projectStore)
            let updatedProject = projectStore.project(id: project.id) ?? project
            let response = result.assistantResponse.isEmpty ? "Saved the current thread to \(updatedProject.name)." : result.assistantResponse
            flowManager.appendAssistantMessage(response)
            updateTurn(
                userMessage: userMessage,
                intent: AssistantIntent(kind: .addNote, confidence: result.confidence),
                response: response,
                modules: [DynamicModule(kind: .projectWorkspace)],
                focusedProject: updatedProject,
                focusedProjectId: updatedProject.id,
                suggestions: []
            )
            return
        }

        guard let name = cleanedAIValue(result.projectName) ?? cleanedAIValue(result.extractedTitle) else {
            showPlaceholderTurn(
                userMessage: userMessage,
                intent: AssistantIntent(kind: .unknown, confidence: result.confidence),
                response: "Which project should I save this to?"
            )
            return
        }

        let project = globalContextStore.saveCurrentSessionToNewProject(name: name, projectStore: projectStore)
        let response = result.assistantResponse.isEmpty ? "Saved the current thread into \(project.name)." : result.assistantResponse
        flowManager.appendAssistantMessage(response)
        updateTurn(
            userMessage: userMessage,
            intent: AssistantIntent(kind: .createProject, confidence: result.confidence),
            response: response,
            modules: [DynamicModule(kind: .projectWorkspace)],
            focusedProject: project,
            focusedProjectId: project.id,
            suggestions: []
        )
    }

    private func saveReminderFromAI(_ result: AIIntentResult, userMessage: String) {
        let title = cleanedAIValue(result.extractedTitle) ?? titleCandidate(from: userMessage)
        let details = cleanedAIValue(result.extractedDetails) ?? userMessage
        globalContextStore.addReminder(title: title, details: details, source: "Axium local interpreter")
        let response = result.assistantResponse.isEmpty ? "Saved that as a global reminder." : result.assistantResponse
        respondToGlobalCapture(userMessage: userMessage, response: response, intent: AssistantIntent(kind: .unknown, confidence: result.confidence))
    }

    private func saveCalendarItemFromAI(_ result: AIIntentResult, userMessage: String) {
        let title = cleanedAIValue(result.extractedTitle) ?? titleCandidate(from: userMessage)
        let details = cleanedAIValue(result.extractedDetails) ?? userMessage
        let startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        globalContextStore.addCalendarItem(title: title, details: details, startDate: startDate, source: "Axium local interpreter")
        let response = result.assistantResponse.isEmpty ? "Saved that as a calendar candidate." : result.assistantResponse
        respondToGlobalCapture(userMessage: userMessage, response: response, intent: AssistantIntent(kind: .unknown, confidence: result.confidence))
    }

    private func targetProject(from result: AIIntentResult, prompt: String) -> Project? {
        if result.target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "global" {
            return nil
        }

        if let projectName = cleanedAIValue(result.projectName),
           let project = projectStore.findProject(named: projectName) ?? projectStore.findProject(in: projectName) {
            return project
        }

        if let target = cleanedAIValue(result.target),
           target.lowercased() != "currentproject",
           target.lowercased() != "project",
           target.lowercased() != "unknown",
           let project = projectStore.findProject(named: target) ?? projectStore.findProject(in: target) {
            return project
        }

        if let project = projectStore.findProject(in: prompt) {
            return project
        }

        return projectStore.project(id: currentProjectId) ?? (projectStore.listProjects().count == 1 ? projectStore.listProjects().first : nil)
    }

    private func cleanedAIValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty == false, trimmed.lowercased() != "null" else { return nil }
        return trimmed
    }

    private func assistantContext() -> AIIntentContext {
        contextBuilder.build(
            projectStore: projectStore,
            globalContextStore: globalContextStore,
            globalConversationMemoryStore: globalConversationMemoryStore,
            currentProjectId: currentProjectId,
            currentTurn: currentTurn,
            appState: appState
        )
    }

    private func createBlankProject(responsePrefix: String? = nil) {
        flowManager.reset()
        let project = projectStore.createProject(
            name: "Untitled Project",
            description: "",
            category: "",
            currentObjective: "",
            priority: .medium
        )
        let message = [responsePrefix, "New project created. Tell me what this is, add notes, or start with a task."]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        flowManager.appendAssistantMessage(message)
        globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .assistant, text: message))
        updateTurn(
            userMessage: "Create project",
            intent: AssistantIntent(kind: .createProject, confidence: 1),
            response: message,
            modules: [DynamicModule(kind: .projectWorkspace)],
            focusedProject: project,
            focusedProjectId: project.id,
            suggestions: []
        )
    }

    private func handleFlowMessage(_ cleanPrompt: String) {
        if cleanPrompt.lowercased() == "cancel" {
            flowManager.cancel()
            updateTurn(
                userMessage: cleanPrompt,
                intent: AssistantIntent(kind: .unknown, confidence: 1),
                response: "No problem. I cancelled that flow.",
                modules: [DynamicModule(kind: .briefing, message: briefingEngine.briefing(for: projectStore, globalContextStore: globalContextStore))],
                focusedProject: nil,
                focusedProjectId: nil,
                suggestions: flowManager.latestSuggestions
            )
            return
        }

        if cleanPrompt.lowercased() == "back" {
            if let result = flowManager.goBack() {
                updateTurn(
                    userMessage: cleanPrompt,
                    intent: AssistantIntent(kind: .createProject, confidence: 1),
                    response: result.assistantMessage,
                    modules: result.modules,
                    focusedProject: nil,
                    focusedProjectId: nil,
                    suggestions: result.suggestions
                )
            }
            return
        }

        guard let result = flowManager.handleUserMessage(cleanPrompt, projectStore: projectStore) else { return }
        updateTurn(
            userMessage: cleanPrompt,
            intent: AssistantIntent(kind: .createProject, confidence: 1),
            response: result.assistantMessage,
            modules: result.modules,
            focusedProject: result.createdProject,
            focusedProjectId: result.focusedProjectId,
            suggestions: result.suggestions
        )
    }

    private func updateTurn(
        userMessage: String,
        intent: AssistantIntent,
        response: String,
        modules: [DynamicModule],
        focusedProject: Project?,
        focusedProjectId: UUID? = nil,
        suggestions: [SuggestedReply]
    ) {
        let resolvedProjectId = focusedProjectId ?? focusedProject?.id
        let turn = AssistantTurn(
            userMessage: userMessage,
            intent: intent,
            response: response,
            modules: modules,
            focusedProject: focusedProject,
            focusedProjectId: resolvedProjectId,
            suggestions: suggestions
        )

        withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
            currentTurn = turn
            if let resolvedProjectId {
                currentProjectId = resolvedProjectId
            }
            appMode = .projectFocus
            assistantState = .responding
        }
        persistAppState(selectedProjectId: resolvedProjectId, focusMode: turn.focusedMode)
        globalConversationMemoryStore.observeAssistantMessage(response)
        voiceSessionManager.speak(response)

        // Runtime decides command vs chat. ContentView still applies module/project UI effects.
    }

    private func returnToLanding() {
        prompt = ""
        currentTurn = .landing
        currentProjectId = nil
        flowManager.reset()

        withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
            appMode = .projectFocus
            assistantState = .idle
        }
        persistAppState(selectedProjectId: nil, focusMode: .conversation)
    }

    private func persistAppState(selectedProjectId: UUID?, focusMode: FocusedWorkspaceMode) {
        appState.selectedProjectId = selectedProjectId
        appState.launchMode = .projectFocus
        appState.activeFocusMode = focusMode
        appState.lastOpenedAt = Date()
        if let selectedProjectId {
            appState.recentProjectIds.removeAll { $0 == selectedProjectId }
            appState.recentProjectIds.insert(selectedProjectId, at: 0)
            appState.recentProjectIds = Array(appState.recentProjectIds.prefix(12))
        }
        AxiumPersistenceController().save(appState, to: .appState)
    }

    private func handleGlobalContextRoute(_ result: ContextRoutingResult, prompt: String, intent: AssistantIntent, fallbackNotice: String? = nil) -> Bool {
        let hasActiveProject = currentProjectId != nil
        let cleanTitle = titleCandidate(from: prompt)
        func response(_ message: String) -> String {
            [fallbackNotice, message]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
                .joined(separator: " ")
        }

        switch result.destination {
        case .globalReminder:
            globalContextStore.addReminder(title: cleanTitle, details: prompt, source: "Axium command")
            respondToGlobalCapture(
                userMessage: prompt,
                response: response("Got it. I saved that as a global reminder placeholder. Dates will stay local until calendar intelligence is connected."),
                intent: intent
            )
            return true

        case .globalCalendarItem:
            let startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            globalContextStore.addCalendarItem(title: cleanTitle, details: prompt, startDate: startDate, source: "Axium command")
            respondToGlobalCapture(
                userMessage: prompt,
                response: response("I saved that in global context as a calendar candidate. Later, Axium can resolve the exact date and sync it when integrations are connected."),
                intent: intent
            )
            return true

        case .globalMemory:
            let memory = memoryStore.savePreferenceMemory(prompt, category: "global_preference", tags: ["global"])
            globalContextStore.addMemory(memory)
            respondToGlobalCapture(
                userMessage: prompt,
                response: response("Remembered. This is stored as reviewable global memory, not hidden model training."),
                intent: intent
            )
            return true

        case .globalTask where hasActiveProject == false && intent.id == .addTask:
            globalContextStore.addTask(title: cleanTitle, details: prompt)
            respondToGlobalCapture(
                userMessage: prompt,
                response: response("Saved as a global task. You can attach it to a project later."),
                intent: intent
            )
            return true

        case .globalNote where hasActiveProject == false && intent.id == .addNote:
            globalContextStore.addNote(title: cleanTitle, body: prompt, source: "Axium command")
            respondToGlobalCapture(
                userMessage: prompt,
                response: response("Saved as a global note. It can become project context whenever you want."),
                intent: intent
            )
            return true

        case .newProject where prompt.localizedCaseInsensitiveContains("save this"):
            let projectName = extractedProjectName(from: prompt) ?? "Untitled Project"
            let project = globalContextStore.saveCurrentSessionToNewProject(name: projectName, projectStore: projectStore)
            let responseText = response("I saved the current thread into \(project.name) and opened it.")
            flowManager.appendAssistantMessage(responseText)
            globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .assistant, text: responseText))
            updateTurn(
                userMessage: prompt,
                intent: AssistantIntent(kind: .createProject, confidence: 0.82),
                response: responseText,
                modules: [DynamicModule(kind: .projectWorkspace)],
                focusedProject: project,
                focusedProjectId: project.id,
                suggestions: []
            )
            return true

        default:
            return false
        }
    }

    private func respondToGlobalCapture(userMessage: String, response: String, intent: AssistantIntent) {
        let activeProject = projectStore.project(id: currentProjectId)
        flowManager.appendAssistantMessage(response)
        globalContextStore.updateWorkingContext(with: ConversationMessage(speaker: .assistant, text: response))
        updateTurn(
            userMessage: userMessage,
            intent: intent,
            response: response,
            modules: activeProject == nil ? [DynamicModule(kind: .briefing, message: response)] : [DynamicModule(kind: .projectWorkspace)],
            focusedProject: activeProject,
            focusedProjectId: activeProject?.id,
            suggestions: []
        )
    }

    private func titleCandidate(from prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 56 else { return trimmed.isEmpty ? "Untitled" : trimmed }
        return String(trimmed.prefix(56)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractedProjectName(from prompt: String) -> String? {
        let markers = ["called ", "named ", "as "]
        let lowercased = prompt.lowercased()
        for marker in markers {
            guard let range = lowercased.range(of: marker) else { continue }
            let suffix = prompt[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if suffix.isEmpty == false {
                return suffix
            }
        }
        return nil
    }

    private func focusedProject(for intent: AssistantIntent, prompt: String) -> Project? {
        if let mentionedProject = projectStore.findProject(in: prompt) {
            return mentionedProject
        }

        guard intent.id == .openProject else { return nil }

        let trimmed = prompt
            .replacingOccurrences(of: "open project", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "show project", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "pull up project", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else { return nil }
        return projectStore.findProject(named: trimmed)
    }

    private func openProject(_ project: Project) {
        let openedProject = projectStore.openProject(id: project.id) ?? project
        let message = "Opening \(openedProject.name). Here is the current workspace."
        flowManager.appendAssistantMessage(message, suggestions: suggestions(for: AssistantIntent(kind: .openProject)))
        updateTurn(
            userMessage: "Open \(openedProject.name)",
            intent: AssistantIntent(kind: .openProject, confidence: 0.98),
            response: message,
            modules: [DynamicModule(kind: .projectWorkspace)],
            focusedProject: openedProject,
            focusedProjectId: openedProject.id,
            suggestions: suggestions(for: AssistantIntent(kind: .openProject))
        )
    }

    private func contextualProjectId(for intent: AssistantIntent, prompt: String) -> UUID? {
        if let mentionedProject = projectStore.findProject(in: prompt) {
            return mentionedProject.id
        }

        switch intent.id {
        case .focusConversation, .viewNotes, .addNote, .addTask, .editProject, .viewMetrics, .viewActivity, .viewTasks, .viewFiles, .connectIntegration:
            return currentProjectId ?? projectStore.listProjects().first?.id
        default:
            return nil
        }
    }

    private func modules(for intent: AssistantIntent, focusedProject: Project?) -> [DynamicModule] {
        switch intent.id {
        case .greeting:
            return [DynamicModule(kind: .briefing, message: briefingEngine.briefing(for: projectStore, globalContextStore: globalContextStore))]
        case .createProject:
            return [DynamicModule(kind: .projectCreation), DynamicModule(kind: .assistantSuggestions)]
        case .viewProjects:
            return [DynamicModule(kind: .projectLibrary)]
        case .openProject:
            if focusedProject != nil {
                return [
                    DynamicModule(kind: .projectWorkspace)
                ]
            }
            return [
                DynamicModule(kind: .emptyState, title: "Project not found.", message: "I could not match that name or alias to a local project."),
                DynamicModule(kind: .projectLibrary)
            ]
        case .focusConversation:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .briefing, message: briefingEngine.briefing(for: projectStore, globalContextStore: globalContextStore))]
        case .summarizePriorities:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .priorities)]
        case .viewNotes:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .emptyState, title: "Choose a project first.", message: "Notes need a real project target before Axium shows them."), DynamicModule(kind: .projectLibrary)]
        case .viewTasks:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .tasks)]
        case .viewMetrics:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .metrics)]
        case .viewActivity:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .activityTimeline)]
        case .viewFiles:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .files)]
        case .addNote:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .emptyState, title: "Choose a project first.", message: "Notes need a real project target before Axium stores them."), DynamicModule(kind: .projectLibrary)]
        case .addTask:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace)]
            }
            return [DynamicModule(kind: .emptyState, title: "Choose a project first.", message: "Tasks need a real project target before Axium stores them."), DynamicModule(kind: .projectLibrary)]
        case .editProject:
            if focusedProject != nil || currentProjectId != nil || projectStore.projects.count == 1 {
                return [DynamicModule(kind: .projectWorkspace), DynamicModule(kind: .projectEdit)]
            }
            return [DynamicModule(kind: .emptyState, title: "Choose a project first.", message: "Tell me which project to edit."), DynamicModule(kind: .projectLibrary)]
        case .createFile:
            return [
                DynamicModule(kind: .emptyState, title: "File creation is staged.", message: "Axium will ask for filename, location, and confirmation before writing files."),
                DynamicModule(kind: .files)
            ]
        case .generatePDF:
            return [DynamicModule(kind: .emptyState, title: "No document data yet.", message: "PDF generation will use real notes, files, or reports after they exist.")]
        case .generateMindMap:
            return [DynamicModule(kind: .emptyState, title: "No mind map source yet.", message: "Mind maps will be generated from real project notes and structure.")]
        case .connectIntegration:
            return [DynamicModule(kind: .integrations)]
        case .unknown:
            return [DynamicModule(kind: .clarification)]
        }
    }

    private func suggestions(for intent: AssistantIntent) -> [SuggestedReply] {
        switch intent.id {
        case .greeting:
            if projectStore.projects.isEmpty {
                return [
                    SuggestedReply("Create project"),
                    SuggestedReply("Show projects")
                ]
            }

            return [
                SuggestedReply("What needs work?"),
                SuggestedReply("Show projects"),
                SuggestedReply("Show activity")
            ]
        case .viewProjects:
            return [
                SuggestedReply("Create project"),
                SuggestedReply("What needs work?")
            ]
        case .summarizePriorities:
            return [
                SuggestedReply("Show tasks"),
                SuggestedReply("Create project")
            ]
        case .viewMetrics:
            return [
                SuggestedReply("Connect Stripe later"),
                SuggestedReply("Show projects")
            ]
        case .viewActivity:
            return [
                SuggestedReply("Show projects"),
                SuggestedReply("Add notes")
            ]
        case .openProject:
            return [
                SuggestedReply("Add note"),
                SuggestedReply("Add task"),
                SuggestedReply("Show notes"),
                SuggestedReply("Show tasks"),
                SuggestedReply("Open files"),
                SuggestedReply("Show activity")
            ]
        case .focusConversation:
            return [
                SuggestedReply("Show notes"),
                SuggestedReply("Show tasks"),
                SuggestedReply("What needs work?")
            ]
        case .viewNotes:
            return [
                SuggestedReply("Add note"),
                SuggestedReply("Show tasks"),
                SuggestedReply("Back to conversation")
            ]
        case .addNote:
            return [
                SuggestedReply("Add task"),
                SuggestedReply("Show activity"),
                SuggestedReply("Back to conversation")
            ]
        case .addTask:
            return [
                SuggestedReply("What needs work?"),
                SuggestedReply("Add note"),
                SuggestedReply("Back to conversation")
            ]
        case .editProject:
            return [
                SuggestedReply("Add note"),
                SuggestedReply("Show projects")
            ]
        case .viewFiles:
            return [
                SuggestedReply("Show activity"),
                SuggestedReply("Show notes"),
                SuggestedReply("Back to conversation")
            ]
        case .unknown:
            return [
                SuggestedReply("Create project"),
                SuggestedReply("Show projects"),
                SuggestedReply("What needs work?")
            ]
        default:
            return []
        }
    }
}

struct OrbOnlyLaunchView: View {
    let assistantState: AssistantState
    let onWake: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RadialGradient(
                    colors: [
                        AxiomColor.accent.opacity(0.15),
                        AxiomColor.background.opacity(0.12),
                        .clear
                    ],
                    center: .center,
                    startRadius: 70,
                    endRadius: 520
                )

                Button(action: onWake) {
                    OrbContainerView(
                        size: min(max(min(proxy.size.width, proxy.size.height) * 0.36, 260), 360),
                        assistantState: assistantState
                    )
                    .opacity(0.94)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Wake Axium")
                .help("Wake Axium")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OrbContainerView: View {
    let size: CGFloat
    var assistantState: AssistantState = .idle
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AxiomColor.background.opacity(0.94))
                .overlay(
                    Circle()
                        .stroke(AxiomColor.accent.opacity(0.16), lineWidth: 1.2)
                )

            orbSurface
                .frame(width: size * 0.88, height: size * 0.88)
                .scaleEffect(orbScale + (isBreathing ? pulseAmplitude : -pulseAmplitude))
                .animation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true), value: isBreathing)
        }
        .frame(width: size, height: size)
        .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius, x: 0, y: 18)
        .accessibilityLabel("Axium assistant orb")
        .onAppear {
            isBreathing = true
        }

        // Future third-party orb UI package integration:
        // Voice, microphone, and model activity should map into AssistantState here so the rest
        // of the app does not depend on the orb package's rendering or animation details.
    }

    @ViewBuilder
    private var orbSurface: some View {
        #if canImport(Orb)
        OrbView(configuration: configuration)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        #else
        fallbackOrb
        #endif
    }

    #if canImport(Orb)
    private var configuration: OrbConfiguration {
        OrbConfiguration(
            backgroundColors: backgroundColors,
            glowColor: glowColor,
            coreGlowIntensity: coreGlowIntensity,
            showBackground: true,
            showWavyBlobs: true,
            showParticles: showParticles,
            showGlowEffects: true,
            showShadow: false,
            speed: animationSpeed
        )
    }
    #endif

    private var fallbackOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: backgroundColors,
                        center: .center,
                        startRadius: 12,
                        endRadius: size * 0.42
                    )
                )

            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 12)
                .padding(18)

            Circle()
                .fill(glowColor.opacity(0.16))
                .frame(width: size * 0.28, height: size * 0.28)
                .blur(radius: 18)
        }
    }

    private var backgroundColors: [Color] {
        switch assistantState {
        case .idle:
            return [
                Color(red: 0.045, green: 0.050, blue: 0.058),
                Color(red: 0.12, green: 0.26, blue: 0.48),
                Color(red: 0.20, green: 0.52, blue: 0.72)
            ]
        case .listening:
            return [
                Color(red: 0.045, green: 0.052, blue: 0.064),
                Color(red: 0.10, green: 0.34, blue: 0.55),
                Color(red: 0.30, green: 0.74, blue: 0.82)
            ]
        case .thinking:
            return [
                Color(red: 0.04, green: 0.05, blue: 0.07),
                Color(red: 0.12, green: 0.32, blue: 0.62),
                Color(red: 0.26, green: 0.66, blue: 0.82)
            ]
        case .responding:
            return [
                Color(red: 0.05, green: 0.06, blue: 0.08),
                Color(red: 0.16, green: 0.42, blue: 0.78),
                Color(red: 0.34, green: 0.80, blue: 0.92)
            ]
        }
    }

    private var glowColor: Color {
        switch assistantState {
        case .idle:
            return Color(red: 0.24, green: 0.55, blue: 0.95)
        case .listening:
            return Color(red: 0.36, green: 0.78, blue: 0.94)
        case .thinking:
            return Color(red: 0.30, green: 0.66, blue: 1.0)
        case .responding:
            return Color(red: 0.42, green: 0.86, blue: 1.0)
        }
    }

    private var animationSpeed: Double {
        switch assistantState {
        case .idle:
            return 16
        case .listening:
            return 20
        case .thinking:
            return 26
        case .responding:
            return 34
        }
    }

    private var coreGlowIntensity: Double {
        switch assistantState {
        case .idle:
            return 0.62
        case .listening:
            return 0.72
        case .thinking:
            return 0.84
        case .responding:
            return 1.0
        }
    }

    private var showParticles: Bool {
        assistantState == .responding
    }

    private var glowOpacity: Double {
        switch assistantState {
        case .idle:
            return 0.20
        case .listening:
            return 0.24
        case .thinking:
            return 0.30
        case .responding:
            return 0.38
        }
    }

    private var glowRadius: CGFloat {
        switch assistantState {
        case .idle:
            return 44
        case .listening:
            return 50
        case .thinking:
            return 58
        case .responding:
            return 68
        }
    }

    private var orbScale: CGFloat {
        switch assistantState {
        case .idle:
            return 0.985
        case .listening:
            return 1.0
        case .thinking:
            return 1.012
        case .responding:
            return 1.022
        }
    }

    private var animationDuration: Double {
        switch assistantState {
        case .idle:
            return 4.8
        case .listening:
            return 4.0
        case .thinking:
            return 3.3
        case .responding:
            return 2.7
        }
    }

    private var pulseAmplitude: CGFloat {
        switch assistantState {
        case .idle:
            return 0.006
        case .listening:
            return 0.008
        case .thinking:
            return 0.012
        case .responding:
            return 0.016
        }
    }
}

struct CommandInputView: View {
    @Binding var prompt: String
    let assistantState: AssistantState
    let placeholder: String
    let compact: Bool
    var leadingSystemImage: String? = nil
    var leadingHelp: String = "Menu"
    var leadingMenu: (() -> ProjectSwitcherPopoverView)?
    let onSubmit: () -> Void

    @State private var isShowingLeadingMenu = false

    var body: some View {
        HStack(spacing: 12) {
            if let leadingSystemImage, let leadingMenu {
                Button {
                    isShowingLeadingMenu.toggle()
                } label: {
                    Image(systemName: leadingSystemImage)
                        .font(.system(size: compact ? 14 : 16, weight: .semibold))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                        .background(Circle().fill(.white.opacity(0.055)))
                }
                .buttonStyle(.plain)
                .help(leadingHelp)
                .popover(isPresented: $isShowingLeadingMenu, arrowEdge: .bottom) {
                    leadingMenu()
                        .frame(width: 340)
                }
            }

            Image(systemName: assistantIcon)
                .font(.system(size: compact ? 15 : 18, weight: .medium))
                .foregroundStyle(AxiomColor.accent)
                .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                .background(Circle().fill(AxiomColor.accent.opacity(0.14)))
                .help("Voice command placeholder")

            TextField(placeholder, text: $prompt)
                .textFieldStyle(.plain)
                .font(.system(size: compact ? 14 : 16, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                    .background(Circle().fill(AxiomColor.accent))
            }
            .buttonStyle(.plain)
            .help("Send command")
        }
        .padding(.leading, compact ? 10 : 14)
        .padding(.trailing, compact ? 8 : 10)
        .padding(.vertical, compact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                .fill(AxiomColor.commandSurface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 16)
    }

    private var assistantIcon: String {
        switch assistantState {
        case .idle:
            return "waveform"
        case .listening:
            return "mic"
        case .thinking:
            return "sparkle.magnifyingglass"
        case .responding:
            return "sparkles"
        }
    }
}

struct VoiceStatusIndicatorView: View {
    @ObservedObject var manager: VoiceSessionManager
    let onToggleMute: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(manager.statusText, systemImage: systemImage)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(foregroundColor)
                }
                .buttonStyle(.plain)
                .help("Voice controls")

                Button(action: onToggleMute) {
                    Image(systemName: manager.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(manager.isMuted ? "Unmute voice session" : "Mute voice session")

                Button(action: onRestart) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Restart listening")

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Stop listening")

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AxiomColor.textMuted)
                    .frame(width: 18, height: 18)
            }

            if manager.settings.showsLiveTranscript && manager.liveTranscript.isEmpty == false {
                Text(manager.liveTranscript)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 360, alignment: .trailing)
            }

            if isExpanded {
                VoiceControlPanelView(
                    manager: manager,
                    onRestart: onRestart,
                    onStop: onStop
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AxiomColor.commandSurface.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .foregroundStyle(AxiomColor.textSecondary)
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private var systemImage: String {
        if manager.isMuted {
            return "mic.slash"
        }

        switch manager.state {
        case .inactive:
            return "mic.slash"
        case .requestingPermission:
            return "lock"
        case .listening:
            return "mic"
        case .transcribing:
            return "waveform"
        case .thinking:
            return "sparkle.magnifyingglass"
        case .speaking:
            return "speaker.wave.2"
        case .interrupted:
            return "hand.raised"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var foregroundColor: Color {
        if manager.isMuted {
            return AxiomColor.textMuted
        }

        switch manager.state {
        case .error:
            return .orange
        case .listening, .transcribing, .speaking:
            return AxiomColor.accentText
        case .inactive, .requestingPermission, .thinking, .interrupted:
            return AxiomColor.textSecondary
        }
    }

    private var borderColor: Color {
        switch manager.state {
        case .error:
            return .orange.opacity(0.28)
        case .listening, .transcribing, .speaking:
            return AxiomColor.accent.opacity(0.24)
        case .inactive, .requestingPermission, .thinking, .interrupted:
            return .white.opacity(0.09)
        }
    }
}

struct VoiceControlPanelView: View {
    @ObservedObject var manager: VoiceSessionManager
    let onRestart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Mode")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)

                Picker("Voice Mode", selection: modeBinding) {
                    ForEach(VoiceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(spacing: 9) {
                VoiceToggleRow(
                    title: "Interruption",
                    subtitle: "Headphones recommended for interruption mode.",
                    isOn: Binding(
                        get: { manager.settings.isInterruptionEnabled },
                        set: { newValue in
                            Task { @MainActor in
                                manager.setInterruptionEnabled(newValue)
                            }
                        }
                    )
                )

                VoiceToggleRow(
                    title: "Live Transcript",
                    subtitle: "Show recognized speech as you talk.",
                    isOn: Binding(
                        get: { manager.settings.showsLiveTranscript },
                        set: { newValue in
                            Task { @MainActor in
                                manager.setLiveTranscriptVisible(newValue)
                            }
                        }
                    )
                )

                VoiceToggleRow(
                    title: "Auto Speak",
                    subtitle: "Speak Axium responses aloud.",
                    isOn: Binding(
                        get: { manager.settings.autoSpeaksResponses },
                        set: { newValue in
                            Task { @MainActor in
                                manager.setAutoSpeakResponses(newValue)
                            }
                        }
                    )
                )

                VoiceToggleRow(
                    title: "Mute Speech",
                    subtitle: "Keep listening, but do not speak aloud.",
                    isOn: Binding(
                        get: { manager.settings.isSpeechOutputMuted },
                        set: { newValue in
                            Task { @MainActor in
                                manager.setSpeechOutputMuted(newValue)
                            }
                        }
                    )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sensitivity")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)

                Picker("Sensitivity", selection: sensitivityBinding) {
                    ForEach(VoiceSensitivity.allCases) { sensitivity in
                        Text(sensitivity.displayName).tag(sensitivity)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Engine")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)

                Picker("Voice Engine", selection: ttsProviderBinding) {
                    ForEach(TTSProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack(spacing: 8) {
                Button(action: onRestart) {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)

                Button(action: onStop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(AxiomColor.textSecondary)

            Text("Wake phrase detection, realtime WhisperKit, advanced VAD, echo cancellation, AirPods optimization, and streaming cloud voice will plug into this panel later.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AxiomColor.textMuted.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 340)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AxiomColor.cardSurface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var modeBinding: Binding<VoiceMode> {
        Binding(
            get: { manager.settings.selectedMode },
            set: { newValue in
                Task { @MainActor in
                    manager.updateMode(newValue)
                }
            }
        )
    }

    private var sensitivityBinding: Binding<VoiceSensitivity> {
        Binding(
            get: { manager.settings.sensitivity },
            set: { newValue in
                Task { @MainActor in
                    manager.updateSensitivity(newValue)
                }
            }
        )
    }

    private var ttsProviderBinding: Binding<TTSProviderType> {
        Binding(
            get: { manager.settings.ttsProviderType },
            set: { newValue in
                Task { @MainActor in
                    manager.updateTTSProviderType(newValue)
                }
            }
        )
    }
}

struct VoiceToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)
            }
        }
        .toggleStyle(.switch)
    }
}

struct ProjectSwitcherPopoverView: View {
    @ObservedObject var projectStore: ProjectStore
    let currentProjectId: UUID?
    let onCreateProject: () -> Void
    let onViewProjects: () -> Void
    let onOpenProject: (Project) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Projects", systemImage: "folder")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AxiomColor.textMuted)

                TextField("Search projects", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.055)))

            VStack(spacing: 8) {
                ProjectMenuAction(title: "Create New Project", systemImage: "folder.badge.plus", action: onCreateProject)
                ProjectMenuAction(title: "View All Projects", systemImage: "rectangle.grid.2x2", action: onViewProjects)
            }

            if filteredProjects.isEmpty == false {
                Divider().overlay(.white.opacity(0.08))

                Text("Recent")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)

                VStack(spacing: 6) {
                    ForEach(filteredProjects.prefix(6)) { project in
                        Button {
                            onOpenProject(project)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: project.id == currentProjectId ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(project.id == currentProjectId ? AxiomColor.accent : AxiomColor.textMuted)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(AxiomColor.textPrimary)
                                        .lineLimit(1)

                                    Text(project.currentObjective.isEmpty ? project.status.displayName : project.currentObjective)
                                        .font(.system(size: 11, weight: .regular, design: .rounded))
                                        .foregroundStyle(AxiomColor.textMuted)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(9)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(project.id == currentProjectId ? AxiomColor.accent.opacity(0.10) : .white.opacity(0.035)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                EmptyStateModuleView(
                    title: "No projects yet.",
                    message: "Create one when you are ready.",
                    systemImage: "folder.badge.plus",
                    compact: true
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AxiomColor.cardSurface.opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var filteredProjects: [Project] {
        let projects = projectStore.listProjects()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return projects }
        return projects.filter { project in
            project.name.lowercased().contains(query)
                || project.description.lowercased().contains(query)
                || project.aliases.contains { $0.lowercased().contains(query) }
        }
    }
}

private struct ProjectMenuAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.045)))
        }
        .buttonStyle(.plain)
    }
}

#if false
struct WorkspaceView: View {
    let project: Project
    @Binding var prompt: String
    let assistantState: AssistantState
    let onSubmit: () -> Void
    let onReturnToLanding: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 18) {
                OrbContainerView(size: 96)
                    .transition(.scale.combined(with: .opacity))

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        StatusPillView(title: "Voice-first shell", systemImage: "waveform", isActive: true)
                        StatusPillView(title: statusTitle, systemImage: "sparkles", isActive: assistantState != .idle)
                    }

                    CommandInputView(
                        prompt: $prompt,
                        assistantState: assistantState,
                        placeholder: "Ask Axiom to build, open, route, or explain...",
                        compact: true,
                        onSubmit: onSubmit
                    )
                    .frame(maxWidth: 620)
                }

                Spacer()

                Button(action: onReturnToLanding) {
                    Image(systemName: "house")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.055))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("Return to landing")
            }
            .padding(.horizontal, 4)
            .transition(.move(edge: .top).combined(with: .opacity))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ProjectHeaderView(project: project)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
                        ForEach(project.metrics) { metric in
                            MetricCardView(metric: metric)
                        }
                    }

                    HStack(alignment: .top, spacing: 18) {
                        ProjectOverviewView(project: project)
                            .frame(maxWidth: .infinity)

                        ProjectNotesView(notes: project.notes)
                            .frame(maxWidth: .infinity)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        ProjectTodoView(todos: project.todos)
                            .frame(maxWidth: .infinity)

                        AssistantRecommendationsView()
                            .frame(maxWidth: .infinity)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        ProjectFilesView(files: project.files)
                            .frame(maxWidth: .infinity)

                        ActivityTimelineView(activity: project.activity)
                            .frame(maxWidth: .infinity)
                    }

                    ProjectSeedContextView(seedPrompt: project.seedPrompt)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AxiomColor.workspaceSurface.opacity(0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.07), lineWidth: 1)
                    )
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var statusTitle: String {
        switch assistantState {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening"
        case .thinking:
            return "Thinking"
        case .responding:
            return "Project active"
        }
    }
}

struct ProjectHeaderView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(project.name)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(AxiomColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(project.description)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    StatusPillView(title: project.status, systemImage: "circle.hexagongrid", isActive: true)

                    Text("Last updated \(ProjectFormatters.relativeString(from: project.updatedAt))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AxiomColor.textMuted)
                }
            }

            HStack(spacing: 12) {
                HeaderInfoPill(title: "Folder", value: project.folderPath, systemImage: "folder")
                HeaderInfoPill(title: "Model / Context", value: project.modelContextStatus, systemImage: "cpu")
                HeaderInfoPill(title: "Created", value: ProjectFormatters.shortDate.string(from: project.createdAt), systemImage: "calendar")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ProjectCardBackground(extraOpacity: 0.08))
    }
}

struct HeaderInfoPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AxiomColor.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)

                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

struct ProjectOverviewView: View {
    let project: Project

    var body: some View {
        ProjectDashboardCard(title: "Project Overview", systemImage: "rectangle.and.text.magnifyingglass") {
            VStack(spacing: 12) {
                ForEach(project.objectives) { objective in
                    EditableMemoryBlock(title: objective.title, text: objective.detail)
                }
            }
        }
    }
}

struct EditableMemoryBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.accentText)

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.white.opacity(0.10))
                )
        )
    }
}

struct ProjectNotesView: View {
    let notes: [ProjectNote]

    var body: some View {
        ProjectDashboardCard(title: "Project Memory", systemImage: "brain.head.profile") {
            VStack(spacing: 12) {
                ForEach(notes) { note in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(AxiomColor.accent.opacity(0.72))
                            .frame(width: 7, height: 7)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(note.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.textPrimary)

                            Text(note.body)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct MetricCardView: View {
    let metric: ProjectMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AxiomColor.accent)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(metric.value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(metric.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)

                Text(metric.caption)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(ProjectCardBackground(extraOpacity: 0.03))
    }
}

struct ProjectTodoView: View {
    let todos: [ProjectTodo]
    private let groups = ["Next actions", "Blockers", "In progress", "Completed"]

    var body: some View {
        ProjectDashboardCard(title: "To-Do / Actions", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.self) { group in
                    let groupTodos = todos.filter { $0.group == group }

                    if groupTodos.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.accentText)

                            ForEach(groupTodos) { todo in
                                HStack(spacing: 10) {
                                    Image(systemName: todo.isComplete ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(todo.isComplete ? Color(red: 0.42, green: 0.86, blue: 0.62) : AxiomColor.textMuted)

                                    Text(todo.title)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(todo.isComplete ? AxiomColor.textMuted : AxiomColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.035)))
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AssistantRecommendationsView: View {
    private let recommendations = [
        ("What to work on next", "Clarify the project’s main outcome and first milestone."),
        ("Risks", "Missing source files, durable memory, and real metrics are not connected yet."),
        ("Missing information", "Audience, constraints, budget, owner, and deadline placeholders need values."),
        ("Possible automations", "Folder creation, note capture, file summaries, and recurring project briefs."),
        ("Growth ideas", "Track experiments, customer feedback, launches, and distribution channels."),
        ("Technical next steps", "Persist the project model and connect file-backed workspace state.")
    ]

    var body: some View {
        ProjectDashboardCard(title: "Axiom Suggestions", systemImage: "wand.and.stars") {
            VStack(spacing: 10) {
                ForEach(recommendations, id: \.0) { item in
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AxiomColor.accent)
                            .padding(.top, 3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.0)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.textPrimary)

                            Text(item.1)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct ProjectFilesView: View {
    let files: [ProjectFile]

    var body: some View {
        ProjectDashboardCard(title: "Files / Assets", systemImage: "shippingbox") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(files) { file in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: file.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AxiomColor.accent)

                        Text(file.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AxiomColor.textPrimary)

                        Text(file.detail)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(AxiomColor.textMuted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                }
            }
        }
    }
}

struct ActivityTimelineView: View {
    let activity: [ProjectActivity]

    var body: some View {
        ProjectDashboardCard(title: "Activity Timeline", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(activity) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AxiomColor.accent)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(AxiomColor.accent.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AxiomColor.textPrimary)

                                Spacer(minLength: 8)

                                Text(ProjectFormatters.relativeString(from: item.timestamp))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(AxiomColor.textMuted)
                            }

                            Text(item.detail)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

struct ProjectSeedContextView: View {
    let seedPrompt: String

    var body: some View {
        ProjectDashboardCard(title: "Seed Context", systemImage: "quote.bubble") {
            Text(seedPrompt.isEmpty ? "The user’s first prompt will be captured here as project context." : seedPrompt)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProjectDashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AxiomColor.accent)

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Spacer(minLength: 0)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ProjectCardBackground())
    }
}

struct ProjectCardBackground: View {
    var extraOpacity: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AxiomColor.cardSurface.opacity(0.88 + extraOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
    }
}

private enum ProjectFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static func relativeString(from date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusPillView: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(isActive ? AxiomColor.accentText : AxiomColor.textMuted)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(isActive ? AxiomColor.accent.opacity(0.16) : .white.opacity(0.055))
                .overlay(
                    Capsule()
                        .stroke(isActive ? AxiomColor.accent.opacity(0.24) : .white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct AssistantMessageView: View {
    let prompt: String
    let response: String
    let errorMessage: String?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AxiomColor.accent)

                Text("Axiom")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
            }

            Text(prompt)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .overlay(.white.opacity(0.08))

            Group {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)

                        Text("Working locally...")
                            .foregroundStyle(AxiomColor.textSecondary)
                    }
                } else if let errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color(red: 1.0, green: 0.64, blue: 0.36))

                        Text(errorMessage)
                            .foregroundStyle(AxiomColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if response.isEmpty == false {
                    Text(response)
                        .foregroundStyle(AxiomColor.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Axiom is ready for local file actions.")
                        .foregroundStyle(AxiomColor.textSecondary)
                }
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AxiomColor.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct ProjectActionCardView: View {
    let card: ProjectActionCardContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: card.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AxiomColor.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AxiomColor.cardSurface.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.075), lineWidth: 1)
                )
        )
    }
}

struct ProjectActionCardContent: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String

    init(title: String, subtitle: String, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    init(fileAction: FileAction) {
        title = fileAction.title
        subtitle = fileAction.url.path

        switch fileAction.kind {
        case .folder:
            systemImage = "folder.badge.plus"
        case .file:
            systemImage = "doc.badge.plus"
        }
    }
}

#endif

private struct AppBackground: View {
    var body: some View {
        ZStack {
            AxiomColor.workspaceSurface

            LinearGradient(
                colors: [
                    AxiomColor.accent.opacity(0.13),
                    .clear,
                    .black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    AxiomColor.accent.opacity(0.11),
                    AxiomColor.workspaceSurface.opacity(0.18),
                    .clear
                ],
                center: .center,
                startRadius: 90,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

enum AxiomColor {
    static let background = Color(red: 0.055, green: 0.058, blue: 0.062)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.12)
    static let commandSurface = Color(red: 0.12, green: 0.13, blue: 0.145)
    static let workspaceSurface = Color(red: 0.085, green: 0.092, blue: 0.102)
    static let cardSurface = Color(red: 0.13, green: 0.14, blue: 0.155)
    static let accent = Color(red: 0.24, green: 0.55, blue: 0.95)
    static let accentText = Color(red: 0.62, green: 0.78, blue: 1.0)
    static let textPrimary = Color(red: 0.94, green: 0.96, blue: 0.98)
    static let textSecondary = Color(red: 0.66, green: 0.70, blue: 0.75)
    static let textMuted = Color(red: 0.48, green: 0.52, blue: 0.58)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
