import SwiftUI

/// How the workspace is laid out, decided only from the space the window really has.
///
/// Apple's guidance is to adapt to the available size, not to ask for a device model
/// or a fold state. So on iPhone Duo the open inner display gets two panes, the cover
/// display gets one, and the same rule works on any iPhone, iPad window or Stage Manager size.
/// DuoBuild doesn't read the hinge angle or guess a tabletop posture.
enum WorkspaceLayout: Equatable {
    /// Builder and preview side by side.
    case split
    /// One pane at a time with a switch between them.
    case single

    /// Below this width the two panes get too narrow to be useful.
    static let minimumSplitWidth: CGFloat = 680

    static func resolve(width: CGFloat, sizeClass: UserInterfaceSizeClass?) -> WorkspaceLayout {
        if width >= minimumSplitWidth { return .split }
        // A regular-width window that's a little narrower still fits two panes.
        if sizeClass == .regular && width >= 600 { return .split }
        return .single
    }

    /// The builder's width in split mode. The preview gets the rest.
    static func builderWidth(total: CGFloat) -> CGFloat {
        min(max(total * 0.4, 320), 440)
    }
}
