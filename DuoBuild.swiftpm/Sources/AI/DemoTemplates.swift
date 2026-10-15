import Foundation

/// The built-in designs Demo mode starts from.
struct DemoTemplate {
    let title: String
    let keywords: [String]
    let make: (String) -> UISpec
}

enum DemoTemplates {
    static let all: [DemoTemplate] = [
        DemoTemplate(title: "Habit tracker", keywords: ["habit", "routine", "streak"], make: DemoTemplates.habitTracker),
        DemoTemplate(title: "Restaurant landing page", keywords: ["restaurant", "cafe", "café", "bistro", "menu", "landing", "bakery"], make: DemoTemplates.restaurant),
        DemoTemplate(title: "Expense tracker", keywords: ["expense", "budget", "spending", "money", "finance"], make: DemoTemplates.expenses),
        DemoTemplate(title: "To-do list", keywords: ["todo", "to-do", "to do", "task", "checklist", "grocer", "shopping"], make: DemoTemplates.todo),
        DemoTemplate(title: "Workout log", keywords: ["workout", "fitness", "gym", "exercise", "running"], make: DemoTemplates.workout),
        DemoTemplate(title: "Event invite", keywords: ["event", "party", "rsvp", "wedding", "invite", "birthday"], make: DemoTemplates.event),
        DemoTemplate(title: "Profile page", keywords: ["profile", "portfolio", "about me", "resume", "bio"], make: DemoTemplates.profile),
    ]

    static func habitTracker(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .indigo), nodes: [
            .text(name, .largeTitle),
            .text("Small steps, every day.", .body, color: .secondary),
            .hstack([
                .card("12", detail: "Day streak", symbol: "flame.fill"),
                .card("4/5", detail: "Done today", symbol: "checkmark.circle.fill"),
            ]),
            .text("Today", .headline),
            .list(["Drink water", "Read 20 pages", "Walk 8,000 steps", "Meditate 5 min", "Sleep by 11pm"], symbol: "circle"),
            .button("Add Habit", message: "In a real app this would open a new habit form."),
        ])
    }

    static func restaurant(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .orange, spacing: .large), nodes: [
            .image("fork.knife.circle.fill", size: .large, color: .orange),
            .text(name, .largeTitle),
            .text("Seasonal plates, wood-fired bread and natural wine in the heart of the city.", .body, color: .secondary),
            .hstack([
                .button("Book a Table", message: "Reservation request sent (preview only)."),
                .button("View Menu", message: "The menu would open here.", secondary: true),
            ]),
            .card("Tonight's special", detail: "Charred leeks, brown butter, hazelnut. $18", symbol: "star.fill"),
            .card("Open hours", detail: "Tue–Sun · 5pm – 11pm", symbol: "clock"),
            .card("Find us", detail: "214 Market Street", symbol: "mappin.and.ellipse"),
        ])
    }

    static func expenses(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .green, background: .grouped), nodes: [
            .text(name, .largeTitle),
            .card("$1,284.50", detail: "Spent this month · $415.50 left", symbol: "creditcard.fill"),
            .hstack([
                .card("$342", detail: "Food", symbol: "cart.fill"),
                .card("$120", detail: "Transport", symbol: "bus.fill"),
            ]),
            .text("Recent", .headline),
            .list(["Groceries · $54.20", "Coffee · $4.50", "Train pass · $32.00", "Dinner out · $46.80"], symbol: "dollarsign.circle"),
            .input("Amount"),
            .button("Add Expense", message: "Expense added (preview only)."),
        ])
    }

    static func todo(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .blue), nodes: [
            .text(name, .largeTitle),
            .text("3 of 6 done", .caption, color: .secondary),
            .input("New task"),
            .list(["Buy milk", "Call the dentist", "Pick up dry cleaning", "Water the plants", "Pay rent", "Plan the weekend"], symbol: "circle"),
            .button("Clear Completed", message: "Completed tasks cleared (preview only).", secondary: true),
        ])
    }

    static func workout(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .red), nodes: [
            .text(name, .largeTitle),
            .hstack([
                .card("42 min", detail: "Duration", symbol: "timer"),
                .card("380", detail: "Calories", symbol: "flame.fill"),
            ]),
            .text("Today's plan", .headline),
            .list(["Warm-up · 5 min", "Squats · 3×12", "Push-ups · 3×15", "Plank · 3×45s", "Stretch · 5 min"], symbol: "figure.strengthtraining.traditional"),
            .button("Start Workout", message: "Workout started (preview only)."),
        ])
    }

    static func event(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .pink, background: .tinted, spacing: .large), nodes: [
            .image("party.popper.fill", size: .medium, color: .pink),
            .text(name, .largeTitle),
            .text("Saturday, June 14 · 7pm", .headline),
            .text("Join us for food, music and good company.", .body, color: .secondary),
            .input("Your name"),
            .hstack([
                .button("I'll be there", message: "Thanks! Your RSVP was saved (preview only)."),
                .button("Can't make it", message: "Sorry you'll miss it.", secondary: true),
            ]),
        ])
    }

    static func profile(_ name: String) -> UISpec {
        UISpec(title: name, theme: SpecTheme(accent: .teal), nodes: [
            .image("person.crop.circle.fill", size: .medium, color: .teal),
            .text(name, .largeTitle),
            .text("Product designer who loves simple tools.", .body, color: .secondary),
            .hstack([
                .button("Contact", message: "Contact form would open here."),
                .button("Follow", message: "Followed (preview only).", secondary: true),
            ]),
            .card("Recent work", detail: "Calm, a meditation timer · Ledger, a budgeting app", symbol: "square.grid.2x2"),
            .list(["Interaction design", "Prototyping", "Design systems"], symbol: "checkmark.seal"),
        ])
    }

    /// When nothing matches, a plain starter screen built from the person's own words.
    static func generic(name: String, prompt: String) -> UISpec {
        let sentence = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let blurb = sentence.count > 140 ? String(sentence.prefix(140)) + "…" : sentence
        return UISpec(title: name, nodes: [
            .text(name, .largeTitle),
            .text(blurb, .body, color: .secondary),
            .card("Getting started", detail: "This is a starter layout. Ask for changes like “Add a list of …”.", symbol: "sparkles"),
            .button("Continue", message: "Button tapped (preview only)."),
        ])
    }
}

/// Starter ideas on the home screen. Opening one uses the template right away, with no AI call.
struct ExampleProject: Identifiable {
    var id: String { name }
    let name: String
    let blurb: String
    let prompt: String
    let symbol: String

    static let all: [ExampleProject] = [
        ExampleProject(name: "Morning Habits", blurb: "Streaks and a daily checklist", prompt: "A personal habit tracker", symbol: "checkmark.circle"),
        ExampleProject(name: "Olive & Ember", blurb: "A restaurant landing page", prompt: "A restaurant landing page", symbol: "fork.knife"),
        ExampleProject(name: "Pocket Budget", blurb: "Track spending by category", prompt: "A simple expense tracker", symbol: "creditcard"),
        ExampleProject(name: "Summer Party", blurb: "An invite with RSVP", prompt: "An event invite with RSVP buttons", symbol: "party.popper"),
    ]
}
