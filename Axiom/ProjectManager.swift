//
//  ProjectManager.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct ProjectCreationResult {
    let project: Project
    let actions: [FileAction]
}

enum ProjectManagerError: LocalizedError, Equatable {
    case invalidProjectName
    case projectAlreadyExists(String)
    case permissionDenied(String)
    case unknownFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidProjectName:
            return "That project name is not valid. Use a simple folder name without slashes, colons, or hidden-file prefixes."
        case .projectAlreadyExists(let path):
            return "A project folder already exists at \(path)."
        case .permissionDenied(let path):
            return "Axium does not have permission to write to \(path)."
        case .unknownFailure(let message):
            return "Axium could not create the project: \(message)"
        }
    }
}

struct ProjectManager {
    private let fileManager: FileManager
    private let projectsRootURL: URL

    init(
        fileManager: FileManager = .default,
        projectsRootURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("AxiumProjects", isDirectory: true)
    ) {
        self.fileManager = fileManager
        self.projectsRootURL = projectsRootURL
    }

    func createProject(named rawName: String) throws -> ProjectCreationResult {
        let name = try validatedProjectName(rawName)
        let projectURL = projectsRootURL.appendingPathComponent(name, isDirectory: true)

        guard fileManager.fileExists(atPath: projectURL.path) == false else {
            throw ProjectManagerError.projectAlreadyExists(projectURL.path)
        }

        do {
            try fileManager.createDirectory(at: projectsRootURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: projectURL, withIntermediateDirectories: false)

            let files = [
                ("README.md", "# \(name)\nCreated by Axium.\n"),
                ("notes.md", "# Notes\n"),
                ("context.md", "# Context\n")
            ]

            var actions = [
                FileAction(title: "Created project folder", url: projectURL, kind: .folder)
            ]

            for file in files {
                let fileURL = projectURL.appendingPathComponent(file.0, isDirectory: false)
                try file.1.write(to: fileURL, atomically: true, encoding: .utf8)
                actions.append(FileAction(title: "Created \(file.0)", url: fileURL, kind: .file))
            }

            return ProjectCreationResult(
                project: Project.createdWorkspace(name: name, folderURL: projectURL, actions: actions),
                actions: actions
            )
        } catch {
            throw mapFileSystemError(error, path: projectURL.path)
        }
    }

    private func validatedProjectName(_ rawName: String) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard name.isEmpty == false,
              name != ".",
              name != "..",
              name.hasPrefix(".") == false,
              name.contains("/") == false,
              name.contains("\\") == false,
              name.contains(":") == false
        else {
            throw ProjectManagerError.invalidProjectName
        }

        return name
    }

    private func mapFileSystemError(_ error: Error, path: String) -> ProjectManagerError {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(nsError.code) {
            return .permissionDenied(path)
        }

        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EACCES) || nsError.code == Int(EPERM) {
            return .permissionDenied(path)
        }

        return .unknownFailure(error.localizedDescription)
    }
}
