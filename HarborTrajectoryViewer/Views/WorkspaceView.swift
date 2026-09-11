import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedStepID: Int?

    var body: some View {
        VStack(spacing: 0) {
            TrajectoryHeaderView()
            Divider()

            if let primary = model.primary {
                if let comparison = model.comparison {
                    TrajectoryComparisonView(primary: primary, comparison: comparison)
                } else {
                    HSplitView {
                        TrajectorySidebar(
                            trajectory: primary,
                            selectedStepID: $selectedStepID
                        )
                        TrajectoryTimelineView(
                            trajectory: primary,
                            selectedStepID: $selectedStepID
                        )
                        .frame(minWidth: 620)
                    }
                    .onAppear {
                        selectedStepID = selectedStepID ?? primary.trajectory.steps.first?.stepID
                    }
                }
            }
        }
        .background(AppTheme.canvas)
    }
}
