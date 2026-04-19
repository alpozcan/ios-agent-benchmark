# Atlas — Implementation Prompt

**You are building Atlas, a knowledge management iOS app. Read the PRD first.**

**Rules:**
- Write ALL code described below. Do NOT run xcodebuild. Do NOT write tests.
- Do NOT create .xcdatamodeld files — create NSManagedObject subclasses manually with @NSManaged properties and initialize NSEntityDescription programmatically.
- Use CoreData programmatically (NSManagedObjectModel built in code, not .xcdatamodeld).
- When finished with implementation, output: `ATLAS_IMPLEMENTATION_COMPLETE`

---

## Directory Structure

Create files under `Atlas/` using this structure:

```
Atlas/
├── App/
│   ├── AtlasApp.swift
│   ├── CoreDataStack.swift
│   └── DIContainer.swift
├── Domain/
│   ├── Models/
│   │   ├── Topic.swift, Link.swift, Tag.swift, Attachment.swift
│   │   ├── Collection.swift, Metadata.swift, SyncRecord.swift
│   │   ├── SearchIndex.swift, UserPreference.swift, Notification.swift
│   │   ├── Cluster.swift, GraphLayout.swift, ReadingSession.swift, DailyStat.swift
│   │   └── Enums.swift (TopicType, LinkType, AttachmentType, etc.)
│   ├── Protocols/
│   │   ├── Repositories/ (15 repository protocols)
│   │   ├── UseCases/ (30 use case protocols)
│   │   ├── Mappers/ (15 mapper protocols)
│   │   ├── Coordinators/ (10 coordinator protocols)
│   │   ├── Services/ (platform, infrastructure, feature, factory, builder, UI, helper protocols)
│   │   └── Decorators/ (cache, logging, analytics, validation protocols)
│   └── Errors/
│       ├── RepositoryError.swift
│       ├── UseCaseError.swift
│       ├── ValidationError.swift
│       └── SyncError.swift
├── Data/
│   ├── Entities/ (14 NSManagedObject subclasses: ATTopic, ATLink, ...)
│   ├── Repositories/ (15 implementations)
│   ├── Mappers/ (15 implementations)
│   └── CoreDataModel.swift (programmatic NSManagedObjectModel)
├── Engine/
│   ├── Graph/
│   │   ├── ForceLayoutEngine.swift
│   │   ├── GraphTraversal.swift
│   │   ├── CommunityDetection.swift
│   │   └── GraphMetrics.swift
│   ├── Search/
│   │   ├── SearchEngine.swift
│   │   ├── TFIDFScorer.swift
│   │   ├── FuzzyMatcher.swift
│   │   └── SearchRanker.swift
│   ├── Text/
│   │   ├── MarkdownParser.swift
│   │   ├── WikiLinkDetector.swift
│   │   ├── TextProcessor.swift
│   │   └── ContentAnalyzer.swift
│   └── Similarity/
│       ├── CosineSimilarity.swift
│       └── DuplicateDetector.swift
├── DI/
│   ├── DIContainer+Repositories.swift
│   ├── DIContainer+UseCases.swift
│   ├── DIContainer+Decorators.swift
│   ├── DIContainer+Coordinators.swift
│   ├── DIContainer+Services.swift
│   ├── DIContainer+Mappers.swift
│   ├── DIContainer+Factories.swift
│   ├── DIContainer+Builders.swift
│   └── DIContainer+Helpers.swift
├── Features/
│   ├── UseCases/ (30 implementations)
│   ├── Coordinators/ (10 implementations)
│   ├── Factories/ (15 implementations)
│   └── Builders/ (15 implementations)
├── Services/
│   ├── Platform/ (10 implementations)
│   ├── Infrastructure/ (15 implementations)
│   ├── Feature/ (30 implementations)
│   ├── Decorators/ (60 implementations — 4 per repository)
│   ├── UI/ (20 implementations)
│   └── Helpers/ (20 implementations)
├── Seeding/
│   ├── SeedData.swift
│   ├── TopicSeeds.swift (50 topics across 10 domains)
│   ├── TagSeeds.swift (30 tags)
│   ├── LinkSeeds.swift (120 links)
│   ├── CollectionSeeds.swift (10 collections)
│   └── StatsSeeds.swift (14 daily stats + 25 reading sessions)
├── UI/
│   ├── Theme/
│   │   ├── AtlasTheme.swift
│   │   ├── Colors.swift
│   │   └── Typography.swift
│   ├── Screens/
│   │   ├── HomeScreen.swift (5 tabs)
│   │   ├── TopicsListScreen.swift
│   │   ├── TopicDetailScreen.swift
│   │   ├── TopicEditorScreen.swift
│   │   ├── GraphCanvasScreen.swift
│   │   ├── SearchScreen.swift
│   │   ├── ActivityScreen.swift
│   │   ├── CollectionsScreen.swift
│   │   ├── CollectionDetailScreen.swift
│   │   ├── SettingsScreen.swift
│   │   └── OnboardingScreen.swift
│   ├── Components/
│   │   ├── TopicCard.swift
│   │   ├── TagChip.swift
│   │   ├── BacklinkSection.swift
│   │   ├── GraphNodeView.swift
│   │   ├── GraphEdgeView.swift
│   │   ├── MinimapView.swift
│   │   ├── SearchBar.swift
│   │   ├── FilterChips.swift
│   │   ├── ReadingProgressView.swift
│   │   ├── ActivityHeatmap.swift
│   │   ├── StatisticsCard.swift
│   │   └── EmptyStateView.swift
│   └── ViewModels/
│       ├── TopicsListViewModel.swift
│       ├── TopicDetailViewModel.swift
│       ├── TopicEditorViewModel.swift
│       ├── GraphViewModel.swift
│       ├── SearchViewModel.swift
│       ├── ActivityViewModel.swift
│       ├── CollectionsViewModel.swift
│       └── SettingsViewModel.swift
└── Extensions/
    ├── Color+Hex.swift
    ├── Date+Relative.swift
    ├── String+Markdown.swift
    ├── View+Modifiers.swift
    └── NSManagedObject+Helpers.swift
```

