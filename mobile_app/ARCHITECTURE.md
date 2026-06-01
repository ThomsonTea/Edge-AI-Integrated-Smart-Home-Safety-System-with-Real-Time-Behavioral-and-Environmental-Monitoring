# Clean Architecture Refactoring - Smart Home Security App

## Overview
This Flutter app has been refactored to follow a clean architecture pattern with strict separation of concerns:
- **UI Layer**: Purely declarative, no business logic
- **ViewModel Layer**: State management and business logic orchestration
- **Service Layer**: API calls and data persistence only

## Architecture Diagram

```
UI (Screens + Widgets)
    ↓ (calls methods & listens to state)
ViewModel (StateManagement + Business Logic)
    ↓ (calls methods)
Services (API + Storage)
    ↓ (HTTP/Secure Storage)
External APIs / Device Storage
```

## Project Structure

```
lib/
├── config/                          # Configuration
│   └── app_config.dart              # API URLs, constants
├── domain/
│   └── models/                      # Data models
│       └── login_result.dart        # API response models
├── services/                        # Business logic & API layer
│   ├── token_service.dart           # Token storage/retrieval (new)
│   ├── auth_service.dart            # Authentication API calls
│   └── alert_service.dart           # Alert data fetching
├── viewmodels/                      # State & business logic (new)
│   ├── login_viewmodel.dart         # Login state + logic (new)
│   └── dashboard_viewmodel.dart     # Dashboard state + logic (new)
├── ui/
│   ├── screens/                     # Full-page screens (new structure)
│   │   ├── login_screen.dart        # Login UI (refactored)
│   │   └── dashboard_screen.dart    # Dashboard UI (refactored)
│   └── widgets/                     # Reusable widgets
│       ├── camera_widget.dart       # Live camera feed
│       └── bottom_nav_bar.dart      # Navigation
├── routing/                         # Navigation (existing)
├── main.dart                        # App entry point (updated)
```

## Key Changes

### 1. New Service: TokenService
**Location**: `lib/services/token_service.dart`

Centralizes all JWT token operations:
```dart
// Get token
String? token = await tokenService.getToken();

// Save token
await tokenService.saveToken(token);

// Delete token (logout)
await tokenService.deleteToken();

// Check if token exists
bool hasToken = await tokenService.hasToken();
```

**Why**: Separates token management from UI and service logic, making it reusable and testable.

### 2. Refactored AuthService
**Location**: `lib/services/auth_service.dart`

- ✅ Removed `FlutterSecureStorage` import (now uses TokenService)
- ✅ Removed `logout()` method (moved to TokenService)
- ✅ Keeps only API calls (`login()` method)
- ✅ Cleaner, focused responsibility

### 3. Refactored AlertService
**Location**: `lib/services/alert_service.dart`

- ✅ Uses `TokenService` instead of direct storage access
- ✅ Keeps only API calls (`fetchAlerts()` method)
- ✅ Clean dependency injection through TokenService

### 4. New ViewModel: LoginViewModel
**Location**: `lib/viewmodels/login_viewmodel.dart`

Handles all login logic and state:
```dart
class LoginViewModel extends ChangeNotifier {
  // State
  bool isLoading;
  String? errorMessage;
  bool isSuccess;

  // Business Logic
  Future<bool> login({required String username, required String password})
  void clearError()
}
```

**Responsibilities**:
- Manage login loading state
- Orchestrate AuthService + TokenService calls
- Emit state changes via `notifyListeners()`

### 5. New ViewModel: DashboardViewModel
**Location**: `lib/viewmodels/dashboard_viewmodel.dart`

Handles dashboard state and data loading:
```dart
class DashboardViewModel extends ChangeNotifier {
  // State
  List<dynamic> alerts;
  bool isLoading;
  String? errorMessage;
  String? jwtToken;

  // Business Logic
  Future<void> initializeDashboard()
  Future<void> loadAlerts()
  Future<void> logout()
}
```

**Responsibilities**:
- Initialize dashboard (get token + load alerts)
- Manage alerts loading state
- Handle logout
- Expose state for UI to render

### 6. Refactored LoginScreen
**Location**: `lib/ui/screens/login_screen.dart`

**Before**: Direct AuthService calls, secure storage access, business logic
**After**: 
- ✅ Creates LoginViewModel instance
- ✅ Uses `AnimatedBuilder` to listen to ViewModel state changes
- ✅ Only calls ViewModel methods on user actions
- ✅ No storage access, no API calls, no business logic
- ✅ 100% declarative UI

```dart
// UI listens to ViewModel
AnimatedBuilder(
  animation: _viewModel,
  builder: (context, child) {
    return ElevatedButton(
      onPressed: _viewModel.isLoading ? null : _handleLogin,
      child: _viewModel.isLoading
          ? CircularProgressIndicator()
          : Text('Login'),
    );
  },
)
```

### 7. Refactored DashboardScreen
**Location**: `lib/ui/screens/dashboard_screen.dart`

**Before**: Direct AlertService calls, token management, state management
**After**:
- ✅ Creates DashboardViewModel instance
- ✅ Listens to ViewModel state changes via `setState()`
- ✅ Only calls ViewModel methods on user actions
- ✅ No storage access, no API calls, no business logic
- ✅ Renders state declaratively

