# Authentication Architecture

## Overview

The authentication system has been refactored for better separation of concerns and maintainability:

## Structure

```
AuthManager (UI State Management)
├── AuthStateManager (State Management)
├── AuthBusinessLogic (Business Logic)
└── AuthService (API Facade)
    ├── SupabaseAuthProvider (Supabase Integration)
    └── GoogleAuthProvider (Google Integration)
```

## Usage Examples

### Using the Unified SignIn Method

```swift
// Email/Password
let request = AuthSignInRequest.emailPassword(email: email, password: password)
let token = try await authService.signIn(request: request)

// Magic Link
let request = AuthSignInRequest.magicLink(
    email: email,
    redirectTo: URL(string: "zunloapp://auth")
)
try await authService.signIn(request: request) // Doesn't return token immediately

// Google
let request = AuthSignInRequest.google(viewController: viewController)
let token = try await authService.signIn(request: request)

// Anonymous
let request = AuthSignInRequest.anonymous
let token = try await authService.signIn(request: request)
```

### Legacy Methods (Still Supported)

```swift
// These methods are still available for backward compatibility
try await authService.signIn(email: email, password: password)
try await authService.signInWithGoogle(viewController: viewController)
try await authService.signInAnonymously()
```

## Benefits

1. **Single Responsibility**: Each class has a focused purpose
2. **Provider Abstraction**: Easy to add new auth providers
3. **Unified Interface**: One method for all sign-in types
4. **Better Testing**: Business logic separated from UI state
5. **Maintainability**: Clear separation makes code easier to understand and modify