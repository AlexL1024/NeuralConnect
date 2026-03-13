# Privacy Policy — NeuralConnect

**Last updated: 2026-03-13**

## Overview

NeuralConnect is a single-player narrative game. We are committed to protecting your privacy. This policy explains what data the app collects, how it is used, and your rights.

## Data Collection

### Data We Do NOT Collect
- We do not collect your name, email, phone number, or any personal identification information.
- We do not track your location.
- We do not use analytics or advertising SDKs.
- We do not create user accounts.

### Data Processed During Gameplay
To generate AI-driven NPC dialogue, the app sends **in-game character conversation context** (fictional NPC names, dialogue lines, and narrative prompts) to the following third-party services:

- **DeepSeek API** (deepseek.com) — cloud-based language model for NPC dialogue generation.
- **EverMemOS API** (evermemos.com) — NPC memory storage service for maintaining character narrative state.

**No personal user data is included in these requests.** Only fictional game content (NPC names, in-game dialogue, character memory seeds) is transmitted.

If your device supports Apple Intelligence (iOS 26+), on-device language models may also be used. In that case, dialogue generation happens entirely on your device with no data sent externally.

## Data Storage

- API configuration tokens are stored locally on your device using the iOS Keychain.
- NPC memory data is stored on the EverMemOS service and is associated with fictional character IDs, not with any real user identity.
- No data is stored on our own servers.

## Third-Party Services

| Service | Purpose | Privacy Policy |
|---------|---------|---------------|
| DeepSeek | NPC dialogue generation | https://www.deepseek.com/privacy |
| EverMemOS | NPC memory persistence | https://evermemos.com/privacy |

## Children's Privacy

NeuralConnect is not directed at children under 13. We do not knowingly collect data from children.

## Your Rights

Since we do not collect personal data, there is no personal data to access, modify, or delete. You can clear all NPC memory data at any time from the in-game Settings menu.

## Changes to This Policy

We may update this policy from time to time. Changes will be reflected in the "Last updated" date above.

## Contact

If you have questions about this privacy policy, please open an issue at:
https://github.com/AlexL1024/NeuralConnect/issues
