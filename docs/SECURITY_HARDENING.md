# Security Hardening Implementation

This document describes the security hardening features implemented in SublerPlus.

## 1. App Sandbox Implementation

### Entitlements File
Created `App/SublerPlus.entitlements` with the following security restrictions:

- **App Sandbox Enabled**: Full sandboxing enabled for production releases
- **Network Restrictions**: 
  - Outgoing network connections only (no inbound except localhost)
  - Localhost server allowed for WebUI
  - App Transport Security exceptions for specific provider domains:
    - `api.theporndb.net` (ThePornDB)
    - `api.themoviedb.org` (TMDB)
    - `image.tmdb.org` (TMDB Images)
    - `api4.thetvdb.com` (TVDB)
    - `opensubtitle.p.rapidapi.com` (OpenSubtitles)
- **File Access**: 
  - User-selected files only (via `NSOpenPanel`/`NSSavePanel`)
  - Security-scoped bookmarks for persistent access
- **Security Features**:
  - JIT compilation disabled
  - Unsigned executable memory disabled
  - Library validation bypass disabled
- **Keychain Access**: Explicit entitlement for secure key storage

### Build Integration
- Build script updated to copy entitlements file to app bundle
- Code signing with entitlements (when `codesign` is available)
- Entitlements applied at runtime if code signing fails

## 2. Mandatory WebUI Token Authentication

### Changes Made

1. **WebServer Initialization**:
   - `requireAuth` parameter defaults to `true`
   - Authentication is now mandatory by default
   - Server will not start properly without a token (warnings shown)

2. **UI Enhancements**:
   - Settings view shows "REQUIRED" label for WebUI token
   - Red border on token field when empty
   - Warning banner when token is not set
   - Success indicator when token is configured
   - Clear messaging about token requirement

3. **Status Messages**:
   - Warning message in status stream if token is missing
   - Clear error messages for unauthorized requests
   - Guidance on setting token in Settings

4. **Authorization Logic**:
   - All API endpoints require authentication
   - Health check endpoint allows access (for monitoring)
   - Clear 401 responses with "Token required" message

### Migration Notes
- Existing installations will see warnings until token is set
- Token can be generated automatically via Settings
- Token rotation reminders shown in UI

## 3. Additional Authentication for Shared Machines

### Session Token Authentication

1. **Session Token Endpoint** (`/api/session`):
   - Requires main authentication token to obtain session token
   - Returns a UUID-based session token
   - Session tokens expire after 1 hour
   - Automatic cleanup of expired sessions

2. **Session Token Usage**:
   - Use `X-Session-Token` header instead of `X-Auth-Token`
   - Reduces exposure of main token
   - Suitable for shared machine scenarios
   - Tokens automatically expire for security

3. **IP Whitelist Support**:
   - Infrastructure for IP-based access control
   - Currently allows all localhost requests (server bound to 127.0.0.1)
   - Can be extended for specific IP ranges in future

### Usage Example

```javascript
// Step 1: Get session token with main token
const response = await fetch('/api/session', {
  headers: {
    'X-Auth-Token': 'your-main-token',
    'Content-Type': 'application/json'
  }
});
const { sessionToken, expiresIn } = await response.json();

// Step 2: Use session token for subsequent requests
const apiResponse = await fetch('/api/status', {
  headers: {
    'X-Session-Token': sessionToken,
    'Content-Type': 'application/json'
  }
});
```

## Security Benefits

### App Sandbox
- **Reduced Attack Surface**: App can only access user-selected files
- **Network Isolation**: Only allowed domains can be accessed
- **Memory Protection**: JIT and unsigned memory disabled
- **Compliance**: Meets Apple's security requirements for distribution

### Mandatory Authentication
- **Prevents Unauthorized Access**: WebUI cannot be accessed without token
- **Clear Security Posture**: Users know authentication is required
- **Reduced Risk**: No accidental exposure of WebUI

### Session Tokens
- **Reduced Token Exposure**: Main token not used for every request
- **Time-Limited Access**: Sessions expire automatically
- **Shared Machine Safety**: Better security for multi-user environments
- **Audit Trail**: Session tokens can be tracked and revoked

## Testing

Security tests updated to verify:
- Authentication requirement enforcement
- Session token validation
- Content type and body size validation
- IP whitelist checking (when applicable)

Run security tests with:
```bash
swift test --filter Security
```

## Configuration

### Required Settings
1. **WebUI Token**: Must be set in Settings for WebUI to function
2. **API Keys**: Stored securely in Keychain

### Optional Settings
- Token rotation reminders (shown in UI)
- Session token expiry (default: 1 hour)

## Migration Guide

### For Existing Users
1. Open Settings
2. Generate or enter WebUI token
3. Save settings
4. WebUI will now require authentication

### For New Installations
1. Token is required from first launch
2. Generate token in Settings before using WebUI
3. Use session tokens for shared machine scenarios

## Future Enhancements

Potential future security improvements:
- IP-based access control configuration UI
- Session token management UI
- Token rotation automation
- Audit logging for security events
- Two-factor authentication support

