# Atlas — Personal Knowledge Atlas (PRD)

## Overview

**Atlas** is a knowledge management app that treats your notes, bookmarks, and ideas as a traversable atlas of interconnected topics. Users build a personal Wikipedia with bi-directional links, auto-tagging, full-text search, and visual graph exploration.

**Key difference from Nexus (v1):** Atlas uses **CoreData** (not SwiftData) with manual migrations, a **service-oriented DI architecture** with 300+ registered services, and performs **heavy data seeding on launch** (200+ pre-loaded topics and connections).

## Target Platform
- iOS 18.0+, Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- iPhone 16 Pro (primary target)
- No third-party dependencies — everything built from scratch
- Tuist for project generation

---

## Architecture: Service Locator + CoreData

```
┌─────────────────────────────────────────────────┐
│                    AtlasApp                      │
│            (DIContainer bootstrap)               │
│                                                  │
│  ┌─────────────────────────────────────────┐    │
│  │           DIContainer                    │    │
│  │  ┌───────────────────────────────────┐  │    │
│  │  │  300+ services registered at init  │  │    │
│  │  │  - 15 Repository services          │  │    │
│  │  │  - 15 Cache decorators             │  │    │
│  │  │  - 15 Logging decorators           │  │    │
│  │  │  - 15 Analytics decorators          │  │    │
│  │  │  - 15 Validation services           │  │    │
│  │  │  - 15 Use case / interactor svcs    │  │    │
│  │  │  - 15 Mapping / transformer svcs    │  │    │
│  │  │  - 10 Coordinator services          │  │    │
│  │  │  - 10 Platform services             │  │    │
│  │  │  - 10 Infrastructure services       │  │    │
│  │  │  - 30 Feature services              │  │    │
│  │  │  - 15 Factory services              │  │    │
│  │  │  - 20 UI services                   │  │    │
│  │  │  - 15 Builder services              │  │    │
│  │  │  - 20 Helper / Utility services     │  │    │
│  │  │  - 50+ more specialized services    │  │    │
│  │  └───────────────────────────────────┘  │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ CoreData │  │  Engine   │  │   SwiftUI    │  │
│  │  Stack   │  │ (Graph +  │  │    Views     │  │
│  │          │  │  Search)  │  │              │  │
│  └──────────┘  └──────────┘  └──────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Data Model (CoreData Entities)

### Core Entities

**`ATTopic`** — The central entity. A knowledge topic/article.
- `id: UUID` — unique identifier
- `title: String` — topic title (indexed)
- `content: String` — full markdown content
- `summary: String` — auto-generated summary (first 200 chars)
- `createdAt: Date` — creation timestamp (indexed)
- `updatedAt: Date` — last modification timestamp
- `topicType: Int16` — enum: article(0), bookmark(1), idea(2), snippet(3), quote(4)
- `priority: Int16` — 0=normal, 1=important, 2=critical
- `isFavorite: Bool` — user flag
- `wordCount: Int32` — cached word count
- `readingTimeMinutes: Double` — estimated reading time
- `version: Int32` — edit version for sync conflict resolution
- Relationships:
  - `tags: [ATTag]` — many-to-many (inverse: ATTag.topics)
  - `outgoingLinks: [ATLink]` — one-to-many (inverse: ATLink.source)
  - `incomingLinks: [ATLink]` — one-to-many (inverse: ATLink.target)
  - `attachments: [ATAttachment]` — one-to-many, cascade (inverse: ATAttachment.topic)
  - `collections: [ATCollection]` — many-to-many (inverse: ATCollection.topics)
  - `metadata: ATMetadata?` — one-to-one, cascade (inverse: ATMetadata.topic)

**`ATLink`** — A directed connection between two topics.
- `id: UUID`
- `contextSnippet: String?` — surrounding text where link appears
- `linkType: Int16` — enum: reference(0), embed(1), seeAlso(2), contradiction(3), supports(4)
- `weight: Double` — 0.0 to 1.0, auto-calculated
- `createdAt: Date`
- Relationships:
  - `source: ATTopic` — many-to-one (inverse: ATTopic.outgoingLinks)
  - `target: ATTopic` — many-to-one (inverse: ATTopic.incomingLinks)

**`ATTag`** — A tag/category for topics.
- `id: UUID`
- `name: String` — unique, indexed
- `colorHex: String` — default "#6C5CE7"
- `usageCount: Int32` — cached count
- `createdAt: Date`
- Relationships:
  - `topics: [ATTopic]` — many-to-many (inverse: ATTopic.tags)

**`ATAttachment`** — Binary data attached to a topic.
- `id: UUID`
- `data: Data` — binary content
- `thumbnailData: Data?` — compressed thumbnail
- `fileName: String?`
- `mimeType: String`
- `attachmentType: Int16` — enum: image(0), audio(1), file(2), video(3)
- `fileSize: Int64` — bytes
- `createdAt: Date`
- Relationships:
  - `topic: ATTopic` — many-to-one (inverse: ATTopic.attachments)

**`ATCollection`** — A named group of topics (like a playlist for knowledge).
- `id: UUID`
- `name: String`
- `icon: String?` — SF Symbol name
- `colorHex: String`
- `sortOrder: Int32`
- `isSmart: Bool` — if true, uses a predicate to auto-populate
- `smartPredicate: String?` — serialized predicate for smart collections
- `createdAt: Date`
- `updatedAt: Date`
- Relationships:
  - `topics: [ATTopic]` — many-to-many (inverse: ATTopic.collections)

**`ATMetadata`** — Extended metadata for a topic.
- `id: UUID`
- `sourceURL: String?`
- `author: String?`
- `languageCode: String?`
- `lastSyncedAt: Date?`
- `checksum: String?` — content hash for sync
- `readCount: Int32`
- `timeSpentReading: Double` — seconds
- Relationships:
  - `topic: ATTopic` — one-to-one (inverse: ATTopic.metadata)

### Sync & Infrastructure Entities

**`ATSyncRecord`** — Tracks changes for iCloud sync.
- `id: UUID`
- `entityID: UUID`
- `entityType: String` — "Topic", "Tag", etc.
- `changeType: Int16` — create(0), update(1), delete(2)
- `timestamp: Date`
- `conflictResolution: Int16` — none(0), localWins(1), remoteWins(2), merge(3)

**`ATSearchIndex`** — Denormalized search data.
- `id: UUID`
- `entityID: UUID`
- `entityType: String`
- `searchableText: String` — concatenated searchable content
- `boost: Double` — search relevance multiplier

**`ATUserPreference`** — Key-value app preferences.
- `id: UUID`
- `key: String` — unique, indexed
- `valueData: Data` — encoded value
- `preferenceType: Int16` — string(0), int(1), double(2), bool(3), data(4)
- `updatedAt: Date`

**`ATNotification`** — Scheduled in-app notifications.
- `id: UUID`
- `title: String`
- `body: String`
- `scheduledDate: Date`
- `notificationType: Int16` — reminder(0), suggestion(1), insight(2)
- `entityID: UUID?`
- `isRead: Bool`
- `createdAt: Date`

### Graph Engine Entities

**`ATCluster`** — Auto-detected topic cluster.
- `id: UUID`
- `name: String?` — auto-generated label
- `centroidX: Double`
- `centroidY: Double`
- `topicCount: Int32`
- `avgLinkDensity: Double`
- `detectedAt: Date`
- Relationships:
  - `topics: [ATTopic]` — many-to-many

**`ATGraphLayout`** — Cached force-directed layout positions.
- `id: UUID`
- `topicID: UUID`
- `positionX: Double`
- `positionY: Double`
- `layoutVersion: Int32`
- `computedAt: Date`

### Statistics Entities

**`ATReadingSession`** — Tracks time spent on a topic.
- `id: UUID`
- `topic: ATTopic` — many-to-one
- `startedAt: Date`
- `endedAt: Date?`
- `durationSeconds: Double`
- `scrollDepth: Double` — 0.0 to 1.0

**`ATDailyStat`** — Aggregated daily statistics.
- `id: UUID`
- `date: Date` — unique, indexed
- `topicsCreated: Int32`
- `topicsRead: Int32`
- `linksCreated: Int32`
- `totalReadingTime: Double`
- `wordsWritten: Int32`
- `searchesPerformed: Int32`

### ER Diagram

```
ATTopic (central)
  ├── outgoingLinks → [ATLink] → target → ATTopic
  ├── incomingLinks → [ATLink] → source → ATTopic
  ├── tags → [ATTag] → topics → [ATTopic]
  ├── attachments → [ATAttachment]
  ├── collections → [ATCollection] → topics → [ATTopic]
  ├── metadata → ATMetadata
  └── clusters → [ATCluster]

