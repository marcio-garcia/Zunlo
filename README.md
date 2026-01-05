# Zunlo

Zunlo is an iOS productivity app that combines tasks, calendar events, reminders, and an AI assistant to help plan your day and keep work organized.

## Features

- Task inbox with priorities, tags, and reminders
- Calendar events with recurring rules and overrides
- AI chat and suggestions to create, update, and plan tasks/events
- Local-first storage with background sync
- Push notifications and optional location context

## Tech Stack

- Swift + Swift Concurrency
- SwiftUI (primary UI) with some UIKit views
- Realm (local persistence)
- Supabase (auth, database sync, edge functions)
- Firebase Messaging (push tokens)
- Google Sign-In
- AdMob via AdStack
- In-repo packages: FlowNavigator, GlowUI, SmartParseKit, LoggingKit, ZunloHelpers

## Requirements

- Xcode with the iOS 17 SDK
- iOS 17.0 deployment target

## Setup and Run

1. Open `Zunlo.xcodeproj` in Xcode.
2. Configure the app Info.plist values used at runtime:
   - `ENVIRONMENT` (DEVELOPMENT, STAGING, PRODUCTION)
   - `API_PROTOCOL` (https)
   - `API_BASE_URL` (your Supabase REST base, without protocol)
   - `API_FUNCTIONS_BASE_URL` (your Supabase Functions base, without protocol)
   - `API_KEY` (Supabase anon key)
   - `GOOGLE_OAUTH_CLIENT_ID` (if using Google Sign-In)
   - `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID`, `ADMOB_REWARDED_ID` (if ads are enabled)
3. Add Firebase config files to the app target bundle:
   - `GoogleService-Info-dev.plist` (dev)
   - `GoogleService-Info-stg.plist` (staging)
   - `GoogleService-Info.plist` (prod)
4. Build and run the `Zunlo` scheme on a simulator or device.

## Project Layout (high level)

- `Zunlo/` - main app code (UI, domain, data, services)
- `ZunloTests/`, `ZunloUITests/` - test targets
- `SupabaseSDK/`, `SmartParseKit/`, `AdStack/`, `GlowUI/`, `FlowNavigator/`, `LoggingKit/`, `ZunloHelpers/` - local packages

