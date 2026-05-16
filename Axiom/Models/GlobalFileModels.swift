//
//  GlobalFileModels.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

struct GlobalFileItem: Identifiable, Equatable, Codable {
    enum FileType: String, CaseIterable, Equatable, Codable {
        case image
        case pdf
        case screenshot
        case document
        case export
        case audio
        case video
        case folder
        case other
    }

    enum Source: String, CaseIterable, Equatable, Codable {
        case localImport
        case projectGenerated
        case screenshot
        case export
        case futureCameraCapture
        case futureEmailAttachment
        case futureCloudIntegration
    }

    enum GlobalVisibility: String, CaseIterable, Equatable, Codable {
        case global
        case projectScoped
        case privateToProject
    }

    let id: UUID
    var name: String
    var type: FileType
    var localPath: String
    var previewPath: String?
    var createdAt: Date
    var updatedAt: Date
    var source: Source
    var tags: [String]
    var relatedProjectIds: [UUID]
    var searchableText: String
    var description: String?
    var isPrivateToProject: Bool
    var globalVisibility: GlobalVisibility
    var lastReferencedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: FileType = .other,
        localPath: String,
        previewPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: Source = .localImport,
        tags: [String] = [],
        relatedProjectIds: [UUID] = [],
        searchableText: String = "",
        description: String? = nil,
        isPrivateToProject: Bool = false,
        globalVisibility: GlobalVisibility = .global,
        lastReferencedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.localPath = localPath
        self.previewPath = previewPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.tags = tags
        self.relatedProjectIds = relatedProjectIds
        self.searchableText = searchableText
        self.description = description
        self.isPrivateToProject = isPrivateToProject
        self.globalVisibility = globalVisibility
        self.lastReferencedAt = lastReferencedAt
    }
}