ATSyncRecord, ATSearchIndex, ATUserPreference (standalone)
ATNotification, ATReadingSession, ATDailyStat (standalone)
ATGraphLayout (per-topic layout cache)
```

---

## Service Architecture (300+ Services)

### Layer 1: Repository Services (15)
Each CoreData entity gets a repository: `TopicRepository`, `LinkRepository`, `TagRepository`, `AttachmentRepository`, `CollectionRepository`, `MetadataRepository`, `SyncRecordRepository`, `SearchIndexRepository`, `UserPreferenceRepository`, `NotificationRepository`, `ClusterRepository`, `GraphLayoutRepository`, `ReadingSessionRepository`, `DailyStatRepository`, `GenericEntityRepository`

Each repository protocol defines:
- `@MainActor` + `Sendable`
- CRUD operations
- Entity-specific queries (fetchOrphans, fetchLinked, fetchRecent, etc.)
- Batch operations (bulkCreate, bulkDelete)
- `Context: NSManagedObjectContext`

### Layer 2: Decorator Services (60)
Each repository gets 4 decorators:
- **CacheDecorator** — in-memory NSCache for hot entities
- **LoggingDecorator** — logs all operations for debugging
- **AnalyticsDecorator** — tracks operation counts and timing
- **ValidationDecorator** — validates entities before write

### Layer 3: Use Case / Interactor Services (30)
Business logic that orchestrates repositories:
- `CreateTopicUseCase` — creates topic + auto-tags + indexes
- `LinkTopicsUseCase` — creates bidirectional link + updates weights
- `AutoTagUseCase` — NLP-based auto-tagging
- `SearchTopicsUseCase` — full-text search with boosting
- `BuildGraphUseCase` — computes force-directed layout
- `DetectClustersUseCase` — community detection
- `CalculateStatsUseCase` — aggregates daily stats
- `SyncChangesUseCase` — CloudKit sync orchestration
- `ResolveConflictUseCase` — merge strategies
- `ExportDataUseCase` — JSON/Markdown export
- `ImportDataUseCase` — parse and import
- `SeedDataUseCase` — initial data population
- `TrackReadingUseCase` — reading session management
- `GenerateSuggestionsUseCase` — AI-powered topic suggestions
- `ProcessAttachmentUseCase` — thumbnail generation
- `ValidateEntityUseCase` — cross-entity validation
- `BuildSearchIndexUseCase` — reindex all topics
- `ComputeSimilarityUseCase` — topic similarity scoring
- `ManageCollectionsUseCase` — smart collection evaluation
- `ScheduleNotificationsUseCase` — reminder scheduling
- `CleanupOrphansUseCase` — remove dangling references
- `ComputeReadingTimeUseCase` — estimate reading time
- `AnalyzeGraphUseCase` — centrality, density metrics
- `BackupDataUseCase` — full backup creation
- `RestoreDataUseCase` — backup restoration
- `MergeTopicsUseCase` — combine duplicate topics
- `GenerateSummaryUseCase` — topic summary extraction
- `TrackDailyActivityUseCase` — daily stat aggregation
- `OptimizeStorageUseCase` — remove old thumbnails, compact
- `WarmCacheUseCase` — preload frequently accessed data

### Layer 4: Mapping / Transformer Services (15)
Convert between layers:
- `TopicEntityMapper` — ATTopic ↔ Topic (domain model)
- `LinkEntityMapper` — ATLink ↔ Link
- `TagEntityMapper` — ATTag ↔ Tag
- `AttachmentEntityMapper` — ATAttachment ↔ Attachment
- `CollectionEntityMapper` — ATCollection ↔ Collection
- `MetadataEntityMapper` — ATMetadata ↔ Metadata
- `SearchResultMapper` — ATSearchIndex → SearchResult
- `NotificationMapper` — ATNotification → AppNotification
- `SyncRecordMapper` — ATSyncRecord → SyncChange
- `StatisticsMapper` — ATDailyStat → DailyStatistics
- `GraphLayoutMapper` — ATGraphLayout → LayoutPosition
- `ClusterMapper` — ATCluster → TopicCluster
- `ReadingSessionMapper` — ATReadingSession → ReadingActivity
- `PreferenceMapper` — ATUserPreference → UserPreference
- `CloudKitRecordMapper` — CKRecord ↔ domain models

### Layer 5: Coordinator Services (10)
Orchestrate multi-use-case flows:
- `AppStartupCoordinator` — seeds data + registers services + warms caches
- `TopicEditingCoordinator` — edit + auto-tag + link detection + index
- `GraphVisualizationCoordinator` — build graph + compute layout + detect clusters
- `SyncCoordinator` — detect changes + push + pull + resolve conflicts
- `SearchCoordinator` — query + rank + filter + suggest
- `OnboardingCoordinator` — first-launch experience
- `ExportCoordinator` — select data + transform + write file
- `NotificationCoordinator` — schedule + present + track
- `BackupCoordinator` — create backup + verify + store
- `DeepLinkCoordinator` — parse URL + navigate + present

### Layer 6: Platform Services (10)
Wrap iOS frameworks:
- `LocationPlatformService` — CoreLocation authorization
- `SpotlightIndexingService` — CoreSpotlight CSSearchableIndex
- `WidgetUpdateService` — WidgetKit timeline reload
- `ShortcutService` — AppIntents registration
- `NotificationScheduleService` — UNUserNotificationCenter
- `CloudKitService` — CKContainer operations
- `FileSystemPlatformService` — FileManager wrappers
- `KeychainService` — Security framework
- `BackgroundTaskService` — BGTaskScheduler registration
- `HapticFeedbackService` — UIImpactFeedbackGenerator

### Layer 7: Infrastructure Services (15)
Core app plumbing:
- `CoreDataStackService` — NSPersistentContainer, migration, contexts
- `DIContainerService` — service registration and resolution
- `ConfigurationService` — app config from Info.plist + defaults
- `SessionManagerService` — user session state
- `CacheManagerService` — NSCache coordination
- `FeatureFlagService` — feature toggles
- `TelemetryService` — performance monitoring
- `ErrorReportingService` — error aggregation and reporting
- `LoggingService` — unified logging (os_log)
- `MainThreadGuaranteeService` — @MainActor enforcement helpers
- `MemoryWarningService` — memory pressure handling
- `ReachabilityService` — network status monitoring
- `ThreadingService` — task dispatch helpers
- `SerializationService` — JSON/Codable helpers
- `DateFormattingService` — consistent date formatting

### Layer 8: Feature Services (30)
Domain-specific business logic:
- `AutoLinkDetectionService` — detect [[wikilinks]] in content
- `SimilarityScoringService` — cosine similarity on TF-IDF vectors
- `GraphMetricsService` — degree centrality, betweenness, clustering coefficient
- `ForceLayoutService` — force-directed graph layout algorithm
- `CommunityDetectionService` — Louvain/label-propagation clustering
- `TextProcessingService` — tokenization, stemming, stop words
- `SearchRankingService` — BM25 scoring
- `FuzzyMatchingService` — Levenshtein distance, n-gram matching
- `SuggestionEngineService` — topic recommendation based on reading history
- `ContentAnalysisService` — word count, reading time, keyword extraction
- `TagAutoCompletionService` — tag suggestion from partial input
- `SmartCollectionService` — predicate evaluation for smart collections
- `ConflictResolutionService` — 3-way merge strategy
- `IncrementalSyncService` — delta change detection
- `BatchImportService` — CSV/JSON bulk import
- `BatchExportService` — filtered export in multiple formats
- `MarkdownParsingService` — CommonMark parser
- `WikiLinkParsingService` — extract [[links]] from content
- `ThumbnailGenerationService` — image/video thumbnail creation
- `StorageAnalysisService` — storage usage breakdown
- `ReadingTrackerService` — scroll depth + time tracking
- `DailyDigestService` — daily summary generation
- `AchievementTrackingService` — usage milestones
- `GraphTraversalService` — BFS, DFS, shortest path
- `LinkWeightCalculationService` — co-occurrence + recency + frequency
- `TopicMergeStrategyService` — field-by-field merge logic
- `DuplicateDetectionService` — similar topic identification
- `ContentValidationService` — required fields, length limits
- `URLValidationService` — bookmark URL checking
- `BackupVerificationService` — backup integrity checking

### Layer 9: Factory Services (15)
Object creation:
- `TopicFactory` — create ATTopic with defaults
- `LinkFactory` — create ATLink with validation
- `TagFactory` — create ATTag with color generation
- `CollectionFactory` — create ATCollection with icon
- `AttachmentFactory` — create ATAttachment with thumbnail
- `MetadataFactory` — create ATMetadata from URL
- `NotificationFactory` — create ATNotification from template
- `SearchIndexFactory` — create ATSearchIndex from topic
- `ClusterFactory` — create ATCluster from topic group
- `GraphLayoutFactory` — create ATGraphLayout with position
- `ReadingSessionFactory` — create ATReadingSession
- `DailyStatFactory` — create ATDailyStat for date
- `SyncRecordFactory` — create ATSyncRecord for change
- `UserPreferenceFactory` — create ATUserPreference
- `PredicateFactory` — create NSPredicate for queries

### Layer 10: UI Services (20)
SwiftUI integration:
- `ThemeService` — colors, typography, spacing tokens
- `NavigationService` — programmatic navigation
- `ToastPresentationService` — in-app toast messages
- `SheetPresentationService` — sheet/detent management
- `AlertPresentationService` — alert dialogs
- `ImageLoadingService` — async image loading + caching
- `PermissionRequestService` — camera, photo, notification permissions
- `KeyboardManagementService` — keyboard avoidance
- `AccessibilityService` — VoiceOver, Dynamic Type
- `LocalizationService` — string lookup
- `AnimationService` — reusable animation configs
- `ListPaginationService` — lazy loading large lists
- `PullToRefreshService` — data refresh coordination
- `SearchBarService` — search state management
- `FilterChipService` — filter state management
- `ContextMenuService` — context menu actions
- `ShareSheetService` — UIActivityViewController
- `FilePickerService` — document picker
- `PasteboardService` — clipboard read/write
- `ReviewPromptService` — App Store review request

### Layer 11: Builder Services (15)
Complex object assembly:
- `TopicDetailViewModelBuilder` — assemble topic + links + tags + stats
- `GraphViewModelBuilder` — assemble nodes + edges + layout + clusters
- `SearchResultBuilder` — assemble ranked results with highlights
- `CollectionDetailViewModelBuilder` — assemble collection + sorted topics
- `StatisticsViewModelBuilder` — assemble daily stats + trends
- `EditTopicViewModelBuilder` — assemble topic + suggestions + recent tags
- `NotificationListViewModelBuilder` — assemble notifications grouped by date
- `ExportConfigurationBuilder` — assemble export options
- `SyncStatusViewModelBuilder` — assemble sync state + conflicts
- `OnboardingStepBuilder` — assemble onboarding steps
- `WidgetConfigurationBuilder` — assemble widget data
- `DeepLinkDestinationBuilder` — parse deep link → destination
- `BackupSummaryBuilder` — assemble backup metadata
- `ShareContentBuilder` — format content for sharing
- `BulkEditConfigurationBuilder` — assemble bulk edit options

### Layer 12: Helper / Utility Services (20+)
Cross-cutting concerns:
- `UUIDGeneratorService` — deterministic UUIDs for seeding
- `ColorPaletteService` — generate consistent colors
- `StringNormalizationService` — Unicode normalization
- `MarkdownRenderingService` — attributed string from markdown
- `DateRelativeFormatterService` — "2 hours ago" formatting
- `NumberFormatterService` — localized number formatting
- `ByteCountFormatterService` — "2.3 MB" formatting
- `DurationFormatterService` — "3 min read" formatting
- `SortDescriptorService` — dynamic sort descriptors
- `FilterPredicateService` — dynamic NSPredicate building
- `PaginationCalculatorService` — page/offset math
- `RateLimiterService` — debounce/throttle
- `RetryPolicyService` — exponential backoff
- `QueueService` — serial/concurrent operation queues
- `WeakReferenceService` — weak wrapper for closures
- `NotificationCenterService` — typed NotificationCenter
- `UserDefaultsService` — typed UserDefaults
- `EnvironmentValueService` — SwiftUI environment injection
- `PreviewDataService` — SwiftUI preview mock data
- `SnapshotTestingService` — view snapshot helpers

### Total: 300+ services

---

## Launch Seeding

On first launch, `AppStartupCoordinator` seeds the database via `SeedDataUseCase`:

### Seeded Data

| Entity | Count | Details |
|--------|-------|---------|
| ATTopic | 50 | Knowledge topics across 5 domains |
| ATTag | 30 | Category tags |
| ATLink | 120 | Cross-topic connections |
| ATCollection | 10 | Curated topic groups |
| ATDailyStat | 14 | 2 weeks of fake statistics |
| ATUserPreference | 15 | Default preferences |
| ATNotification | 5 | Welcome notifications |
| ATReadingSession | 25 | Simulated reading history |
| ATGraphLayout | 50 | Pre-computed layout positions |
| ATCluster | 8 | Auto-detected topic clusters |
| ATSearchIndex | 50 | Pre-built search indices |
| **Total** | **382** | **records inserted synchronously on launch** |

### Seed Domains (10 topics each)
1. Machine Learning & AI
2. Software Architecture
3. iOS Development
4. Distributed Systems
5. Design Patterns
6. Data Structures & Algorithms
7. DevOps & Infrastructure
8. Product Design
9. Mathematics & Statistics
10. Personal Productivity

### Startup Sequence (measured)

```
1. CoreDataStackService.initialize()          — create NSPersistentContainer
2. DIContainerService.registerAll()           — register 300+ services
3. SeedDataUseCase.execute()                  — insert 382 records
4. CacheWarmService.warm()                    — preload hot entities
5. SpotlightIndexingService.indexAll()        — CoreSpotlight indexing
6. WidgetUpdateService.reloadTimelines()      — WidgetKit refresh
7. BackgroundTaskService.register()           — BGTaskScheduler
8. NotificationScheduleService.requestAccess() — UNUserNotification
9. ThemeService.apply()                       — load saved theme
10. NavigationService.restoreState()          — state restoration
```

---

## DI Container Design

```swift
@MainActor
final class DIContainer: Sendable {
    private var services: [String: Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping (DIContainer) -> T) {
        services[String(describing: type)] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        guard let factory = services[String(describing: type)] as? (DIContainer) -> T else {
            fatalError("Service not registered: \(type)")  // Only allowed here
        }
        return factory(self)
    }
}

