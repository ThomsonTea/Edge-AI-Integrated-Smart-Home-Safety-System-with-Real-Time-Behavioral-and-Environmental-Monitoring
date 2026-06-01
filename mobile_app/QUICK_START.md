# Clean Architecture Quick Start Guide

## 🎯 How to Use This Architecture

### Understanding the Layers

#### 1. **Services** (`lib/services/`)
Pure API/Storage operations. No UI, no logic.

```dart
// ✅ What services do:
final alerts = await alertService.fetchAlerts(); // Just fetch
final token = await tokenService.getToken();     // Just get
await authService.login(user, pass);              // Just call API
```

**When to modify services:**
- API endpoint changes
- New data source needed
- Storage implementation changes

---

#### 2. **ViewModels** (`lib/viewmodels/`)
State management + business logic. Orchestrates services.

```dart
// ✅ What ViewModels do:
// 1. Hold state
bool isLoading;
String? errorMessage;
List<dynamic> alerts;

// 2. Call services
await alertService.fetchAlerts();
await authService.login(user, pass);

// 3. Notify UI of state changes
notifyListeners();
```

**When to modify ViewModels:**
- Business logic changes (validation, calculation, flow)
- State management changes
- Need to orchestrate multiple services

---

#### 3. **UI** (`lib/ui/screens/` & `lib/ui/widgets/`)
Only rendering. Call ViewModel methods.

```dart
// ✅ What UI does:
// 1. Create ViewModel instance
final _viewModel = LoginViewModel();

// 2. Listen to ViewModel state
AnimatedBuilder(
  animation: _viewModel,
  builder: (context, child) {
    return Text(_viewModel.errorMessage ?? 'No error');
  },
)

// 3. Call ViewModel methods on user actions
onPressed: () => _viewModel.login(user, pass)
```

**When to modify UI:**
- Visual changes only
- Layout reorganization
- New widgets

---

## 📋 Common Tasks

### ❓ "Where do I add a new API call?"
1. Add to the appropriate **Service** (`auth_service.dart`, `alert_service.dart`, etc.)
2. Call it from **ViewModel**
3. Expose state in **ViewModel**
4. Render in **Screen**

### ❓ "Where do I put validation logic?"
→ In the **ViewModel**, not in the Screen

```dart
// ✅ GOOD: In ViewModel
Future<bool> login(String user, String pass) {
  if (user.isEmpty) {
    _errorMessage = 'Username required';
    notifyListeners();
    return false;
  }
  // ... continue
}

// ❌ BAD: In Screen
onPressed: () {
  if (_controller.text.isEmpty) {
    // Validation in UI!
  }
}
```

### ❓ "Where do I put business logic?"
→ In the **ViewModel**, orchestrating services

```dart
// ✅ GOOD: Logic in ViewModel
Future<void> initializeDashboard() async {
  _jwtToken = await _tokenService.getToken();    // Service call
  _alerts = await _alertService.fetchAlerts();   // Service call
  // Business logic: coordinate multiple services
}
```

### ❓ "Where do I handle errors?"
→ In **ViewModel**, expose to **UI**

```dart
// ✅ GOOD: Error handling in ViewModel
try {
  await authService.login(...);
} catch (e) {
  _errorMessage = e.toString();  // Store error
  notifyListeners();              // Notify UI
}

// UI renders based on ViewModel.errorMessage
```

### ❓ "How do I add a new feature?"

**Step 1: Create Service (if needed)**
```dart
// lib/services/device_service.dart
class DeviceService {
  Future<List<Device>> getDevices() async {
    // API call only
  }
}
```

**Step 2: Create ViewModel**
```dart
// lib/viewmodels/device_viewmodel.dart
class DeviceViewModel extends ChangeNotifier {
  final _deviceService = DeviceService();
  
  List<Device> _devices = [];
  bool _isLoading = false;
  
  Future<void> loadDevices() async {
    _isLoading = true;
    notifyListeners();
    
    _devices = await _deviceService.getDevices();
    
    _isLoading = false;
    notifyListeners();
  }
}
```

**Step 3: Create Screen**
```dart
// lib/ui/screens/device_screen.dart
class DeviceScreen extends StatefulWidget {
  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final _viewModel = DeviceViewModel();
  
  @override
  void initState() {
    super.initState();
    _viewModel.addListener(() => setState(() {}));
    _viewModel.loadDevices();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _viewModel.isLoading
          ? CircularProgressIndicator()
          : ListView.builder(
              itemCount: _viewModel.devices.length,
              itemBuilder: (context, index) {
                return DeviceListItem(_viewModel.devices[index]);
              },
            ),
    );
  }
}
```

**Step 4: Add route**
```dart
// routing/routes.dart
class AppRoutes {
  static const String devices = '/devices';
}

// routing/router.dart
GoRouter(
  routes: [
    GoRoute(path: AppRoutes.devices, builder: (context, state) => DeviceScreen()),
  ],
)
```

**Done!** New feature is fully decoupled and testable.

---

## 🧪 Testing Examples

