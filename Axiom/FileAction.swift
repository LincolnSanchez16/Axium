//
//  FileAction.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct FileAction: Identifiable, Equatable {
    enum Kind: Equatable {
        case folder
        case file
    }

    let id = UUID()
    let title: String
    let url: URL
    let kind: Kind
}