---

## Implementation Order

### 1. Domain Layer — Models + Enums + Errors

Create `Enums.swift` with all enums as Int16 raw values:
- `TopicType`: article(0), bookmark(1), idea(2), snippet(3), quote(4)
- `LinkType`: reference(0), embed(1), seeAlso(2), contradiction(3), supports(4)
- `AttachmentType`: image(0), audio(1), file(2), video(3)
- `ChangeType`: create(0), update(1), delete(2)
- `ConflictResolution`: none(0), localWins(1), remoteWins(2), merge(3)
- `PreferenceType`: string(0), int(1), double(2), bool(3), data(4)
- `NotificationType`: reminder(0), suggestion(1), insight(2)

Create domain models as plain structs (Sendable): `Topic`, `Link`, `Tag`, `Attachment`, `Collection`, `Metadata`, `SyncRecord`, `SearchIndex`, `UserPreference`, `AppNotification`, `TopicCluster`, `LayoutPosition`, `ReadingActivity`, `DailyStatistics`.

Create error enums: `RepositoryError`, `UseCaseError`, `ValidationError`, `SyncError` — all conform to `LocalizedError`.

### 2. Data Layer — CoreData Entities

Create `CoreDataModel.swift` — programmatic NSManagedObjectModel:
- Define NSEntityDescription for all 14 entities
- Define NSAttributeDescription for all attributes
- Define NSRelationshipDescription for all relationships
- Set up inverse relationships correctly
- Create NSManagedObjectModel from these descriptions
- Set up NSPersistentStoreDescription with auto-migration options

Create NSManagedObject subclasses for each entity. Each subclass:
- Extends `NSManagedObject`
- Uses `@NSManaged` for all properties
- Has convenience `init(context:)` that sets default values
- Has `toDomainModel()` method returning the corresponding struct

### 3. Repository Protocols + Implementations

For each of the 15 entities, create:
- Protocol in `Domain/Protocols/Repositories/` — `@MainActor`, `Sendable`
- Implementation in `Data/Repositories/` — uses NSManagedObjectContext
- CRUD: `create`, `fetch(by:)`, `fetchAll()`, `update(_:),` `delete(_:)`
- Entity-specific queries

### 4. Mapper Protocols + Implementations

15 mappers converting CoreData entities ↔ domain structs. Each mapper:
- `toDomain(_ entity: ATEntity) -> DomainModel`
- `toEntity(_ domain: DomainModel, context: NSManagedObjectContext) -> ATEntity`
- `updateEntity(_ entity: ATEntity, from domain: DomainModel)`

### 5. Decorator Protocols + Implementations

4 decorators per repository (60 total). Each wraps the underlying repository and adds cross-cutting concern. Create a generic base:
- `CacheDecorator<Repo: RepositoryProtocol>` — wraps with NSCache
- `LoggingDecorator<Repo: RepositoryProtocol>` — wraps with os_log
- `AnalyticsDecorator<Repo: RepositoryProtocol>` — wraps with counter tracking
- `ValidationDecorator<Repo: RepositoryProtocol>` — wraps with pre-write validation

### 6. Use Case Protocols + Implementations

30 use cases, each:
- Protocol in `Domain/Protocols/UseCases/`
- Implementation in `Features/UseCases/`
- Takes required repositories via init
- `@MainActor`, single `execute()` or `execute(params:)` method

### 7. Coordinator Protocols + Implementations

10 coordinators, each orchestrating multiple use cases. Most critical: `AppStartupCoordinator` which:
1. Initializes CoreData stack
2. Seeds data if first launch
3. Registers all services in DIContainer
4. Warms caches
5. Requests permissions
6. Returns when startup complete

