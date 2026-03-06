---
title: CurrentFileAbbreviated
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CurrentFileAbbreviated.idechatprompttemplate
original_filename: CurrentFileAbbreviated.idechatprompttemplate
---

# CurrentFileAbbreviated

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CurrentFileAbbreviated.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

The user is currently inside this file: {{ currentFile.fileName }}
Unfortunately, this file is too big to read in full. Doing so will consume your entire context window. `{{ currentFile.fileName }}` is {{ currentFile.lineCount }} lines long.

Instead of seeing the whole file now, try using your `view` tool to view smaller line ranges of the file, looking for the information you need to do your job.
