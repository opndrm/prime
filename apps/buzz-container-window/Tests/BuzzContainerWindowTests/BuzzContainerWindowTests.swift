import Testing
@testable import BuzzContainerWindow

@Test @MainActor func presentationStartsInSafeUnassignedState() {
    let state = ContainerPresentationState()

    #expect(state.lifecycle == "Unassigned")
    #expect(state.viewer == "Unavailable")
    #expect(state.record == "Unavailable")
    #expect(state.detail.contains("No task is attached"))
}
