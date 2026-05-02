//
//  EditorRoute.swift
//  Feature
//
//  Navigation graph for the editor flow. The root scene owns a
//  `NavigationStack(path:)` bound to `[EditorRoute]` and pushes / pops
//  these cases to move between Home → Editor → Export.
//

import Foundation

public enum EditorRoute: Hashable {
    case editor
    case export
}
