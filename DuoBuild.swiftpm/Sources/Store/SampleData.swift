import Foundation

/// Projects that are already there on first launch, so the app is useful right away.
/// They're built with Demo mode, and their messages say so.
enum SampleData {
    static func seedProjects(now: Date = Date()) -> [Project] {
        var habits = makeProject(
            name: "Morning Habits", prompt: "A personal habit tracker with streaks",
            date: now.addingTimeInterval(-26 * 3600)
        )
        refine(&habits, "Make it green and add a button that says See Stats", date: now.addingTimeInterval(-25 * 3600))
        refine(&habits, "Add more space", date: now.addingTimeInterval(-2 * 3600))

        var restaurant = makeProject(
            name: "Olive & Ember", prompt: "A restaurant landing page for a small wood-fired bistro",
            date: now.addingTimeInterval(-3 * 86400)
        )
        refine(&restaurant, "Add a field for your email and add a button that says Join the List", date: now.addingTimeInterval(-3 * 86400 + 600))

        return [habits, restaurant]
    }

    static func makeProject(name: String, prompt: String, date: Date = Date()) -> Project {
        let result = DemoEngine.generate(name: name, prompt: prompt)
        let spec = (try? SpecValidator.validate(result.spec)) ?? result.spec
        return Project(name: name, originalPrompt: prompt, spec: spec, summary: result.summary, date: date)
    }

    private static func refine(_ project: inout Project, _ instruction: String, date: Date) {
        project.messages.append(ChatMessage(role: .user, text: instruction, date: date))
        guard let result = try? DemoEngine.refine(project.spec, instruction: instruction) else { return }
        let version = project.commit(result.spec, summary: result.summary, date: date)
        project.messages.append(ChatMessage(role: .assistant, text: result.summary, date: date, versionID: version.id))
    }
}