### Testing ViewModel
```dart
test('LoginViewModel should call AuthService and save token', () async {
  // Mock services
  final mockAuthService = MockAuthService();
  final mockTokenService = MockTokenService();
  
  // Setup
  mockAuthService.mockLogin(token: 'abc123');
  
  // Execute
  final viewModel = LoginViewModel(authService: mockAuthService, tokenService: mockTokenService);
  await viewModel.login(username: 'user', password: 'pass');
  
  // Verify
  expect(viewModel.isSuccess, true);
  verify(mockTokenService.saveToken('abc123')).called(1);
});
```

### Testing Service
```dart
test('AuthService should make POST request with credentials', () async {
  final mockHttp = MockHttp();
  mockHttp.mockPost(response: {'token': 'abc123'});
  
  final service = AuthService(http: mockHttp);
  final result = await service.login(username: 'user', password: 'pass');
  
  expect(result.token, 'abc123');
  verify(mockHttp.post(Uri(path: '/profile/login'))).called(1);
});
```

### Testing UI
```dart
testWidgets('LoginScreen should show loading indicator while logging in', (tester) async {
  final mockViewModel = MockLoginViewModel();
  mockViewModel.isLoading = true;
  
  await tester.pumpWidget(LoginScreen(viewModel: mockViewModel));
  
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

---

## ⚠️ Common Mistakes (Don't Do This)

### ❌ API calls in UI
```dart
// ❌ WRONG
onPressed: () async {
  final response = await http.get(...);  // Direct HTTP in UI!
}

// ✅ RIGHT
onPressed: () => _viewModel.loadData()
```

### ❌ Storage access in Screen
```dart
// ❌ WRONG
final token = await storage.read(key: 'token');  // Direct storage in UI!

// ✅ RIGHT
final token = _viewModel.jwtToken;
```

### ❌ Business logic in UI
```dart
// ❌ WRONG
if (user.isEmpty) { /* validation */ }  // Logic in UI

// ✅ RIGHT
// Validation in ViewModel, UI just calls: _viewModel.login(user, pass)
```

### ❌ Creating services in every screen
```dart
// ❌ WRONG
class Screen1 { final authService = AuthService(); }
class Screen2 { final authService = AuthService(); }
// Multiple instances!

// ✅ RIGHT
// Create once in ViewModel or use dependency injection
```

### ❌ Mixing ViewModel concerns
```dart
// ❌ WRONG
class MegaViewModel extends ChangeNotifier {
  Future<void> doEverything() {
    // login, load alerts, control devices, ...
    // Too many responsibilities!
  }
}

// ✅ RIGHT
class LoginViewModel { ... }
class DashboardViewModel { ... }
class DeviceViewModel { ... }
// Each ViewModel has one job
```

---

## 📚 File Reference

### Services Layer
- `lib/services/token_service.dart` - JWT token management
- `lib/services/auth_service.dart` - Authentication API
- `lib/services/alert_service.dart` - Alert data API

### ViewModels Layer
- `lib/viewmodels/login_viewmodel.dart` - Login state + logic
- `lib/viewmodels/dashboard_viewmodel.dart` - Dashboard state + logic

### UI Layer
- `lib/ui/screens/login_screen.dart` - Login screen
- `lib/ui/screens/dashboard_screen.dart` - Dashboard screen
- `lib/ui/widgets/camera_widget.dart` - Camera feed widget
- `lib/ui/widgets/bottom_nav_bar.dart` - Navigation widget

### Config & Models
- `lib/config/app_config.dart` - API URLs and constants
- `lib/domain/models/login_result.dart` - API response models

---

## 🎓 SOLID Principles Applied

✅ **Single Responsibility**: Each class does one thing
✅ **Open/Closed**: Easy to extend without modifying existing code
✅ **Liskov Substitution**: Services are interchangeable
✅ **Interface Segregation**: Minimal, focused dependencies
✅ **Dependency Inversion**: Depend on abstractions (services), not implementations

---

## 🚀 Performance Tips

1. **Lazy load**: Load data only when needed
2. **Cache**: Store data in ViewModel state to avoid re-fetching
3. **Debounce**: Use debounceTime for search/filter operations
4. **Pagination**: Load alerts in batches, not all at once

---

## 📞 Debugging Checklist

- [ ] Is my API call in a Service?
- [ ] Is my business logic in a ViewModel?
- [ ] Is my UI 100% declarative (renders state)?
- [ ] Am I using ChangeNotifier for state changes?
- [ ] Are my services single-purpose?
- [ ] Can I test my ViewModel with mock services?

---

## Summary

**This architecture ensures:**
- ✅ UI is ALWAYS clean and simple
- ✅ Services are ALWAYS focused on API/storage
- ✅ ViewModels are ALWAYS the orchestrators
- ✅ New features can be added without touching existing code
- ✅ Everything is testable and maintainable

**Remember:** When in doubt, ask: "Which layer should this code go in?"
- **Storage/API call?** → Service
- **Business logic?** → ViewModel  
- **Rendering/Layout?** → UI
