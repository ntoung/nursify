import SwiftUI

/// A user-created, ordered collection of concepts, for grouping things to
/// review (e.g. "Cardiac drips"). Device-local, like notes - see AppState.
struct ConceptList: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var conceptIds: [UUID]
    var createdAt: Date
}

/// Which saved collection a list-detail screen is showing.
enum SavedKind: Hashable {
    case favorites
    case list(UUID)
}

// MARK: - "Saved" section (shown on the Search tab when the query is empty)

struct SavedSection: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingNewList = false
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "Saved")
                Spacer()
                Button { newName = ""; showingNewList = true } label: {
                    Label("New list", systemImage: "plus")
                        .font(Theme.Font.body(13, weight: .semibold))
                        .foregroundStyle(Theme.Color.accentInk)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                NavigationLink(destination: ConceptListDetailView(kind: .favorites)) {
                    SavedRow(icon: "star.fill", tint: Theme.Color.accentInk, name: "Favorites", count: appState.favorites.count)
                }
                .buttonStyle(.plain)

                ForEach(appState.lists) { list in
                    Divider().padding(.leading, 16)
                    NavigationLink(destination: ConceptListDetailView(kind: .list(list.id))) {
                        SavedRow(icon: "square.stack.3d.up.fill", tint: Theme.Color.sub, name: list.name, count: list.conceptIds.count)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Color.line, lineWidth: 1))
        }
        .alert("New list", isPresented: $showingNewList) {
            TextField("List name", text: $newName)
            Button("Create") {
                let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !n.isEmpty { _ = appState.createList(named: n) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Group concepts together to review.")
        }
    }
}

private struct SavedRow: View {
    let icon: String
    let tint: Color
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(name)
                .font(Theme.Font.heading(15.5))
                .foregroundStyle(Theme.Color.ink)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(Theme.Font.body(13, weight: .semibold))
                .foregroundStyle(Theme.Color.sub)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: "C9C2B4"))
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - List detail (the concepts in a saved collection, for review)

struct ConceptListDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let kind: SavedKind

    @State private var isRenaming = false
    @State private var draftName = ""

    private var listId: UUID? { if case .list(let id) = kind { return id } else { return nil } }

    private var title: String {
        switch kind {
        case .favorites: return "Favorites"
        case .list(let id): return appState.lists.first { $0.id == id }?.name ?? "List"
        }
    }

    private var items: [ConceptSummary] {
        let ids: [UUID]
        switch kind {
        case .favorites: ids = Array(appState.favorites)
        case .list(let id): ids = appState.lists.first { $0.id == id }?.conceptIds ?? []
        }
        var summaries = appState.library.summaries(ids: ids)
        // Favorites is an unordered set, so present it alphabetically; named
        // lists keep their most-recent-first insertion order.
        if case .favorites = kind {
            summaries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return summaries
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyStateView(
                    icon: kind == .favorites ? "star" : "square.stack.3d.up",
                    title: "Nothing here yet",
                    message: "Open any concept and tap Favorite or Add to list to build this collection."
                )
                .padding(.top, 60)
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink(destination: ConceptDetailView(conceptId: item.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(Theme.Font.heading(15.5))
                                    .foregroundStyle(Theme.Color.ink)
                                Text(item.type.displayName)
                                    .font(Theme.Font.body(12, weight: .semibold))
                                    .foregroundStyle(Theme.Color.sub)
                            }
                        }
                        // List cells default to an opaque system background; clear
                        // it so the screen's background shows through (matches the
                        // rest of the app's theming).
                        .listRowBackground(SwiftUI.Color.clear)
                    }
                    .onDelete(perform: remove)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let listId {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { draftName = title; isRenaming = true } label: { Label("Rename", systemImage: "pencil") }
                        Button(role: .destructive) { appState.deleteList(listId); dismiss() } label: { Label("Delete list", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Rename list", isPresented: $isRenaming) {
            TextField("List name", text: $draftName)
            Button("Save") {
                let n = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let listId, !n.isEmpty { appState.renameList(listId, to: n) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func remove(at offsets: IndexSet) {
        let ids = offsets.map { items[$0].id }
        switch kind {
        case .favorites: ids.forEach { appState.toggleFavorite($0) }
        case .list(let id): ids.forEach { appState.setConcept($0, inList: id, member: false) }
        }
    }
}

// MARK: - "Add to list" sheet (from a concept's detail page)

struct AddToListSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let conceptId: UUID
    @State private var newListName = ""

    private var trimmedNew: String { newListName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section("New list") {
                    HStack {
                        TextField("List name", text: $newListName)
                        Button("Create") {
                            let id = appState.createList(named: trimmedNew)
                            appState.setConcept(conceptId, inList: id, member: true)
                            newListName = ""
                        }
                        .disabled(trimmedNew.isEmpty)
                    }
                }
                if !appState.lists.isEmpty {
                    Section("Your lists") {
                        ForEach(appState.lists) { list in
                            Button {
                                let isMember = appState.isConcept(conceptId, inList: list.id)
                                appState.setConcept(conceptId, inList: list.id, member: !isMember)
                            } label: {
                                HStack {
                                    Text(list.name).foregroundStyle(Theme.Color.ink)
                                    Spacer()
                                    if appState.isConcept(conceptId, inList: list.id) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Theme.Color.accentInk)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