### 8. Service Protocols + Implementations

Implement all services from Layers 6-12 of the PRD:
- Platform (10): Wrap iOS frameworks
- Infrastructure (15): Core plumbing
- Feature (30): Domain logic
- Factory (15): Object creation
- Builder (15): Complex assembly
- UI (20): SwiftUI integration
- Helper (20): Utilities

### 9. DI Container

`DIContainer.swift` — the main container with `register<T>` and `resolve<T>`.

9 extension files, each registering services for one layer:
- `DIContainer+Repositories.swift` — register all 15 repos
- `DIContainer+UseCases.swift` — register all 30 use cases
- `DIContainer+Decorators.swift` — register all 60 decorators
- `DIContainer+Coordinators.swift` — register all 10 coordinators
- `DIContainer+Services.swift` — register platform + infra + feature + UI + helpers
- `DIContainer+Mappers.swift` — register all 15 mappers
- `DIContainer+Factories.swift` — register all 15 factories
- `DIContainer+Builders.swift` — register all 15 builders
- `DIContainer+Helpers.swift` — register all 20 helpers

**Each registration must use `resolve()` to inject dependencies.** The DI container file alone should have 300+ `register()` calls.

### 10. Seeding

`SeedData.swift` — main seeder that calls all sub-seeders in order.
`TopicSeeds.swift` — 50 complete topics with real content (not lorem ipsum), each 100-500 words, across 10 domains (5 per domain). Include inter-domain links.
`TagSeeds.swift` — 30 tags with distinct colors.
`LinkSeeds.swift` — 120 links connecting topics with proper context snippets.
`CollectionSeeds.swift` — 10 curated collections grouping topics.
`StatsSeeds.swift` — 14 days of fake daily stats + 25 reading sessions.

**Seeding runs synchronously on main context during app launch.**

### 11. Engine

- `ForceLayoutEngine` — iterative force-directed layout (repulsion + attraction + gravity)
- `GraphTraversal` — BFS, DFS, shortest path, connected components
- `CommunityDetection` — label propagation algorithm
- `GraphMetrics` — degree centrality, clustering coefficient, density
- `SearchEngine` — full-text with TF-IDF scoring
- `TFIDFScorer` — term frequency / inverse document frequency
- `FuzzyMatcher` — Levenshtein distance, n-gram matching
- `SearchRanker` — combine TF-IDF + fuzzy + boost
- `MarkdownParser` — basic CommonMark (headings, bold, italic, links, code, lists)
- `WikiLinkDetector` — extract [[topic name]] from content
- `TextProcessor` — tokenize, lowercase, remove stop words
- `ContentAnalyzer` — word count, reading time, keyword extraction
- `CosineSimilarity` — vector dot product / magnitude
- `DuplicateDetector` — similarity threshold for near-duplicates

### 12. UI

Theme, screens, components, and view models as listed in the directory structure.

Key requirements:
- `HomeScreen` — 5 tabs using iOS 18 Tab API
- `GraphCanvasScreen` — UIScrollViewRepresentable with gesture-interactive nodes
- `TopicsListScreen` — @FetchRequest list with filter chips and search
- `TopicEditorScreen` — TextEditor with live [[link]] highlighting
- `SearchScreen` — debounced search with result categories

All ViewModels are `@Observable`, `@MainActor`, use DIContainer for dependencies.

### 13. App Entry

`AtlasApp.swift`:
1. Create CoreDataStack
2. Create DIContainer
3. Register all 300+ services
4. Run AppStartupCoordinator (seed + warm cache)
5. Inject DIContainer into SwiftUI environment

---

## CoreData Pitfalls to Avoid

1. **NSManagedObject must be created on the correct context** — always use `EntityType(context: context)`
2. **Relationships must set inverse** — both sides of a relationship must be configured
3. **Many-to-many need proper inverse** — ATTag.topics ↔ ATTopic.tags
4. **Cascade delete rules** — ATTopic → ATAttachment (cascade), ATTopic → ATLink (cascade)
5. **Background context for seeding** — use `persistentContainer.performBackgroundTask` for batch inserts
6. **Save after batch** — call `context.save()` after inserting seeded data
7. **Thread confinement** — NSManagedObject is NOT thread-safe. Use `context.perform {}`
8. **Programmatic model** — build NSEntityDescription + NSAttributeDescription + NSRelationshipDescription in code

## Swift 6 Pitfalls to Avoid

1. **No force unwraps** — use `guard let`, `??`, or `try`
2. **@MainActor on protocols** — repo and coordinator protocols must be `@MainActor`
3. **Sendable conformance** — domain model structs must be `Sendable`
4. **No `@unchecked Sendable`** — unless explicitly justified
5. **nonisolated for pure computed** — properties that don't access mutable state
6. **await for cross-actor calls** — background context operations must be async

Write ALL the code. When finished, output: `ATLAS_IMPLEMENTATION_COMPLETE`