```dart
// UI renders based on ViewModel state
if (_viewModel.isLoading) {
  return CircularProgressIndicator();
}
if (_viewModel.errorMessage != null) {
  return ErrorWidget();
}
return AlertsList(alerts: _viewModel.alerts);
```

### 8. Updated main.dart
**Location**: `lib/main.dart`

- ✅ Updated import to new `LoginScreen` location
- ✅ No other changes (only imports)

## Data Flow

### Login Flow
```
User enters credentials → LoginScreen calls loginViewModel.login()
  ↓
LoginViewModel.login() calls AuthService.login()
  ↓
AuthService makes HTTP POST request to backend
  ↓
Backend returns token
  ↓
LoginViewModel calls TokenService.saveToken(token)
  ↓
TokenService writes token to secure storage
  ↓
LoginViewModel notifies listeners (isSuccess = true)
  ↓
LoginScreen detects state change via AnimatedBuilder
  ↓
LoginScreen navigates to DashboardScreen
```

### Dashboard Load Flow
```
DashboardScreen.initState() → calls dashboardViewModel.initializeDashboard()
  ↓
DashboardViewModel calls TokenService.getToken()
  ↓
DashboardViewModel calls AlertService.fetchAlerts()
  ↓
AlertService uses TokenService.getToken() for authorization
  ↓
AlertService makes HTTP GET request with Bearer token
  ↓
Backend returns alerts
  ↓
DashboardViewModel sets alerts state and notifies listeners
  ↓
DashboardScreen detects state change via setState()
  ↓
DashboardScreen renders alerts list
```

### Logout Flow
```
User clicks logout → DashboardScreen calls dashboardViewModel.logout()
  ↓
DashboardViewModel calls TokenService.deleteToken()
  ↓
TokenService deletes token from secure storage
  ↓
DashboardScreen navigates to LoginScreen
```

## Benefits of This Architecture

### 1. **Separation of Concerns**
- UI doesn't know about API calls or storage
- ViewModels don't know about UI frameworks
- Services don't know about business logic

### 2. **Testability**
- UI components can be tested with mock ViewModels
- ViewModels can be tested with mock Services
- Services can be tested independently

### 3. **Reusability**
- Services can be used by multiple ViewModels
- ViewModels can be reused with different UIs
- TokenService is centralized and reusable

### 4. **Maintainability**
- Changes to API only affect Services
- Changes to business logic only affect ViewModels
- UI changes don't ripple through the codebase

### 5. **Scalability**
- Easy to add new screens (create Screen + ViewModel + wire up)
- Easy to add new services (just implement the service interface)
- No tight coupling makes refactoring safe

## Best Practices Implemented

✅ **Single Responsibility Principle**: Each class has one reason to change
✅ **Dependency Injection**: Services are injectable, not created globally
✅ **Clear Data Flow**: Unidirectional UI → ViewModel → Service
✅ **Error Handling**: Errors flow back through ViewModel to UI
✅ **State Management**: ChangeNotifier pattern (no extra packages needed)
✅ **Minimal Dependencies**: Uses built-in Flutter patterns, no external packages for MVVM

## Migration Notes

### What Changed
- Moved UI screens to `ui/screens/`
- Created `services/` layer with TokenService
- Created `viewmodels/` layer
- Updated imports across the project

### What Stayed the Same
- API endpoints (auth_service.dart, alert_service.dart API URLs)
- Models (LoginResult)
- Config (AppConfig)
- Routing (routing/ directory)
- CameraWidget and other widgets

### Files Removed
- `lib/ui/auth/` (screens moved to `ui/screens/`)
- `lib/ui/dashboard_screen.dart` (moved to `ui/screens/dashboard_screen.dart`)
- `lib/data/` (services moved to `lib/services/`)

## Next Steps

### To Add More Features
1. Create a new Service for the API calls
2. Create a new ViewModel for business logic
3. Create a new Screen that uses the ViewModel
4. Hook up navigation in routing/

### To Add Testing
1. Create a `test/` directory
2. Write unit tests for ViewModels (mock Services)
3. Write unit tests for Services (mock HTTP)
4. Write widget tests for Screens (mock ViewModels)

### To Improve Further
1. Consider adding Provider package for simpler state management
2. Add error handling with custom exceptions
3. Create a BaseViewModel for common logic
4. Implement app-wide error handling

## Example: Adding a New Feature

To add a new "Room Control" feature:

```dart
// 1. Create Service
lib/services/room_service.dart
Future<List<Room>> getRooms()
Future<void> controlRoom(String roomId, String command)

// 2. Create ViewModel
lib/viewmodels/room_viewmodel.dart
Future<void> loadRooms()
Future<void> control(String roomId, String command)

// 3. Create Screen
lib/ui/screens/room_screen.dart
RoomScreen(roomViewModel) → renders based on ViewModel state

// 4. Add Route
routing/router.dart → add RoomScreen route

// 5. Add Navigation
Add button in DashboardScreen to navigate to RoomScreen
```

That's it! No changes to existing code, just add new layers.
