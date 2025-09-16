# CWSDirectoryMaps

A comprehensive SwiftUI navigation app for shopping malls and large buildings, featuring interactive floor maps, intelligent pathfinding, and real-time turn-by-turn navigation.

## 📱 Features

### 🗺️ **Interactive Multi-Floor Maps**
- Browse detailed floor plans for all building levels
- Zoom and pan functionality with smooth gestures
- Real-time floor switching with animated transitions
- Visual store markers and facility indicators

### 🔍 **Smart Search & Discovery**
- Intelligent search for stores, restaurants, and facilities
- Category-based filtering (Shop, F&B, Facilities, Lobbies)
- Special search queries:
  - "baby room" → Restrooms with changing facilities
  - "wheelchair" → Information desks with accessibility services
  - "charging station" → Phone charging locations
  - "atm" → Banking and ATM services

### 🧭 **Advanced Navigation**
- **Multi-floor pathfinding** with elevator/escalator routing
- **Real-time turn-by-turn directions** with visual landmarks
- **Travel mode selection** (escalator vs elevator preferences)
- **Distance and time estimates** with dynamic recalculation
- **Floor transition notifications** for seamless navigation

### 📍 **Location Services**
- "From Here" and "To Here" navigation options
- Current location tracking on maps
- Smart location swapping and route reversal
- Visual path highlighting with progress indicators

## 🏗️ Architecture

### **MVVM Pattern**
```
Views/ (SwiftUI)
├── HomePageView
├── NavigationModalView
├── DirectionView
└── TenantDetailModalView

ViewModels/
└── DirectoryViewModel

Models/
├── Store
├── Graph & Node
├── Floor
└── NavigationState

Services/
├── DataManager
├── PathfindingManager
├── StoreService
└── NetworkManager
```

### **Core Components**

- **DataManager**: Handles multi-floor map data loading and preprocessing
- **PathfindingManager**: A* algorithm implementation with multi-floor support
- **DirectoryViewModel**: Centralized state management for search and navigation
- **IntegratedMapView**: Interactive map rendering with real-time overlays

## 🚀 Getting Started

### Prerequisites
- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/CWSDirectoryMaps.git
   cd CWSDirectoryMaps
   ```

2. **Open in Xcode**
   ```bash
   open CWSDirectoryMaps.xcodeproj
   ```

3. **Configure API Settings**
   Update `APIConfiguration.swift` with your backend URL:
   ```swift
   var baseURL: String {
       return "https://your-api-domain.com"
   }
   ```

4. **Add Map Data**
   Place your JSON map files in the project:
   ```
   Resources/
   ├── ground_path.json
   ├── 1st_path.json
   ├── 2nd_path.json
   └── ...
   ```

5. **Run the app**
   - Select your target device
   - Press `Cmd + R` to build and run

## 📁 Project Structure

```
CWSDirectoryMaps/
├── App/
│   ├── CWSDirectoryMapsApp.swift
│   └── ContentView.swift
├── Features/
│   ├── HomePage/
│   │   ├── View/
│   │   └── ViewModel/
│   ├── DirectionModal/
│   ├── TenantDetailModal/
│   └── Navigation/
├── Components/
│   ├── IntegratedMapView.swift
│   ├── SearchBarView.swift
│   ├── CategoryFilterView.swift
│   └── StoreRowView.swift
├── Network/
│   ├── Services/
│   ├── Endpoints/
│   └── Base/
├── Models/
│   ├── Store.swift
│   ├── Models.swift
│   └── APIModels.swift
└── Resources/
    ├── Maps/
    └── Images/
```

## 🔧 Configuration

### **API Configuration**
```swift
// APIConfiguration.swift
struct APIConfiguration {
    static let shared = APIConfiguration()
    
    var baseURL: String = "https://your-api.com"
    var useAPI: Bool = true
    var requestTimeout: TimeInterval = 30.0
}
```

### **Map Data Format**
Maps should be provided as JSON files with this structure:
```json
{
  "metadata": {
    "totalNodes": 1250,
    "totalEdges": 1800,
    "nodeTypes": ["circle-center", "path-point", "rect-corner"],
    "edgeTypes": ["line"]
  },
  "nodes": [
    {
      "id": "node_1",
      "x": 100.5,
      "y": 200.3,
      "type": "circle-center",
      "label": "store_name",
      "parentLabel": "store_name"
    }
  ],
  "edges": [
    {
      "source": "node_1",
      "target": "node_2",
      "type": "line"
    }
  ]
}
```

## 🎯 Usage Examples

### **Basic Navigation**
```swift
// Start navigation from code
let startStore = Store(name: "Entrance A", ...)
let endStore = Store(name: "Starbucks", ...)

pathfindingManager.runPathfinding(
    startStore: startStore,
    endStore: endStore,
    unifiedGraph: dataManager.unifiedGraph
)
```

### **Search Implementation**
```swift
// Search for stores
viewModel.searchText = "coffee"
// Results will automatically filter to coffee shops

// Special facility search
viewModel.searchText = "baby room"
// Returns restrooms with baby changing facilities
```

### **Custom Travel Modes**
```swift
// Set travel preference
pathfindingManager.updateTravelMode(.escalator) // or .elevator
```

## 📊 Performance Features

- **Lazy loading** of map data per floor
- **Debounced search** (300ms) for smooth typing
- **Efficient pathfinding** with A* algorithm optimization
- **Memory management** with proper cleanup
- **Background processing** for heavy computations

## 🐛 Troubleshooting

### **Common Issues**

**Map not loading:**
- Check JSON file format and placement
- Verify node/edge data structure
- Ensure proper file naming convention

**Navigation not working:**
- Confirm `graphLabel` mapping between stores and map nodes
- Check unified graph construction
- Verify floor transition connections

**Search not returning results:**
- Check API connectivity
- Verify store data loading
- Review search normalization logic

**Performance issues:**
- Reduce map complexity if needed
- Check for memory leaks in navigation flow
- Optimize image loading

## 👥 Contributors

### **Core Team**

#### **🚀 Tech Lead**
- **[Agus Darmawan](https://github.com/agus-darmawan)** - Technical Architecture & Project Leadership

#### **💻 Software Developers**
- **[Louis Fernando](https://github.com/LouisFernando1204)** - Software Engineer & UI/UX Implementation
- **[Daniel Fernando](https://github.com/danielfernandoo07)** - Software Engineer & UI/UX Implementation
- **[Steven Go](https://github.com/xAnonym101)** - UI/UX Implementation & Performance

#### **🎨 Designer**
- **[Jessica Tisha](https://www.linkedin.com/in/jessica-tisha-193967275/)** - UI/UX Design & User Experience

---

### **How to Contribute**

### **How to Contribute**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### **Code Style**
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain MVVM architecture
- Add documentation for public APIs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- SwiftUI framework for modern iOS development
- A* pathfinding algorithm implementation
- Community contributions and feedback