// Registration happens in DIContainer+Registration.swift extension:
extension DIContainer {
    func registerAllServices(
        coreDataStack: CoreDataStackService,
        configuration: ConfigurationService
    ) {
        // Layer 1: Repositories (15)
        register(TopicRepository.self) { c in TopicRepositoryImpl(context: coreDataStack.mainContext) }
        register(LinkRepository.self) { c in LinkRepositoryImpl(context: coreDataStack.mainContext) }
        // ... 300+ registrations
    }
}
```

---

## UI Screens

### Tab Structure
1. **Atlas** — Graph visualization (force-directed)
2. **Topics** — Topic list with filters
3. **Search** — Full-text search with suggestions
4. **Activity** — Reading stats and daily digest
5. **Settings** — Preferences, export, sync

### Key Screens

**Topic Detail** — Markdown rendering, backlinks, related topics, edit-in-place
**Graph Canvas** — Pan/zoom, node/edge rendering, cluster highlighting, minimap
**Topic Editor** — Markdown editor with [[link]] autocomplete, tag chips, attachment picker
**Statistics** — Reading streaks, activity heatmap, top tags, knowledge coverage

---

## Color & Theme

```
Dark Theme:
  Background:    #0A0A0F
  Card:          #1A1A24
  Border:        #2A2A35
  Text:          #F0F0F5
  TextSecondary: #8888A0
  Accent:        #6C5CE7
  Success:       #00D68F
  Warning:       #FFB800
  Error:         #FF3B5C
  
  Topic Colors by Type:
    Article:  #6C5CE7 (purple)
    Bookmark: #0984E3 (blue)
    Idea:     #E17055 (coral)
    Snippet:  #00B894 (green)
    Quote:    #FDCB6E (gold)
```

---

## Constraints

- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- No third-party dependencies
- No force unwraps (except DIContainer.resolve — one allowed fatalError)
- @MainActor on all ViewModels, Repositories, and Coordinators
- CoreData: NSPersistentContainer with both main and background contexts
- All services must be `Sendable` or `@MainActor`
- No `@unchecked Sendable` unless explicitly justified in comment
