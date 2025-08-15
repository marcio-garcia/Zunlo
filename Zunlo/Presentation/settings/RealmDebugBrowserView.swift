//
//  RealmDebugBrowserView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/14/25.
//

#if DEBUG
import SwiftUI
import RealmSwift

// MARK: - Entry point
public struct RealmDebugBrowserView: View {
    private let configuration: Realm.Configuration
    @State private var objectSchemas: [ObjectSchema] = []

    public init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.configuration = configuration
        // Preload schemas up front for a snappy UI
        do {
            let realm = try Realm(configuration: configuration)
            _objectSchemas = State(initialValue: realm.schema.objectSchema.filter { !$0.isEmbedded })
        } catch {
            _objectSchemas = State(initialValue: [])
            print("RealmDebugBrowserView init error:", error)
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(objectSchemas, id: \.className) { schema in
                    NavigationLink {
                        DynamicObjectsListView(configuration: configuration, schema: schema)
                    } label: {
                        HStack {
                            Text(schema.className)
                            Spacer()
                            CountBadge(configuration: configuration, className: schema.className)
                        }
                    }
                }
            }
            .navigationTitle("Realm Browser")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = configuration.fileURL?.path ?? "(in-memory / unknown path)"
                    } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy Realm file path")
                }
            }
        }
    }
}

// MARK: - Small count badge for types list
private struct CountBadge: View {
    let configuration: Realm.Configuration
    let className: String
    @State private var count: Int = 0

    var body: some View {
        Text("\(count)")
            .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .onAppear(perform: refresh)
    }

    private func refresh() {
        do {
            let realm = try Realm(configuration: configuration)
            count = realm.dynamicObjects(className).count
        } catch {
            count = 0
        }
    }
}

// MARK: - Dynamic list view for a selected type
private struct DynamicObjectsListView: View {
    let configuration: Realm.Configuration
    let schema: ObjectSchema

    @StateObject private var observer: DynamicResultsObserver
    @State private var searchText: String = ""

    init(configuration: Realm.Configuration, schema: ObjectSchema) {
        self.configuration = configuration
        self.schema = schema
        _observer = StateObject(wrappedValue: DynamicResultsObserver(configuration: configuration, className: schema.className))
    }

    var body: some View {
        List {
            ForEach(Array(filteredItems.enumerated()), id: \.offset) { _, obj in
                NavigationLink {
                    DynamicObjectDetailView(object: obj, schema: schema)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryLine(for: obj))
                            .font(.body)
                            .lineLimit(1)
                        Text(secondaryLine(for: obj))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .onDelete { offsets in
                do {
                    let realm = try Realm(configuration: configuration)
                    let doomed = offsets.map { filteredItems[$0] }   // use filtered source
                    try realm.write { realm.delete(doomed) }
                    observer.refresh()
                } catch {
                    print("Delete error:", error)
                }
            }
        }
        .navigationTitle(schema.className)
        .searchable(text: $searchText, prompt: "Search properties")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) { deleteAll() } label: {
                        Label("Delete All \(schema.className)", systemImage: "trash")
                    }
                    Button { observer.refresh() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var filteredItems: [DynamicObject] {
        guard !searchText.isEmpty else { return observer.items }
        let needle = searchText.lowercased()
        let keys = schema.properties.map(\.name)
        return observer.items.filter { obj in
            for k in keys {
                if let v = (obj.value(forKey: k)).map({ String(describing: $0) })?.lowercased(),
                   v.contains(needle) { return true }
            }
            return false
        }
    }

    private func primaryLine(for obj: DynamicObject) -> String {
        // Prefer primary key if present; else first few properties
        if let pk = schema.primaryKeyProperty?.name,
           let val = obj.value(forKey: pk) {
            return "\(pk): \(val)"
        }
        let keys = schema.properties.prefix(2).map(\.name)
        let parts = keys.compactMap { k -> String? in
            guard let v = obj.value(forKey: k) else { return nil }
            return "\(k)=\(v)"
        }
        return parts.isEmpty ? "(object)" : parts.joined(separator: "  ")
    }

    private func secondaryLine(for obj: DynamicObject) -> String {
        let keys = schema.properties.map(\.name)
        let parts = keys.compactMap { k -> String? in
            guard let v = obj.value(forKey: k) else { return nil }
            return "\(k)=\(v)"
        }
        return parts.joined(separator: " • ")
    }

//    private func delete(_ offsets: IndexSet) {
//        do {
//            let realm = try Realm(configuration: configuration)
//            try realm.write {
//                offsets.map { observer.items[$0] }.forEach { realm.delete($0) }
//            }
//            observer.refresh()
//        } catch {
//            print("Delete error:", error)
//        }
//    }

    private func deleteAll() {
        do {
            let realm = try Realm(configuration: configuration)
            let all = realm.dynamicObjects(schema.className)
            try realm.write { realm.delete(all) }
            observer.refresh()
        } catch {
            print("DeleteAll error:", error)
        }
    }
}

// MARK: - Object detail
private struct DynamicObjectDetailView: View {
    let object: DynamicObject
    let schema: ObjectSchema

    var body: some View {
        List {
            ForEach(schema.properties, id: \.name) { prop in
                HStack(alignment: .top) {
                    Text(prop.name).font(.body)
                    Spacer()
                    Text(stringValue(for: prop.name))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("Details")
    }

    private func stringValue(for key: String) -> String {
        guard let value = object.value(forKey: key) else { return "nil" }
        // Keep it simple for debug – show a short version for collections
        if let list = value as? AnyRealmCollection<AnyRealmValue> {
            return "List(\(list.count))"
        }
        return String(describing: value)
    }
}

// MARK: - Results observer (dynamic)
final class DynamicResultsObserver: ObservableObject {
    @Published var items: [DynamicObject] = []

    private let configuration: Realm.Configuration
    private let className: String
    private var realm: Realm?
    private var results: Results<DynamicObject>?
    private var token: NotificationToken?

    init(configuration: Realm.Configuration, className: String) {
        self.configuration = configuration
        self.className = className
        openAndObserve()
    }

    deinit { token?.invalidate() }

    func refresh() {
        // Simply re-open to be safe in DEBUG
        token?.invalidate()
        openAndObserve()
    }

    private func openAndObserve() {
        do {
            realm = try Realm(configuration: configuration)
            results = realm?.dynamicObjects(className)
            token = results?.observe { [weak self] change in
                switch change {
                case .initial(let r), .update(let r, _, _, _):
                    self?.items = Array(r)
                case .error(let err):
                    print("Observe error:", err)
                }
            }
        } catch {
            print("Realm open error:", error)
            items = []
        }
    }
}
#endif
