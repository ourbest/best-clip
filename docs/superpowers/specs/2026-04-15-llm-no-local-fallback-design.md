# LLM Failure Handling Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make LLM request failures visible to the user instead of silently falling back to a local recommendation, so they can fix provider settings when generation fails.

**Architecture:** Keep the current pipeline entry point, but remove the silent fallback path for remote recommendation failures. If the app has no API key, it can still use the existing local fallback path for now; if a configured LLM request fails at runtime, the error should propagate into the generation flow. `GenerationFlowViewModel` will surface that failure as a visible error state and offer a settings entry point so the user can correct `provider`, `baseURL`, `modelName`, or `apiKey`. The rest of the export pipeline remains unchanged.

**Tech Stack:** Swift, SwiftUI, Foundation, XCTest.

---

## Desired Behavior

- When an API key is configured and the LLM request fails, generation should stop and show an error.
- The UI should not silently swap to a local recommendation.
- The user should be able to go to Settings from the failure state and edit LLM configuration.
- Existing local fallback for missing configuration can remain unchanged unless explicitly removed later.

## Implementation Notes

- Remove the silent catch-and-fallback behavior from `MemoryVideoPipeline`.
- Make `GenerationFlowViewModel.generatePreviewExportAsync()` handle thrown recommendation errors and publish a user-facing error string.
- Add a generation error state to the UI so the user can see what failed and navigate to Settings.

## Testing Plan

- Add a pipeline test proving remote recommendation failures throw instead of returning a fallback recommendation.
- Add a view model test proving the failure is surfaced to UI state.
- Keep the existing no-API-key fallback test intact.

