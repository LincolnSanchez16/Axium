//
//  AIIntentResult.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct AIIntentResult: Equatable, Codable {
    enum Intent: String, CaseIterable, Codable {
        case greeting
        case createProject
        case openProject
        case viewProjects
        case addNote
        case addTask
        case showNotes
        case showTasks
        case showMetrics
        case showFiles
        case showActivity
        case showIntegrations
        case saveToProject
        case addReminder
        case addCalendarItem
        case rememberUserInfo
        case updateUserProfile
        case savePreference
        case unknown

        static func normalized(_ rawValue: String) -> Intent {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerCamel = trimmed.prefix(1).lowercased() + String(trimmed.dropFirst())
            if let intent = Intent(rawValue: trimmed) ?? Intent(rawValue: lowerCamel) {
                return intent
            }

            let compact = trimmed
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")

            switch compact {
            case "notes", "viewnotes", "shownotes", "opennotes":
                return .showNotes
            case "tasks", "viewtasks", "showtasks", "opentasks":
                return .showTasks
            case "metrics", "viewmetrics", "showmetrics":
                return .showMetrics
            case "files", "viewfiles", "showfiles":
                return .showFiles
            case "activity", "timeline", "viewactivity", "showactivity":
                return .showActivity
            case "integrations", "viewintegrations", "showintegrations":
                return .showIntegrations
            case "projects", "listprojects", "viewprojects", "showprojects":
                return .viewProjects
            case "note", "addnote":
                return .addNote
            case "task", "todo", "addtask":
                return .addTask
            case "reminder", "addreminder":
                return .addReminder
            case "calendar", "event", "addcalendaritem":
                return .addCalendarItem
            case "remember", "rememberuserinfo", "memory", "saveuserinfo":
                return .rememberUserInfo
            case "updateuserprofile", "profile", "username", "preferredname":
                return .updateUserProfile
            case "savepreference", "preference", "rememberpreference":
                return .savePreference
            default:
                return .unknown
            }
        }
    }

    let intent: Intent
    let target: String
    let projectName: String?
    let module: String?
    let extractedTitle: String?
    let extractedDetails: String?
    let confidence: Double
    let shouldUseCloudAPI: Bool
    let assistantResponse: String

    enum CodingKeys: String, CodingKey {
        case intent
        case target
        case projectName
        case module
        case extractedTitle
        case extractedDetails
        case confidence
        case shouldUseCloudAPI
        case assistantResponse
    }

    init(
        intent: Intent,
        target: String,
        projectName: String?,
        module: String?,
        extractedTitle: String?,
        extractedDetails: String?,
        confidence: Double,
        shouldUseCloudAPI: Bool,
        assistantResponse: String
    ) {
        self.intent = intent
        self.target = target
        self.projectName = projectName
        self.module = module
        self.extractedTitle = extractedTitle
        self.extractedDetails = extractedDetails
        self.confidence = confidence
        self.shouldUseCloudAPI = shouldUseCloudAPI
        self.assistantResponse = assistantResponse
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawIntent = try container.decodeIfPresent(String.self, forKey: .intent) ?? Intent.unknown.rawValue
        intent = Intent.normalized(rawIntent)
        target = try container.decodeIfPresent(String.self, forKey: .target) ?? "unknown"
        projectName = try container.decodeNullableString(forKey: .projectName)
        module = try container.decodeNullableString(forKey: .module)
        extractedTitle = try container.decodeNullableString(forKey: .extractedTitle)
        extractedDetails = try container.decodeNullableString(forKey: .extractedDetails)
        confidence = try container.decodeFlexibleDouble(forKey: .confidence) ?? 0
        shouldUseCloudAPI = try container.decodeIfPresent(Bool.self, forKey: .shouldUseCloudAPI) ?? false
        assistantResponse = try container.decodeIfPresent(String.self, forKey: .assistantResponse) ?? ""
    }

    var assistantIntentKind: AssistantIntent.Kind {
        switch intent {
        case .greeting:
            return .greeting
        case .createProject:
            return .createProject
        case .openProject:
            return .openProject
        case .viewProjects:
            return .viewProjects
        case .addNote:
            return .addNote
        case .addTask:
            return .addTask
        case .showNotes:
            return .viewNotes
        case .showTasks:
            return .viewTasks
        case .showMetrics:
            return .viewMetrics
        case .showFiles:
            return .viewFiles
        case .showActivity:
            return .viewActivity
        case .showIntegrations:
            return .connectIntegration
        case .rememberUserInfo, .updateUserProfile, .savePreference:
            return .focusConversation
        case .saveToProject, .addReminder, .addCalendarItem, .unknown:
            return .unknown
        }
    }
}

private extension KeyedDecodingContainer where K == AIIntentResult.CodingKeys {
    func decodeNullableString(forKey key: K) throws -> String? {
        if try decodeNil(forKey: key) { return nil }
        let value = try decodeIfPresent(String.self, forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, value.isEmpty == false, value.lowercased() != "null" else { return nil }
        return value
    }

    func decodeFlexibleDouble(forKey key: K) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}
