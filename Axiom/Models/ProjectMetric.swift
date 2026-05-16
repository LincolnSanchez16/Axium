//
//  ProjectMetric.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct ProjectMetric: Identifiable, Equatable, Codable {
    enum Category: String, CaseIterable, Equatable, Codable {
        case revenue
        case mrr
        case arr
        case profit
        case expenses
        case users
        case growth
        case activity
        case timeWorked
        case custom

        var displayName: String {
            switch self {
            case .mrr:
                return "MRR"
            case .arr:
                return "ARR"
            case .timeWorked:
                return "Time Worked"
            default:
                return rawValue.capitalized
            }
        }
    }

    let id: UUID
    var name: String
    var value: Double
    var unit: String
    var category: Category
    var timestamp: Date
    var source: String
    var isConnectedData: Bool

    init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String = "",
        category: Category,
        timestamp: Date = Date(),
        source: String,
        isConnectedData: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.category = category
        self.timestamp = timestamp
        self.source = source
        self.isConnectedData = isConnectedData
    }
}
