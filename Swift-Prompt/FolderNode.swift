import Foundation
import SwiftUI

struct FolderNode: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FolderNode] = []
    
    var optionalChildren: [FolderNode]? {
        children.isEmpty ? nil : children
    }
}
