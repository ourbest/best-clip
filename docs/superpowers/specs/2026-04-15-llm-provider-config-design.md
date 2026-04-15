# LLM Provider Configuration Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit LLM provider configuration so the app can target OpenAI, Anthropic, or compatible endpoints with editable `baseURL`, `modelName`, and `apiKey` settings.

**Architecture:** Keep recommendation generation behind a single pipeline entry point, but move provider selection into settings and client construction. `SettingsStore` owns persisted provider metadata and connection defaults, `SettingsView` exposes editable provider/base URL fields, and `GenerationFlowViewModel` turns those settings into a configured client. The transport layer stays generic: `LLMClient` continues to send a chat-completions-style request to the configured base URL, while the pipeline retains its current local fallback when no API key is configured.

**Tech Stack:** Swift, SwiftUI, Foundation, XCTest, Keychain-backed local storage.

---

## Problem Statement

The current app can already call a remote model, but the configuration surface is incomplete:

- The settings UI only exposes `modelName` and `apiKey`.
- The network base URL is hard-coded to the OpenAI endpoint.
- There is no clear way to configure provider presets for OpenAI or Anthropic.

This makes it hard to target compatible gateways or provider-specific endpoints without editing code.

## Proposed Design

### Settings model

Persist four values:

- `provider`: a user-facing preset that can be `openAI` or `anthropic`
- `baseURL`: editable URL text, always available to the user
- `modelName`: the model identifier to send to the provider
- `apiKey`: stored in Keychain, never written to the plain JSON settings file

`provider` only seeds defaults. It does not restrict `baseURL`, so the user can point either provider preset at a compatible proxy or gateway.

### UI

The settings screen will show:

- a provider picker
- an editable base URL field
- a model name field
- an API key field

Selecting a provider updates the base URL field with a sensible default:

- OpenAI -> `https://api.openai.com`
- Anthropic -> `https://api.anthropic.com`

The field remains editable after the default is inserted.

### Client construction

`GenerationFlowViewModel` will create the recommendation client from the saved settings:

- if `apiKey` is empty, keep the current local fallback behavior
- otherwise, create `LLMClient` with the configured `baseURL`, `modelName`, and `apiKey`

`LLMClient` remains generic and does not need provider-specific branching for this change.

### Compatibility expectations

This change intentionally keeps request format assumptions stable. The initial implementation will continue using the current chat-completions request shape against the configured endpoint. That is sufficient for OpenAI and for OpenAI-compatible gateways. Anthropic can be configured with a provider preset and custom `baseURL`, but if its response shape diverges from the current parser, that will be addressed as a separate follow-up.

## Out of Scope

- Provider-specific response parsing differences beyond the current chat-completions flow
- Automatic provider detection
- Secret sync across devices
- Multiple saved accounts

## Error Handling

- If the base URL is missing or malformed, the app should keep the current local fallback path rather than crashing.
- If the remote request fails, the existing pipeline fallback remains in place.
- Settings save/load should continue to tolerate missing or legacy files.

## Testing Plan

Add tests that cover:

- settings persistence for provider and base URL
- provider selection with default base URL values
- editable base URL surviving save/reload
- pipeline client construction using the configured endpoint
- fallback behavior when API key is absent

## Implementation Order

1. Extend the settings storage model and its tests.
2. Update the settings UI to edit provider and base URL.
3. Change pipeline construction to use the configured endpoint.
4. Add tests for provider/base URL persistence and client selection.
5. Verify the existing generation and fallback flows still behave correctly.

